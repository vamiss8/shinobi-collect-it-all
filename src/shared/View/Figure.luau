--!strict
-- The figures that stand for shinobi and enemies in the world.
--
-- A figure is a real model when one has been supplied, and a placeholder otherwise. To supply
-- one, put a Model into ReplicatedStorage.Models (in Studio) named after the character's id from
-- Config/Characters, e.g. "kakashi", or "enemy_" plus a zone id from Config/Zones for that
-- zone's enemy. It is cloned, scaled to a standard height and stood on its feet; nothing else in
-- the game needs to change. The placeholder is a block body in the rank's color with a head.
--
-- Shared because the server stands figures on pads and the client rolls them in the reveal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require("./Build")
local Catalog = require("../Config/Catalog")
local Economy = require("../Logic/Economy")
local Format = require("../Logic/Format")
local Net = require("../Net")

local Figure = {}

local UNIT_HEIGHT = 4.8
local ENEMY_HEIGHT = 9.3
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
	if not template or not template:IsA("Model") then
		return nil
	end

	local model = template:Clone()
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
	model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, height / 2, 0))
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
		"TagAnchor",
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
		local glow = Build.part(
			model,
			"Glow",
			Vector3.new(7, 7, 7),
			Vector3.new(0, UNIT_HEIGHT / 2, 0),
			Color3.fromHex(mutation.color),
			Enum.Material.Neon
		)
		glow.Shape = Enum.PartType.Ball
		glow.Transparency = 0.8
		glow.CastShadow = false
	end

	-- The tag grows upwards with its line count; its bottom edge stays just above the head.
	local text, lineCount = tag(unit)
	local height = 1.3 * lineCount
	Build.label(topAnchor(model, UNIT_HEIGHT), text, 0.4 + height / 2, Vector2.new(13, height))

	untouchable(model)
	return model
end

-- Builds a zone's enemy standing at the world origin, pivot at its feet.
function Figure.enemy(zone: Catalog.Zone): Model
	local model = supplied(`enemy_{zone.id}`, ENEMY_HEIGHT)
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

-- Carries the figure above a character's head.
function Figure.attach(figure: Model, character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	figure:PivotTo(root.CFrame * CFrame.new(0, 3.5, 0))
	for _, part in figure:GetDescendants() do
		if part:IsA("BasePart") then
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
			part.Anchored = false
		end
	end
	figure.Parent = character
end

return Figure
