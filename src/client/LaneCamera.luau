--!strict
-- Keeps the player's own camera inside the lane.
--
-- The lane's walls are unseen and the scenery beside it is only for show, so the game's
-- camera, which backs off from solid things only, went straight through both: a player running
-- home along the lane's edge who turned the camera sideways saw the stands of the arena from
-- inside. While the player is on the lane the camera is now pulled in along its own line of
-- sight until it is back between the walls, the way it would be at a wall it could see
-- (Logic/Corridor has the arithmetic). The staged cameras of a throw are not touched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Corridor = require(ReplicatedStorage.Shared.Logic.Corridor)
local Net = require(ReplicatedStorage.Shared.Net)

local LaneCamera = {}

local RENDER_STEP = "LaneCamera"
-- How far from the lane's middle the camera may stand. The walls' inner faces are 30 out and
-- the scenery starts a stud and a half behind them; this leaves room for what the camera sees
-- to either side of itself.
local LIMIT = 29.4

local function confine()
	local camera = Workspace.CurrentCamera
	local hub = Workspace:FindFirstChild(Net.HUB_FOLDER)
	local origin = if hub then hub:GetAttribute(Net.ORIGIN_ATTRIBUTE) else nil
	if not camera or camera.CameraType ~= Enum.CameraType.Custom or typeof(origin) ~= "Vector3" then
		return
	end
	-- In the Hub's terms: X runs down the lane from its start, Z across it.
	local focus = camera.Focus.Position - origin
	local eye = camera.CFrame.Position - origin
	-- Behind the lane's start lies the yard, which is wider than the lane: only a camera that
	-- is itself past the start, looking at something that is, can be outside a wall.
	if focus.X < 0 or eye.X < 0 then
		return
	end
	local share = Corridor.reach(focus.Z, eye.Z, LIMIT)
	if share < 1 then
		local place = camera.Focus.Position:Lerp(camera.CFrame.Position, share)
		camera.CFrame = camera.CFrame.Rotation + place
	end
end

function LaneCamera.start()
	-- After the game's own camera has placed itself for this frame.
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 2, confine)
end

return LaneCamera
