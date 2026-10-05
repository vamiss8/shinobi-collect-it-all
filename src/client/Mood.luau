--!strict
-- Every zone has its own time of day and air. The mood follows the camera, so it shifts as the
-- kunai flies down the lane and as the player runs home, and returns to plain daylight at the
-- dojos. It is local to each player: lighting is not shared between clients.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Net = require(ReplicatedStorage.Shared.Net)

local Mood = {}

type Look = {
	clock: number, -- time of day, hours
	ambient: Color3, -- light in the shadows
	air: Color3, -- tint of the haze and the horizon
	density: number, -- how thick the air is, 0..1
	haze: number, -- how much the distance washes out, 0..10
}

local HOME = "home"
local CHECK_SECONDS = 0.3
local SHIFT_SECONDS = 1.5

local LOOKS: { [string]: Look } = {
	[HOME] = {
		clock = 13.5,
		ambient = Color3.fromRGB(150, 150, 150),
		air = Color3.fromRGB(199, 213, 225),
		density = 0.28,
		haze = 0.5,
	},
	academy = {
		clock = 13.5,
		ambient = Color3.fromRGB(150, 150, 150),
		air = Color3.fromRGB(199, 220, 255),
		density = 0.28,
		haze = 0.5,
	},
	land_of_waves = {
		clock = 9,
		ambient = Color3.fromRGB(140, 160, 175),
		air = Color3.fromRGB(200, 225, 240),
		density = 0.45,
		haze = 2.5,
	},
	forest_of_death = {
		clock = 16.5,
		ambient = Color3.fromRGB(70, 95, 70),
		air = Color3.fromRGB(120, 150, 110),
		density = 0.5,
		haze = 2,
	},
	chunin_exam_finals = {
		clock = 12,
		ambient = Color3.fromRGB(165, 160, 145),
		air = Color3.fromRGB(215, 225, 240),
		density = 0.25,
		haze = 0.3,
	},
	valley_of_the_end = {
		clock = 17.4,
		ambient = Color3.fromRGB(170, 140, 110),
		air = Color3.fromRGB(255, 200, 150),
		density = 0.3,
		haze = 1,
	},
	hidden_sand = {
		clock = 14.5,
		ambient = Color3.fromRGB(190, 165, 120),
		air = Color3.fromRGB(240, 210, 150),
		density = 0.42,
		haze = 2.5,
	},
	akatsuki_lair = {
		clock = 18.6,
		ambient = Color3.fromRGB(120, 60, 60),
		air = Color3.fromRGB(160, 70, 70),
		density = 0.5,
		haze = 2,
	},
	hidden_rain = {
		clock = 7,
		ambient = Color3.fromRGB(90, 100, 115),
		air = Color3.fromRGB(120, 130, 145),
		density = 0.6,
		haze = 4,
	},
	kamui_dimension = {
		clock = 21,
		ambient = Color3.fromRGB(95, 100, 140),
		air = Color3.fromRGB(70, 75, 115),
		density = 0.55,
		haze = 3,
	},
	great_ninja_war = {
		clock = 19.3,
		ambient = Color3.fromRGB(110, 60, 90),
		air = Color3.fromRGB(150, 60, 90),
		density = 0.5,
		haze = 3,
	},
}

function Mood.start()
	task.spawn(function()
		-- The server builds the world at startup, but this script may run first.
		local hub = Workspace:WaitForChild(Net.HUB_FOLDER, 60)
		local origin = if hub then hub:GetAttribute(Net.ORIGIN_ATTRIBUTE) else nil
		if typeof(origin) ~= "Vector3" then
			return
		end

		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if not atmosphere then
			atmosphere = Instance.new("Atmosphere")
			atmosphere.Parent = Lighting
		end
		local shift =
			TweenInfo.new(SHIFT_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

		local current: string? = nil
		while true do
			-- Where the camera is along the lane decides the mood; behind the lane's start is home.
			local camera = Workspace.CurrentCamera
			local along = if camera then camera.CFrame.Position.X - origin.X else -1
			local place = if along < 0 then HOME else Catalog.zoneAt(along).id
			local look = LOOKS[place]
			if place ~= current and look then
				current = place
				TweenService:Create(Lighting, shift, {
					ClockTime = look.clock,
					OutdoorAmbient = look.ambient,
				}):Play()
				TweenService:Create(atmosphere, shift, {
					Color = look.air,
					Decay = look.air,
					Density = look.density,
					Haze = look.haze,
				}):Play()
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return Mood
