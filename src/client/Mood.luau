--!strict
-- Every zone has its own light: time of day, air, color and glow (Config/ZoneArt). The mood
-- follows the camera, so it shifts as the kunai flies down the lane and as the player runs
-- home, and returns to the village's morning at the dojos. It is local to each player:
-- lighting is not shared between clients.
--
-- The light is set by where the camera is, every frame: near the line between two places it
-- is the two mixed (Logic/Crossing), and what is on screen closes on that quickly. Nothing
-- waits for a line to be crossed and then takes its time.
--
-- The village's own light goes by the hour of its day (Logic/Daylight, client Daytime): the
-- plaza with its dojos, and the first zone. Every other zone keeps its light whatever the hour.
--
-- Only numbers are changed here, on Lighting, its Atmosphere and its effects. The place's Sky,
-- and with it the moon, is never touched.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Crossing = require(ReplicatedStorage.Shared.Logic.Crossing)
local Daylight = require(ReplicatedStorage.Shared.Logic.Daylight)
local Daytime = require("./Daytime")
local Looks = require(ReplicatedStorage.Shared.Config.ZoneArt)
local Net = require(ReplicatedStorage.Shared.Net)

local Mood = {}

-- Where the camera is when it is behind the lane's start: the dojos, the market, the strip.
Mood.HOME = Crossing.HOME
-- The name of the effect the weather flashes its lightning through (client Weather). It is of
-- the class the zones' colors are graded with, and the two must not be taken for each other.
Mood.LIGHTNING = "Lightning"
-- And the name of the effect an event tints the picture with (client EventShow), passed over
-- like the lightning's.
Mood.EVENT = "EventTint"

-- How fast the light on screen closes on the light of where the camera is: this share of what
-- is left of the way, every second, as a rate. A camera that walks or runs is followed all but
-- exactly; one that flies down the lane behind a kunai, through a zone in half a second, is
-- followed smoothly instead of in flashes, and the light has settled a moment after it lands.
local FOLLOW = 6
-- Closer to where it is going than this, the light is put there and left alone.
local SETTLED = 0.002
-- The village's light is worked out anew this often, seconds, and what is on screen is written
-- out again once it has moved this far from what was last written. The sun then crosses the
-- sky in steps of a tenth of a degree, a few a second, instead of being moved every frame.
local HOUR_SECONDS = 0.2
local WRITTEN = 0.0005

-- A look as two rows, numbers and colors, in the order they are written out below. The first
-- number is the hour, which is mixed and measured round the clock.
type Row = { numbers: { number }, colors: { Color3 } }
local CLOCK = 1

type Listener = (place: string) -> ()

local listeners: { Listener } = {}
local current: string? = nil

-- Calls `fn` with where the camera is, a zone's id or Mood.HOME: right away if that is known
-- already, and again whenever it changes.
function Mood.onPlace(fn: Listener)
	table.insert(listeners, fn)
	if current then
		fn(current)
	end
end

-- The effect of that class in Lighting, made if the place has none. The weather's own effect
-- is passed over: found here, the zone's colors and the lightning would be written to one
-- effect and undo each other.
local function effect(className: string): any
	for _, child in Lighting:GetChildren() do
		local own = child.Name ~= Mood.LIGHTNING and child.Name ~= Mood.EVENT
		if child.ClassName == className and own then
			return child
		end
	end
	local made = Instance.new(className)
	made.Name = "Mood" .. className
	made.Parent = Lighting
	return made
end

local function row(look: Looks.Light): Row
	return {
		numbers = {
			look.clock,
			look.brightness,
			look.exposure,
			look.density,
			look.haze,
			look.glare,
			look.offset,
			look.saturation,
			look.contrast,
			look.lift,
			look.bloom,
			look.bloomSize,
			look.bloomThreshold,
			look.rays,
			look.raysSpread,
		},
		colors = {
			Color3.fromHex(look.ambient),
			Color3.fromHex(look.outdoor),
			Color3.fromHex(look.air),
			Color3.fromHex(look.decay),
			Color3.fromHex(look.tint),
		},
	}
end

-- `share` of the way from one row to another.
local function between(from: Row, to: Row, share: number): Row
	local numbers, colors = table.create(#from.numbers), table.create(#from.colors)
	for i, value in from.numbers do
		numbers[i] = value + (to.numbers[i] - value) * share
	end
	numbers[CLOCK] = Daylight.toward(from.numbers[CLOCK], to.numbers[CLOCK], share)
	for i, color in from.colors do
		colors[i] = color:Lerp(to.colors[i], share)
	end
	return { numbers = numbers, colors = colors }
end

-- How far apart two rows are, by the one thing that differs most. Hours and bloom sizes run
-- into the tens while most of the rest stays under one, hence the scale.
local function apart(a: Row, b: Row): number
	local most = math.abs(Daylight.onward(a.numbers[CLOCK], b.numbers[CLOCK])) / 12
	for i, value in a.numbers do
		if i ~= CLOCK then
			local scale = math.max(math.abs(value), math.abs(b.numbers[i]), 1)
			most = math.max(most, math.abs(value - b.numbers[i]) / scale)
		end
	end
	for i, color in a.colors do
		local other = b.colors[i]
		most = math.max(
			most,
			math.abs(color.R - other.R),
			math.abs(color.G - other.G),
			math.abs(color.B - other.B)
		)
	end
	return most
end

function Mood.start()
	task.spawn(function()
		-- The server builds the world at startup, but this script may run first.
		local hub = Workspace:WaitForChild(Net.HUB_FOLDER, 60)
		local origin = if hub then hub:GetAttribute(Net.ORIGIN_ATTRIBUTE) else nil
		if typeof(origin) ~= "Vector3" then
			return
		end

		local atmosphere: Atmosphere = effect("Atmosphere")
		local bloom: BloomEffect = effect("BloomEffect")
		local rays: SunRaysEffect = effect("SunRaysEffect")
		local grade: ColorCorrectionEffect = effect("ColorCorrectionEffect")

		local rows: { [string]: Row } = { [Mood.HOME] = row(Looks.home) }
		-- The places lit by the hour of the village's day.
		local daily: { [string]: boolean } = { [Mood.HOME] = true }
		for id, art in Looks.zones do
			rows[id] = row(art.light)
			daily[id] = art.daily == true
		end
		local hours: { Row } = {}
		for index, hour in Looks.day do
			hours[index] = row(hour.light)
		end

		-- The village's light at this hour. The hour itself is put in as it stands on the
		-- clock: the hours listed are only where the light is known.
		local village: Row = rows[Mood.HOME]
		local villageAt = -math.huge
		local function byTheHour(): Row
			local now = os.clock()
			if now - villageAt >= HOUR_SECONDS then
				villageAt = now
				local clock = Daytime.clock()
				local from, to, share = Daylight.mix(clock)
				village = between(hours[from], hours[to], share)
				village.numbers[CLOCK] = clock
			end
			return village
		end

		local function put(look: Row)
			local n, c = look.numbers, look.colors
			Lighting.ClockTime = n[CLOCK]
			Lighting.Brightness = n[2]
			Lighting.ExposureCompensation = n[3]
			Lighting.Ambient = c[1]
			Lighting.OutdoorAmbient = c[2]
			atmosphere.Color = c[3]
			atmosphere.Decay = c[4]
			atmosphere.Density = n[4]
			atmosphere.Haze = n[5]
			atmosphere.Glare = n[6]
			atmosphere.Offset = n[7]
			grade.TintColor = c[5]
			grade.Saturation = n[8]
			grade.Contrast = n[9]
			grade.Brightness = n[10]
			bloom.Intensity = n[11]
			bloom.Size = n[12]
			bloom.Threshold = n[13]
			rays.Intensity = n[14]
			rays.Spread = n[15]
		end

		-- What is on screen, what was last written out, and whether the light is where it is
		-- going: then nothing is worked out until the camera's place asks for another light,
		-- or the hour does.
		local shown: Row? = nil
		local written: Row? = nil
		local settled = false
		local lastFrom, lastTo, lastShare = "", "", -1

		RunService.RenderStepped:Connect(function(dt)
			-- Where the camera is along the lane decides the mood; behind the lane's start is home.
			local camera = Workspace.CurrentCamera
			local along = if camera then camera.CFrame.Position.X - origin.X else -1

			local place = Crossing.place(along)
			if place ~= current and rows[place] then
				current = place
				for _, fn in listeners do
					task.spawn(fn, place)
				end
			end

			local from, to, share = Crossing.mix(along)
			local byHour = daily[from] or daily[to]
			local first = if daily[from] then byTheHour() else rows[from]
			local second = if daily[to] then byTheHour() else rows[to]
			if not first or not second then
				return
			end
			local same = from == lastFrom and to == lastTo and share == lastShare
			if settled and same and not byHour then
				return
			end
			lastFrom, lastTo, lastShare = from, to, share

			local wanted = if share == 0 then first else between(first, second, share)
			-- The first light of a session is put on at once: there is nothing to come from.
			local now = if shown then between(shown, wanted, 1 - math.exp(-FOLLOW * dt)) else wanted
			settled = apart(now, wanted) < SETTLED
			if settled then
				now = wanted
			end
			shown = now
			if not written or apart(now, written) >= WRITTEN then
				written = now
				put(now)
			end
		end)
	end)
end

return Mood
