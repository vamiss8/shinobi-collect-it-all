--!strict
-- The model of a kunai, when one has been supplied. To supply one, put a Model or a MeshPart
-- into ReplicatedStorage.Models (in Studio) named "kunai_" plus the kunai's id from
-- Config/Kunai, e.g. "kunai_steel". It is cloned, scaled to a set length and pointed along its
-- longest side, so it has to lie along one of its own axes, not across them. If it turns out
-- to fly ring first, give it a boolean attribute "Flip" set to true; if they all do, give the
-- Models folder a boolean attribute "FlipKunai" instead.
--
-- Shared because the client flies kunai and the server hangs them in the showroom.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require("../Config/Catalog")
local KunaiEffects = require("./KunaiEffects")
local Net = require("../Net")

local KunaiModel = {}

-- How long a kunai is in the world, studs: the first one in the store, and how much longer
-- each next one is. A character is about five studs tall, so a kunai is a short sword's length:
-- larger than life, as it has to be to be seen from the camera that chases it, but never
-- longer than whoever threw it. The last of the nineteen is 3.9 studs. What sets a better
-- kunai apart is mostly its effects (View/KunaiEffects), not its size.
local FIRST_LENGTH = 2.8
local GROWTH = 0.022

-- The length of the kunai at this place in the store (Config/Kunai), studs.
function KunaiModel.length(tier: number): number
	return FIRST_LENGTH * (1 + GROWTH * (math.max(tier, 1) - 1))
end

-- The supplied model of a kunai, made safe to show and scaled to `length`, or nil if there is
-- none. Its pivot is put in its middle, looking along its longest side with its thinnest side
-- up: pivoting it to a CFrame points the blade the way that CFrame looks and lays the flat of
-- the blade towards that CFrame's up.
function KunaiModel.supplied(id: string, length: number): Model?
	local folder = ReplicatedStorage:FindFirstChild(Net.MODELS_FOLDER)
	local template = if folder then folder:FindFirstChild(Net.KUNAI_MODEL .. id) else nil
	if not template then
		return nil
	end

	local model: Model
	if template:IsA("Model") then
		model = template:Clone()
	elseif template:IsA("BasePart") then
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
			item.CastShadow = false
		elseif item:IsA("LuaSourceContainer") then
			-- Models from outside may carry scripts; a kunai never needs one.
			item:Destroy()
		end
	end

	-- Without a primary part the bounding box is measured along the world's axes.
	model.PrimaryPart = nil
	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest <= 0 then
		model:Destroy()
		return nil
	end
	model:ScaleTo(model:GetScale() * length / longest)

	local box, scaled = model:GetBoundingBox()
	local sides = {
		{ axis = Vector3.xAxis, size = scaled.X },
		{ axis = Vector3.yAxis, size = scaled.Y },
		{ axis = Vector3.zAxis, size = scaled.Z },
	}
	table.sort(sides, function(a, b)
		return a.size < b.size
	end)
	local along, up = sides[3].axis, sides[1].axis
	-- The folder's attribute turns every kunai around; a kunai's own turns it once more.
	local allTurned = folder ~= nil and folder:GetAttribute(Net.FLIP_KUNAI_ATTRIBUTE) == true
	if allTurned ~= (template:GetAttribute(Net.FLIP_ATTRIBUTE) == true) then
		along = -along
	end
	model.WorldPivot = CFrame.lookAt(box.Position, box.Position + along, up)
	return model
end

-- The plain blade that stands in for a kunai without a model is this thick, as a share of its
-- length.
local BLADE_THICKNESS = 0.18

-- A whole kunai at the given place in the store, ready to be put in the world: the part it is
-- moved by, the supplied model that has to be pivoted along with the part if there is one, and
-- its effects. The part's front is where the kunai points. Without a model the part itself is
-- the kunai, a plain blade in the kunai's color.
function KunaiModel.build(place: number, at: CFrame): (Part, Model?, KunaiEffects.Effects)
	local tier = math.clamp(place, 1, #Catalog.kunai)
	local look = Catalog.kunai[tier]
	local length = KunaiModel.length(tier)

	local kunai = Instance.new("Part")
	kunai.Name = "Kunai"
	kunai.Anchored = true
	kunai.CanCollide = false
	kunai.CanQuery = false
	kunai.CastShadow = false
	kunai.Size = Vector3.new(BLADE_THICKNESS, BLADE_THICKNESS, 1) * length
	kunai.Color = Color3.fromHex(look.color)
	kunai.Material = if look.glow then Enum.Material.Neon else Enum.Material.Metal
	kunai.CFrame = at

	-- With a model, the plain blade only carries the effects.
	local model = KunaiModel.supplied(look.id, length)
	if model then
		kunai.Transparency = 1
		model:PivotTo(at)
		model.Parent = kunai
	end
	return kunai, model, KunaiEffects.attach(kunai, tier)
end

return KunaiModel
