--!strict
-- How every zone looks: its colors, the ground beside the lane and the lane's own surface, the
-- board of its sign, its light and its weather. The scenery itself is built by the server
-- (World/ZoneArt, one module per zone id) out of these colors; the light and the weather are
-- put on by each client as its camera enters the zone (client Mood and Weather).
--
-- Plain data, so that it can be checked without Roblox: colors are hex strings and materials
-- are named as in Enum.Material.
--
-- THE LAST ZONE'S LIGHT IS A REFERENCE. The owner likes the moon and the light of Great Ninja
-- War as they are (2026-10-06) and they are not to change: its `light` below is exactly what
-- the game showed that day, the five values the old Mood set plus the place's own Lighting for
-- the rest, and tests/ZoneArt.spec pins every number. The moon itself belongs to the place's
-- Sky, which no code touches. Its scenery is another matter: the owner had it rebuilt the same
-- day, once the other nine were seen, the old one being too plain beside them.

export type Surface = {
	color: string,
	material: string,
}

export type Light = {
	clock: number, -- Lighting.ClockTime, hours
	brightness: number, -- Lighting.Brightness
	exposure: number, -- Lighting.ExposureCompensation
	ambient: string, -- Lighting.Ambient
	outdoor: string, -- Lighting.OutdoorAmbient
	air: string, -- Atmosphere.Color
	decay: string, -- Atmosphere.Decay
	density: number, -- Atmosphere.Density, 0..1
	haze: number, -- Atmosphere.Haze, 0..10
	glare: number, -- Atmosphere.Glare, 0..10
	offset: number, -- Atmosphere.Offset, 0..1
	tint: string, -- ColorCorrection.TintColor; white changes nothing
	saturation: number, -- ColorCorrection.Saturation, -1..1
	contrast: number, -- ColorCorrection.Contrast, -1..1
	lift: number, -- ColorCorrection.Brightness, -1..1
	bloom: number, -- Bloom.Intensity
	bloomSize: number, -- Bloom.Size
	bloomThreshold: number, -- Bloom.Threshold
	rays: number, -- SunRays.Intensity
	raysSpread: number, -- SunRays.Spread
}

-- One emitter that travels with the camera. Kept light: it has to run on a phone.
export type Weather = {
	texture: "sparkle" | "smoke" | "fire",
	direction: "down" | "up" | "across", -- which way particles set off; across is over the lane
	rate: number, -- particles a second
	life: { number }, -- seconds, shortest and longest
	speed: { number }, -- studs a second, slowest and fastest
	spread: number, -- degrees off the direction
	size: { number }, -- studs, when a particle appears and when it is gone
	squash: number, -- 0 is round; more is longer and thinner, up to 3
	streaks: boolean, -- drawn along their flight, as rain is, instead of facing the camera
	spin: number, -- degrees a second, either way
	glow: number, -- 0 is paint, 1 is light
	fade: number, -- how see-through a particle is at its clearest, 0..1
	color: string,
	wind: { number }, -- push along the lane and across it, studs a second squared
	fall: number, -- pull downwards, studs a second squared
	box: { number }, -- the space particles appear in: along the lane, tall, across it
	shift: { number }, -- where its middle is from the camera: along the lane, up, across
	flash: { number }?, -- lightning: seconds between flashes, at least and at most
}

export type Art = {
	palette: { [string]: string },
	ground: Surface, -- the ground either side of the lane, all the way to the horizon
	lane: Surface?, -- the lane's own surface; nil leaves it as the Hub built it
	sign: Surface?, -- the board of the zone's sign; dark, for the writing on it is light
	light: Light,
	weather: Weather?,
}

-- Everything a zone's light is made of, in the place's own values: a look states only what it
-- changes.
local function light(changes: { [string]: any }): Light
	local full: { [string]: any } = {
		clock = 14.5,
		brightness = 3,
		exposure = 0,
		ambient = "#464646",
		outdoor = "#464646",
		air = "#C7C7C7",
		decay = "#6A707D",
		density = 0.3,
		haze = 0,
		glare = 0,
		offset = 0.25,
		tint = "#FFFFFF",
		saturation = 0,
		contrast = 0,
		lift = 0,
		bloom = 1,
		bloomSize = 24,
		bloomThreshold = 2,
		rays = 0.01,
		raysSpread = 0.1,
	}
	for key, value in changes do
		full[key] = value
	end
	return full :: any
end

-- Something light drifting down: leaves, feathers. Whatever `changes` names replaces the usual.
local function drifting(changes: { [string]: any }): Weather
	local full: { [string]: any } = {
		texture = "smoke",
		direction = "down",
		rate = 4,
		life = { 6, 8 },
		speed = { 1.5, 3 },
		spread = 25,
		size = { 0.55, 0.45 },
		squash = 0.8,
		streaks = false,
		spin = 150,
		glow = 0,
		fade = 0.1,
		color = "#FFFFFF",
		wind = { -1, 0.6 },
		fall = 0.2,
		box = { 70, 2, 70 },
		shift = { 0, 20, 0 },
	}
	for key, value in changes do
		full[key] = value
	end
	return full :: any
end

-- Rain: thin streaks coming down fast.
local function raining(changes: { [string]: any }): Weather
	return drifting({
		rate = changes.rate,
		life = changes.life,
		speed = changes.speed,
		spread = 3,
		size = { 0.14, 0.14 },
		squash = 3,
		streaks = true,
		spin = 0,
		fade = changes.fade,
		color = changes.color,
		wind = changes.wind,
		fall = 0,
		shift = { 0, 28, 0 },
		flash = changes.flash,
	})
end

local MORNING = light({
	clock = 8.2,
	brightness = 3.2,
	outdoor = "#AAA08C",
	air = "#FFE0BA",
	decay = "#FFC896",
	density = 0.26,
	haze = 1.2,
	glare = 0.2,
	tint = "#FFF6E6",
	saturation = 0.12,
	contrast = 0.05,
	bloom = 1.1,
	bloomThreshold = 1.8,
	rays = 0.08,
	raysSpread = 0.3,
})

-- The village: the first zone and the streets round the dojos are built in the same colors.
local VILLAGE = {
	bark = "#6D4C41",
	leaf = "#689F38",
	leafLight = "#9CCC65",
	blossom = "#F8BBD0",
	wall = "#F3E5C3",
	wallShade = "#D9C49A",
	roof = "#D2552B",
	roofDark = "#A63E1F",
	trim = "#5D4037",
	window = "#4E7CA8",
	door = "#4E342E",
	stone = "#B8B2A6",
	path = "#CDB98F",
	band = "#C62828",
	target = "#F5F5F5",
	cloth = "#FFF8E1",
	lantern = "#FF8A50",
	cliff = "#A9A190",
	cliffShade = "#8D8576",
	flower = "#FFD54F",
	fence = "#8D6E63",
	hill = "#5C9138",
	hillFar = "#4F7F3A",
	-- Only the streets behind the lane use these.
	rampart = "#D9C9A3",
	rampartCap = "#3F6B3A",
	gateGreen = "#2E6B3E",
	gateRed = "#B5362A",
	hall = "#C4452D",
	wire = "#2B2B2B",
	tank = "#7FA7B5",
}

local ZoneArt = {}

-- The dojos, the market and the throwing strip share the first zone's morning: they are the
-- same village, and a camera standing on the strip crosses the lane's start all the time.
ZoneArt.home = MORNING

-- What stands round the dojos (World/ZoneArt/home): not a zone, so it has no lane, sign or
-- weather of its own. Its grass is the Hub's.
ZoneArt.village = {
	palette = VILLAGE,
	ground = { color = "#689F38", material = "Grass" },
	light = MORNING,
} :: Art

ZoneArt.zones = {
	-- A sunny morning in the village: green and orange under a warm sky.
	academy = {
		palette = VILLAGE,
		ground = { color = "#7CB342", material = "Grass" },
		lane = { color = "#9CCC65", material = "Grass" },
		sign = { color = "#4E342E", material = "WoodPlanks" },
		light = MORNING,
		weather = drifting({ rate = 2, color = "#A5C95A", shift = { 0, 22, 0 } }),
	},

	-- A cold morning on the water: an unfinished bridge in thick fog, gray and blue.
	land_of_waves = {
		palette = {
			water = "#3E6F8E",
			waterDeep = "#2B546E",
			foam = "#DCEAF0",
			pile = "#5B4636",
			plank = "#9A7B5B",
			plankDark = "#735840",
			rope = "#C9B48A",
			boat = "#7A5A44",
			hut = "#8A7460",
			roof = "#5E6B73",
			rock = "#5F6B70",
			leaf = "#4E6B57",
			bark = "#4A3B30",
			mist = "#E4EEF2",
			cloth = "#B9C7CE",
		},
		ground = { color = "#3E6F8E", material = "Glass" },
		lane = { color = "#9A7B5B", material = "WoodPlanks" },
		sign = { color = "#3B2F26", material = "WoodPlanks" },
		light = light({
			clock = 6.6,
			brightness = 1.6,
			ambient = "#5A646E",
			outdoor = "#788796",
			air = "#BECDD7",
			decay = "#96AAB9",
			density = 0.62,
			haze = 6,
			tint = "#DCE8F5",
			saturation = -0.35,
			bloom = 0.8,
			rays = 0,
		}),
	},

	-- Giant trees and a green dusk under them, with shafts of light through the leaves.
	forest_of_death = {
		palette = {
			bark = "#4A3528",
			barkDark = "#35251C",
			root = "#402E22",
			leaf = "#1F5A24",
			leafDark = "#143F1A",
			moss = "#5E7F2E",
			fern = "#3F7A2C",
			rock = "#4C5347",
			vine = "#2C4A1E",
			mushroom = "#C8E6A0",
			shaft = "#F6F2B8",
			fence = "#3B4145",
			mesh = "#262B2E",
			sign = "#ECE7D8",
			signMark = "#C62828",
		},
		ground = { color = "#2F4A1E", material = "LeafyGrass" },
		lane = { color = "#3F5226", material = "LeafyGrass" },
		sign = { color = "#23292B", material = "SmoothPlastic" },
		light = light({
			clock = 9.6,
			brightness = 1.4,
			ambient = "#283C28",
			outdoor = "#3C553C",
			air = "#5A7D55",
			decay = "#3C5A3C",
			density = 0.55,
			haze = 3,
			tint = "#D7F0CD",
			saturation = -0.05,
			contrast = 0.12,
			bloom = 1.2,
			rays = 0.25,
			raysSpread = 0.6,
		}),
		weather = drifting({ rate = 5, color = "#3F7A2C", fade = 0.15 }),
	},

	-- The exam arena at noon: sand, pale stone, flags and a crowd.
	chunin_exam_finals = {
		palette = {
			patch = "#CDB57F",
			wall = "#D8CFBB",
			wallShade = "#B9AE96",
			cap = "#8D8473",
			tier = "#C4BAA4",
			roof = "#7B2D26",
			wood = "#6D4C41",
			pole = "#4E342E",
			flag = "#C62828",
			flagAlt = "#1E5AA8",
			banner = "#F5F0E0",
			crowdRed = "#E57373",
			crowdBlue = "#64B5F6",
			crowdGold = "#FFD54F",
			crowdGreen = "#81C784",
			crowdWhite = "#F5F5F5",
			robe = "#F5F5F5",
			hatFire = "#C62828",
			hatWind = "#2E7D32",
			bark = "#6D4C41",
			leaf = "#558B2F",
			torch = "#FF8A3D",
			hill = "#5E8F3A",
			hillFar = "#4F7F3A",
		},
		ground = { color = "#C4B28A", material = "Sand" },
		lane = { color = "#E3CFA0", material = "Sand" },
		sign = { color = "#3A2A22", material = "WoodPlanks" },
		light = light({
			clock = 12.2,
			brightness = 3.6,
			outdoor = "#AFAA9B",
			air = "#D7E1F0",
			decay = "#B4C3D7",
			density = 0.22,
			haze = 0.3,
			tint = "#FFFAEE",
			saturation = 0.15,
			contrast = 0.08,
			bloom = 1.1,
		}),
		-- The feathers of the sleeping spell that opened the invasion.
		weather = drifting({ rate = 5, squash = 1.4, glow = 0.6, fade = 0.05, life = { 7, 9 } }),
	},

	-- A canyon in the rain at sunset: wet rock, a river, two stone giants and a waterfall.
	valley_of_the_end = {
		palette = {
			rock = "#6B7074",
			rockDark = "#4C5256",
			rockWarm = "#7A6F66",
			water = "#4F7F93",
			fall = "#BFE3EE",
			foam = "#EAF4F7",
			statue = "#8A8E8C",
			statueDark = "#5E6361",
			moss = "#5B6E45",
			bark = "#3E322B",
			needle = "#2F4A35",
			mist = "#E6EEF0",
		},
		ground = { color = "#5C6468", material = "Slate" },
		lane = { color = "#6E7479", material = "Slate" },
		sign = { color = "#33383B", material = "Slate" },
		light = light({
			clock = 17.6,
			brightness = 1.8,
			outdoor = "#827369",
			air = "#CDA07D",
			decay = "#966E5F",
			density = 0.42,
			haze = 3.5,
			tint = "#F0DECD",
			saturation = -0.25,
			contrast = 0.05,
		}),
		weather = raining({
			rate = 40,
			life = { 0.7, 0.9 },
			speed = { 52, 62 },
			fade = 0.5,
			color = "#C8D7E6",
			wind = { -2, 0 },
		}),
	},

	-- The desert village at its hottest: dunes, sandstone domes and sand on the wind.
	hidden_sand = {
		palette = {
			dune = "#E2BC78",
			clay = "#D6AC6C",
			clayDark = "#B58A52",
			cliff = "#C39A5E",
			strata = "#A67C48",
			door = "#4E342E",
			cloth = "#B5462F",
			clothAlt = "#3F6C8C",
			pot = "#A8663C",
			wood = "#7A5536",
			rock = "#BC8F56",
			plate = "#EFE2BD",
			scrub = "#8C8A4E",
		},
		ground = { color = "#DEB873", material = "Sand" },
		lane = { color = "#EBC47E", material = "Sand" },
		sign = { color = "#5B3F26", material = "Sandstone" },
		light = light({
			clock = 14,
			brightness = 4,
			exposure = 0.2,
			outdoor = "#C8AF7D",
			air = "#F0D296",
			decay = "#E1B46E",
			density = 0.4,
			haze = 3,
			glare = 0.6,
			tint = "#FFF0CD",
			saturation = 0.05,
			contrast = 0.1,
			bloom = 1.4,
			bloomThreshold = 1.6,
		}),
		weather = drifting({
			direction = "across",
			rate = 22,
			life = { 1.6, 2.4 },
			speed = { 22, 34 },
			spread = 12,
			size = { 1.2, 2.4 },
			squash = 0,
			spin = 40,
			fade = 0.78,
			color = "#E6C88C",
			wind = { -3, 0 },
			fall = 0,
			box = { 80, 14, 4 },
			shift = { 0, 4, -40 },
		}),
	},

	-- A cave under the earth: black rock, red light and bowls of black flame.
	akatsuki_lair = {
		-- The rock is dark, not black: in a cave nothing is lit but by the air's own light
		-- and the fires, and near-black rock under them was a black screen.
		palette = {
			rock = "#6A5A5E",
			rockDark = "#52464A",
			rockRed = "#7C4A4E",
			-- The mountain the cave is in, seen from outside under its neighbors' daylight:
			-- pale enough not to be a black shape against the sand.
			crag = "#514547",
			cragDark = "#3F3537",
			bowl = "#3B3436",
			ember = "#E53935",
			-- What the fires light the cave with: warmer and paler than the embers, so that
			-- what it falls on shows in its own colors and not only in red.
			firelight = "#FF8A66",
			flame = "#0D0D0D",
			banner = "#141214",
			cloud = "#B71C1C",
			bone = "#8E857A",
			boneDark = "#655E56",
			crystal = "#FF5252",
		},
		ground = { color = "#4C3E41", material = "Slate" },
		lane = { color = "#62504F", material = "Slate" },
		sign = { color = "#141214", material = "Fabric" },
		-- Under a roof the sun and the sky's light do not reach: what is seen is seen by the
		-- indoor ambient light, the fires and the exposure. All three are set high for a cave,
		-- because at the first try (ambient at a twelfth of white, thick dark-red air, the
		-- contrast turned up) the owner saw "very dark, nothing to be seen, all of it black".
		-- It is still the dimmest zone, and red; it is no longer a dark one.
		light = light({
			clock = 20.5,
			brightness = 1.5,
			exposure = 0.5,
			ambient = "#A08890",
			outdoor = "#8C747C",
			air = "#74484E",
			decay = "#4C2C32",
			density = 0.3,
			haze = 1,
			tint = "#FFE2DE",
			saturation = -0.05,
			contrast = 0.05,
			lift = 0.03,
			bloom = 1.6,
			bloomSize = 30,
			bloomThreshold = 1.2,
			rays = 0,
		}),
		-- Embers rising in the dark.
		weather = drifting({
			texture = "sparkle",
			direction = "up",
			rate = 5,
			life = { 4, 6 },
			speed = { 1.5, 3 },
			size = { 0.35, 0.1 },
			squash = 0,
			glow = 1,
			fade = 0,
			color = "#FF5A36",
			wind = { 0, 0 },
			fall = -0.3,
			box = { 60, 2, 60 },
			shift = { 0, -4, 0 },
		}),
	},

	-- The village where it never stops raining: steel towers, pipes and puddles.
	--
	-- It was all but black when the owner first saw it (2026-10-06). Three things were dark at
	-- once and each is undone here: the hour was sunset, with the sun on the horizon behind the
	-- towers and thick fog taking the color of dusk; the ambient light was a quarter of white on
	-- surfaces a third of white; and nearly everything was of Metal or DiamondPlate, which show
	-- what they reflect and little else. Now it is an overcast afternoon, the ambient light is
	-- twice as strong, the steel is paler and only small fittings are metal.
	hidden_rain = {
		palette = {
			steel = "#64747F",
			steelDark = "#44525C",
			steelLight = "#8494A0",
			pipe = "#39454D",
			rust = "#7A5544",
			window = "#FFD54F",
			lamp = "#BFE1FF",
			puddle = "#33475A",
			grate = "#2B353B",
			face = "#6A7983",
			far = "#55636E",
			farDark = "#414E58",
		},
		ground = { color = "#4E5C66", material = "Concrete" },
		lane = { color = "#60707B", material = "Cobblestone" },
		sign = { color = "#2B363E", material = "Concrete" },
		light = light({
			clock = 15.6,
			brightness = 1.5,
			ambient = "#5F6975",
			outdoor = "#8E9AAA",
			air = "#8794A3",
			decay = "#6B7786",
			density = 0.46,
			haze = 2.6,
			tint = "#D6E2F2",
			saturation = -0.3,
			contrast = 0.06,
			lift = 0.02,
			bloom = 1.2,
			rays = 0,
		}),
		weather = raining({
			rate = 85,
			life = { 0.55, 0.7 },
			speed = { 75, 90 },
			fade = 0.35,
			color = "#BECDE1",
			wind = { -4, 0 },
			flash = { 7, 16 },
		}),
	},

	-- A void with no sky: pale cubes and columns hanging in gray, with a breath of violet.
	kamui_dimension = {
		palette = {
			cube = "#8D90A1",
			cubeDark = "#6C6F80",
			cubeLight = "#B4B6C4",
			edge = "#B39DDB",
		},
		ground = { color = "#7D7F8E", material = "SmoothPlastic" },
		lane = { color = "#9B9DAC", material = "SmoothPlastic" },
		sign = { color = "#4B4E60", material = "SmoothPlastic" },
		light = light({
			clock = 18.9,
			brightness = 0.4,
			ambient = "#9696A5",
			outdoor = "#9696A5",
			air = "#80808E",
			decay = "#6E6C80",
			-- Thick enough to hide where the cubes end, and no thicker: at 0.74 and a haze
			-- of 9 the owner asked for less fog.
			density = 0.42,
			haze = 4,
			tint = "#E8E2FF",
			saturation = -0.8,
			contrast = 0.05,
			lift = 0.04,
			bloom = 0.6,
			rays = 0,
		}),
	},

	-- The battlefield under the moon. Its light is not to be changed: see the note at the top.
	great_ninja_war = {
		palette = {
			spike = "#6D4C41",
			boulder = "#424242",
			rockWarm = "#57463E",
			gate = "#C62828",
			gateDark = "#7F1D1D",
			trunk = "#3E2723",
			trunkDark = "#2E1C19",
			root = "#4A342C",
			crown = "#880E4F",
			petal = "#AD1457",
			glow = "#FF80AB",
			scorch = "#231C1A",
			meteor = "#3A3436",
			ridge = "#32282A",
			rope = "#C9B48A",
			tag = "#ECE7D8",
			tent = "#8D8372",
			flap = "#3E3A34",
			banner = "#1F3A5F",
			pole = "#4E342E",
			steel = "#8D9499",
			char = "#1E1917",
			ember = "#FF7043",
			smoke = "#5A5050",
		},
		ground = { color = "#3E322E", material = "Ground" },
		lane = { color = "#4A3B37", material = "Ground" },
		sign = { color = "#2E2320", material = "WoodPlanks" },
		light = light({
			clock = 19.3,
			outdoor = "#6E3C5A",
			air = "#963C5A",
			decay = "#963C5A",
			density = 0.5,
			haze = 3,
		}),
		-- Ash coming down on the field.
		weather = drifting({
			rate = 5,
			life = { 6, 8 },
			speed = { 1, 2.2 },
			size = { 0.3, 0.2 },
			squash = 0,
			spin = 60,
			fade = 0.35,
			color = "#B9A7A2",
			wind = { -0.6, 0.3 },
			fall = 0.1,
		}),
	},
} :: { [string]: Art }

return ZoneArt
