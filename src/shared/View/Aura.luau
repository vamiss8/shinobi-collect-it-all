--!strict
-- What a mutation looks like on a figure: particles round the shinobi and a faint light of the
-- mutation's color. Every mutation moves in its own way, set in LOOKS by mutation id; one that
-- is not listed there gets rising motes.
--
-- THE RARER THE MUTATION, THE MORE THERE IS TO ITS AURA (owner, 2026-10-08: "cooler animations
-- of particles for the mutations... the further, the cooler it looks"; Chakra and Kurama he
-- said to leave as they are). Chakra is motes and Kurama flames, one kind of particle each;
-- from Ice on an aura is several kinds at once, in three places: round the body, on the ground
-- under the feet, and off an unseen ball round the figure for what is drawn in towards it.
-- Storm cracks, Rinnegan pulls the air in over rings spreading on the ground, and Six Paths
-- burns black and gold. Sizes and brightness are those found to be seen at all on a runner
-- (Services/SpeedLook): nothing under 0.7 of a stud, half paint and half light, drawn brighter
-- than its color.
--
-- Nothing rises far over the head: the figure's tag hangs there.

local Build = require("./Build")
local Catalog = require("../Config/Catalog")
local Particles = require("./Particles")

local Aura = {}

local SPARKLE, FIRE, SMOKE = Particles.SPARKLE, Particles.FIRE, Particles.SMOKE

type Layer = Particles.Layer

-- An aura: its layers by where they come from, and how strong its light is (0.9 when left out).
export type Look = {
	body: { Layer }?, -- out of an unseen box round the body
	ground: { Layer }?, -- out of the ground under the feet
	around: { Layer }?, -- off an unseen ball round the figure
	light: number?,
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

local DEFAULT: Look = { body = { MOTES } }

-- The layers of the auras, each named for what it is; LOOKS below says which go where.

local KURAMA_FLAMES: Layer = {
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
}
local ICE_SNOW: Layer = {
	texture = SPARKLE,
	rate = 12,
	life = { 2, 3 },
	speed = { 0.6, 1.2 },
	down = true,
	spread = 40,
	size = { 0.75, 0.3 },
	lift = -0.5,
	spin = 90,
	glow = 0.5,
	bright = 2,
	fade = 0.05,
}
local ICE_GLINTS: Layer = {
	texture = SPARKLE,
	rate = 3,
	life = { 0.25, 0.45 },
	speed = { 0, 0.2 },
	spread = 180,
	size = { 0.2, 1.9, 0.2 },
	lift = 0,
	spin = 40,
	glow = 0.8,
	bright = 3.5,
	fade = 0,
	color = "#FFFFFF",
}
local ICE_MIST: Layer = {
	texture = SMOKE,
	rate = 5,
	life = { 2.2, 3 },
	speed = { 0.3, 0.8 },
	spread = 80,
	size = { 2, 3.6 },
	lift = 0.1,
	spin = 15,
	glow = 0.3,
	bright = 1.3,
	fade = 0.6,
	color = "#E1F5FE",
}
local LAVA_SMOKE: Layer = {
	texture = SMOKE,
	rate = 4,
	life = { 1.8, 2.6 },
	speed = { 1, 1.8 },
	spread = 20,
	size = { 1.4, 3.2 },
	lift = 0.5,
	spin = 20,
	glow = 0,
	lit = true,
	fade = 0.6,
	color = "#3E2723",
}
local LAVA_POOL: Layer = {
	texture = FIRE,
	rate = 6,
	life = { 1.2, 1.8 },
	speed = { 0.3, 0.5 },
	spread = 0,
	flat = true,
	size = { 2.2, 4.4 },
	lift = 0,
	spin = 25,
	glow = 0.6,
	bright = 2.5,
	fade = 0.25,
	color = "#FF6D00",
}
local LAVA_FLAMES: Layer = {
	texture = FIRE,
	rate = 12,
	life = { 0.6, 1 },
	speed = { 2, 3.5 },
	spread = 20,
	size = { 1.8, 0.4 },
	lift = 1.5,
	spin = 30,
	glow = 0.5,
	bright = 2.2,
	fade = 0.15,
}
local LAVA_EMBERS: Layer = {
	texture = SPARKLE,
	rate = 20,
	life = { 0.7, 1.2 },
	speed = { 7, 11 },
	spread = 25,
	streak = 1.2,
	size = { 0.75, 0.2 },
	lift = -12,
	spin = 0,
	glow = 0.6,
	bright = 3,
	fade = 0,
	color = "#FFAB40",
}
local STORM_ARCS: Layer = {
	texture = SPARKLE,
	rate = 34,
	life = { 0.12, 0.28 },
	speed = { 9, 16 },
	spread = 180,
	streak = 2.5,
	size = { 1.1, 0.3 },
	lift = 0,
	spin = 0,
	glow = 0.6,
	bright = 3.5,
	fade = 0,
	color = "#B388FF",
}
local STORM_FLASH: Layer = {
	texture = SPARKLE,
	rate = 1.6,
	life = { 0.08, 0.14 },
	speed = { 0, 0.1 },
	spread = 180,
	size = { 4.5, 6 },
	lift = 0,
	spin = 0,
	glow = 0.9,
	bright = 4,
	fade = 0.25,
	color = "#EDE7F6",
}
local STORM_HAZE: Layer = {
	texture = SMOKE,
	rate = 4,
	life = { 1.4, 2 },
	speed = { 0.4, 0.9 },
	spread = 180,
	size = { 1.6, 3 },
	lift = 0,
	spin = 30,
	glow = 0.3,
	bright = 1.4,
	fade = 0.7,
}
local STORM_CRACKLE: Layer = {
	texture = SPARKLE,
	rate = 12,
	life = { 0.2, 0.4 },
	speed = { 5, 9 },
	spread = 85,
	streak = 2,
	size = { 0.8, 0.2 },
	lift = 0,
	spin = 0,
	glow = 0.6,
	bright = 3,
	fade = 0,
}
local RINNEGAN_RINGS: Layer = {
	texture = SMOKE,
	rate = 1.4,
	life = { 1.6, 2 },
	speed = { 0.2, 0.3 },
	spread = 0,
	flat = true,
	size = { 0.6, 7 },
	lift = 0,
	spin = 10,
	glow = 0.5,
	bright = 2,
	fade = 0.45,
}
local RINNEGAN_PULL: Layer = {
	texture = SPARKLE,
	rate = 24,
	life = { 0.9, 1.2 },
	speed = { 2.4, 3 },
	from = "shell",
	inward = true,
	spread = 0,
	streak = 1.6,
	size = { 0.9, 0.2 },
	lift = 0,
	spin = 0,
	glow = 0.6,
	bright = 3,
	fade = 0.05,
}
local SAGE_BLACK_FLAME: Layer = {
	texture = FIRE,
	rate = 18,
	life = { 0.8, 1.3 },
	speed = { 2.5, 4 },
	spread = 16,
	size = { 2.4, 0.6 },
	lift = 2,
	spin = 30,
	glow = 0,
	fade = 0.2,
	color = "#141218",
}
local SAGE_GOLD_FLAME: Layer = {
	texture = FIRE,
	rate = 10,
	life = { 0.6, 1 },
	speed = { 2, 3.2 },
	spread = 14,
	size = { 1.5, 0.3 },
	lift = 1.5,
	spin = 30,
	glow = 0.5,
	bright = 3,
	fade = 0.1,
	color = "#FFE9A8",
}
local SAGE_DARTS: Layer = {
	texture = SPARKLE,
	rate = 14,
	life = { 0.5, 0.8 },
	speed = { 5, 7 },
	spread = 6,
	streak = 3,
	size = { 0.9, 0.2 },
	lift = 0,
	spin = 0,
	glow = 0.6,
	bright = 3.5,
	fade = 0,
	color = "#FFF3C4",
}
local SAGE_HALO: Layer = {
	texture = SMOKE,
	rate = 1,
	life = { 1.8, 2.2 },
	speed = { 0.2, 0.3 },
	spread = 0,
	flat = true,
	size = { 0.8, 8 },
	lift = 0,
	spin = 10,
	glow = 0.6,
	bright = 2.2,
	fade = 0.5,
	color = "#FFE082",
}
local SAGE_PULL: Layer = {
	texture = SPARKLE,
	rate = 12,
	life = { 1, 1.3 },
	speed = { 2.2, 2.8 },
	from = "shell",
	inward = true,
	spread = 0,
	streak = 1.4,
	size = { 0.8, 0.2 },
	lift = 0,
	spin = 0,
	glow = 0.6,
	bright = 3,
	fade = 0.05,
	color = "#FFD54F",
}
local MOON_MIST: Layer = {
	texture = SMOKE,
	rate = 5,
	life = { 2, 3 },
	speed = { 0.5, 1 },
	spread = 60,
	size = { 1.8, 3.4 },
	lift = 0.3,
	spin = 20,
	glow = 0.3,
	bright = 1.4,
	fade = 0.65,
}
local MOON_SPARKS: Layer = {
	texture = SPARKLE,
	rate = 8,
	life = { 1.5, 2.4 },
	speed = { 0.8, 1.6 },
	spread = 60,
	size = { 0.8, 0.2 },
	lift = 0.4,
	spin = 90,
	glow = 0.6,
	bright = 3,
	fade = 0.05,
}
local AKATSUKI_CLOUDS: Layer = {
	texture = SMOKE,
	rate = 6,
	life = { 2.4, 3.4 },
	speed = { 0.6, 1.2 },
	spread = 35,
	size = { 2, 3.6 },
	lift = 0.3,
	spin = 25,
	glow = 0.3,
	bright = 1.5,
	fade = 0.5,
}
local FESTIVAL_LEAVES: Layer = {
	texture = SPARKLE,
	rate = 10,
	life = { 2, 3 },
	speed = { 0.6, 1.4 },
	down = true,
	spread = 50,
	size = { 0.8, 0.4 },
	lift = -1,
	spin = 180,
	glow = 0.5,
	bright = 2.5,
	fade = 0.05,
}

-- Storm: bolts striking straight down through the figure.
local STORM_BOLTS: Layer = {
	texture = SPARKLE,
	rate = 8,
	life = { 0.12, 0.2 },
	speed = { 20, 28 },
	down = true,
	spread = 8,
	streak = 3,
	size = { 1.6, 0.5 },
	lift = 0,
	spin = 0,
	glow = 0.7,
	bright = 4,
	fade = 0,
	color = "#EDE7F6",
}
-- Rinnegan: rings climbing the figure one over another, feet to head.
local RINNEGAN_CLIMB: Layer = {
	texture = SMOKE,
	rate = 2.5,
	life = { 1.6, 2 },
	speed = { 2.1, 2.4 },
	spread = 0,
	flat = true,
	size = { 4.2, 3.4 },
	lift = 0,
	spin = 0,
	glow = 0.6,
	bright = 2.4,
	fade = 0.4,
}
-- Rinnegan: and now the push, a shell of force going out from it.
local RINNEGAN_PUSH: Layer = {
	texture = SMOKE,
	rate = 6,
	life = { 0.4, 0.6 },
	speed = { 3, 4 },
	from = "shell",
	spread = 0,
	size = { 1, 2.6 },
	lift = 0,
	spin = 20,
	glow = 0.4,
	bright = 1.6,
	fade = 0.6,
	color = "#4527A0",
}
-- Rinnegan: dark specks held still at its heart, where all is drawn to.
local RINNEGAN_CORE: Layer = {
	texture = SPARKLE,
	rate = 6,
	life = { 0.8, 1.2 },
	speed = { 0, 0.2 },
	from = "ball",
	inward = true,
	spread = 180,
	size = { 0.3, 1.1, 0.3 },
	lift = 0,
	spin = 200,
	glow = 0.2,
	fade = 0.05,
	color = "#1A0F33",
}
-- Six Paths: rays of light shot out of the figure every way.
local SAGE_RAYS: Layer = {
	texture = SPARKLE,
	rate = 20,
	life = { 0.2, 0.3 },
	speed = { 12, 18 },
	spread = 180,
	streak = 3,
	size = { 1.3, 0.3 },
	lift = 0,
	spin = 0,
	drag = 3,
	glow = 0.7,
	bright = 4,
	fade = 0,
	color = "#FFF8E1",
}

local LOOKS: { [string]: Look } = {
	-- Blue motes of Chakra drifting up.
	chakra = {
		body = { MOTES },
	},
	-- The fox's cloak: flames licking upwards.
	kurama = {
		body = { KURAMA_FLAMES },
	},
	-- Snow sinking round the figure, glints of ice popping in the air, cold mist on the ground.
	ice = {
		body = { ICE_SNOW, ICE_GLINTS },
		ground = { ICE_MIST },
	},
	-- A pool of molten rock under the feet, flames out of it, embers thrown up that fall back,
	-- and dark smoke over it all.
	lava = {
		body = { LAVA_SMOKE },
		ground = { LAVA_POOL, LAVA_FLAMES, LAVA_EMBERS },
		light = 1.1,
	},
	-- Bolts strike down through the figure, arcs crack off it every way, sparks run out over
	-- the ground, and now and again all of it flashes white in a charged haze.
	storm = {
		body = { STORM_BOLTS, STORM_ARCS, STORM_FLASH, STORM_HAZE },
		ground = { STORM_CRACKLE },
		light = 1.2,
	},
	-- The pull and the push of the Rinnegan. Nothing of it drifts: rings climb the figure from
	-- its feet, others spread out over the ground, motes streak in to it from all round while a
	-- shell of force goes out, and dark specks hang at its heart.
	rinnegan = {
		body = { RINNEGAN_CORE },
		ground = { RINNEGAN_CLIMB, RINNEGAN_RINGS },
		around = { RINNEGAN_PULL, RINNEGAN_PUSH },
		light = 1.2,
	},
	-- The Sage of Six Paths, the most of all: a cloak of black flame over a core of pale gold,
	-- rays shot out of it every way, darts of light rising out of the ground, gold drawn in
	-- from all round, and a halo spreading underfoot.
	six_paths = {
		body = { SAGE_BLACK_FLAME, SAGE_GOLD_FLAME, SAGE_RAYS },
		ground = { SAGE_DARTS, SAGE_HALO },
		around = { SAGE_PULL },
		light = 1.4,
	},
	-- A red mist with sparks in it, under glints of a red moon.
	tsukuyomi = {
		body = { MOON_MIST, MOON_SPARKS },
	},
	-- Red clouds rolling up.
	akatsuki = {
		body = { AKATSUKI_CLOUDS },
	},
	-- Golden leaves coming down, turning as they fall.
	leaf_festival = {
		body = { FESTIVAL_LEAVES },
	},
}

-- Every mutation's aura by its id, for whoever wants to count what is in them.
Aura.looks = LOOKS

-- How wide the ball is that an aura's particles are drawn in from, studs: wide enough to be
-- seen streaking in, not so wide that it reaches into the shinobi on the next pad.
local AROUND = 6
-- How far round the feet the ground gives off particles, and how far over the ground. (Plain
-- numbers: this module is also loaded outside Roblox, by the tests, for its looks.)
local GROUND = 3.4
local GROUND_HEIGHT = 0.35

-- Wraps a figure standing at the world origin, `height` studs tall, in its mutation's aura. The
-- particles come out of unseen parts round the body, which belong to the model and move with
-- it.
function Aura.attach(model: Model, mutation: Catalog.Mutation, height: number)
	local color = Color3.fromHex(mutation.color)
	local look = LOOKS[mutation.id] or DEFAULT

	local function host(name: string, size: Vector3, middle: Vector3, layers: { Layer }?): Part?
		if not layers then
			return nil
		end
		local part = Build.part(model, name, size, middle, color)
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		for _, layer in layers do
			Particles.emitter(layer, color).Parent = part
		end
		return part
	end

	local waist = Vector3.new(0, height / 2, 0)
	local body = host("Aura", Vector3.new(3, height * 0.9, 2.4), waist, look.body or {})
	local patch = Vector3.new(GROUND, 0.2, GROUND)
	host("AuraGround", patch, Vector3.new(0, GROUND_HEIGHT, 0), look.ground)
	host("AuraAround", Vector3.new(AROUND, AROUND, AROUND), waist, look.around)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 9
	light.Brightness = look.light or 0.9
	light.Shadows = false
	light.Parent = body
end

return Aura
