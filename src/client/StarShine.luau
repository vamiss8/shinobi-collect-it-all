--!strict
-- Sets the greater merge stars moving, wherever they are drawn (View/Stars: the tags over the
-- figures, cards, merge chips, slots): a platinum star's sparkle twinkles now and again; a Six
-- Paths star's rays turn, its dark shadow breathes, its six orbs go round it, passing in front
-- of it and behind, and its sparkle twinkles. Each star keeps its own time, so that a row of
-- them does not twinkle at once. The letters' own colors are client Lettering's.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Stars = require(ReplicatedStorage.Shared.View.Stars)

local StarShine = {}

-- How often the stars are moved, seconds: as smooth as the eye asks of something this small.
local STEP = 1 / 30
-- A sparkle's twinkle: how long it shows, and how often it comes, by kind.
local TWINKLE = 0.55
local EVERY: { [string]: number } = { platinum = 2.8, sixpaths = 1.9 }
-- How fast a Six Paths star's rays turn (degrees a second) and its orbs go round (radians).
local RAYS_TURN = 24
local ORBITS = 1.2

type Record = {
	kind: string,
	seed: number,
	z: number,
	glint: Frame?,
	twinkle: UIScale?,
	rays: Frame?,
	breath: UIScale?,
	orbs: { Frame },
}

local tracked: { [Frame]: Record } = {}

local function adopt(instance: Instance)
	if not instance:IsA("Frame") or tracked[instance] then
		return
	end
	local kind = instance:GetAttribute(Stars.KIND_ATTRIBUTE)
	if typeof(kind) ~= "string" then
		return
	end
	local glint = instance:FindFirstChild("Glint")
	local rays = instance:FindFirstChild("Rays")
	local shadow = instance:FindFirstChild("Shadow")
	local orbs: { Frame } = {}
	for _, child in instance:GetChildren() do
		if child.Name == "Orb" and child:IsA("Frame") then
			table.insert(orbs, child)
		end
	end
	local twinkle = if glint then glint:FindFirstChild("Twinkle") else nil
	local breath = if shadow then shadow:FindFirstChild("Breath") else nil
	tracked[instance] = {
		kind = kind,
		seed = math.random() * 10,
		z = instance.ZIndex,
		glint = if glint and glint:IsA("Frame") then glint else nil,
		twinkle = if twinkle and twinkle:IsA("UIScale") then twinkle else nil,
		rays = if rays and rays:IsA("Frame") then rays else nil,
		breath = if breath and breath:IsA("UIScale") then breath else nil,
		orbs = orbs,
	}
end

local function move(record: Record, now: number)
	local twinkle, glint = record.twinkle, record.glint
	if twinkle and glint then
		local every = EVERY[record.kind] or 2.5
		local into = (now + record.seed) % every
		twinkle.Scale = if into < TWINKLE then math.sin(into / TWINKLE * math.pi) else 0
		glint.Rotation = into / TWINKLE * 90
	end
	local rays = record.rays
	if rays then
		rays.Rotation = ((now + record.seed) * RAYS_TURN) % 360
	end
	local breath = record.breath
	if breath then
		breath.Scale = 1 + 0.09 * math.sin(now * 2.6 + record.seed)
	end
	for index, orb in record.orbs do
		local angle = now * ORBITS + record.seed + (index - 1) * math.pi / 3
		local front = math.sin(angle)
		orb.Position = UDim2.fromScale(0.5 + 0.62 * math.cos(angle), 0.5 + 0.26 * front)
		-- On the near side of its round it passes before the star, on the far side behind it.
		orb.ZIndex = if front > 0 then record.z + 2 else record.z
	end
end

function StarShine.start()
	CollectionService:GetInstanceAddedSignal(Net.STAR_TAG):Connect(adopt)
	for _, instance in CollectionService:GetTagged(Net.STAR_TAG) do
		adopt(instance)
	end
	CollectionService:GetInstanceRemovedSignal(Net.STAR_TAG):Connect(function(instance)
		if instance:IsA("Frame") then
			tracked[instance] = nil
		end
	end)

	local since = 0
	RunService.RenderStepped:Connect(function(dt)
		since += dt
		if since < STEP then
			return
		end
		since = 0
		local now = os.clock()
		for core, record in tracked do
			if core.Parent then
				move(record, now)
			else
				tracked[core] = nil
			end
		end
	end)
end

return StarShine
