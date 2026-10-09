--!strict
-- An event on this player's screen (Config/Events; the server says which is running and until
-- when, on the Hub folder). When one begins the player cannot miss it: the screen flashes in
-- its color, a scroll names it and what it brings, and the camera lifts to the sky, where the
-- event hangs. While it runs the whole picture is tinted, something falls or rises everywhere,
-- and a scroll in the corner counts down what is left of it. No two events look alike: a red
-- moon over a red world, a ceiling of red cloud shedding black feathers, fireworks over
-- falling gold leaves.
--
-- All of it is this client's own: the tint is an effect of its own in Lighting, beside the
-- zone's and the lightning's (client Mood, Weather), and what is in the sky follows this
-- camera. The camera is only lifted for a player who is doing nothing that needs it: not
-- while they aim, nor during a throw or the run home. And the last zone keeps its own light
-- through any event, as it is to keep it through everything.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Cinematic = require("./Cinematic")
local Events = require(ReplicatedStorage.Shared.Logic.Events)
local Hud = require("./Hud")
local Icons = require("./Icons")
local Mood = require("./Mood")
local Net = require(ReplicatedStorage.Shared.Net)
local Particles = require(ReplicatedStorage.Shared.View.Particles)
local Remotes = require("./Remotes")
local StageFlash = require("./StageFlash")
local Strings = require("./Strings")
local Ui = require("./Ui")
local Weather = require("./Weather")

local EventShow = {}

-- The scroll with the countdown, in the top left corner.
local TIMER = Vector2.new(330, 78)
local TIMER_SEAL = 56
-- How long the picture takes to take an event's tint, and to lose it, seconds.
local TINT_SECONDS = 2.5
-- The look at the sky when an event begins: the camera lifts, holds and comes back, seconds.
local LOOK_UP = 0.9
local LOOK_HOLD = 1.7
local LOOK_BACK = 0.8
-- Which way the moon hangs, and how far off and how wide it is, studs. Near enough for the
-- air's haze to leave it be, high enough to clear whatever stands beside the lane.
local MOON_WAY = Vector3.new(-0.42, 0.56, 0.72).Unit
local MOON_FAR = 340
local MOON_WIDE = 64
-- The cloud ceiling: how far over the camera it hangs and how wide it is, studs.
local CEILING_UP = 120
local CEILING_WIDE = 420
-- Fireworks: where a rocket bursts from the camera, studs out and up, and how long between two.
local BURST_OUT = 150
local BURST_UP = { 70, 130 }
local BURST_EVERY = { 0.6, 1.3 }
local BURST_COLORS = { "#FFD54F", "#FF80AB", "#69F0AE", "#FFFFFF" }

-- What an event has put in the world for this client, to be taken out again.
type Scene = {
	follow: (camera: Camera) -> (), -- moves it with the camera, every frame
	stop: () -> (),
}

local function unseen(size: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.Parent = Workspace
	return part
end

-- A red moon: a disc that always faces the camera, far off in one part of the sky.
local function moon(): Scene
	local anchor = unseen(Vector3.one)
	local board: BillboardGui = Ui.make("BillboardGui", {
		Size = UDim2.fromScale(MOON_WIDE, MOON_WIDE),
		LightInfluence = 0,
		Brightness = 2,
		MaxDistance = MOON_FAR * 3,
	}, anchor)
	local function disc(size: number, x: number, y: number, color: Color3, clear: number)
		local frame = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(size, size),
			BackgroundColor3 = color,
			BackgroundTransparency = clear,
			BorderSizePixel = 0,
		}, board)
		Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	end
	-- A halo, the moon, and the darker seas on it.
	disc(1, 0.5, 0.5, Color3.fromRGB(255, 23, 68), 0.82)
	disc(0.82, 0.5, 0.5, Color3.fromRGB(255, 61, 85), 0.6)
	disc(0.66, 0.5, 0.5, Color3.fromRGB(229, 20, 46), 0)
	disc(0.16, 0.42, 0.42, Color3.fromRGB(170, 8, 28), 0)
	disc(0.12, 0.60, 0.58, Color3.fromRGB(170, 8, 28), 0)
	disc(0.07, 0.58, 0.36, Color3.fromRGB(170, 8, 28), 0)
	return {
		follow = function(camera)
			anchor.CFrame = CFrame.new(camera.CFrame.Position + MOON_WAY * MOON_FAR)
		end,
		stop = function()
			anchor:Destroy()
		end,
	}
end

-- A ceiling of cloud over the camera: great slow puffs, dark red among black.
local function clouds(): Scene
	local ceiling = unseen(Vector3.new(CEILING_WIDE, 2, CEILING_WIDE))
	for _, color in { "#8E1B26", "#1A1014" } do
		local puffs = Particles.emitter({
			texture = Particles.SMOKE,
			rate = 7,
			life = { 7, 9 },
			speed = { 3, 6 },
			down = true,
			spread = 80,
			size = { 70, 95 },
			lift = 0.4,
			spin = 6,
			glow = 0.1,
			fade = 0.35,
		}, Color3.fromHex(color))
		puffs.Parent = ceiling
	end
	return {
		follow = function(camera)
			ceiling.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, CEILING_UP, 0))
		end,
		stop = function()
			ceiling:Destroy()
		end,
	}
end

-- Fireworks: every so often a rocket bursts somewhere over the camera, in one color or
-- another.
local function fireworks(): Scene
	local rocket = unseen(Vector3.one)
	local bursts: { ParticleEmitter } = {}
	for _, color in BURST_COLORS do
		local sparks = Particles.emitter({
			texture = Particles.SPARKLE,
			rate = 0,
			life = { 1, 1.7 },
			speed = { 26, 40 },
			spread = 180,
			size = { 2.4, 0.3 },
			drag = 2.6,
			lift = -14,
			spin = 120,
			glow = 1,
			bright = 4,
			fade = 0,
		}, Color3.fromHex(color))
		sparks.Parent = rocket
		table.insert(bursts, sparks)
	end
	local rng = Random.new()
	local at = Vector3.zero
	local running = true
	task.spawn(function()
		while running do
			task.wait(rng:NextNumber(BURST_EVERY[1], BURST_EVERY[2]))
			if not running then
				break
			end
			local out = Vector3.new(
				rng:NextNumber(-BURST_OUT, BURST_OUT),
				rng:NextNumber(BURST_UP[1], BURST_UP[2]),
				rng:NextNumber(-BURST_OUT, BURST_OUT)
			)
			rocket.CFrame = CFrame.new(at + out)
			bursts[rng:NextInteger(1, #bursts)]:Emit(rng:NextInteger(30, 46))
		end
	end)
	return {
		follow = function(camera)
			at = camera.CFrame.Position
		end,
		stop = function()
			running = false
			-- What is in the air burns out first.
			task.delay(3, function()
				rocket:Destroy()
			end)
		end,
	}
end

-- What falls or rises everywhere while the event runs: an emitter that travels with the
-- camera, as a zone's weather does.
local function falling(weather: Events.Event): Scene
	local look = weather.weather
	local cloud = unseen(Vector3.new(look.box[1], look.box[2], look.box[3]))
	local shift = Vector3.new(look.shift[1], look.shift[2], look.shift[3])
	local made = Weather.emitter(look)
	made.Parent = cloud
	return {
		follow = function(camera)
			cloud.CFrame = CFrame.new(camera.CFrame.Position + shift)
		end,
		stop = function()
			made.Enabled = false
			task.delay(8, function()
				cloud:Destroy()
			end)
		end,
	}
end

-- 4:05 for 245 seconds.
local function clock(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function EventShow.start()
	local layer = Ui.screen("Event", 12)
	local paper = Ui.parchment(layer, {
		Position = UDim2.fromOffset(28, 18),
		Size = UDim2.fromOffset(TIMER.X, TIMER.Y),
		Visible = false,
	}, TIMER_SEAL)
	local emblem: Frame = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, paper.seal)
	local title = Ui.text(paper.page, {
		Position = UDim2.fromOffset(TIMER_SEAL + 40, 8),
		Size = UDim2.new(1, -(TIMER_SEAL + 62), 0, 34),
		TextScaled = true,
		TextColor3 = Ui.INK,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 30 }, title)
	local left = Ui.text(paper.page, {
		Position = UDim2.fromOffset(TIMER_SEAL + 40, 42),
		Size = UDim2.new(1, -(TIMER_SEAL + 62), 0, 28),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextTransparency = 0.15,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 24 }, left)

	-- The tint. Made here, after the zone's own effect has been found (client Mood).
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = Mood.EVENT
	tint.Parent = Lighting
	local lastZone = Catalog.zones[#Catalog.zones].id
	local inLastZone = false

	-- The event on show, the moment it ends, and what it has put in the world.
	local showing: Events.Event? = nil
	local endsAt = 0
	local scenes: { Scene } = {}

	local function colorize()
		local event = showing
		local sky = if event and not inLastZone then event.sky else nil
		TweenService:Create(tint, TweenInfo.new(TINT_SECONDS), {
			TintColor = if sky then Color3.fromHex(sky.tint) else Color3.new(1, 1, 1),
			Brightness = if sky then sky.brightness else 0,
			Contrast = if sky then sky.contrast else 0,
			Saturation = if sky then sky.saturation else 0,
		}):Play()
	end
	Mood.onPlace(function(place)
		inLastZone = place == lastZone
		colorize()
	end)

	-- Whether the player is busy with a throw: aiming, or from the kunai's flight to the end
	-- of the run home. Their camera is theirs, or the reveal's, all that while.
	local aiming, thrown = false, false
	Remotes.KickStart.OnClientEvent:Connect(function()
		aiming = true
	end)
	Remotes.KickResult.OnClientEvent:Connect(function(result: Net.KickResult?)
		aiming = false
		thrown = result ~= nil
	end)
	Remotes.RunEnd.OnClientEvent:Connect(function()
		aiming, thrown = false, false
	end)

	-- Lifts the camera to look `way`, holds it there and gives it back where it was, moved by
	-- however far the character has walked meanwhile. Given up at once if a throw's staging
	-- takes the camera.
	local function lookUp(way: Vector3)
		local camera = Workspace.CurrentCamera
		if not camera or aiming or thrown or Cinematic.staging() then
			return
		end
		local from = camera.CFrame
		local focus = camera.Focus.Position
		local startedAt = os.clock()
		camera.CameraType = Enum.CameraType.Scriptable
		local watching: RBXScriptConnection
		watching = RunService.RenderStepped:Connect(function()
			if Cinematic.staging() then
				-- The reveal has the camera now, and will hand it back itself.
				watching:Disconnect()
				return
			end
			local t = os.clock() - startedAt
			local moved = camera.Focus.Position - focus
			local home = from + moved
			local sky = CFrame.lookAt(home.Position, home.Position + way)
			local share
			if t < LOOK_UP then
				share = TweenService:GetValue(
					t / LOOK_UP,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.InOut
				)
			elseif t < LOOK_UP + LOOK_HOLD then
				share = 1
			elseif t < LOOK_UP + LOOK_HOLD + LOOK_BACK then
				share = 1
					- TweenService:GetValue(
						(t - LOOK_UP - LOOK_HOLD) / LOOK_BACK,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.InOut
					)
			else
				watching:Disconnect()
				camera.CameraType = Enum.CameraType.Custom
				return
			end
			camera.CFrame = home:Lerp(sky, share)
		end)
	end

	local function finish(announce: boolean)
		local event = showing
		if not event then
			return
		end
		showing = nil
		for _, scene in scenes do
			scene.stop()
		end
		scenes = {}
		colorize()
		Ui.rollUp(paper)
		if announce then
			Hud.toast(Strings.get("EventOver", event.name), Color3.fromHex(event.color))
		end
	end

	-- Puts an event on show. `fresh` is whether it began while this player was here to see
	-- it begin: one they walked into has no announcement, only its sky and its timer.
	local function begin(event: Events.Event, ends: number, fresh: boolean)
		if showing == event then
			endsAt = ends
			return
		end
		finish(false)
		showing = event
		endsAt = ends
		local color = Color3.fromHex(event.color)

		table.insert(scenes, falling(event))
		local sky = if event.shows == "moon"
			then moon()
			elseif event.shows == "clouds" then clouds()
			else fireworks()
		table.insert(scenes, sky)
		colorize()

		title.Text = string.upper(event.name)
		paper.edge.Color = color
		paper.seal.BackgroundColor3 = color
		emblem:ClearAllChildren()
		Icons.event(emblem, event.shows)
		Ui.unroll(paper)

		if fresh then
			local mutation = Catalog.mutationById[event.mutation]
			StageFlash.show(
				color,
				function(holder)
					Icons.event(holder, event.shows)
				end,
				string.upper(event.name),
				Strings.get(
					"EventBegins",
					if mutation then mutation.name else event.mutation,
					if mutation then mutation.multiplier else 1
				)
			)
			-- Up at whatever hangs there: the moon where it is, the rest overhead, the way
			-- the camera already faces.
			local camera = Workspace.CurrentCamera
			local ahead = if camera then camera.CFrame.LookVector * Vector3.new(1, 0, 1) else nil
			local way = if event.shows == "moon"
					or not ahead
					or ahead.Magnitude < 0.01
				then MOON_WAY
				else (ahead.Unit + Vector3.new(0, 0.95, 0)).Unit
			lookUp(way)
		end
	end

	-- What the server says is running, read off the Hub folder.
	local started = false
	local function read()
		local hub = Workspace:FindFirstChild(Net.HUB_FOLDER)
		local id = if hub then hub:GetAttribute(Net.EVENT_ATTRIBUTE) else nil
		local ends = if hub then hub:GetAttribute(Net.EVENT_ENDS_ATTRIBUTE) else nil
		local event = if typeof(id) == "string" then Events.byId[id] else nil
		if event and typeof(ends) == "number" and Workspace:GetServerTimeNow() < ends then
			begin(event, ends, started)
		else
			finish(started)
		end
		started = true
	end
	-- The two attributes are set one after the other: they are read once both are in.
	local waiting = false
	local function changed()
		if not waiting then
			waiting = true
			task.defer(function()
				waiting = false
				read()
			end)
		end
	end
	task.spawn(function()
		local hub = Workspace:WaitForChild(Net.HUB_FOLDER, 60)
		if hub then
			hub:GetAttributeChangedSignal(Net.EVENT_ATTRIBUTE):Connect(changed)
			hub:GetAttributeChangedSignal(Net.EVENT_ENDS_ATTRIBUTE):Connect(changed)
			read()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local event = showing
		local camera = Workspace.CurrentCamera
		if not event or not camera then
			return
		end
		for _, scene in scenes do
			scene.follow(camera)
		end
		local remaining = endsAt - Workspace:GetServerTimeNow()
		if remaining <= 0 then
			-- The clock has run out before the server's word of it arrived.
			finish(true)
		else
			local text = Strings.get("EventLeft", clock(remaining))
			if left.Text ~= text then
				left.Text = text
			end
		end
	end)
end

return EventShow
