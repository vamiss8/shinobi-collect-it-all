--!strict
-- The orbs of a player's rank (Logic/RankLook): balls of Chakra in the rank's color that hang
-- in a wheel behind the back of everyone who has done a rebirth, one more with every rank.
--
-- Every client draws them for every player, itself included, from the count of rebirths the
-- server keeps on each Player. They are parts of the client's own, moved every frame: nothing
-- is fixed to the character, so nothing can jolt with it, and nothing is sent. An orb goes
-- after its place in the wheel rather than sitting in it, so the wheel trails behind a runner
-- and sways after a jump; and an orb is a plain lit ball, not a light, so it is bright in the
-- sun and dim in the cave like everything round it. (The first mark of a rank was a plate of
-- light fixed under the feet, which did neither and blinked at every landing.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local RankLook = require(ReplicatedStorage.Shared.Logic.RankLook)

local RankOrbs = {}

-- The wheel: how wide it is, and where its middle is from the middle of the character's root,
-- behind the back and a little up, studs. It breathes by BREATH, in and out.
local RADIUS = 2.3
local BEHIND = 1.5
local LIFT = 0.6
local BREATH = 0.14
-- How fast an orb closes on its place, a second, and how far behind it may fall, studs.
local FOLLOW = 15
local SLACK = 3.4
-- Wheels of players farther from the camera than this are not drawn, studs.
local FAR = 240
-- The last rank's orbs.
local DARK = Color3.fromRGB(24, 20, 30)

type Wheel = {
	look: RankLook.Look?,
	orbs: { Part },
	-- Whether the orbs stand where they were left a frame ago; false makes them appear in
	-- their places instead of flying in from wherever they last were.
	placed: boolean,
}

local wheels: { [Player]: Wheel } = {}
local folder: Folder? = nil

local function orb(look: RankLook.Look): Part
	local color = Color3.fromHex(look.color)
	local part = Instance.new("Part")
	part.Name = "RankOrb"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * look.size
	part.Color = if look.dark then DARK else color
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = if look.dark then 0.28 else 0.12
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	if look.tail then
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(0, look.size * 0.36, 0)
		top.Parent = part
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(0, -look.size * 0.36, 0)
		bottom.Parent = part
		local tail = Instance.new("Trail")
		tail.Attachment0 = top
		tail.Attachment1 = bottom
		tail.FaceCamera = true
		tail.Lifetime = 0.38
		tail.MinLength = 0.05
		tail.Color = ColorSequence.new(color)
		tail.Transparency = NumberSequence.new(0.3, 1)
		tail.WidthScale = NumberSequence.new(1, 0)
		tail.LightEmission = 0.35
		tail.LightInfluence = 0.6
		tail.Parent = part
	end
	return part
end

-- Makes the wheel of a player anew for the rank they hold now.
local function dress(player: Player)
	local wheel = wheels[player]
	if not wheel then
		return
	end
	for _, part in wheel.orbs do
		part:Destroy()
	end
	local count = player:GetAttribute(Net.PLAYER_REBIRTHS)
	local look = RankLook.of(if typeof(count) == "number" then count else 0)
	wheel.look = look
	wheel.orbs = {}
	wheel.placed = false
	if look then
		for _ = 1, look.orbs do
			table.insert(wheel.orbs, orb(look))
		end
	end
end

local function put(wheel: Wheel, to: Instance?)
	for _, part in wheel.orbs do
		part.Parent = to
	end
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local home = folder
	if not camera or not home then
		return
	end
	local eye = camera.CFrame.Position
	local now = os.clock()
	local ease = 1 - math.exp(-FOLLOW * dt)
	for player, wheel in wheels do
		local look = wheel.look
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local seen = look ~= nil
			and root ~= nil
			and root:IsA("BasePart")
			and humanoid ~= nil
			and humanoid.Health > 0
			and (root.Position - eye).Magnitude < FAR
		if not look or not root or not root:IsA("BasePart") or not seen then
			if wheel.placed then
				put(wheel, nil)
				wheel.placed = false
			end
			continue
		end

		-- The wheel stands upright behind the back, in the plane the character faces.
		local frame = root.CFrame
		local middle = frame:PointToWorldSpace(Vector3.new(0, LIFT, BEHIND))
		local right, up = frame.RightVector, frame.UpVector
		local radius = RADIUS + BREATH * math.sin(now * 1.7)
		local turn = math.rad(look.spin) * now
		for index, part in wheel.orbs do
			local angle = turn + (index - 1) / #wheel.orbs * 2 * math.pi
			local place = middle
				+ right * (math.cos(angle) * radius)
				+ up * (math.sin(angle) * radius)
			local at = if wheel.placed then part.Position:Lerp(place, ease) else place
			local behind = at - place
			if behind.Magnitude > SLACK then
				at = place + behind.Unit * SLACK
			end
			part.CFrame = CFrame.new(at)
		end
		if not wheel.placed then
			put(wheel, home)
			wheel.placed = true
		end
	end
end

local function adopt(player: Player)
	wheels[player] = { look = nil, orbs = {}, placed = false }
	player:GetAttributeChangedSignal(Net.PLAYER_REBIRTHS):Connect(function()
		dress(player)
	end)
	dress(player)
end

function RankOrbs.start()
	local made = Instance.new("Folder")
	made.Name = "RankOrbs"
	made.Parent = Workspace
	folder = made

	Players.PlayerAdded:Connect(adopt)
	Players.PlayerRemoving:Connect(function(player)
		local wheel = wheels[player]
		if wheel then
			for _, part in wheel.orbs do
				part:Destroy()
			end
			wheels[player] = nil
		end
	end)
	for _, player in Players:GetPlayers() do
		adopt(player)
	end
	RunService.RenderStepped:Connect(step)
end

return RankOrbs
