--!strict
-- The weather of the zone the camera is in (Config/ZoneArt): leaves, feathers, rain, sand on
-- the wind, and lightning. It is one emitter that travels with the camera, so it costs the same
-- however long the zone is, and it exists only on this player's screen.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Looks = require(ReplicatedStorage.Shared.Config.ZoneArt)
local Mood = require("./Mood")
local Particles = require(ReplicatedStorage.Shared.View.Particles)

local Weather = {}

local TEXTURES = {
	sparkle = Particles.SPARKLE,
	smoke = Particles.SMOKE,
	fire = Particles.FIRE,
}
local DIRECTIONS = {
	down = Enum.NormalId.Bottom,
	up = Enum.NormalId.Top,
	across = Enum.NormalId.Back,
}

-- A flash of lightning: how bright the screen jumps, and how long each of its two strokes
-- takes to die away, seconds.
local FLASH = 0.55
local AFTERFLASH = 0.3
local STROKE_SECONDS = { 0.12, 0.4 }

local function emitter(weather: Looks.Weather): ParticleEmitter
	local color = Color3.fromHex(weather.color)
	local clear = weather.fade
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = TEXTURES[weather.texture]
	particles.EmissionDirection = DIRECTIONS[weather.direction]
	particles.Rate = weather.rate
	particles.Lifetime = NumberRange.new(weather.life[1], weather.life[2])
	particles.Speed = NumberRange.new(weather.speed[1], weather.speed[2])
	particles.SpreadAngle = Vector2.new(weather.spread, weather.spread)
	particles.Acceleration = Vector3.new(weather.wind[1], -weather.fall, weather.wind[2])
	particles.Size = NumberSequence.new(weather.size[1], weather.size[2])
	particles.Squash = NumberSequence.new(weather.squash)
	if weather.streaks then
		particles.Orientation = Enum.ParticleOrientation.VelocityParallel
	else
		particles.Rotation = NumberRange.new(0, 360)
		particles.RotSpeed = NumberRange.new(-weather.spin, weather.spin)
	end
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.1, clear),
		NumberSequenceKeypoint.new(0.85, clear),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Color = ColorSequence.new(color)
	particles.LightEmission = weather.glow
	-- What does not glow is lit by the zone: rain in the dark is dark.
	particles.LightInfluence = 1 - weather.glow
	return particles
end

-- The emitter of a kind of weather, for whoever else has something fall on the camera (an
-- event has: client EventShow).
Weather.emitter = emitter

function Weather.start()
	-- The space the particles appear in; it is moved with the camera every frame.
	local cloud = Instance.new("Part")
	cloud.Name = "Weather"
	cloud.Anchored = true
	cloud.CanCollide = false
	cloud.CanQuery = false
	cloud.CanTouch = false
	cloud.Transparency = 1
	cloud.Parent = Workspace

	-- Lightning brightens the screen through an effect of its own, so it never fights the
	-- zone's light (client Mood) over the same number.
	local lightning = Instance.new("ColorCorrectionEffect")
	lightning.Name = Mood.LIGHTNING
	lightning.Parent = Lighting

	local shift = Vector3.zero
	local falling: ParticleEmitter? = nil
	-- Changes with the weather, so a storm that was left stops flashing.
	local token = {}

	local function flashes(mine: {}, gap: { number })
		local rng = Random.new()
		while token == mine do
			task.wait(rng:NextNumber(gap[1], gap[2]))
			if token ~= mine then
				break
			end
			for stroke, brightness in { FLASH, AFTERFLASH } do
				lightning.Brightness = brightness
				local fade = TweenService:Create(
					lightning,
					TweenInfo.new(
						STROKE_SECONDS[stroke],
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out
					),
					{ Brightness = 0 }
				)
				fade:Play()
				fade.Completed:Wait()
			end
		end
	end

	Mood.onPlace(function(place)
		token = {}
		lightning.Brightness = 0
		if falling then
			-- What is in the air finishes falling.
			falling.Enabled = false
			Debris:AddItem(falling, 10)
			falling = nil
		end

		local art = Looks.zones[place]
		local weather = if art then art.weather else nil
		if not weather then
			return
		end
		cloud.Size = Vector3.new(weather.box[1], weather.box[2], weather.box[3])
		shift = Vector3.new(weather.shift[1], weather.shift[2], weather.shift[3])
		local made = emitter(weather)
		made.Parent = cloud
		falling = made
		if weather.flash then
			task.spawn(flashes, token, weather.flash)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if camera and falling then
			cloud.CFrame = CFrame.new(camera.CFrame.Position + shift)
		end
	end)
end

return Weather
