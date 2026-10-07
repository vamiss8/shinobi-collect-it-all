--!strict
-- The figures that stand for shinobi and enemies in the world.
--
-- A figure is a real model when one has been supplied, and a placeholder otherwise. To supply
-- one, put a Model (or a single MeshPart) into ReplicatedStorage.Models (in Studio) named after
-- the character's id from Config/Characters, e.g. "kakashi", or "enemy_" plus a zone id from
-- Config/Zones for that zone's enemy. It is cloned, scaled to a standard height and stood on
-- its feet; nothing else in the game needs to change. A model that turns out to stand with its
-- back to the viewer is turned around by giving it a boolean attribute "Flip" set to true; if
-- they all do, the same attribute on the Models folder turns every one of them.
-- The placeholder is a block body in the rank's color with a head.
--
-- Shared because the server stands figures on pads and the client rolls them in the reveal.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Aura = require("./Aura")
local Build = require("./Build")
local Catalog = require("../Config/Catalog")
local Economy = require("../Logic/Economy")
local Format = require("../Logic/Format")
local Net = require("../Net")

local Figure = {}

local UNIT_HEIGHT = 4.8
local ENEMY_HEIGHT = 9.3
-- A figure's tag: how tall a line of it is, how wide the tag, and how far over the figure's
-- head its lower edge floats, all in studs.
local TAG_LINE = 1.3
local TAG_WIDTH = 13
local TAG_GAP = 0.4
local TAG_ANCHOR = "TagAnchor"

-- How high over a carrier's root a carried figure's feet are.
Figure.CARRY_HEIGHT = 3.5
-- How tall a shinobi's figure stands.
Figure.HEIGHT = UNIT_HEIGHT
local SKIN = Color3.fromRGB(255, 219, 172)

function Figure.title(unit: Economy.Unit): string
	return Catalog.unitTitle(unit.character, unit.mutation, unit.level, unit.upgrade)
end

-- The tag above a figure, top to bottom: mutation (if any), rank, name with merge stars, level
-- with income, and for an upgraded unit its base income: what it earned at level 1, which is
-- what tells a strong unit from a weak one that was merely leveled up. Returns the text and
-- how many lines it has.
local function tag(unit: Economy.Unit): (string, number)
	local character = Catalog.characterById[unit.character]
	local rank = if character then Catalog.ranks[Catalog.rankOrder[character.rank]] else nil
	local mutation = Catalog.mutationById[unit.mutation]

	local lines = {}
	if mutation then
		table.insert(lines, `<font color="{mutation.color}">{string.upper(mutation.name)}</font>`)
	end
	if rank then
		table.insert(lines, `<font color="{rank.color}">{rank.name}</font>`)
	end
	local name = if character then character.name else unit.character
	if unit.level > 1 then
		name ..= ` <font color="#FFD54F">{Catalog.stars(unit.level)}</font>`
	end
	table.insert(lines, name)
	local upgrades = unit.upgrade or 0
	table.insert(lines, `Lvl {upgrades + 1} · {Format.short(Economy.unitIncome(unit))}/s`)
	if upgrades > 0 then
		local base = Format.short(Economy.baseIncome(unit))
		table.insert(lines, `<font color="#BDBDBD">Base: {base}/s</font>`)
	end
	return table.concat(lines, "\n"), #lines
end

-- A supplied model by name, made safe to show: frozen in place, untouchable, scripts removed,
-- scaled to `height` and with its pivot at its feet. Nil if no such model was supplied.
local function supplied(name: string, height: number): Model?
	local folder = ReplicatedStorage:FindFirstChild(Net.MODELS_FOLDER)
	local template = if folder then folder:FindFirstChild(name) else nil
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
	elseif template and template:IsA("BasePart") then
		-- An importer may hand over a single mesh with no model around it.
		model = Instance.new("Model")
		template:Clone().Parent = model
	else
		return nil
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
		elseif item:IsA("LuaSourceContainer") then
			-- Models from outside may carry scripts; a figure never needs one.
			item:Destroy()
		elseif item:IsA("Humanoid") then
			item.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end

	model.PrimaryPart = nil
	local _, size = model:GetBoundingBox()
	if size.Y <= 0 then
		model:Destroy()
		return nil
	end
	model:ScaleTo(model:GetScale() * height / size.Y)
	local box = model:GetBoundingBox()
	local feet = CFrame.new(box.Position - Vector3.new(0, height / 2, 0))
	-- The folder's attribute turns every figure around; a figure's own turns it once more.
	local allTurned = folder ~= nil and folder:GetAttribute(Net.FLIP_ATTRIBUTE) == true
	if allTurned ~= (template:GetAttribute(Net.FLIP_ATTRIBUTE) == true) then
		feet *= CFrame.Angles(0, math.pi, 0)
	end
	model.WorldPivot = feet
	model:PivotTo(CFrame.new())
	return model
end

-- The stand-in for a shinobi without a model: a block body in the rank's color and a head.
local function placeholderUnit(color: Color3): Model
	local model = Instance.new("Model")
	local body = Build.part(model, "Body", Vector3.new(2, 3, 1.2), Vector3.new(0, 1.5, 0), color)
	body.PivotOffset = CFrame.new(0, -1.5, 0)
	model.PrimaryPart = body
	local head = Build.part(model, "Head", Vector3.new(1.8, 1.8, 1.8), Vector3.new(0, 3.9, 0), SKIN)
	head.Shape = Enum.PartType.Ball
	return model
end

-- The stand-in for an enemy without a model: a big block body with a glowing head.
local function placeholderEnemy(color: Color3): Model
	local model = Instance.new("Model")
	local body = Build.part(model, "Body", Vector3.new(4, 6, 2.6), Vector3.new(0, 3, 0), color)
	body.PivotOffset = CFrame.new(0, -3, 0)
	model.PrimaryPart = body
	local head = Build.part(
		model,
		"Head",
		Vector3.new(3.4, 3.4, 3.4),
		Vector3.new(0, 7.6, 0),
		Color3.fromRGB(198, 40, 40),
		Enum.Material.Neon
	)
	head.Shape = Enum.PartType.Ball
	return model
end

-- An invisible part at the top of a figure standing at the origin, to hang its label on.
local function topAnchor(model: Model, height: number): Part
	local anchor = Build.part(
		model,
		TAG_ANCHOR,
		Vector3.new(0.2, 0.2, 0.2),
		Vector3.new(0, height, 0),
		Color3.new(1, 1, 1)
	)
	anchor.Transparency = 1
	return anchor
end

local function untouchable(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
		end
	end
end

-- Builds a shinobi standing at the world origin. Its pivot is at its feet, so
-- `figure:PivotTo(cframe)` stands it on that point.
function Figure.build(unit: Economy.Unit): Model
	local character = Catalog.characterById[unit.character]
	local rank = if character then Catalog.ranks[Catalog.rankOrder[character.rank]] else nil
	local rankColor = if rank then Color3.fromHex(rank.color) else Color3.new(1, 1, 1)
	local mutation = Catalog.mutationById[unit.mutation]

	local model = supplied(unit.character, UNIT_HEIGHT) or placeholderUnit(rankColor)
	model.Name = Figure.title(unit)

	if mutation then
		Aura.attach(model, mutation, UNIT_HEIGHT)
	end

	-- The tag grows upwards with its line count; its bottom edge stays just above the head.
	local text, lineCount = tag(unit)
	local height = TAG_LINE * lineCount
	Build.label(
		topAnchor(model, UNIT_HEIGHT),
		text,
		TAG_GAP + height / 2,
		Vector2.new(TAG_WIDTH, height)
	)

	untouchable(model)
	return model
end

-- Rewrites the tag of a figure that is already standing, for a unit that has changed but is
-- the same shinobi: after an upgrade its level and income read differently. The figure itself
-- is left alone; built anew it would be gone for a moment.
function Figure.retag(figure: Model, unit: Economy.Unit)
	figure.Name = Figure.title(unit)
	local anchor = figure:FindFirstChild(TAG_ANCHOR)
	local gui = if anchor then anchor:FindFirstChildOfClass("BillboardGui") else nil
	local label = if gui then gui:FindFirstChildOfClass("TextLabel") else nil
	if gui and label then
		local text, lineCount = tag(unit)
		local height = TAG_LINE * lineCount
		gui.Size = UDim2.fromScale(TAG_WIDTH, height)
		gui.StudsOffset = Vector3.new(0, TAG_GAP + height / 2, 0)
		label.Text = text
	end
end

-- A character's supplied model and nothing else: no tag, no aura. It stands at the world's
-- origin with its feet on it, Figure.HEIGHT tall, its face to -Z. Nil when no model has been
-- supplied for the character. For portraits (client/Portrait).
function Figure.bare(characterId: string): Model?
	return supplied(characterId, UNIT_HEIGHT)
end

-- Builds a zone's enemy standing at the world origin, pivot at its feet.
function Figure.enemy(zone: Catalog.Zone): Model
	local model = supplied(Net.ENEMY_MODEL .. zone.id, ENEMY_HEIGHT)
		or placeholderEnemy(Color3.fromHex(zone.enemy.color))
	model.Name = zone.enemy.name
	Build.label(
		topAnchor(model, ENEMY_HEIGHT),
		`<font color="#FF5252">{zone.enemy.name}</font>`,
		2.4,
		Vector2.new(18, 4)
	)
	untouchable(model)
	return model
end

-- Carries the figure above a character's head. The whole figure hangs from the character's
-- root on one joint, so that it can be turned as one piece: every client turns the joint to
-- make the figure face its own camera (client/Carried finds it by its tag). Until a client
-- does, the figure looks back over its carrier's shoulder, where the camera usually is.
--
-- (Each of its parts used to be welded to the root as it stood, face forward: whoever carried
-- a shinobi saw its back, and it turned with every turn of the carrier.)
function Figure.attach(figure: Model, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local seat = CFrame.new(0, Figure.CARRY_HEIGHT, 0) * CFrame.Angles(0, math.pi, 0)
	figure:PivotTo(root.CFrame * seat)

	-- An unseen piece at the figure's feet that everything else of it is fixed to.
	local handle = Build.part(figure, "CarryHandle", Vector3.new(0.2, 0.2, 0.2), Vector3.zero, SKIN)
	handle.CFrame = root.CFrame * seat
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	for _, part in figure:GetDescendants() do
		if part:IsA("BasePart") and part ~= handle then
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
			part.Anchored = false
		end
	end

	local joint = Instance.new("Weld")
	joint.Name = Net.CARRY_TAG
	joint.Part0 = root
	joint.Part1 = handle
	joint.C0 = seat
	joint.Parent = handle
	handle.Anchored = false
	CollectionService:AddTag(joint, Net.CARRY_TAG)
	figure.Parent = character
end

return Figure
