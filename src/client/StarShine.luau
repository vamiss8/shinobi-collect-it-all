--!strict
-- Sets the greater merge stars moving, wherever they are drawn (View/Stars: the tags over the
-- figures, cards, merge chips, slots): a platinum star's sparkle twinkles now and again; a Six
-- Paths star's rays flare and fade, its dark shadow breathes, a ring of light spreads from it
-- and is gone, and its sparkle twinkles. (Its orbs that went round it are gone: "its orbit
-- sometimes does not turn", owner, 2026-10-19.) Each star keeps its own time, so that a row of
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
-- A Six Paths star's beat: its rays flare and its ring spreads once in this many seconds.
local BEAT = 1.6

type Record = {
	kind: string,
	seed: number,
	z: number,
	glint: Frame?,
	twinkle: UIScale?,
	flare: UIScale?,
	breath: UIScale?,
	spread: UIScale?,
	ring: UIStroke?,
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
	local halo = instance:FindFirstChild("Halo")
	local twinkle = if glint then glint:FindFirstChild("Twinkle") else nil
	local flare = if rays then rays:FindFirstChild("Flare") else nil
	local breath = if shadow then shadow:FindFirstChild("Breath") else nil
	local spread = if halo then halo:FindFirstChild("Spread") else nil
	local ring = if halo then halo:FindFirstChild("Ring") else nil
	tracked[instance] = {
		kind = kind,
		seed = math.random() * 10,
		z = instance.ZIndex,
		glint = if glint and glint:IsA("Frame") then glint else nil,
		twinkle = if twinkle and twinkle:IsA("UIScale") then twinkle else nil,
		flare = if flare and flare:IsA("UIScale") then flare else nil,
		breath = if breath and breath:IsA("UIScale") then breath else nil,
		spread = if spread and spread:IsA("UIScale") then spread else nil,
		ring = if ring and ring:IsA("UIStroke") then ring else nil,
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
	-- The beat: at its start the rays flare out and the ring leaves the star; through it the
	-- rays sink back and the ring spreads and fades.
	local beat = ((now + record.seed) % BEAT) / BEAT
	local flare = record.flare
	if flare then
		flare.Scale = 0.8 + 0.4 * (1 - beat) ^ 2
	end
	local breath = record.breath
	if breath then
		breath.Scale = 1 + 0.1 * math.sin(beat * 2 * math.pi)
	end
	local spread, ring = record.spread, record.ring
	if spread and ring then
		spread.Scale = 1 + 1.1 * beat
		ring.Transparency = 0.15 + 0.85 * beat
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
