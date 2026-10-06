--!strict
-- Every zone has its own light: time of day, air, color and glow (Config/ZoneArt). The mood
-- follows the camera, so it shifts as the kunai flies down the lane and as the player runs
-- home, and returns to the village's morning at the dojos. It is local to each player:
-- lighting is not shared between clients.
--
-- Only numbers are changed here, on Lighting, its Atmosphere and its effects. The place's Sky,
-- and with it the moon, is never touched.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Looks = require(ReplicatedStorage.Shared.Config.ZoneArt)
local Net = require(ReplicatedStorage.Shared.Net)

local Mood = {}

-- Where the camera is when it is behind the lane's start: the dojos, the market, the strip.
Mood.HOME = "home"

local CHECK_SECONDS = 0.3
local SHIFT_SECONDS = 1.5

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

-- The effect of that class in Lighting, made if the place has none.
local function effect(className: string): any
	local found = Lighting:FindFirstChildOfClass(className)
	if not found then
		found = Instance.new(className)
		found.Name = "Mood" .. className
		found.Parent = Lighting
	end
	return found
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
		local shift =
			TweenInfo.new(SHIFT_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

		local function put(look: Looks.Light)
			TweenService:Create(Lighting, shift, {
				ClockTime = look.clock,
				Brightness = look.brightness,
				ExposureCompensation = look.exposure,
				Ambient = Color3.fromHex(look.ambient),
				OutdoorAmbient = Color3.fromHex(look.outdoor),
			}):Play()
			TweenService:Create(atmosphere, shift, {
				Color = Color3.fromHex(look.air),
				Decay = Color3.fromHex(look.decay),
				Density = look.density,
				Haze = look.haze,
				Glare = look.glare,
				Offset = look.offset,
			}):Play()
			TweenService:Create(grade, shift, {
				TintColor = Color3.fromHex(look.tint),
				Saturation = look.saturation,
				Contrast = look.contrast,
				Brightness = look.lift,
			}):Play()
			TweenService:Create(bloom, shift, {
				Intensity = look.bloom,
				Size = look.bloomSize,
				Threshold = look.bloomThreshold,
			}):Play()
			TweenService:Create(rays, shift, {
				Intensity = look.rays,
				Spread = look.raysSpread,
			}):Play()
		end

		while true do
			-- Where the camera is along the lane decides the mood; behind the lane's start is home.
			local camera = Workspace.CurrentCamera
			local along = if camera then camera.CFrame.Position.X - origin.X else -1
			local place = if along < 0 then Mood.HOME else Catalog.zoneAt(along).id
			if place ~= current then
				local art = Looks.zones[place]
				local look = if place == Mood.HOME then Looks.home elseif art then art.light else nil
				if look then
					current = place
					put(look)
					for _, fn in listeners do
						task.spawn(fn, place)
					end
				end
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return Mood
