--!strict
-- What a kunai looks like in the air beyond its shape: the ribbon it trails, the particles that
-- stream off it, and its light.
--
-- A better kunai is not much bigger than a worse one (View/KunaiModel): it is louder. The
-- first four are plain metal and wood and leave a thin ribbon. From the Explosive Tag on,
-- every kunai has particles of its own and lights what it flies past, and its ribbon is wider.
-- The last few trail a second, broader ribbon, like a comet.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Particles = require(ReplicatedStorage.Shared.View.Particles)

local KunaiEffects = {}

export type Effects = { emitters: { ParticleEmitter } }

-- The place in the store from which the ribbon is at its widest, and from which a kunai
-- trails the second one.
local BROAD_FROM = 14
local COMET_FROM = 17
-- Half the ribbon's width as a share of the kunai's length, before the tier widens it.
local RIBBON = 0.11

local SPARKLE, FIRE, SMOKE = Particles.SPARKLE, Particles.FIRE, Particles.SMOKE

-- A layer that streams off the back of a flying kunai and travels with it, so it reads as the
-- kunai burning or sparking and not as dots left behind on the lane. Whatever `layer` names
-- replaces the usual: sparkles, 30 a second, gone in half a second.
local function stream(layer: { [string]: any }): Particles.Layer
	local full: { [string]: any } = {
		texture = SPARKLE,
		rate = 30,
		life = { 0.3, 0.6 },
		speed = { 4, 8 },
		spread = 25,
		size = { 0.8, 0.1 },
		lift = 0,
		spin = 120,
		glow = 1,
		fade = 0,
		back = true,
		locked = true,
	}
	for key, value in layer do
		full[key] = value
	end
	return full :: any
end

-- By kunai id (Config/Kunai). A kunai that is not listed has no particles.
local EFFECTS: { [string]: { Particles.Layer } } = {
	-- A burning fuse: sparks and a thread of smoke.
	explosive_tag = {
		stream({
			rate = 40,
			life = { 0.2, 0.4 },
			speed = { 5, 10 },
			spread = 35,
			size = { 0.7, 0.1 },
			spin = 300,
			color = "#FFD180",
		}),
		stream({
			texture = SMOKE,
			rate = 10,
			life = { 0.5, 0.8 },
			speed = { 3, 5 },
			spread = 15,
			size = { 0.8, 1.8 },
			glow = 0,
			fade = 0.7,
			color = "#5D4037",
		}),
	},
	-- A purple haze that drips green.
	poison = {
		stream({
			texture = SMOKE,
			rate = 16,
			life = { 0.5, 0.9 },
			speed = { 3, 5 },
			spread = 20,
			size = { 1, 2.2 },
			glow = 0.3,
			fade = 0.55,
		}),
		stream({
			rate = 10,
			life = { 0.4, 0.6 },
			speed = { 2, 4 },
			spread = 30,
			size = { 0.5, 0.1 },
			lift = -6,
			glow = 0.8,
			color = "#B9F65A",
		}),
	},
	-- Motes of Chakra.
	chakra_blade = { stream({ size = { 0.8, 0.1 } }) },
	-- Dust and grit.
	earth = {
		stream({
			texture = SMOKE,
			rate = 14,
			life = { 0.5, 0.9 },
			speed = { 3, 6 },
			size = { 1, 2 },
			glow = 0,
			fade = 0.6,
		}),
		stream({ rate = 8, size = { 0.4, 0.1 }, glow = 0.3 }),
	},
	-- Drops flung off and falling.
	water = {
		stream({
			rate = 36,
			life = { 0.35, 0.6 },
			spread = 30,
			size = { 0.7, 0.15 },
			lift = -8,
			glow = 0.7,
			fade = 0.05,
		}),
	},
	-- Pale streaks of air.
	wind = {
		stream({
			texture = SMOKE,
			rate = 18,
			life = { 0.3, 0.5 },
			speed = { 8, 14 },
			spread = 10,
			size = { 0.8, 1.8 },
			glow = 0.4,
			fade = 0.7,
		}),
	},
	-- Flames and embers.
	fire = {
		stream({
			texture = FIRE,
			rate = 40,
			life = { 0.3, 0.55 },
			spread = 20,
			size = { 1.6, 0.3 },
			lift = 3,
			spin = 40,
			fade = 0.15,
			color = "#FF8F00",
		}),
		stream({ rate = 14, size = { 0.5, 0.1 }, spin = 200 }),
	},
	-- Sparks cracking off every way.
	lightning = {
		stream({
			rate = 50,
			life = { 0.12, 0.25 },
			speed = { 8, 16 },
			spread = 180,
			size = { 0.9, 0.2 },
			spin = 500,
			color = "#E1D5FF",
		}),
	},
	-- Leaves torn off and tumbling.
	wood = {
		stream({
			rate = 18,
			life = { 0.5, 0.9 },
			speed = { 3, 6 },
			spread = 40,
			size = { 0.6, 0.3 },
			lift = -3,
			spin = 220,
			glow = 0.5,
		}),
	},
	-- A cloud of gold sand.
	magnet = {
		stream({ rate = 45, speed = { 3, 7 }, spread = 45, size = { 0.45, 0.1 }, glow = 0.9 }),
	},
	-- White-hot flames in a shimmer of heat.
	scorch = {
		stream({
			texture = FIRE,
			rate = 40,
			life = { 0.3, 0.55 },
			spread = 20,
			size = { 1.8, 0.4 },
			lift = 3,
			spin = 40,
			fade = 0.1,
			color = "#FFB74D",
		}),
		stream({
			texture = SMOKE,
			rate = 8,
			life = { 0.4, 0.7 },
			size = { 1.2, 2.4 },
			glow = 0.5,
			fade = 0.85,
		}),
	},
	-- Splinters of ice.
	dust = {
		stream({ rate = 40, speed = { 3, 7 }, spread = 60, size = { 0.7, 0.1 }, spin = 200 }),
	},
	-- Black fire with a magenta edge.
	black_flame = {
		stream({
			texture = FIRE,
			rate = 44,
			life = { 0.35, 0.6 },
			spread = 20,
			size = { 1.8, 0.4 },
			lift = 3,
			spin = 40,
			glow = 0,
			fade = 0.1,
			color = "#101010",
		}),
		stream({
			texture = FIRE,
			rate = 20,
			life = { 0.3, 0.5 },
			spread = 30,
			size = { 1.2, 0.2 },
			lift = 3,
			spin = 40,
		}),
	},
	-- A burst of yellow light.
	thunder_god = {
		stream({
			rate = 50,
			life = { 0.15, 0.3 },
			speed = { 8, 14 },
			spread = 180,
			size = { 1, 0.2 },
			spin = 500,
			color = "#FFF59D",
		}),
	},
	-- Black orbs in a wake of gold.
	truth_seeking = {
		stream({
			texture = SMOKE,
			rate = 16,
			life = { 0.5, 0.8 },
			speed = { 2, 4 },
			spread = 60,
			size = { 1, 0.6 },
			glow = 0,
			fade = 0.15,
			color = "#0A0A0A",
		}),
		stream({ rate = 30, spread = 40, size = { 0.6, 0.1 } }),
	},
}

-- A ribbon stretched between two points either side of the part's middle.
local function ribbon(kunai: BasePart, half: number, color: Color3): Trail
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, half, 0)
	top.Parent = kunai
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -half, 0)
	bottom.Parent = kunai

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(color)
	-- Tapers to a point behind the kunai.
	trail.WidthScale = NumberSequence.new(1, 0.15)
	trail.FaceCamera = true
	trail.Parent = kunai
	return trail
end

-- Dresses the part a kunai is flown by: its ribbon, and for the kunai that have them its
-- particles and its light. `tier` is the kunai's place in the store. The part's length is the
-- kunai's, and its front is where the kunai points.
function KunaiEffects.attach(kunai: BasePart, tier: number): Effects
	local look = Catalog.kunai[tier]
	local trailColor = Color3.fromHex(look.trail)
	local length = kunai.Size.Z
	local widening = if tier >= BROAD_FROM then 1.9 elseif look.glow then 1.4 else 1

	local trail = ribbon(kunai, RIBBON * length * widening, trailColor)
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.Lifetime = 0.25 + 0.07 * tier
	trail.LightEmission = if look.glow then 1 else 0.2

	if tier >= COMET_FROM then
		local comet = ribbon(kunai, RIBBON * length * widening * 2.4, Color3.fromHex(look.color))
		comet.Transparency = NumberSequence.new(0.6, 1)
		comet.Lifetime = trail.Lifetime * 0.6
		comet.LightEmission = 0.6
	end

	local emitters: { ParticleEmitter } = {}
	local layers: { Particles.Layer } = EFFECTS[look.id] or {}
	for _, layer in layers do
		local emitter = Particles.emitter(layer, trailColor)
		emitter.Parent = kunai
		table.insert(emitters, emitter)
	end

	if look.glow then
		local light = Instance.new("PointLight")
		light.Color = trailColor
		light.Range = 8 + 0.5 * tier
		light.Brightness = 1.2 + 0.05 * tier
		light.Shadows = false
		light.Parent = kunai
	end
	return { emitters = emitters }
end

-- The kunai has struck the ground: a burst of its particles, and after that it only smolders.
function KunaiEffects.land(effects: Effects)
	for _, emitter in effects.emitters do
		emitter:Emit(math.clamp(math.floor(emitter.Rate * 0.5), 8, 24))
		emitter.Rate *= 0.35
	end
end

return KunaiEffects
