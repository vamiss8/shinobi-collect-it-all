--!strict
-- What a mutation looks like on a figure: particles in the mutation's color around the shinobi
-- and a faint light of the same color. Every mutation moves in its own way (motes rising,
-- flames, snow falling, sparks), set in STYLES by mutation id; one that is not listed there
-- gets rising motes.
--
-- Only textures that ship with Roblox are used, so there is nothing to upload.

local Build = require("./Build")
local Catalog = require("../Config/Catalog")

local Aura = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- One emitter. A style is one or more of them layered.
type Layer = {
	texture: string,
	rate: number, -- particles a second
	life: { number }, -- seconds, shortest and longest
	speed: { number }, -- studs a second, slowest and fastest
	down: boolean?, -- particles set off downwards instead of upwards
	spread: number, -- degrees off that direction; 180 is every way
	size: { number }, -- studs, when a particle appears and when it is gone
	lift: number, -- pull upwards, studs a second squared; negative sinks
	spin: number, -- degrees a second, either way
	glow: number, -- 0 is paint, 1 is light
	fade: number, -- how see-through a particle is at its clearest, 0..1
	color: string?, -- hex; the mutation's own color when left out
}

local MOTES: Layer = {
	texture = SPARKLE,
	rate = 10,
	life = { 1.6, 2.6 },
	speed = { 1, 2.2 },
	spread = 25,
	size = { 0.5, 0.1 },
	lift = 0.6,
	spin = 60,
	glow = 0.8,
	fade = 0.15,
}

local DEFAULT: { Layer } = { MOTES }

local STYLES: { [string]: { Layer } } = {
	-- Blue motes of Chakra drifting up.
	chakra = { MOTES },
	-- The fox's cloak: flames licking upwards.
	kurama = {
		{
			texture = FIRE,
			rate = 22,
			life = { 0.7, 1.2 },
			speed = { 2.5, 4 },
			spread = 18,
			size = { 1.6, 0.4 },
			lift = 2,
			spin = 30,
			glow = 0.9,
			fade = 0.25,
		},
	},
	-- Snow sinking slowly around the figure.
	ice = {
		{
			texture = SPARKLE,
			rate = 9,
			life = { 2.2, 3.2 },
			speed = { 0.5, 1.1 },
			down = true,
			spread = 40,
			size = { 0.45, 0.2 },
			lift = -0.5,
			spin = 90,
			glow = 0.5,
			fade = 0.1,
		},
	},
	-- Embers shooting up through dark smoke.
	lava = {
		{
			texture = FIRE,
			rate = 14,
			life = { 0.9, 1.5 },
			speed = { 3, 5 },
			spread = 30,
			size = { 0.9, 0.2 },
			lift = 1,
			spin = 80,
			glow = 1,
			fade = 0.15,
		},
		{
			texture = SMOKE,
			rate = 4,
			life = { 1.8, 2.6 },
			speed = { 1, 1.8 },
			spread = 20,
			size = { 1.4, 3 },
			lift = 0.5,
			spin = 20,
			glow = 0,
			fade = 0.75,
			color = "#3E2723",
		},
	},
	-- Sparks cracking off every way and gone at once.
	storm = {
		{
			texture = SPARKLE,
			rate = 30,
			life = { 0.25, 0.45 },
			speed = { 7, 12 },
			spread = 180,
			size = { 0.6, 0.15 },
			lift = 0,
			spin = 400,
			glow = 1,
			fade = 0,
		},
	},
	-- Motes hanging in a slow violet haze.
	rinnegan = {
		{
			texture = SPARKLE,
			rate = 8,
			life = { 2.5, 3.5 },
			speed = { 0.4, 0.9 },
			spread = 180,
			size = { 0.7, 0.25 },
			lift = 0,
			spin = 120,
			glow = 0.7,
			fade = 0.1,
		},
		{
			texture = SMOKE,
			rate = 3,
			life = { 2, 3 },
			speed = { 0.3, 0.7 },
			spread = 180,
			size = { 2, 3.5 },
			lift = 0.2,
			spin = 15,
			glow = 0.3,
			fade = 0.85,
		},
	},
	-- White light rising with flecks of gold.
	six_paths = {
		{
			texture = SPARKLE,
			rate = 16,
			life = { 1.8, 2.8 },
			speed = { 1.2, 2.6 },
			spread = 30,
			size = { 0.6, 0.15 },
			lift = 0.8,
			spin = 80,
			glow = 1,
			fade = 0,
		},
		{
			texture = SPARKLE,
			rate = 6,
			life = { 1.4, 2.2 },
			speed = { 0.6, 1.4 },
			spread = 180,
			size = { 0.4, 0.1 },
			lift = 0.4,
			spin = 160,
			glow = 1,
			fade = 0,
			color = "#FFE082",
		},
	},
	-- A red mist with sparks in it.
	tsukuyomi = {
		{
			texture = SMOKE,
			rate = 5,
			life = { 2, 3 },
			speed = { 0.5, 1 },
			spread = 60,
			size = { 1.6, 3 },
			lift = 0.3,
			spin = 20,
			glow = 0.2,
			fade = 0.75,
		},
		{
			texture = SPARKLE,
			rate = 6,
			life = { 1.5, 2.4 },
			speed = { 0.8, 1.6 },
			spread = 60,
			size = { 0.45, 0.1 },
			lift = 0.4,
			spin = 90,
			glow = 0.9,
			fade = 0.1,
		},
	},
	-- Red clouds rolling up.
	akatsuki = {
		{
			texture = SMOKE,
			rate = 5,
			life = { 2.4, 3.4 },
			speed = { 0.6, 1.2 },
			spread = 35,
			size = { 1.8, 3.2 },
			lift = 0.3,
			spin = 25,
			glow = 0.2,
			fade = 0.6,
		},
	},
	-- Golden leaves coming down, turning as they fall.
	leaf_festival = {
		{
			texture = SPARKLE,
			rate = 10,
			life = { 2, 3 },
			speed = { 0.6, 1.4 },
			down = true,
			spread = 50,
			size = { 0.5, 0.25 },
			lift = -1,
			spin = 180,
			glow = 0.6,
			fade = 0.1,
		},
	},
}

local function emitter(layer: Layer, own: Color3): ParticleEmitter
	local color = if layer.color then Color3.fromHex(layer.color) else own
	local clear = layer.fade
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = layer.texture
	particles.Rate = layer.rate
	particles.Lifetime = NumberRange.new(layer.life[1], layer.life[2])
	particles.Speed = NumberRange.new(layer.speed[1], layer.speed[2])
	particles.EmissionDirection = if layer.down then Enum.NormalId.Bottom else Enum.NormalId.Top
	particles.SpreadAngle = Vector2.new(layer.spread, layer.spread)
	particles.Acceleration = Vector3.new(0, layer.lift, 0)
	particles.Rotation = NumberRange.new(0, 360)
	particles.RotSpeed = NumberRange.new(-layer.spin, layer.spin)
	particles.Size = NumberSequence.new(layer.size[1], layer.size[2])
	-- Each particle fades in, holds, and fades out again.
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, clear),
		NumberSequenceKeypoint.new(0.7, clear + (1 - clear) * 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Color = ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.4))
	particles.LightEmission = layer.glow
	particles.LightInfluence = 0
	return particles
end

-- Wraps a figure standing at the world origin, `height` studs tall, in its mutation's aura. The
-- particles come out of an unseen box around the body, which belongs to the model and moves
-- with it.
function Aura.attach(model: Model, mutation: Catalog.Mutation, height: number)
	local color = Color3.fromHex(mutation.color)
	local body = Build.part(
		model,
		"Aura",
		Vector3.new(3, height * 0.9, 2.4),
		Vector3.new(0, height / 2, 0),
		color
	)
	body.Transparency = 1
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.CastShadow = false

	for _, layer in STYLES[mutation.id] or DEFAULT do
		emitter(layer, color).Parent = body
	end

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 9
	light.Brightness = 0.9
	light.Shadows = false
	light.Parent = body
end

return Aura
