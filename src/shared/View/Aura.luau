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
--
-- NO DARTS (`streak`) IN AN AURA BUT STORM'S, where the owner asked for them back: sharp
-- flat lines jumping about are what a storm is told by, as long as no other aura has them. The first rework had them in every rare aura, as arcs, bolts
-- and rays, and in the game they came out as flat lines flickering and jumping about, which
-- was the middle of every aura and made them all look alike (owner, 2026-10-08). An aura is
-- told by its shape and by which way it moves, with plain round particles: down, up in a
-- column, inward, flashing, or straight up in a pillar.
-- Chakra: blue motes drifting up, slowly.
local CHAKRA_MOTES: Layer = {
	texture = SPARKLE,
	rate = 10,
	life = { 1.6, 2.4 },
	speed = { 1, 2 },
	spread = 25,
	size = { 0.8, 0.25 },
	lift = 0.5,
	spin = 60,
	glow = 0.6,
	bright = 2.5,
	fade = 0.1,
}
-- Chakra: a soft blue glow breathing round the feet.
local CHAKRA_GLOW: Layer = {
	texture = SMOKE,
	rate = 3,
	life = { 1.6, 2.2 },
	speed = { 0.2, 0.5 },
	spread = 70,
	size = { 1.6, 3 },
	lift = 0.2,
	spin = 15,
	glow = 0.5,
	bright = 1.8,
	fade = 0.7,
}
-- Kurama: the fox's cloak, tall orange flames up the whole body.
local KURAMA_CLOAK: Layer = {
	texture = FIRE,
	rate = 24,
	life = { 0.7, 1.1 },
	speed = { 3, 4.5 },
	spread = 16,
	size = { 2.2, 0.5 },
	lift = 2,
	spin = 30,
	glow = 0.5,
	bright = 2.4,
	fade = 0.15,
}
-- Kurama: embers floating up off the flames.
local KURAMA_EMBERS: Layer = {
	texture = SPARKLE,
	rate = 6,
	life = { 1.2, 1.8 },
	speed = { 2, 3.5 },
	spread = 35,
	size = { 0.7, 0.2 },
	lift = 1,
	spin = 120,
	glow = 0.6,
	bright = 3,
	fade = 0.05,
	color = "#FFE082",
}
-- Ice: thick snow coming down round the figure, the only aura that falls.
local ICE_SNOW: Layer = {
	texture = SPARKLE,
	rate = 16,
	life = { 1.8, 2.6 },
	speed = { 1.2, 2 },
	down = true,
	spread = 35,
	size = { 0.9, 0.5 },
	lift = -0.8,
	spin = 90,
	glow = 0.4,
	bright = 2.2,
	fade = 0.05,
	color = "#FFFFFF",
}
-- Ice: a wide white fog lying on the ground.
local ICE_FOG: Layer = {
	texture = SMOKE,
	rate = 6,
	life = { 2.4, 3.2 },
	speed = { 0.6, 1.2 },
	spread = 88,
	size = { 2.4, 4.6 },
	lift = -0.2,
	spin = 15,
	glow = 0.3,
	bright = 1.5,
	fade = 0.45,
	color = "#E1F5FE",
}
-- Ice: big glints flaring and gone.
local ICE_GLINTS: Layer = {
	texture = SPARKLE,
	rate = 3,
	life = { 0.3, 0.5 },
	speed = { 0, 0.2 },
	spread = 180,
	size = { 0.3, 2.4, 0.3 },
	lift = 0,
	spin = 40,
	glow = 0.8,
	bright = 3.5,
	fade = 0,
}
-- Lava: a tall column of black smoke, seen before anything else of it.
local LAVA_COLUMN: Layer = {
	texture = SMOKE,
	rate = 7,
	life = { 2, 2.8 },
	speed = { 2.2, 3.2 },
	spread = 10,
	size = { 1.8, 4 },
	lift = 0.6,
	spin = 20,
	glow = 0,
	lit = true,
	fade = 0.3,
	color = "#1E1410",
}
-- Lava: low fire all round the feet.
local LAVA_FIRE: Layer = {
	texture = FIRE,
	rate = 16,
	life = { 0.5, 0.9 },
	speed = { 1.5, 2.5 },
	spread = 45,
	size = { 2.4, 0.6 },
	lift = 1,
	spin = 30,
	glow = 0.5,
	bright = 2.5,
	fade = 0.1,
}
-- Lava: glowing blobs lobbed up out of it, arcing over and dropping back.
local LAVA_BLOBS: Layer = {
	texture = SPARKLE,
	rate = 9,
	life = { 1, 1.4 },
	speed = { 9, 12 },
	spread = 22,
	size = { 1.3, 0.9 },
	lift = -18,
	spin = 200,
	glow = 0.5,
	bright = 3.5,
	fade = 0,
	color = "#FFC400",
}
-- Lava: the red glow of the pool underfoot.
local LAVA_GLOW: Layer = {
	texture = SMOKE,
	rate = 4,
	life = { 1.2, 1.8 },
	speed = { 0.2, 0.4 },
	spread = 85,
	size = { 2.6, 3.6 },
	lift = 0,
	spin = 15,
	glow = 0.7,
	bright = 2.6,
	fade = 0.5,
	color = "#FF3D00",
}
-- Storm: a dark thundercloud wrapped round the figure.
local STORM_CLOUD: Layer = {
	texture = SMOKE,
	rate = 7,
	life = { 1.5, 2.1 },
	speed = { 0.4, 1 },
	spread = 180,
	size = { 2.4, 3.8 },
	lift = 0,
	spin = 40,
	glow = 0,
	lit = true,
	fade = 0.4,
	color = "#2A1F4A",
}
-- Storm: the cloud lit from inside, a great white flash several times a second.
local STORM_FLASH: Layer = {
	texture = SPARKLE,
	rate = 3.5,
	life = { 0.07, 0.13 },
	speed = { 0, 0.1 },
	spread = 180,
	size = { 6, 8 },
	lift = 0,
	spin = 0,
	glow = 0.9,
	bright = 5,
	fade = 0.15,
	color = "#F3E5F5",
}
-- Storm: violet sparks bursting out of it and gone at once.
local STORM_SPARKS: Layer = {
	texture = SPARKLE,
	rate = 34,
	life = { 0.12, 0.28 },
	speed = { 10, 16 },
	spread = 180,
	streak = 2.5,
	size = { 1.2, 0.3 },
	lift = 0,
	spin = 0,
	glow = 0.6,
	bright = 3.5,
	fade = 0,
}
-- Storm: sparks skittering out over the ground.
local STORM_GROUND: Layer = {
	texture = SPARKLE,
	rate = 10,
	life = { 0.25, 0.4 },
	speed = { 7, 11 },
	spread = 88,
	streak = 2,
	size = { 0.9, 0.3 },
	lift = -4,
	spin = 0,
	glow = 0.6,
	bright = 3,
	fade = 0,
	color = "#B388FF",
}
-- Rinnegan: big violet motes flying in to the figure from all round it.
local RINNEGAN_PULL: Layer = {
	texture = SPARKLE,
	rate = 24,
	life = { 0.9, 1.1 },
	speed = { 2.6, 3 },
	from = "shell",
	inward = true,
	spread = 0,
	size = { 1.3, 0.2 },
	lift = 0,
	spin = 120,
	glow = 0.6,
	bright = 3,
	fade = 0,
}
-- Rinnegan: a violet veil closing in with them.
local RINNEGAN_VEIL: Layer = {
	texture = SMOKE,
	rate = 5,
	life = { 0.9, 1.1 },
	speed = { 2.2, 2.6 },
	from = "shell",
	inward = true,
	spread = 0,
	size = { 3, 1 },
	lift = 0,
	spin = 20,
	glow = 0.4,
	bright = 1.6,
	fade = 0.6,
}
-- Rinnegan: a dark heart they vanish into.
local RINNEGAN_CORE: Layer = {
	texture = SMOKE,
	rate = 5,
	life = { 0.8, 1.2 },
	speed = { 0, 0.2 },
	spread = 180,
	size = { 2.2, 1.2 },
	lift = 0,
	spin = 60,
	glow = 0,
	fade = 0.25,
	color = "#12081F",
}
-- Rinnegan: pale rings of light opening slowly in the dark.
local RINNEGAN_EYES: Layer = {
	texture = SPARKLE,
	rate = 2,
	life = { 1, 1.4 },
	speed = { 0, 0.1 },
	spread = 180,
	size = { 0.4, 3, 0.4 },
	lift = 0,
	spin = 30,
	glow = 0.7,
	bright = 3,
	fade = 0.1,
	color = "#EDE7F6",
}
-- Rinnegan: violet light pooled on the ground under it.
local RINNEGAN_FLOOR: Layer = {
	texture = SMOKE,
	rate = 3,
	life = { 1.8, 2.4 },
	speed = { 0.2, 0.4 },
	spread = 88,
	size = { 2.8, 4.2 },
	lift = 0,
	spin = 15,
	glow = 0.6,
	bright = 2.2,
	fade = 0.55,
}
-- Six Paths: a pillar of white-gold light going straight up, far over the head.
local SAGE_PILLAR: Layer = {
	texture = SPARKLE,
	rate = 16,
	life = { 0.9, 1.2 },
	speed = { 9, 11 },
	spread = 3,
	size = { 1.6, 0.6 },
	lift = 0,
	spin = 200,
	glow = 0.7,
	bright = 4,
	fade = 0,
	color = "#FFF8E1",
}
-- Six Paths: black fire up the whole body.
local SAGE_BLACK_FLAME: Layer = {
	texture = FIRE,
	rate = 16,
	life = { 0.8, 1.2 },
	speed = { 2.5, 4 },
	spread = 16,
	size = { 2.6, 0.6 },
	lift = 2,
	spin = 30,
	glow = 0,
	fade = 0.15,
	color = "#0E0A14",
}
-- Six Paths: and gold fire at its heart.
local SAGE_GOLD_FLAME: Layer = {
	texture = FIRE,
	rate = 10,
	life = { 0.6, 1 },
	speed = { 2, 3.2 },
	spread = 12,
	size = { 1.6, 0.3 },
	lift = 1.5,
	spin = 30,
	glow = 0.5,
	bright = 3,
	fade = 0.1,
	color = "#FFD54F",
}
-- Six Paths: gold drawn in from all round, as the Rinnegan draws violet.
local SAGE_PULL: Layer = {
	texture = SPARKLE,
	rate = 10,
	life = { 1, 1.2 },
	speed = { 2.4, 2.8 },
	from = "shell",
	inward = true,
	spread = 0,
	size = { 1.1, 0.2 },
	lift = 0,
	spin = 120,
	glow = 0.6,
	bright = 3,
	fade = 0,
	color = "#FFD54F",
}
-- Six Paths: a wide gold glow on the ground.
local SAGE_HALO: Layer = {
	texture = SMOKE,
	rate = 3,
	life = { 1.8, 2.4 },
	speed = { 0.3, 0.6 },
	spread = 88,
	size = { 3, 5 },
	lift = 0,
	spin = 15,
	glow = 0.7,
	bright = 2.6,
	fade = 0.5,
	color = "#FFE082",
}
-- Six Paths: great stars flaring white round it.
local SAGE_STARS: Layer = {
	texture = SPARKLE,
	rate = 3,
	life = { 0.4, 0.6 },
	speed = { 0, 0.2 },
	spread = 180,
	size = { 0.4, 3.2, 0.4 },
	lift = 0,
	spin = 60,
	glow = 0.8,
	bright = 4,
	fade = 0,
	color = "#FFFFFF",
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

local LOOKS: { [string]: Look } = {
	-- Each is a shape of its own, to be told from far off: Chakra a calm blue drift, Kurama a
	-- cloak of orange flame, Ice snow coming down on white fog, Lava a black column of smoke
	-- with blobs lobbed out of it, Storm a dark cloud that flashes white, Rinnegan everything
	-- flying inward to a dark heart, Six Paths a pillar of light out of black fire.
	chakra = {
		body = { CHAKRA_MOTES },
		ground = { CHAKRA_GLOW },
	},
	kurama = {
		body = { KURAMA_CLOAK, KURAMA_EMBERS },
		light = 1,
	},
	ice = {
		body = { ICE_SNOW, ICE_GLINTS },
		ground = { ICE_FOG },
	},
	lava = {
		body = { LAVA_COLUMN },
		ground = { LAVA_FIRE, LAVA_BLOBS, LAVA_GLOW },
		light = 1.1,
	},
	storm = {
		body = { STORM_CLOUD, STORM_FLASH, STORM_SPARKS },
		ground = { STORM_GROUND },
		light = 1.2,
	},
	rinnegan = {
		body = { RINNEGAN_CORE, RINNEGAN_EYES },
		ground = { RINNEGAN_FLOOR },
		around = { RINNEGAN_PULL, RINNEGAN_VEIL },
		light = 1.2,
	},
	six_paths = {
		body = { SAGE_BLACK_FLAME, SAGE_GOLD_FLAME, SAGE_STARS },
		ground = { SAGE_PILLAR, SAGE_HALO },
		around = { SAGE_PULL },
		light = 1.5,
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

-- THE LEGENDARY SHINOBI (Config/Legends) HAVE AURAS OF THEIR OWN, each richer than any
-- mutation's: they are what Robux buy, and are to be known from across the plaza. Each is a
-- shape of its own again, with the plain round particles the mutations' auras are made of:
-- Tsunade green light rising through petals coming down, Tobirama a fountain thrown up and
-- falling back into its own mist, Hagoromo a pillar of white light out of white fire with
-- gold and violet drawn in to it. The colors are theirs: a legendary shinobi has no mutation
-- to take one from.

-- Tsunade: the green light of her healing, rising off her.
local TSUNADE_HEAL: Layer = {
	texture = SPARKLE,
	rate = 12,
	life = { 1.4, 2 },
	speed = { 1.4, 2.4 },
	spread = 20,
	size = { 1.1, 0.3 },
	lift = 0.8,
	spin = 80,
	glow = 0.6,
	bright = 3,
	fade = 0.05,
	color = "#69F0AE",
}
-- Tsunade: petals coming down through it, turning.
local TSUNADE_PETALS: Layer = {
	texture = SPARKLE,
	rate = 6,
	life = { 2, 2.8 },
	speed = { 0.5, 1 },
	down = true,
	spread = 55,
	size = { 0.9, 0.5 },
	lift = -0.6,
	spin = 200,
	glow = 0.4,
	bright = 2.2,
	fade = 0.05,
	color = "#F8BBD0",
}
-- Tsunade: the mark on her brow let go, flaring violet about her.
local TSUNADE_SEAL: Layer = {
	texture = SPARKLE,
	rate = 2,
	life = { 0.5, 0.7 },
	speed = { 0, 0.2 },
	spread = 180,
	size = { 0.4, 2.8, 0.4 },
	lift = 0,
	spin = 60,
	glow = 0.8,
	bright = 4,
	fade = 0,
	color = "#CE93D8",
}
-- Tsunade: a wide green glow on the ground.
local TSUNADE_GLOW: Layer = {
	texture = SMOKE,
	rate = 3,
	life = { 1.8, 2.4 },
	speed = { 0.3, 0.6 },
	spread = 88,
	size = { 3, 5 },
	lift = 0,
	spin = 15,
	glow = 0.7,
	bright = 2.4,
	fade = 0.5,
	color = "#B9F6CA",
}
-- Tsunade: a rose haze low about her feet.
local TSUNADE_HAZE: Layer = {
	texture = SMOKE,
	rate = 4,
	life = { 1.6, 2.2 },
	speed = { 0.4, 0.9 },
	spread = 70,
	size = { 2, 3.4 },
	lift = 0.3,
	spin = 20,
	glow = 0.4,
	bright = 1.6,
	fade = 0.6,
	color = "#F48FB1",
}
-- Tsunade: beads of light springing up off the ground and dropping back.
local TSUNADE_BEADS: Layer = {
	texture = SPARKLE,
	rate = 8,
	life = { 0.8, 1.1 },
	speed = { 5, 7 },
	spread = 30,
	size = { 0.8, 0.3 },
	lift = -11,
	spin = 160,
	glow = 0.6,
	bright = 3.2,
	fade = 0,
	color = "#B9F6CA",
}
-- Tsunade: green drawn in to her from all round.
local TSUNADE_PULL: Layer = {
	texture = SPARKLE,
	rate = 8,
	life = { 1, 1.2 },
	speed = { 2.4, 2.8 },
	from = "shell",
	inward = true,
	spread = 0,
	size = { 1, 0.2 },
	lift = 0,
	spin = 120,
	glow = 0.6,
	bright = 3,
	fade = 0,
	color = "#00E676",
}
-- Tobirama: a column of spray going up round him.
local WATER_COLUMN: Layer = {
	texture = SMOKE,
	rate = 10,
	life = { 0.8, 1.2 },
	speed = { 3.5, 5 },
	spread = 12,
	size = { 2, 3.2 },
	lift = 1,
	spin = 40,
	glow = 0.35,
	bright = 1.8,
	fade = 0.45,
	color = "#4FC3F7",
}
-- Tobirama: drops thrown up out of the ground, arcing over and falling back: a fountain.
local WATER_FOUNTAIN: Layer = {
	texture = SPARKLE,
	rate = 16,
	life = { 0.9, 1.3 },
	speed = { 8, 11 },
	spread = 26,
	size = { 1, 0.4 },
	lift = -17,
	spin = 160,
	glow = 0.5,
	bright = 3,
	fade = 0,
	color = "#E1F5FE",
}
-- Tobirama: the mist it all falls back into.
local WATER_MIST: Layer = {
	texture = SMOKE,
	rate = 4,
	life = { 2, 2.8 },
	speed = { 0.4, 0.8 },
	spread = 85,
	size = { 3, 5.5 },
	lift = 0,
	spin = 12,
	glow = 0.3,
	bright = 1.6,
	fade = 0.55,
	color = "#E1F5FE",
}
-- Tobirama: bubbles rising slowly, swelling and gone.
local WATER_BUBBLES: Layer = {
	texture = SPARKLE,
	rate = 7,
	life = { 1.6, 2.2 },
	speed = { 0.8, 1.4 },
	spread = 30,
	size = { 0.4, 1.2, 0.2 },
	lift = 0.6,
	spin = 30,
	glow = 0.5,
	bright = 2.6,
	fade = 0.1,
	color = "#80D8FF",
}
-- Tobirama: spray flung outward off him, every way.
local WATER_SPRAY: Layer = {
	texture = SPARKLE,
	rate = 9,
	life = { 0.6, 0.8 },
	speed = { 3.4, 4.4 },
	from = "shell",
	spread = 0,
	size = { 0.9, 0.2 },
	lift = -3,
	spin = 120,
	glow = 0.5,
	bright = 3,
	fade = 0,
	color = "#40C4FF",
}
-- Tobirama: light caught in the water, flashing white.
local WATER_GLINTS: Layer = {
	texture = SPARKLE,
	rate = 3,
	life = { 0.4, 0.6 },
	speed = { 0, 0.2 },
	spread = 180,
	size = { 0.4, 2.6, 0.4 },
	lift = 0,
	spin = 60,
	glow = 0.8,
	bright = 4,
	fade = 0,
	color = "#FFFFFF",
}
-- Tobirama: a deep blue glow on the ground under the fountain.
local WATER_POOL: Layer = {
	texture = SMOKE,
	rate = 3,
	life = { 1.6, 2.2 },
	speed = { 0.2, 0.4 },
	spread = 88,
	size = { 2.8, 4.4 },
	lift = 0,
	spin = 15,
	glow = 0.6,
	bright = 2.2,
	fade = 0.5,
	color = "#0288D1",
}
-- Hagoromo: white fire up the whole body.
local SAGE_WHITE_FLAME: Layer = {
	texture = FIRE,
	rate = 18,
	life = { 0.8, 1.2 },
	speed = { 3, 4.5 },
	spread = 14,
	size = { 2.8, 0.6 },
	lift = 2,
	spin = 30,
	glow = 0.6,
	bright = 3,
	fade = 0.15,
	color = "#FFF8E1",
}
-- Hagoromo: specks of the dark his orbs are made of, drifting up through it.
local SAGE_DARK: Layer = {
	texture = SMOKE,
	rate = 6,
	life = { 1.4, 2 },
	speed = { 1, 1.8 },
	spread = 40,
	size = { 1.2, 0.5 },
	lift = 0.4,
	spin = 60,
	glow = 0,
	fade = 0.2,
	color = "#14101C",
}
-- Hagoromo: great stars flaring white round him.
local SAGE_FLARES: Layer = {
	texture = SPARKLE,
	rate = 3,
	life = { 0.4, 0.6 },
	speed = { 0, 0.2 },
	spread = 180,
	size = { 0.4, 3.4, 0.4 },
	lift = 0,
	spin = 60,
	glow = 0.8,
	bright = 4,
	fade = 0,
	color = "#FFFFFF",
}
-- Hagoromo: a pillar of light straight up out of the ground.
local SAGE_BEAM: Layer = {
	texture = SPARKLE,
	rate = 14,
	life = { 0.9, 1.2 },
	speed = { 9, 11 },
	spread = 3,
	size = { 1.7, 0.6 },
	lift = 0,
	spin = 200,
	glow = 0.7,
	bright = 4,
	fade = 0,
	color = "#FFFDE7",
}
-- Hagoromo: a wide gold glow on the ground.
local SAGE_GLORY: Layer = {
	texture = SMOKE,
	rate = 3,
	life = { 1.8, 2.4 },
	speed = { 0.3, 0.6 },
	spread = 88,
	size = { 3.2, 5.4 },
	lift = 0,
	spin = 15,
	glow = 0.7,
	bright = 2.6,
	fade = 0.5,
	color = "#FFE082",
}
-- Hagoromo: the violet of the Rinnegan pooled under the gold.
local SAGE_VIOLET: Layer = {
	texture = SMOKE,
	rate = 3,
	life = { 1.6, 2.2 },
	speed = { 0.3, 0.7 },
	spread = 80,
	size = { 2.2, 3.6 },
	lift = 0.2,
	spin = 20,
	glow = 0.5,
	bright = 2,
	fade = 0.6,
	color = "#B388FF",
}
-- Hagoromo: gold drawn in to him from all round.
local SAGE_GATHER: Layer = {
	texture = SPARKLE,
	rate = 9,
	life = { 1, 1.2 },
	speed = { 2.4, 2.8 },
	from = "shell",
	inward = true,
	spread = 0,
	size = { 1.1, 0.2 },
	lift = 0,
	spin = 120,
	glow = 0.6,
	bright = 3,
	fade = 0,
	color = "#FFD54F",
}
-- Hagoromo: and violet with it, slower.
local SAGE_DRAW: Layer = {
	texture = SPARKLE,
	rate = 6,
	life = { 1.3, 1.6 },
	speed = { 1.8, 2.2 },
	from = "shell",
	inward = true,
	spread = 0,
	size = { 0.9, 0.2 },
	lift = 0,
	spin = 120,
	glow = 0.6,
	bright = 3,
	fade = 0,
	color = "#B388FF",
}

-- A legendary shinobi's aura with the color its light is.
export type Legend = { look: Look, color: string }

local LEGENDS: { [string]: Legend } = {
	tsunade = {
		color = "#69F0AE",
		look = {
			body = { TSUNADE_HEAL, TSUNADE_PETALS, TSUNADE_SEAL },
			ground = { TSUNADE_GLOW, TSUNADE_HAZE, TSUNADE_BEADS },
			around = { TSUNADE_PULL },
			light = 1.4,
		},
	},
	tobirama = {
		color = "#40C4FF",
		look = {
			body = { WATER_COLUMN, WATER_BUBBLES, WATER_GLINTS },
			ground = { WATER_FOUNTAIN, WATER_MIST, WATER_POOL },
			around = { WATER_SPRAY },
			light = 1.5,
		},
	},
	hagoromo = {
		color = "#FFE082",
		look = {
			body = { SAGE_WHITE_FLAME, SAGE_DARK, SAGE_FLARES },
			ground = { SAGE_BEAM, SAGE_GLORY, SAGE_VIOLET },
			around = { SAGE_GATHER, SAGE_DRAW },
			light = 1.8,
		},
	},
}

-- Every legendary shinobi's aura by its id.
Aura.legends = LEGENDS

-- How wide the ball is that an aura's particles are drawn in from, studs: wide enough to be
-- seen streaking in, not so wide that it reaches into the shinobi on the next pad.
local AROUND = 6
-- How far round the feet the ground gives off particles, and how far over the ground. (Plain
-- numbers: this module is also loaded outside Roblox, by the tests, for its looks.)
local GROUND = 3.4
local GROUND_HEIGHT = 0.35

-- Wraps a figure standing at the world origin, `height` studs tall, in an aura whose light and
-- unnamed colors are `color`. The particles come out of unseen parts round the body, which
-- belong to the model and move with it.
local function wrap(model: Model, look: Look, color: Color3, height: number)
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

-- Wraps a figure in its mutation's aura.
function Aura.attach(model: Model, mutation: Catalog.Mutation, height: number)
	wrap(model, LOOKS[mutation.id] or DEFAULT, Color3.fromHex(mutation.color), height)
end

-- Wraps the figure of a legendary shinobi in the aura that is its own; one that has none is
-- left as it is.
function Aura.legend(model: Model, legendId: string, height: number)
	local legend = LEGENDS[legendId]
	if legend then
		wrap(model, legend.look, Color3.fromHex(legend.color), height)
	end
end

return Aura
