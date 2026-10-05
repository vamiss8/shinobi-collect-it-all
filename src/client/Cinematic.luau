--!strict
-- Kunai flights and the thrower's reveal.
--
-- Every client draws every kunai. For the local player's own throw this module also takes the
-- camera away from them and stages the reveal on the schedule the server sent:
--   flight  the camera chases the kunai
--   roll    it holds on the landing spot while shinobi flick past, slowing down, until the
--           roulette stops on the one that was rolled
--   hold    the result stays on screen
--   intro   once the server has teleported the player there, the camera turns to the zone's enemy
-- Then control comes back with the camera behind the player, looking the way home.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Hud = require("./Hud")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Strings = require("./Strings")

local Cinematic = {}

local RENDER_STEP = "CinematicCamera"
-- The roulette starts this fast and slows by this factor with every shinobi shown.
local ROLL_FIRST_INTERVAL = 0.07
local ROLL_SLOWDOWN = 1.15
-- If the run has not started this long after it should have, the camera is given back anyway.
local FAILSAFE_SECONDS = 4

type Stage = {
	reveal: Net.Reveal,
	startedAt: number,
	down: Vector3, -- unit vector pointing down the lane, away from home
	introFrom: number?, -- os.clock() time the enemy intro began
}

local localPlayer = Players.LocalPlayer
local rng = Random.new()

local stage: Stage? = nil
local myKunai: BasePart? = nil

-- Ends the staged camera and hands it back to the player. With `behindPlayer` it is first put
-- behind the character looking home, and the default camera carries on from that direction.
local function release(behindPlayer: boolean)
	local ended = stage
	if not ended then
		return
	end
	stage = nil
	RunService:UnbindFromRenderStep(RENDER_STEP)

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil

	if behindPlayer and root and root:IsA("BasePart") then
		local at = root.Position
		camera.CFrame = CFrame.lookAt(
			at + ended.down * 14 + Vector3.new(0, 7, 0),
			at - ended.down * 30 + Vector3.new(0, 2, 0)
		)
	end
	camera.CameraType = Enum.CameraType.Custom
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

-- Moves the camera towards where the current beat of the reveal wants it.
local function stepCamera(dt: number)
	local current = stage
	local camera = Workspace.CurrentCamera
	if not current or not camera then
		return
	end
	local reveal = current.reveal
	local down = current.down
	local now = os.clock()
	local kunai = myKunai

	local target: CFrame
	local stiffness: number
	if current.introFrom then
		if now - current.introFrom >= reveal.intro then
			release(true)
			return
		end
		local eye = reveal.at - down * 12 + Vector3.new(0, 10, 0)
		target = CFrame.lookAt(eye, reveal.enemyAt + Vector3.new(0, 5, 0))
		stiffness = 6
	elseif now - current.startedAt < reveal.flight and kunai and kunai.Parent then
		local at = kunai.Position
		target = CFrame.lookAt(at - down * 22 + Vector3.new(0, 10, 0), at)
		stiffness = 14
	else
		local eye = reveal.at - down * 15 + Vector3.new(0, 8, 0)
		target = CFrame.lookAt(eye, reveal.at + Vector3.new(0, 3, 0))
		stiffness = 6
	end
	-- Exponential smoothing: the same feel at any frame rate.
	camera.CFrame = camera.CFrame:Lerp(target, 1 - math.exp(-stiffness * dt))
end

-- A burst of light in the rank's color when the roulette stops.
local function flash(at: Vector3, color: Color3)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Transparency = 0.2
	ball.Size = Vector3.new(2, 2, 2)
	ball.Position = at + Vector3.new(0, 3, 0)
	ball.Parent = Workspace

	local tween = TweenService:Create(
		ball,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(18, 18, 18), Transparency = 1 }
	)
	tween.Completed:Once(function()
		ball:Destroy()
	end)
	tween:Play()
end

-- Shows shinobi the zone can drop one after another where the kunai landed, ever slower, and
-- stops on the one the server rolled. The decoys are picked here; they are only for show.
local function roulette(mine: Stage)
	local reveal = mine.reveal
	task.wait(reveal.flight)
	if stage ~= mine then
		return
	end

	-- The roulette shows what this zone can drop: its own rank and the next one up.
	local pool: { string } = {}
	local zone = Catalog.zoneById[reveal.zone]
	if zone then
		local ranks = { zone.rank }
		local nextRank = Catalog.nextRank(zone.rank)
		if nextRank then
			table.insert(ranks, nextRank)
		end
		for _, rankId in ranks do
			for _, character in Catalog.charactersByRank[rankId] do
				table.insert(pool, character.id)
			end
		end
	end
	if #pool == 0 then
		table.insert(pool, reveal.character)
	end

	-- Standing on the landing spot, facing home, which is also towards the camera.
	local standing = CFrame.lookAt(reveal.at, reveal.at - mine.down)
	local figure: Model? = nil
	local function show(unit: Economy.Unit)
		if figure then
			figure:Destroy()
		end
		local built = Figure.build(unit)
		built:PivotTo(standing)
		built.Parent = Workspace
		figure = built
	end

	local elapsed, interval = 0, ROLL_FIRST_INTERVAL
	while stage == mine and elapsed + interval < reveal.roll do
		local decoy = pool[rng:NextInteger(1, #pool)]
		show({ character = decoy, mutation = Catalog.NONE, level = 1 })
		task.wait(interval)
		elapsed += interval
		interval *= ROLL_SLOWDOWN
	end
	if stage == mine then
		task.wait(math.max(reveal.roll - elapsed, 0))
	end

	if stage == mine then
		local color = Hud.rankColor(reveal.character)
		show({ character = reveal.character, mutation = reveal.mutation, level = 1 })
		flash(reveal.at, color)
		local title = Catalog.unitTitle(reveal.character, reveal.mutation, 1)
		Hud.toast(Strings.get("Reveal", title), color)

		-- It stays until the server teleports the player here; from then on the same shinobi
		-- is carried over their head.
		local deadline = os.clock() + reveal.hold + FAILSAFE_SECONDS
		while stage == mine and not mine.introFrom and os.clock() < deadline do
			task.wait()
		end
	end
	if figure then
		figure:Destroy()
	end
end

-- Takes the camera and starts the reveal for the local player's own throw.
local function begin(reveal: Net.Reveal)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	release(false)

	local offset = reveal.enemyAt - reveal.at
	local mine: Stage = {
		reveal = reveal,
		startedAt = os.clock(),
		down = if offset.Magnitude > 0.01 then offset.Unit else Vector3.xAxis,
	}
	stage = mine
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep(RENDER_STEP, Enum.RenderPriority.Camera.Value + 1, stepCamera)

	task.spawn(roulette, mine)

	local expected = reveal.flight + reveal.roll + reveal.hold + reveal.intro
	task.delay(expected + FAILSAFE_SECONDS, function()
		if stage == mine then
			release(false)
		end
	end)
end

-- Builds the kunai for a flight. Which kunai the thrower owns decides its color, whether it
-- glows, and the trail it leaves; better ones are a little bigger with a longer trail.
local function buildKunai(index: number, at: Vector3): Part
	local tier = math.clamp(index, 1, #Catalog.kunai)
	local look = Catalog.kunai[tier]
	local scale = 1 + 0.06 * (tier - 1)

	local kunai = Instance.new("Part")
	kunai.Name = "Kunai"
	kunai.Anchored = true
	kunai.CanCollide = false
	kunai.CanQuery = false
	kunai.CastShadow = false
	kunai.Size = Vector3.new(0.5, 0.5, 2.8) * scale
	kunai.Color = Color3.fromHex(look.color)
	kunai.Material = if look.glow then Enum.Material.Neon else Enum.Material.Metal
	kunai.CFrame = CFrame.new(at)

	-- A trail is a ribbon stretched between two points on the part.
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.3 * scale, 0)
	top.Parent = kunai
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.3 * scale, 0)
	bottom.Parent = kunai

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(Color3.fromHex(look.trail))
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Lifetime = 0.25 + 0.07 * tier
	trail.LightEmission = if look.glow then 1 else 0.2
	trail.FaceCamera = true
	trail.Parent = kunai

	kunai.Parent = Workspace
	return kunai
end

-- Draws one kunai along its arc.
local function fly(flight: Net.Flight)
	local kunai = buildKunai(flight.kunai, flight.from)

	if flight.thrower == localPlayer.UserId then
		myKunai = kunai
	end

	-- A point on the arc: a straight line from start to landing plus a parabola on top.
	local function pointAt(t: number): Vector3
		local lift = 4 * flight.height * t * (1 - t)
		return flight.from:Lerp(flight.to, t) + Vector3.new(0, lift, 0)
	end

	local startedAt = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - startedAt) / flight.duration, 1)
		if t < 1 then
			-- Point the kunai along its path by looking at where it will be a moment later.
			kunai.CFrame = CFrame.lookAt(pointAt(t), pointAt(t + 0.01))
		else
			kunai.CFrame = kunai.CFrame.Rotation + flight.to
			connection:Disconnect()
		end
	end)

	task.delay(flight.duration + flight.linger, function()
		connection:Disconnect()
		if myKunai == kunai then
			myKunai = nil
		end
		kunai:Destroy()
	end)
end

function Cinematic.start()
	Remotes.Flight.OnClientEvent:Connect(fly)
	Remotes.Reveal.OnClientEvent:Connect(begin)

	Remotes.RunStart.OnClientEvent:Connect(function()
		if stage then
			stage.introFrom = os.clock()
		end
	end)

	-- Normally the intro ends the staging on its own; these cover a run that ended early and a
	-- character that died in the middle of it.
	Remotes.RunEnd.OnClientEvent:Connect(function()
		release(false)
	end)
	localPlayer.CharacterAdded:Connect(function()
		release(false)
	end)
end

return Cinematic
