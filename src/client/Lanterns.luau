--!strict
-- The village's lanterns burn by the hour (Logic/Daylight): low through the day, up over the
-- evening, bright all night, and down again in the morning. Never out altogether: a lantern
-- that is quite dead is a gray lump on its post.
--
-- A lantern is a glowing part the server tagged, with its light inside it if it has one. What
-- the server built is the lantern at its brightest; this dims it from there, on this player's
-- screen only. The hour is the same for everyone (client Daytime), so the lanterns are too.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Daylight = require(ReplicatedStorage.Shared.Logic.Daylight)
local Daytime = require("./Daytime")
local Looks = require(ReplicatedStorage.Shared.Config.ZoneArt)
local Net = require(ReplicatedStorage.Shared.Net)

local Lanterns = {}

-- How often the hour is looked at, seconds, and how far the glow has to have moved for the
-- lanterns to be touched again. An evening takes the better part of a minute.
local CHECK_SECONDS = 0.25
local STEP = 0.004

type Lantern = {
	bright: Color3, -- the shade as the server built it
	dim: Color3,
	light: Light?,
	lightBright: number,
}

local lanterns: { [BasePart]: Lantern } = {}
local shown = -1

local function put(part: BasePart, lantern: Lantern, glow: number)
	part.Color = lantern.dim:Lerp(lantern.bright, Daylight.shade(glow))
	-- A light may arrive after the part it is in.
	local light = lantern.light
	if not light then
		light = part:FindFirstChildWhichIsA("Light")
		if light then
			lantern.light = light
			lantern.lightBright = light.Brightness
		end
	end
	if light then
		light.Brightness = lantern.lightBright * glow
	end
end

local function adopt(instance: Instance)
	if not instance:IsA("BasePart") or lanterns[instance] then
		return
	end
	local bright = instance.Color
	local shade = Looks.lanterns.shade
	local lantern: Lantern = {
		bright = bright,
		dim = Color3.new(bright.R * shade, bright.G * shade, bright.B * shade),
		light = nil,
		lightBright = 0,
	}
	lanterns[instance] = lantern
	put(instance, lantern, if shown >= 0 then shown else Daylight.glow(Daytime.clock()))
end

function Lanterns.start()
	CollectionService:GetInstanceAddedSignal(Net.LANTERN_TAG):Connect(adopt)
	CollectionService:GetInstanceRemovedSignal(Net.LANTERN_TAG):Connect(function(instance)
		lanterns[instance :: BasePart] = nil
	end)
	for _, instance in CollectionService:GetTagged(Net.LANTERN_TAG) do
		adopt(instance)
	end

	task.spawn(function()
		while true do
			local glow = Daylight.glow(Daytime.clock())
			if math.abs(glow - shown) >= STEP then
				shown = glow
				for part, lantern in lanterns do
					put(part, lantern, glow)
				end
			end
			task.wait(CHECK_SECONDS)
		end
	end)
end

return Lanterns
