--!strict
-- Checks the models that were supplied in ReplicatedStorage.Models, and on request stands all of
-- them up to be looked over.
--
-- The check runs at every start and prints to the Output window: how many of the shinobi,
-- enemies, kunai and shopkeepers have a model, which are missing, which names it does not know, and which
-- models look wrong (lying on their side, not long and thin for a kunai).
--
-- The showroom is for after an import: in a Studio test, with the boolean attribute "Showroom"
-- set to true on the Models folder, every shinobi and enemy is stood on the lane, a row per
-- zone, facing the throwing strip, with the kunai hung in the air in front of them, each with
-- its effects, and the market's shopkeepers in a row of their own in front. Whoever has no
-- model yet is there as a placeholder. A number attribute "Kunai" on the folder hands the
-- tester the kunai at that place in the store, to throw one they have not bought; a number
-- attribute "Speed" gives them that many levels of run speed, so that every speed stage can
-- be tried on their own character at the Youth Training Ground; and with a boolean attribute
-- "Auras" the showroom's shinobi wear the mutations in turn, none first and then from the
-- commonest to the rarest, so that every aura and every lettering of a name can be looked over
-- without rolling for it. None of it ever happens on a live server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Data = require("../Data")
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Hub = require("./Hub")
local KunaiModel = require(ReplicatedStorage.Shared.View.KunaiModel)
local Net = require(ReplicatedStorage.Shared.Net)
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Showroom = {}

-- A figure wider than this many times its height is taken to be lying down. Enemies are not
-- held to it: a snake or a beast may well be wider than it is tall.
local LYING = 1.7
-- A kunai's longest side is at least this many times its next longest, or it is not lying along
-- one axis.
local SLENDER = 1.8

-- Where the showroom's rows stand, in Hub-local studs.
local KUNAI_WALL = Tuning.Kick.stripDepth + 10
local KUNAI_COLUMNS = 5
local KUNAI_GAP = 12 -- between kunai in a row: room for what streams off each
local KUNAI_FLOOR = 2.5 -- the lowest row hangs this high
local KUNAI_RISE = 3.5 -- and each row above it this much higher
local FIRST_ROW = Tuning.Kick.stripDepth + 26
local ROW_GAP = 10
local ENEMY_SIDE = -25
local FIRST_SHINOBI = -13
local SHINOBI_GAP = 9.5

type Kind = "shinobi" | "enemy" | "kunai" | "keeper"

-- A name as it would be without capitals, spaces and punctuation, to guess what a misnamed
-- model was meant to be.
local function plain(name: string): string
	return (string.gsub(string.lower(name), "[^%w]", ""))
end

local function sizeOf(template: Instance): Vector3?
	if template:IsA("Model") then
		local _, size = template:GetBoundingBox()
		return size
	elseif template:IsA("BasePart") then
		return template.Size
	end
	return nil
end

-- Prints what the models folder holds. Returns the folder, if there is one.
local function check(): Instance?
	local expected: { [string]: Kind } = {}
	local order: { string } = {}
	local function expect(name: string, kind: Kind)
		expected[name] = kind
		table.insert(order, name)
	end
	for _, character in Catalog.characters do
		expect(character.id, "shinobi")
	end
	for _, zone in Catalog.zones do
		expect(Net.ENEMY_MODEL .. zone.id, "enemy")
	end
	for _, kunai in Catalog.kunai do
		expect(Net.KUNAI_MODEL .. kunai.id, "kunai")
	end
	for _, keeper in Catalog.keepers do
		expect(keeper.id, "keeper")
	end

	local folder = ReplicatedStorage:FindFirstChild(Net.MODELS_FOLDER)
	if not folder then
		print(
			`[Models] no ReplicatedStorage.{Net.MODELS_FOLDER} folder: every figure is a placeholder`
		)
		return nil
	end

	local byPlain: { [string]: string } = {}
	for name in expected do
		byPlain[plain(name)] = name
	end

	local have: { [string]: boolean } = {}
	local found = { shinobi = 0, enemy = 0, kunai = 0, keeper = 0 }
	local total = { shinobi = 0, enemy = 0, kunai = 0, keeper = 0 }
	for _, kind in expected do
		total[kind] += 1
	end
	local notes: { string } = {}

	for _, template in folder:GetChildren() do
		local name = template.Name
		local kind = expected[name]
		if not kind then
			local guess = byPlain[plain(name)]
			table.insert(
				notes,
				if guess
					then `"{name}" is not a name the game knows: rename it to "{guess}"`
					else `"{name}" is not a name the game knows`
			)
			continue
		end
		if have[name] then
			table.insert(notes, `"{name}" is there twice: only one of them is used`)
			continue
		end
		local size = sizeOf(template)
		if not size or size.Magnitude <= 0 then
			table.insert(notes, `"{name}" is a {template.ClassName} with no parts: it is not used`)
			continue
		end
		have[name] = true
		found[kind] += 1

		if kind == "shinobi" and math.max(size.X, size.Z) > size.Y * LYING then
			table.insert(notes, `"{name}" is much wider than it is tall: is it lying down?`)
		elseif kind == "kunai" then
			local sides = { size.X, size.Y, size.Z }
			table.sort(sides)
			if sides[3] < sides[2] * SLENDER then
				table.insert(
					notes,
					`"{name}" is not long and thin along one axis: a kunai must not lie diagonally`
				)
			end
		end
	end

	print(
		`[Models] shinobi {found.shinobi}/{total.shinobi}, enemies {found.enemy}/{total.enemy},`
			.. ` kunai {found.kunai}/{total.kunai}, shopkeepers {found.keeper}/{total.keeper}`
	)
	-- The details are for whoever is importing; a live server's log does not need them.
	if not RunService:IsStudio() then
		return folder
	end
	local missing: { string } = {}
	for _, name in order do
		if not have[name] then
			table.insert(missing, name)
		end
	end
	if #missing > 0 then
		print(`[Models] no model yet for: {table.concat(missing, ", ")}`)
	end
	for _, note in notes do
		warn(`[Models] {note}`)
	end
	return folder
end

-- Stands every figure and kunai on the lane.
local function parade(auras: boolean)
	-- What the shinobi wear, one after another, when their auras are to be looked over.
	local worn = { Catalog.NONE }
	for _, mutation in Catalog.mutations do
		if not mutation.event then
			table.insert(worn, mutation.id)
		end
	end
	local stood = 0

	local hall = Instance.new("Folder")
	hall.Name = "Showroom"
	-- Towards the throwing strip, where whoever is looking stands.
	local home = Vector3.new(-1, 0, 0)

	local function standAt(figure: Model, x: number, z: number)
		local at = Hub.at(x, 0, z)
		figure:PivotTo(CFrame.lookAt(at, at + home))
		figure.Parent = hall
	end

	-- The shopkeepers in the front row, where the shinobi's columns are.
	for place, keeper in Catalog.keepers do
		standAt(Figure.keeper(keeper), FIRST_ROW, FIRST_SHINOBI + (place - 1) * SHINOBI_GAP)
	end

	for row, zone in Catalog.zones do
		local x = FIRST_ROW + row * ROW_GAP
		local function stand(figure: Model, z: number)
			standAt(figure, x, z)
		end
		stand(Figure.enemy(zone), ENEMY_SIDE)
		for place, character in Catalog.charactersByRank[zone.rank] do
			local mutation = if auras then worn[stood % #worn + 1] else Catalog.NONE
			stood += 1
			local unit = { character = character.id, mutation = mutation, level = 1 }
			stand(Figure.build(unit), FIRST_SHINOBI + (place - 1) * SHINOBI_GAP)
		end
	end

	-- The kunai hang in the air past the strip like a wall of them, five to a row, the first
	-- at the top left: each seen from its broad side, tip to the right, with what streams off
	-- it in flight streaming off to the left. One without a model hangs there as a plain blade.
	-- The ribbon a kunai trails only shows on one that moves.
	local columns = KUNAI_COLUMNS
	local rows = math.ceil(#Catalog.kunai / columns)
	for place, kunai in Catalog.kunai do
		local column = (place - 1) % columns
		local row = (place - 1) // columns
		local at = Hub.at(
			KUNAI_WALL,
			KUNAI_FLOOR + (rows - 1 - row) * KUNAI_RISE,
			(column - (columns - 1) / 2) * KUNAI_GAP
		)
		local facing = CFrame.lookAt(at, at + Vector3.zAxis, home)
		local part = KunaiModel.build(place, facing)
		-- Fifteen lights side by side flood the wall and hide what hangs on it; a kunai in
		-- flight is alone with its own.
		local glow = part:FindFirstChildWhichIsA("PointLight")
		if glow then
			glow:Destroy()
		end
		part.Parent = hall
		Build.label(part, `{place}. {kunai.id}`, 1.2, Vector2.new(9, 0.9))
	end

	hall.Parent = Workspace
	print(
		"[Models] showroom is up: stand on the throwing strip and look down the lane. The kunai"
			.. " hang in the air right past it, the shopkeepers stand in the first row behind"
			.. " them and the shinobi with their enemies in the rows after, a zone to a row."
			.. " Shift+P is the free camera for a closer look"
	)
end

-- Whether a switch was set on the folder. Forgiving about how the attribute was put in: any
-- capitals, a ticked box or the word "true", and on a model in the folder as well as on the
-- folder itself, which is where a first try tends to leave it.
local function wanted(folder: Instance, switch: string): boolean
	local asked = string.lower(switch)
	local places = folder:GetChildren()
	table.insert(places, folder)
	for _, place in places do
		for name, value in place:GetAttributes() do
			if string.lower(name) == asked and (value == true or value == "true") then
				return true
			end
		end
	end
	return false
end

function Showroom.start()
	local folder = check()
	if not folder or not RunService:IsStudio() then
		return
	end
	-- The kunai to test with: a save in a Studio test lives in memory, so nothing real is
	-- touched.
	local testKunai = folder:GetAttribute(Net.TEST_KUNAI_ATTRIBUTE)
	if typeof(testKunai) == "number" then
		local place = math.clamp(math.floor(testKunai), 1, #Catalog.kunai)
		Data.onLoaded(function(_, data)
			data.kunai = place
		end)
		print(`[Models] this test throws kunai {place}, {Catalog.kunai[place].id}`)
	end
	-- The run speed to test with: every speed stage up to it can then be worn at the Youth
	-- Training Ground.
	local testSpeed = folder:GetAttribute(Net.TEST_SPEED_ATTRIBUTE)
	if typeof(testSpeed) == "number" then
		local level = math.clamp(math.floor(testSpeed), 0, Tuning.Speed.maxLevel)
		Data.onLoaded(function(_, data)
			data.speedLevel = level
			data.runAt = -1
		end)
		print(`[Models] this test has {level} levels of run speed`)
	end
	-- And the rebirths to test with: what they pay is on from the start.
	local testRebirths = folder:GetAttribute(Net.TEST_REBIRTHS_ATTRIBUTE)
	if typeof(testRebirths) == "number" then
		local count = Rebirth.done(testRebirths)
		Data.onLoaded(function(_, data)
			data.rebirths = count
		end)
		print(`[Models] this test has {count} rebirths done: {Rebirth.title(count)}`)
	end

	if wanted(folder, Net.SHOWROOM_ATTRIBUTE) then
		parade(wanted(folder, Net.TEST_AURAS_ATTRIBUTE))
	else
		print(
			`[Models] showroom is off. To stand every model on the lane: stop the test, select`
				.. ` the {Net.MODELS_FOLDER} folder in ReplicatedStorage, and under Properties >`
				.. ` Attributes add "{Net.SHOWROOM_ATTRIBUTE}" of type boolean with its box ticked`
		)
	end
end

return Showroom
