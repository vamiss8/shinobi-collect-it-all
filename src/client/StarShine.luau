--!strict
-- Sets the greater merge stars moving, wherever they are drawn (View/Stars: the tags over the
-- figures, cards, merge chips, slots): a platinum star's sparkle twinkles now and again; a Six
-- Paths star's rays turn slowly and flare on the beat, its dark shadow breathes, its sparkle
-- twinkles on the beat and three small ones glitter round it after it, one by one.
--
-- EVERY STAR OF A KIND KEEPS ONE TIME, the clock's: stars that each kept their own pulsed at
-- odd moments, which looked strange (owner, 2026-10-19), and so did the ring that spread from
-- a Six Paths star, which is gone. The letters' own colors are client Lettering's.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Stars = require(ReplicatedStorage.Shared.View.Stars)

local StarShine = {}

-- How often the stars are moved, seconds: as smooth as the eye asks of something this small.
local STEP = 1 / 30
-- A sparkle's twinkle, seconds.
local TWINKLE = 0.5
-- How often a platinum star's sparkle twinkles; a Six Paths star's beat.
local PLATINUM_EVERY = 2.6
local BEAT = 1.4
-- How fast a Six Paths star's rays turn, degrees a second.
local RAYS_TURN = 16

type Record = {
	kind: string,
	glint: Frame?,
	twinkle: UIScale?,
	flare: UIScale?,
	rays: Frame?,
	breath: UIScale?,
	glitter: { { frame: Frame, scale: UIScale } },
}

local tracked: { [Frame]: Record } = {}

-- A sparkle and its twinkle, if a frame by that name has them.
local function sparkleOf(core: Instance, name: string): (Frame?, UIScale?)
	local frame = core:FindFirstChild(name)
	if not frame or not frame:IsA("Frame") then
		return nil, nil
	end
	local scale = frame:FindFirstChild("Twinkle")
	return frame, if scale and scale:IsA("UIScale") then scale else nil
end

local function adopt(instance: Instance)
	if not instance:IsA("Frame") or tracked[instance] then
		return
	end
	local kind = instance:GetAttribute(Stars.KIND_ATTRIBUTE)
	if typeof(kind) ~= "string" then
		return
	end
	local glint, twinkle = sparkleOf(instance, "Glint")
	local rays = instance:FindFirstChild("Rays")
	local shadow = instance:FindFirstChild("Shadow")
	local flare = if rays then rays:FindFirstChild("Flare") else nil
	local breath = if shadow then shadow:FindFirstChild("Breath") else nil
	local glitter = {}
	for index = 1, 3 do
		local frame, scale = sparkleOf(instance, `Glitter{index}`)
		if frame and scale then
			table.insert(glitter, { frame = frame, scale = scale })
		end
	end
	tracked[instance] = {
		kind = kind,
		glint = glint,
		twinkle = twinkle,
		flare = if flare and flare:IsA("UIScale") then flare else nil,
		rays = if rays and rays:IsA("Frame") then rays else nil,
		breath = if breath and breath:IsA("UIScale") then breath else nil,
		glitter = glitter,
	}
end

-- How bright a sparkle whose twinkle began `since` seconds ago is: 0 when it is not showing,
-- up to 1 at its brightest.
local function twinkleAt(since: number): number
	if since < 0 or since >= TWINKLE then
		return 0
	end
	return math.sin(since / TWINKLE * math.pi)
end

local function move(record: Record, now: number)
	if record.kind == "platinum" then
		local into = now % PLATINUM_EVERY
		if record.twinkle and record.glint then
			record.twinkle.Scale = twinkleAt(into)
			record.glint.Rotation = into / TWINKLE * 90
		end
		return
	end

	-- A Six Paths star: everything on one beat.
	local into = now % BEAT
	local beat = into / BEAT
	local rays = record.rays
	if rays then
		rays.Rotation = (now * RAYS_TURN) % 360
	end
	local flare = record.flare
	if flare then
		-- Flung out at the beat's start, sinking back through it.
		flare.Scale = 0.85 + 0.35 * (1 - beat) ^ 3
	end
	local breath = record.breath
	if breath then
		breath.Scale = 1 + 0.12 * (1 - beat) ^ 2
	end
	if record.twinkle and record.glint then
		record.twinkle.Scale = twinkleAt(into)
		record.glint.Rotation = into / TWINKLE * 90
	end
	-- The small ones, one after another through the rest of the beat.
	for index, spark in record.glitter do
		local since = into - index * (BEAT / 4)
		spark.scale.Scale = twinkleAt(since)
		spark.frame.Rotation = since / TWINKLE * 90
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
