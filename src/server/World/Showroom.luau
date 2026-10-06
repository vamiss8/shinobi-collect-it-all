--!strict
-- Checks the models that were supplied in ReplicatedStorage.Models, and on request stands all of
-- them up to be looked over.
--
-- The check runs at every start and prints to the Output window: how many of the shinobi,
-- enemies and kunai have a model, which are missing, which names it does not know, and which
-- models look wrong (lying on their side, not long and thin for a kunai).
--
-- The showroom is for after an import: in a Studio test, with the boolean attribute "Showroom"
-- set to true on the Models folder, every shinobi and enemy is stood on the lane, a row per
-- zone, facing the throwing strip, with the kunai lined up in front of them. Whoever has no
-- model yet stands there as a placeholder. It never appears on a live server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Hub = require("./Hub")
local KunaiModel = require(ReplicatedStorage.Shared.View.KunaiModel)
local Net = require(ReplicatedStorage.Shared.Net)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Showroom = {}

-- A figure wider than this many times its height is taken to be lying down. Enemies are not
-- held to it: a snake or a beast may well be wider than it is tall.
local LYING = 1.7
-- A kunai's longest side is at least this many times its next longest, or it is not lying along
-- one axis.
local SLENDER = 1.8

-- Where the showroom's rows stand, in Hub-local studs.
local KUNAI_ROW = Tuning.Kick.stripDepth + 5
local FIRST_ROW = Tuning.Kick.stripDepth + 14
local ROW_GAP = 10
local ENEMY_SIDE = -25
local FIRST_SHINOBI = -13
local SHINOBI_GAP = 9.5
local KUNAI_GAP = 3

type Kind = "shinobi" | "enemy" | "kunai"

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
	local found = { shinobi = 0, enemy = 0, kunai = 0 }
	local total = { shinobi = 0, enemy = 0, kunai = 0 }
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
			.. ` kunai {found.kunai}/{total.kunai}`
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
local function parade()
	local hall = Instance.new("Folder")
	hall.Name = "Showroom"
	-- Towards the throwing strip, where whoever is looking stands.
	local home = Vector3.new(-1, 0, 0)

	for row, zone in Catalog.zones do
		local x = FIRST_ROW + (row - 1) * ROW_GAP
		local function stand(figure: Model, z: number)
			local at = Hub.at(x, 0, z)
			figure:PivotTo(CFrame.lookAt(at, at + home))
			figure.Parent = hall
		end
		stand(Figure.enemy(zone), ENEMY_SIDE)
		for place, character in Catalog.charactersByRank[zone.rank] do
			local unit = { character = character.id, mutation = Catalog.NONE, level = 1 }
			stand(Figure.build(unit), FIRST_SHINOBI + (place - 1) * SHINOBI_GAP)
		end
	end

	-- The kunai stand on their rings, tips up; one without a model is a gray stick.
	local first = -(#Catalog.kunai - 1) / 2 * KUNAI_GAP
	for place, kunai in Catalog.kunai do
		-- Each at the length it flies at.
		local length = KunaiModel.length(place)
		local at = Hub.at(KUNAI_ROW, length / 2 + 0.3, first + (place - 1) * KUNAI_GAP)
		local upright = CFrame.lookAt(at, at + Vector3.yAxis, home)
		local model = KunaiModel.supplied(kunai.id, length)
		local tagged: Instance
		if model then
			model:PivotTo(upright)
			model.Parent = hall
			tagged = model:FindFirstChildWhichIsA("BasePart", true) or model
		else
			local stick = Build.part(
				hall,
				kunai.id,
				Vector3.new(0.3, 0.3, length),
				at,
				Color3.fromRGB(120, 120, 120)
			)
			stick.CFrame = upright
			stick.CanCollide = false
			tagged = stick
		end
		-- Every other name hangs higher, so neighbors do not cover each other.
		Build.label(tagged, kunai.id, 2.6 + (place % 2) * 1.1, Vector2.new(6, 1))
	end

	hall.Parent = Workspace
	print(
		"[Models] showroom is up: stand on the throwing strip and look down the lane, the rows"
			.. " begin right past it. Shift+P is the free camera for a closer look"
	)
end

-- Whether the showroom was asked for. Forgiving about how the attribute was put in: any
-- capitals, a ticked box or the word "true", and on a model in the folder as well as on the
-- folder itself, which is where a first try tends to leave it.
local function wanted(folder: Instance): boolean
	local asked = string.lower(Net.SHOWROOM_ATTRIBUTE)
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
	if wanted(folder) then
		parade()
	else
		print(
			`[Models] showroom is off. To stand every model on the lane: stop the test, select`
				.. ` the {Net.MODELS_FOLDER} folder in ReplicatedStorage, and under Properties >`
				.. ` Attributes add "{Net.SHOWROOM_ATTRIBUTE}" of type boolean with its box ticked`
		)
	end
end

return Showroom
