--!strict
-- Turns every carried shinobi to face this player's screen.
--
-- A shinobi that is carried, picked out of the inventory or caught and on its way home, rides
-- over its carrier's head on one joint (see View/Figure.attach). Left alone it would turn with
-- the carrier and show its back or its side most of the time. Here, every frame, each such
-- joint is turned so that the shinobi looks at this client's camera: whoever carries it sees
-- its face, and so does everyone else, each on their own screen. Turning a joint here changes
-- nothing for anybody else.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Net = require(ReplicatedStorage.Shared.Net)

local Carried = {}

local RENDER_STEP = "CarriedFacing"
-- A camera straight overhead has no side to turn the shinobi to; nearer than this, level, it
-- is left as it stands.
local OVERHEAD = 0.5
-- The least room between the top of the carrier's head and the shinobi's feet, studs. Standing
-- or running there is more than this and the shinobi rides at its usual height; a carrier who
-- meditates is raised well over a stud off the ground, head and all, and without this their
-- head would stand in the shinobi's feet.
local HEAD_ROOM = 1

local function faceCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	for _, joint in CollectionService:GetTagged(Net.CARRY_TAG) do
		local root = if joint:IsA("Weld") then joint.Part0 else nil
		if joint:IsA("Weld") and root then
			local height = Figure.CARRY_HEIGHT
			local carrier = root.Parent
			local head = if carrier then carrier:FindFirstChild("Head") else nil
			if head and head:IsA("BasePart") then
				local top = root.CFrame:PointToObjectSpace(head.Position).Y + head.Size.Y / 2
				height = math.max(height, top + HEAD_ROOM)
			end
			local at = root.CFrame * Vector3.new(0, height, 0)
			local toEye = (eye - at) * Vector3.new(1, 0, 1)
			if toEye.Magnitude > OVERHEAD then
				-- Where the figure should stand and look, in the root's own terms.
				joint.C0 = root.CFrame:ToObjectSpace(CFrame.lookAt(at, at + toEye))
			end
		end
	end
end

function Carried.start()
	-- After the camera has moved for this frame.
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 5, faceCamera)
end

return Carried
