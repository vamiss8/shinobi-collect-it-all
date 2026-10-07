--!strict
-- Kunai flights and the thrower's reveal.
--
-- Every client draws every kunai. For the local player's own throw this module also takes the
-- camera away from them and stages the reveal on the schedule the server sent:
--   flight  the camera chases the kunai
--   roll    it holds on the landing spot while shinobi flick past a few steps beyond the
--           kunai, slowing down, until the roulette stops on the one that was rolled
--   hold    the camera moves in on the result
--   intro   once the server has teleported the player there, the camera flies past them, a
--           few steps to one side, at the zone's enemy while a banner names it, then swings
--           back behind the player
-- Then control comes back with the camera behind the player, looking the way home.
--
-- A kunai is a real model when one has been supplied (see View/KunaiModel), and a plain blade
-- otherwise.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Hud = require("./Hud")
local KunaiEffects = require(ReplicatedStorage.Shared.View.KunaiEffects)
local KunaiModel = require(ReplicatedStorage.Shared.View.KunaiModel)
local Net = require(ReplicatedStorage.Shared.Net)
local Particles = require(ReplicatedStorage.Shared.View.Particles)
local Remotes = require("./Remotes")
local Strings = require("./Strings")
local Ui = require("./Ui")

local Cinematic = {}

local RENDER_STEP = "CinematicCamera"
-- The roulette starts this fast and slows by this factor with every shinobi shown.
local ROLL_FIRST_INTERVAL = 0.07
local ROLL_SLOWDOWN = 1.15
-- The roulette stands this far past the kunai, studs: the kunai is then seen in front of the
-- shinobi's feet. On the very spot, the shinobi stood over the kunai and hid it.
local ROLL_BEYOND = 5
-- Each shinobi of the roulette springs up to its size in this long; the one it stops on takes
-- longer about it and ends larger than life.
local POP_SECONDS = 0.12
local RESULT_POP_SECONDS = 0.38
local RESULT_SIZE = 1.18
-- How far to one side of the player the camera passes them on its way to the enemy, studs.
local PASS_ASIDE = 7
-- The last stretch of the intro, in which the camera swings back behind the player, and how
-- long the banner's last words stay up once the player is running.
local SWING_SECONDS = 0.7
local RUN_WORDS_SECONDS = 1.6
-- If the run has not started this long after it should have, the camera is given back anyway.
local FAILSAFE_SECONDS = 4
-- A landed kunai sticks in the ground leaning this steeply forward, with this share of its
-- length in the earth. Steeply, because the camera of the reveal looks from behind and above:
-- left the way it came down, the kunai would point away from the camera and show only its ring.
local STUCK_PITCH = math.rad(65)
local BURIED = 0.25

-- What flies up round the shinobi the roulette stops on.
local BURST: Particles.Layer = {
	texture = Particles.SPARKLE,
	rate = 0,
	life = { 0.6, 1.1 },
	speed = { 10, 18 },
	spread = 60,
	size = { 1.1, 0.2 },
	lift = -16,
	spin = 180,
	glow = 0.8,
	fade = 0.05,
}

type Stage = {
	reveal: Net.Reveal,
	startedAt: number,
	down: Vector3, -- unit vector pointing down the lane, away from home
	aside: Vector3, -- unit vector across the lane, from the landing spot towards its middle
	shownAt: number?, -- os.clock() time the roulette stopped on its result
	introFrom: number?, -- os.clock() time the enemy intro began
}

-- The scroll over the look at the enemy: its name, a line under it, and what takes the
-- scroll's color.
type Banner = {
	frame: Frame,
	name: TextLabel,
	line: TextLabel,
	scale: UIScale,
	edge: UIStroke,
	seal: Frame,
	mark: TextLabel, -- what the seal is stamped with
}

local localPlayer = Players.LocalPlayer
local rng = Random.new()

local stage: Stage? = nil
local myKunai: BasePart? = nil
local banner: Banner? = nil
local announced = 0 -- counts what the banner has been told, so that a late order can be dropped

-- Where the camera stands when control comes back: behind a player who stands on the landing
-- spot `at`, looking home.
local function behind(at: Vector3, down: Vector3): CFrame
	return CFrame.lookAt(
		at + down * 14 + Vector3.new(0, 7, 0),
		at - down * 30 + Vector3.new(0, 2, 0)
	)
end

-- Shows the banner with these words, springing up, or hides it when given none. `color` goes
-- to its outline and its seal; `stamp` is the color of the mark on the seal, the parchment's
-- own unless the seal is too pale for that.
local function announce(name: string?, line: string?, color: Color3?, stamp: Color3?)
	local shown = banner
	if not shown then
		return
	end
	announced += 1
	if not name then
		shown.frame.Visible = false
		return
	end
	shown.name.Text = name
	shown.line.Text = line or ""
	shown.edge.Color = color or Ui.SEAL
	shown.seal.BackgroundColor3 = color or Ui.SEAL
	shown.mark.TextColor3 = stamp or Ui.PARCHMENT
	shown.frame.Visible = true
	shown.scale.Scale = 0.6
	TweenService:Create(
		shown.scale,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

-- Ends the staged camera and hands it back to the player. With `behindPlayer` it is first put
-- behind the character looking home, and the default camera carries on from that direction.
local function release(behindPlayer: boolean)
	local ended = stage
	if not ended then
		return
	end
	stage = nil
	RunService:UnbindFromRenderStep(RENDER_STEP)
	if behindPlayer then
		-- The banner's last words stay for the first steps of the run.
		local order = announced
		task.delay(RUN_WORDS_SECONDS, function()
			if announced == order then
				announce(nil)
			end
		end)
	else
		announce(nil)
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local character = localPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil

	if behindPlayer and root and root:IsA("BasePart") then
		camera.CFrame = behind(root.Position, ended.down)
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
	local spot = reveal.at + down * ROLL_BEYOND

	local target: CFrame
	local stiffness: number
	if current.introFrom then
		local since = now - current.introFrom
		local look = math.max(reveal.intro - SWING_SECONDS, 0.1)
		if since >= reveal.intro then
			release(true)
			return
		elseif since >= look then
			-- Back to where control returns, so that the hand-over is not a cut.
			target = behind(reveal.at, down)
			stiffness = 7
		else
			-- From behind the player's shoulder past them towards the enemy, well to one
			-- side all the way. The player stands on the landing spot with the catch over
			-- their head: a camera that went straight over them went through the catch.
			local share = since / look
			local eye = reveal.at
				+ down * (-7 + 24 * share)
				+ current.aside * (PASS_ASIDE - 2.5 * share)
				+ Vector3.new(0, 8.5 - 2.5 * share, 0)
			target = CFrame.lookAt(eye, reveal.enemyAt + Vector3.new(0, 5.5, 0))
			stiffness = 5
		end
	elseif now - current.startedAt < reveal.flight and kunai and kunai.Parent then
		local at = kunai.Position
		target = CFrame.lookAt(at - down * 22 + Vector3.new(0, 10, 0), at)
		stiffness = 14
	elseif current.shownAt then
		-- The roulette has stopped: closer to the one it stopped on.
		local eye = reveal.at - down * 8 + Vector3.new(0, 6.5, 0)
		target = CFrame.lookAt(eye, spot + Vector3.new(0, 3, 0))
		stiffness = 5
	else
		local eye = reveal.at - down * 15 + Vector3.new(0, 8, 0)
		target = CFrame.lookAt(eye, reveal.at + down * (ROLL_BEYOND / 2) + Vector3.new(0, 3, 0))
		stiffness = 6
	end
	-- Exponential smoothing: the same feel at any frame rate.
	camera.CFrame = camera.CFrame:Lerp(target, 1 - math.exp(-stiffness * dt))
end

-- A piece of light for the reveal: seen, never touched, and gone after `seconds`.
local function glow(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	part.Parent = Workspace
	return part
end

local function fade(part: Part, seconds: number, goal: { [string]: any })
	local tween = TweenService:Create(
		part,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
end

-- What happens in the rank's color when the roulette stops: a burst of light, a pillar of it
-- that thins away upwards, and sparks thrown up round the shinobi.
local function celebrate(at: Vector3, color: Color3)
	local ball =
		glow(Enum.PartType.Ball, Vector3.new(2, 2, 2), CFrame.new(at + Vector3.new(0, 3, 0)), color)
	ball.Transparency = 0.2
	fade(ball, 0.5, { Size = Vector3.new(18, 18, 18), Transparency = 1 })

	-- A cylinder lies along its X axis; this stands it up.
	local upright = CFrame.new(at + Vector3.new(0, 22, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local pillar = glow(Enum.PartType.Cylinder, Vector3.new(44, 3, 3), upright, color)
	pillar.Transparency = 0.5
	fade(pillar, 0.8, { Size = Vector3.new(44, 0.2, 0.2), Transparency = 1 })

	local source = glow(
		Enum.PartType.Block,
		Vector3.new(3, 0.2, 3),
		CFrame.new(at + Vector3.new(0, 0.6, 0)),
		color
	)
	source.Transparency = 1
	local sparks = Particles.emitter(BURST, color)
	sparks.Parent = source
	sparks:Emit(40)
	task.delay(2, function()
		source:Destroy()
	end)
end

-- How large a shinobi of the roulette is drawn `t` of the way through springing up (0..1):
-- quickly to its size and no further.
local function spring(t: number): number
	return 0.82 + 0.18 * (1 - (1 - t) ^ 3)
end

-- The same for the one the roulette stops on: from small, past its size and back to it.
local function leap(t: number): number
	local s = 1.70158
	local back = 1 + (s + 1) * (t - 1) ^ 3 + s * (t - 1) ^ 2
	return 0.6 + 0.4 * back
end

-- Shows shinobi the zone can drop one after another a few steps past where the kunai landed,
-- ever slower, and stops on the one the server rolled. Each springs up as it appears, over a
-- disc of light in its rank's color that beats with the roulette. The decoys are picked here;
-- they are only for show.
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

	-- Standing past the kunai, facing home, which is also towards the camera.
	local spot = reveal.at + mine.down * ROLL_BEYOND
	local standing = CFrame.lookAt(spot, spot - mine.down)
	-- A cylinder lies along its X axis; this lays the disc flat.
	local flat = CFrame.new(spot + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local disc = glow(Enum.PartType.Cylinder, Vector3.new(0.2, 7, 7), flat, Ui.WHITE)
	disc.Transparency = 0.5
	local function beat(color: Color3, seconds: number, wide: number)
		disc.Color = color
		disc.Size = Vector3.new(0.2, 5.6, 5.6)
		disc.Transparency = 0.15
		TweenService:Create(
			disc,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(0.2, wide, wide), Transparency = 0.55 }
		):Play()
	end

	-- The shinobi on show, the size it was built at, and how it is springing up.
	local figure: Model? = nil
	local builtAt, bornAt = 1, 0
	local grow, seconds, full = spring, POP_SECONDS, 1
	local settled = false
	local springing = RunService.RenderStepped:Connect(function()
		local shown = figure
		if not shown or settled then
			return
		end
		local t = (os.clock() - bornAt) / seconds
		if t < 1 then
			shown:ScaleTo(builtAt * full * grow(t))
		else
			shown:ScaleTo(builtAt * full)
			settled = true
		end
	end)
	local function show(unit: Economy.Unit, result: boolean)
		if figure then
			figure:Destroy()
		end
		local built = Figure.build(unit)
		builtAt, bornAt, settled = built:GetScale(), os.clock(), false
		if result then
			grow, seconds, full = leap, RESULT_POP_SECONDS, RESULT_SIZE
		end
		built:ScaleTo(builtAt * full * grow(0))
		built:PivotTo(standing)
		built.Parent = Workspace
		figure = built
	end

	local elapsed, interval = 0, ROLL_FIRST_INTERVAL
	while stage == mine and elapsed + interval < reveal.roll do
		local decoy = pool[rng:NextInteger(1, #pool)]
		show({ character = decoy, mutation = Catalog.NONE, level = 1 }, false)
		beat(Hud.rankColor(decoy), math.min(interval, 0.3), 7.4)
		task.wait(interval)
		elapsed += interval
		interval *= ROLL_SLOWDOWN
	end
	if stage == mine then
		task.wait(math.max(reveal.roll - elapsed, 0))
	end

	if stage == mine then
		local color = Hud.rankColor(reveal.character)
		show({ character = reveal.character, mutation = reveal.mutation, level = 1 }, true)
		mine.shownAt = os.clock()
		beat(color, 0.6, 10)
		celebrate(spot, color)
		local title = Catalog.unitTitle(reveal.character, reveal.mutation, 1)
		Hud.toast(Strings.get("Reveal", title), color)

		-- It stays until the server teleports the player here; from then on the same shinobi
		-- is carried over their head.
		local deadline = os.clock() + reveal.hold + FAILSAFE_SECONDS
		while stage == mine and not mine.introFrom and os.clock() < deadline do
			task.wait()
		end
	end
	springing:Disconnect()
	disc:Destroy()
	if figure then
		figure:Destroy()
	end
end

-- Names the enemy over the look at it, and for the last stretch of the intro, as the camera
-- swings back, says what to do about it.
local function narrate(mine: Stage)
	local zone = Catalog.zoneById[mine.reveal.zone]
	local enemy = if zone then zone.enemy.name else mine.reveal.zone
	announce(string.upper(enemy), Strings.get("ChaseWarn"), Ui.SEAL)
	task.wait(math.max(mine.reveal.intro - SWING_SECONDS, 0.1))
	if stage == mine then
		announce(Strings.get("ChaseRun"), Strings.get("ChaseRunFrom", enemy), Ui.GOLD, Ui.INK)
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
	local down = if offset.Magnitude > 0.01 then offset.Unit else Vector3.xAxis
	-- Across the lane, towards its middle from where the kunai landed: on that side there is
	-- room for the camera between the walls wherever the landing spot is.
	local across = down:Cross(Vector3.yAxis)
	local hub = Workspace:FindFirstChild(Net.HUB_FOLDER)
	local origin = if hub then hub:GetAttribute(Net.ORIGIN_ATTRIBUTE) else nil
	if typeof(origin) == "Vector3" and (reveal.at - origin):Dot(across) > 0 then
		across = -across
	end
	local mine: Stage = {
		reveal = reveal,
		startedAt = os.clock(),
		down = down,
		aside = across,
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

-- Draws one kunai along its arc.
local function fly(flight: Net.Flight)
	-- Which kunai the thrower owns decides its shape, color, effects and length.
	local kunai, model, effects = KunaiModel.build(flight.kunai, CFrame.new(flight.from))
	kunai.Parent = Workspace
	local function place(cframe: CFrame)
		kunai.CFrame = cframe
		if model then
			model:PivotTo(cframe)
		end
	end

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
			place(CFrame.lookAt(pointAt(t), pointAt(t + 0.01)))
		else
			local ahead = (flight.to - flight.from) * Vector3.new(1, 0, 1)
			local forward = if ahead.Magnitude > 0.01 then ahead.Unit else Vector3.xAxis
			local axis = forward * math.cos(STUCK_PITCH) - Vector3.yAxis * math.sin(STUCK_PITCH)
			local middle = flight.to + axis * (BURIED - 0.5) * kunai.Size.Z
			place(CFrame.lookAt(middle, middle + axis))
			KunaiEffects.land(effects)
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

-- The banner of the intro: a scroll like the one messages are written on, larger and hung
-- under it, with the enemy's name in ink and a line under the name. What it says in color it
-- says with its outline and its seal, as every message does. (It was red and white lettering
-- straight on the picture at first, which was nothing like the rest of the game.)
local function buildBanner(): Banner
	local screen = Ui.screen("Chase", 16)
	local paper = Ui.parchment(screen, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 128),
		Size = UDim2.fromOffset(840, 148),
		Visible = false,
	}, 76)
	paper.edge.Thickness = 4
	local scale: UIScale = Ui.make("UIScale", {}, paper.frame)
	-- The seal is stamped with a mark of warning.
	local mark = Ui.text(paper.seal, {
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		TextColor3 = Ui.PARCHMENT,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "!",
	})
	local name = Ui.text(paper.frame, {
		Position = UDim2.fromOffset(122, 6),
		Size = UDim2.new(1, -160, 0, 88),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 76 }, name)
	-- A drawn line between the name and what is said of it.
	Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 42, 0, 94),
		Size = UDim2.new(1, -220, 0, 3),
		BackgroundColor3 = Ui.INK,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, paper.frame)
	local line = Ui.text(paper.frame, {
		Position = UDim2.fromOffset(122, 98),
		Size = UDim2.new(1, -160, 0, 44),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 36 }, line)
	return {
		frame = paper.frame,
		name = name,
		line = line,
		scale = scale,
		edge = paper.edge,
		seal = paper.seal,
		mark = mark,
	}
end

function Cinematic.start()
	banner = buildBanner()

	-- The supplied models are fetched ahead of time, in the background: the roulette swaps
	-- figures many times a second, and one whose mesh is still on its way shows as nothing.
	task.spawn(function()
		local folder = ReplicatedStorage:FindFirstChild(Net.MODELS_FOLDER)
		if folder then
			pcall(function()
				ContentProvider:PreloadAsync(folder:GetChildren())
			end)
		end
	end)

	Remotes.Flight.OnClientEvent:Connect(fly)
	Remotes.Reveal.OnClientEvent:Connect(begin)

	Remotes.RunStart.OnClientEvent:Connect(function()
		local current = stage
		if current then
			current.introFrom = os.clock()
			task.spawn(narrate, current)
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
