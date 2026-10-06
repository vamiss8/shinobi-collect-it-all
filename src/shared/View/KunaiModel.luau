--!strict
-- The model of a kunai, when one has been supplied. To supply one, put a Model or a MeshPart
-- into ReplicatedStorage.Models (in Studio) named "kunai_" plus the kunai's id from
-- Config/Kunai, e.g. "kunai_steel". It is cloned, scaled to a set length and pointed along its
-- longest side, so it has to lie along one of its own axes, not across them. If it turns out
-- to fly ring first, give it a boolean attribute "Flip" set to true.
--
-- Shared because the client flies kunai and the server stands them in the showroom.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require("../Net")

local KunaiModel = {}

-- How long a kunai is in the world, studs: the first one in the store, and how much longer
-- each next one is. A character is about five studs tall, so a kunai is a short sword's length:
-- larger than life, as it has to be to be seen from the camera that chases it, but never
-- longer than whoever threw it. The last of the nineteen is 3.9 studs. What sets a better
-- kunai apart is mostly its effects (client KunaiEffects), not its size.
local FIRST_LENGTH = 2.8
local GROWTH = 0.022

-- The length of the kunai at this place in the store (Config/Kunai), studs.
function KunaiModel.length(tier: number): number
	return FIRST_LENGTH * (1 + GROWTH * (math.max(tier, 1) - 1))
end

-- The supplied model of a kunai, made safe to show and scaled to `length`, or nil if there is
-- none. Its pivot is put in its middle, looking along its longest side, so that pivoting it to
-- a CFrame points the blade the way that CFrame looks.
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
	local along, up = Vector3.zAxis, Vector3.yAxis
	if scaled.X >= scaled.Y and scaled.X >= scaled.Z then
		along = Vector3.xAxis
	elseif scaled.Y >= scaled.Z then
		along, up = Vector3.yAxis, Vector3.zAxis
	end
	if template:GetAttribute(Net.FLIP_ATTRIBUTE) == true then
		along = -along
	end
	model.WorldPivot = CFrame.lookAt(box.Position, box.Position + along, up)
	return model
end

return KunaiModel
