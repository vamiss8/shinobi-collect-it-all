--!strict
-- An event on this player's screen (Config/Events; the server says which is running and until
-- when, on the Hub folder). When one begins the player cannot miss it: the screen flashes in
-- its color, a scroll names it and what it brings, and the camera flies off from the player,
-- climbs, looks up at the sky, where the event hangs, and flies home (Logic/SkyLook). While it
-- runs the whole picture is tinted, something falls or rises everywhere, and a scroll in the
-- corner counts down what is left of it. No two events look alike: the moon turned red over a
-- red night, a ceiling of red cloud shedding black feathers, fireworks over falling gold
-- leaves on a lantern-lit evening.
--
-- THE RED MOON IS THE MOON, NOT A DRAWING OF ONE (owner, 2026-10-09, on the first, a disc of
-- flat red with three dark spots: "it looks slightly cartoonish, and is not always laid over
-- the Moon at once: at the start of the camera's flight it is sometimes not there yet, and it
-- looks crooked"). It is the place's own moon texture, tinted red, on a board that stands
-- exactly where the hour has the moon, from the first frame and through the turn of the clock:
-- the board is put there again whenever the light is written (Mood.onLit).
--
-- AN EVENT LOOKS THE SAME WHATEVER THE HOUR: the village is held in the event's own light for
-- as long as it runs (Mood.hold), and nothing an event puts in the air takes the light of the
-- place, which by night would turn gold leaves gray.
--
-- All of it is this client's own: the tint is an effect of its own in Lighting, beside the
-- zone's and the lightning's (client Mood, Weather), and what is in the sky follows this
-- camera. And the last zone keeps its own light and its own sky through any event, as it is
-- to keep them through everything: no tint there, no red moon over its moon, no cloud across
-- it.
--
-- NOBODY IS INTERRUPTED BY AN EVENT (owner, 2026-10-10: "I hope the events' animations do
-- not start for people who are at home, in a throw and so on, even if they only sit in the
-- throw panel"). A player on the throwing strip, with its bar swinging, or anywhere between
-- their kunai's flight and the end of their run home, gets no flash, no scroll across the
-- screen and no camera: a line on the message scroll and the timer in the corner tell them,
-- and the sky is there when they look up. The camera is flown only for a player who is doing
-- nothing that needs it: not with a window or the throw power slider open either, nor under
-- a roof, which is to say at home in their dojo.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Cinematic = require("./Cinematic")
local Events = require(ReplicatedStorage.Shared.Logic.Events)
local Hud = require("./Hud")
local Icons = require("./Icons")
local Looks = require(ReplicatedStorage.Shared.Config.ZoneArt)
local Mood = require("./Mood")
local Net = require(ReplicatedStorage.Shared.Net)
local Particles = require(ReplicatedStorage.Shared.View.Particles)
local Remotes = require("./Remotes")
local SkyLook = require(ReplicatedStorage.Shared.Logic.SkyLook)
local StageFlash = require("./StageFlash")
local Strings = require("./Strings")
local ThrowPower = require("./ThrowPower")
local Ui = require("./Ui")
local Weather = require("./Weather")

local EventShow = {}

-- The scroll with the countdown, in the top left corner.
local TIMER = Vector2.new(330, 78)
local TIMER_SEAL = 56
-- How long the picture takes to take an event's tint, and to lose it, seconds.
local TINT_SECONDS = 2.5
-- The look at the sky when an event begins (Logic/SkyLook has its timing and its way). The
-- camera watches a point this far over the player's middle, studs. It is not flown for a
-- player with something solid this near overhead, nor for one whose camera is nearer them than
-- FIRST_PERSON, who is looking out of their own eyes. It keeps CLEAR studs short of whatever
-- stands in its way, and is not flown at all with less than ROOM_LEAST of the way free.
local EYES = 1.5
local ROOF = 40
local FIRST_PERSON = 1.5
local CLEAR = 2
local ROOM_LEAST = 0.4
-- The clock is turned to an event's hour in this long, seconds: the sky has all but arrived
-- by the time the camera's eyes have lifted to it (Logic/SkyLook).
local HOLD_SECONDS = 2.4
-- The red moon is the place's own moon turned red: a board that hangs before it and hides it,
-- wherever the hour has it in the sky. In a place lit by the hour that is where it always is,
-- below the horizon too, so that it rises with the moon as the clock is turned. Elsewhere it
-- is on the moon when the zone's hour has one up (MOON_LOW is how high, as the height of its
-- direction) and hangs MOON_WAY when it has none, and goes from the one to the other in
-- MOON_SWING seconds as the camera passes from zone to zone. The board is MOON_FAR studs off,
-- near enough for the air's haze to leave it be; MOON_DISC of it is the moon and the rest its
-- glow, and the moon on it is MOON_OVER times as wide as the one it covers, which is
-- MOON_ANGLE degrees wide when the place has no Sky to ask.
local MOON_WAY = Vector3.new(-0.42, 0.56, 0.72).Unit
local MOON_LOW = 0.3
local MOON_SWING = 0.7
local MOON_FAR = 340
local MOON_DISC = 0.62
local MOON_OVER = 1.14
local MOON_ANGLE = 11
-- The moon every place has unless its Sky names another, and where the disc lies in that
-- picture, which is 128 pixels square with black round the moon: the corner and the size of
-- the square the disc fills, a pixel inside its soft edge.
local MOON_TEXTURE = "rbxasset://sky/moon.jpg"
local MOON_CUT = { 9, 7, 111, 112 }
-- What the gray moon is multiplied by, and how many times brighter than that it is drawn.
local MOON_RED = Color3.fromRGB(255, 58, 70)
local MOON_BRIGHT = 2.2
-- The cloud ceiling: how far over the camera it hangs and how wide it is, studs.
local CEILING_UP = 120
local CEILING_WIDE = 420
-- Fireworks: where a rocket bursts from the camera, studs out and up, and how long between two.
local BURST_OUT = 150
local BURST_UP = { 70, 130 }
local BURST_EVERY = { 0.6, 1.3 }
local BURST_COLORS = { "#FFD54F", "#FF80AB", "#69F0AE", "#FFFFFF" }
-- While the camera looks at the sky they burst where it looks: this far off, within this far
-- of the middle of the picture, studs, and this often.
local WATCHED_OUT = 150
local WATCHED_SPREAD = 46
local WATCHED_EVERY = { 0.3, 0.55 }

-- What an event has put in the world for this client, to be taken out again.
type Scene = {
	follow: (camera: Camera) -> (), -- moves it with the camera, every frame
	stop: () -> (),
	-- Which way it hangs from the camera, for what hangs in one part of the sky.
	way: (() -> Vector3)?,
	-- Called with whether the camera is where the sky is to be left as it is (the last zone):
	-- what would hang across that sky is taken out of it.
	plain: ((plain: boolean) -> ())?,
	-- Called with the way the camera looks while it looks at the sky, and with nil after.
	watched: ((way: Vector3?) -> ())?,
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

-- A red moon: the moon's own picture, tinted, on a board that always faces the camera, far
-- off, before the moon. `byTheHour` says whether the camera is in a place lit by the hour,
-- where the board keeps to the moon whatever its height.
local function moon(byTheHour: () -> boolean): Scene
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local angle = if sky then sky.MoonAngularSize else MOON_ANGLE
	local texture = if sky and sky.MoonTextureId ~= "" then sky.MoonTextureId else MOON_TEXTURE
	local wide = 2 * MOON_FAR * math.tan(math.rad(angle * MOON_OVER / 2)) / MOON_DISC
	local anchor = unseen(Vector3.one)
	local board: BillboardGui = Ui.make("BillboardGui", {
		Size = UDim2.fromScale(wide, wide),
		LightInfluence = 0,
		Brightness = MOON_BRIGHT,
		MaxDistance = MOON_FAR * 3,
	}, anchor)
	local function disc(size: number, color: Color3, clear: number)
		local frame = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(size, size),
			BackgroundColor3 = color,
			BackgroundTransparency = clear,
			BorderSizePixel = 0,
		}, board)
		Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	end
	-- A faint glow, thinning outward; under the moon a plain red disc, which is all there is
	-- should the picture not load; and the moon.
	disc(1, Color3.fromRGB(255, 40, 70), 0.93)
	disc(0.86, Color3.fromRGB(255, 50, 76), 0.88)
	disc(0.72, Color3.fromRGB(255, 64, 84), 0.8)
	disc(MOON_DISC, Color3.fromRGB(190, 26, 44), 0)
	local face: ImageLabel = Ui.make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(MOON_DISC, MOON_DISC),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = texture,
		ImageColor3 = MOON_RED,
		ScaleType = Enum.ScaleType.Stretch,
	}, board)
	if texture == MOON_TEXTURE then
		face.ImageRectOffset = Vector2.new(MOON_CUT[1], MOON_CUT[2])
		face.ImageRectSize = Vector2.new(MOON_CUT[3], MOON_CUT[4])
	end
	-- The picture is square, with black in its corners: the board shows the round of it.
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, face)

	-- How much the board is on the real moon, 0..1, and where that puts it.
	local function wanted(): number
		return if byTheHour() or Lighting:GetMoonDirection().Y > MOON_LOW then 1 else 0
	end
	local onMoon = wanted()
	local way = MOON_WAY
	local last = os.clock()
	return {
		follow = function(camera)
			local now = os.clock()
			local goal = wanted()
			local step = (now - last) / MOON_SWING
			last = now
			onMoon = if goal > onMoon
				then math.min(onMoon + step, goal)
				else math.max(onMoon - step, goal)
			local real = Lighting:GetMoonDirection()
			-- On the moon it is on the moon exactly: anything that eased it there would let
			-- the white moon show beside it while the clock is turned.
			local mixed = if onMoon >= 1 then real else MOON_WAY:Lerp(real, onMoon)
			if mixed.Magnitude > 0.01 then
				way = mixed.Unit
			end
			anchor.CFrame = CFrame.new(camera.CFrame.Position + way * MOON_FAR)
		end,
		stop = function()
			anchor:Destroy()
		end,
		way = function()
			return way
		end,
		plain = function(plain)
			board.Enabled = not plain
		end,
	}
end

-- A ceiling of cloud over the camera: great slow puffs, dark red among black.
local function clouds(): Scene
	local ceiling = unseen(Vector3.new(CEILING_WIDE, 2, CEILING_WIDE))
	local banks: { ParticleEmitter } = {}
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
		table.insert(banks, puffs)
	end
	return {
		follow = function(camera)
			ceiling.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, CEILING_UP, 0))
		end,
		stop = function()
			ceiling:Destroy()
		end,
		plain = function(plain)
			for _, puffs in banks do
				puffs.Enabled = not plain
			end
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
			-- Not all light: light alone is lost against a sky that is still bright.
			glow = 0.6,
			bright = 4,
			fade = 0,
		}, Color3.fromHex(color))
		sparks.Parent = rocket
		table.insert(bursts, sparks)
	end
	local rng = Random.new()
	local at = Vector3.zero
	local watched: Vector3? = nil
	local running = true
	task.spawn(function()
		while running do
			local every = if watched then WATCHED_EVERY else BURST_EVERY
			task.wait(rng:NextNumber(every[1], every[2]))
			if not running then
				break
			end
			local looked = watched
			local out = if looked
				then looked * WATCHED_OUT + Vector3.new(
					rng:NextNumber(-WATCHED_SPREAD, WATCHED_SPREAD),
					rng:NextNumber(-WATCHED_SPREAD, WATCHED_SPREAD),
					rng:NextNumber(-WATCHED_SPREAD, WATCHED_SPREAD)
				)
				else Vector3.new(
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
		watched = function(way)
			watched = way
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
	-- A zone's weather takes the light of its zone. An event's shows its own colors: the
	-- village may be at any hour when it begins, and a gold leaf is gold at all of them.
	made.LightInfluence = 0
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
	-- Whether the camera is in a place lit by the hour of the village's day.
	local inVillage = true

	-- The event on show, the moment it ends, and what it has put in the world.
	local showing: Events.Event? = nil
	local endsAt = 0
	local scenes: { Scene } = {}

	local function colorize()
		local event = showing
		local sky = if event and not inLastZone then event.sky else nil
		for _, scene in scenes do
			if scene.plain then
				scene.plain(inLastZone)
			end
		end
		TweenService:Create(tint, TweenInfo.new(TINT_SECONDS), {
			TintColor = if sky then Color3.fromHex(sky.tint) else Color3.new(1, 1, 1),
			Brightness = if sky then sky.brightness else 0,
			Contrast = if sky then sky.contrast else 0,
			Saturation = if sky then sky.saturation else 0,
		}):Play()
	end
	Mood.onPlace(function(place)
		inLastZone = place == lastZone
		local art = Looks.zones[place]
		inVillage = place == Mood.HOME or (art ~= nil and art.daily == true)
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

	-- Whether the player is in the middle of a throw, from the bar on the strip to the end of
	-- the run home: nothing of an event is to come between them and it.
	local function throwing(): boolean
		return aiming or thrown or Cinematic.staging()
	end

	-- Whether the player is at something on the screen: a window, or the throw power slider.
	local function reading(): boolean
		return Ui.windowOpen() or ThrowPower.isOpen()
	end

	-- The look at the sky (Logic/SkyLook): the camera leaves the player's shoulder, draws back
	-- and climbs with them still in the picture, lifts its eyes `way`, and comes home the way
	-- it went, to where it was about the player, who may have walked on meanwhile. `over` is
	-- called when it is done with. Not flown for a player who is busy with a throw or with a
	-- window, stands under a roof or looks out of their own eyes; given up at once if a
	-- throw's staging takes the camera, and flown home quickly for a player who begins to aim
	-- or opens a window.
	local function lookUp(way: () -> Vector3, over: () -> ()): boolean
		local camera = Workspace.CurrentCamera
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not camera or not root or not root:IsA("BasePart") then
			return false
		end
		if throwing() or reading() then
			return false
		end
		-- Something else has the camera.
		if camera.CameraType ~= Enum.CameraType.Custom then
			return false
		end
		local from = camera.CFrame
		local offset = from.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude < FIRST_PERSON then
			return false
		end
		local stand: SkyLook.Stand = {
			radius = flat.Magnitude,
			height = offset.Y,
			angle = math.atan2(flat.Z, flat.X),
		}
		-- The camera climbs on the side of the player away from what it will look at; for
		-- something straight overhead, on the side it is on.
		local toward = way()
		local side = if math.abs(toward.X) + math.abs(toward.Z) > 0.05
			then math.atan2(-toward.Z, -toward.X)
			else stand.angle

		-- What stands in the way is what a character would bump into: the dojos, the shops'
		-- roofs, the yard's unseen fence. Other players do not count.
		local people: { Instance } = {}
		for _, player in Players:GetPlayers() do
			if player.Character then
				table.insert(people, player.Character)
			end
		end
		local solid = RaycastParams.new()
		solid.FilterType = Enum.RaycastFilterType.Exclude
		solid.FilterDescendantsInstances = people
		solid.RespectCanCollide = true
		local eyes = root.Position + Vector3.new(0, EYES, 0)
		if Workspace:Raycast(eyes, Vector3.new(0, ROOF, 0), solid) then
			return false
		end
		local function about(at: SkyLook.Stand): Vector3
			return Vector3.new(
				math.cos(at.angle) * at.radius,
				at.height,
				math.sin(at.angle) * at.radius
			)
		end
		local out = root.Position + about(SkyLook.peak(stand, side, 1)) - eyes
		local hit = Workspace:Raycast(eyes, out, solid)
		local room = if hit then math.max(hit.Distance - CLEAR, 0) / out.Magnitude else 1
		if room < ROOM_LEAST then
			return false
		end
		local peak = SkyLook.peak(stand, side, room)

		local startedAt = os.clock()
		-- When the look was given up, and how far out the camera and its eyes were then.
		local hurriedAt: number? = nil
		local flyFrom, gazeFrom = 0, 0
		camera.CameraType = Enum.CameraType.Scriptable
		local watching: RBXScriptConnection
		local function home()
			watching:Disconnect()
			if root.Parent then
				camera.CFrame = CFrame.new(root.Position + offset) * from.Rotation
			end
			camera.CameraType = Enum.CameraType.Custom
			over()
		end
		watching = RunService.RenderStepped:Connect(function()
			if Cinematic.staging() then
				-- The reveal has the camera now, and will hand it back itself.
				watching:Disconnect()
				over()
				return
			end
			if not root.Parent then
				home()
				return
			end
			local now = os.clock()
			local fly: number, gaze: number
			if hurriedAt then
				local still = 1 - SkyLook.eased((now - hurriedAt) / SkyLook.HURRY)
				if still <= 0 then
					home()
					return
				end
				fly, gaze = flyFrom * still, gazeFrom * still
			else
				local time = now - startedAt
				if time >= SkyLook.length() then
					home()
					return
				end
				fly, gaze = SkyLook.at(time)
				if throwing() or reading() then
					hurriedAt, flyFrom, gazeFrom = now, fly, gaze
				end
			end
			local place = root.Position + about(SkyLook.orbit(stand, peak, fly))
			local onPlayer = CFrame.lookAt(place, root.Position + Vector3.new(0, EYES, 0)).Rotation
			local onSky = CFrame.lookAt(place, place + way()).Rotation
			-- At the shoulder the camera looks as the player had it; a third of the way out it
			-- has turned to them.
			local turned = from.Rotation:Lerp(onPlayer, SkyLook.eased(fly * 3))
			camera.CFrame = CFrame.new(place) * turned:Lerp(onSky, gaze)
		end)
		return true
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
		Mood.hold(nil)
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
			then moon(function()
				return inVillage
			end)
			elseif event.shows == "clouds" then clouds()
			else fireworks()
		table.insert(scenes, sky)
		-- Where it all hangs from the first moment, before a frame has gone by.
		local eye = Workspace.CurrentCamera
		if eye then
			for _, scene in scenes do
				scene.follow(eye)
			end
		end
		Mood.hold(event.light, HOLD_SECONDS)
		colorize()

		title.Text = string.upper(event.name)
		paper.edge.Color = color
		paper.seal.BackgroundColor3 = color
		emblem:ClearAllChildren()
		Icons.event(emblem, event.shows)
		Ui.unroll(paper)

		local mutation = Catalog.mutationById[event.mutation]
		if fresh and throwing() then
			-- In the middle of a throw the event is told in a line and no more: a flash across
			-- the bar would cost a Perfect, and a scroll would lie over the roulette.
			Hud.toast(
				Strings.get(
					"EventBegan",
					event.name,
					if mutation then mutation.name else event.mutation
				),
				color
			)
		elseif fresh then
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
			local overhead = if ahead and ahead.Magnitude > 0.01
				then (ahead.Unit + Vector3.new(0, 0.95, 0)).Unit
				else MOON_WAY
			local way: () -> Vector3 = sky.way or function(): Vector3
				return overhead
			end
			local watched = sky.watched
			local flown = lookUp(way, function()
				if watched then
					watched(nil)
				end
			end)
			if flown and watched then
				watched(way())
			end
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

	-- What hangs where the hour has the moon is put there again once the hour has been written
	-- for the frame: whichever of the two modules is stepped first, it ends where the moon is.
	Mood.onLit(function()
		local camera = Workspace.CurrentCamera
		if showing and camera then
			for _, scene in scenes do
				scene.follow(camera)
			end
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
