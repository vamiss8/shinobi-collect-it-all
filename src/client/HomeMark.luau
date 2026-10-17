--!strict
-- The player's own dojo, outlined for their eyes alone (owner, 2026-10-17: "show which dojo is
-- yours more plainly; one forgets, and has to look high up to make out one's dojo"). Its name
-- is written on its roof, which is where the eye does not go from the plaza. A slip saying
-- "your dojo" over its stairs was tried first and turned down: it was seen through everything
-- on the run home and looked cheap; "maybe outline your dojo, in white lines pulsing a little;
-- when you come close let it go". So the whole dojo has a white outline, which breathes, seen
-- only where the dojo itself is seen; it fades out as the player comes within a few strides of
-- it and is gone inside, and it is not drawn from farther than the plaza reaches.
-- The server makes the dojo a Model and marks it with its owner, and puts in it an unseen part
-- as large as its floor that distances are measured from (World/Plots, Net.HOME_PART).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)

local HomeMark = {}

local WHITE = Color3.new(1, 1, 1)
-- How far out from the dojo's floor the outline is gone, and where it is whole, studs; and
-- the farthest it is drawn from.
local GONE = 22
local WHOLE = 42
local FARTHEST = 300
-- The outline's breath: how see-through it is at its strongest and its faintest, and how
-- long a breath takes.
local STRONG = 0.1
local FAINT = 0.65
local BREATH = 2.2
local LOOK = 0.5

-- The dojo given to this player and its unseen floor, once the server has given one.
local function homeOf(userId: number): (Model?, BasePart?)
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and child:GetAttribute(Net.DOJO_OWNER_ATTRIBUTE) == userId then
			local part = child:FindFirstChild(Net.HOME_PART)
			return child, if part and part:IsA("BasePart") then part else nil
		end
	end
	return nil, nil
end

-- How far a point is from the dojo's floor, sideways, studs: 0 on it.
local function away(floor: BasePart, point: Vector3): number
	local spot = floor.CFrame:PointToObjectSpace(point)
	local dx = math.max(math.abs(spot.X) - floor.Size.X / 2, 0)
	local dz = math.max(math.abs(spot.Z) - floor.Size.Z / 2, 0)
	return math.sqrt(dx * dx + dz * dz)
end

function HomeMark.start()
	local me = Players.LocalPlayer
	local dojo: Model? = nil
	local floor: BasePart? = nil
	local glow: Highlight? = nil

	task.spawn(function()
		while true do
			local current = dojo
			if not current or not current.Parent then
				local found, part = homeOf(me.UserId)
				dojo, floor = found, part
				local old = glow
				if old then
					old:Destroy()
					glow = nil
				end
				if found then
					-- Made here, so it is this client's alone.
					local made = Instance.new("Highlight")
					made.Name = "HomeMark"
					made.FillTransparency = 1
					made.OutlineColor = WHITE
					made.OutlineTransparency = 1
					made.DepthMode = Enum.HighlightDepthMode.Occluded
					made.Enabled = false
					made.Adornee = found
					made.Parent = found
					glow = made
				end
			end
			task.wait(LOOK)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local made = glow
		local part = floor
		if not made or not part then
			return
		end
		local character = me.Character
		local body = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not body or not body:IsA("BasePart") then
			made.Enabled = false
			return
		end
		local distance = away(part, body.Position)
		-- Whole from WHOLE studs out, gone at GONE and nearer, and gone past FARTHEST.
		local near = math.clamp((distance - GONE) / (WHOLE - GONE), 0, 1)
		if near <= 0 or distance > FARTHEST then
			made.Enabled = false
			return
		end
		made.Enabled = true
		local breath = (math.cos(os.clock() * 2 * math.pi / BREATH) + 1) / 2
		local faintness = STRONG + (FAINT - STRONG) * breath
		made.OutlineTransparency = 1 - (1 - faintness) * near
	end)
end

return HomeMark
