--!strict
local Catalog = require("../src/shared/Config/Catalog")
local T = require("./harness")
local ZoneArt = require("../src/shared/Config/ZoneArt")

-- The names of Enum.Material the looks may use.
local MATERIALS = {
	Cobblestone = true,
	Concrete = true,
	DiamondPlate = true,
	Fabric = true,
	Glass = true,
	Grass = true,
	Ground = true,
	LeafyGrass = true,
	Sand = true,
	Sandstone = true,
	Slate = true,
	SmoothPlastic = true,
	WoodPlanks = true,
}

local LIGHT_COLORS = { "ambient", "outdoor", "air", "decay", "tint" }

local function isHex(text: string): boolean
	return string.match(text, "^#%x%x%x%x%x%x$") ~= nil
end

-- How bright a hex color is, 0 for black to 1 for white.
local function brightness(hex: string): number
	local red = tonumber(string.sub(hex, 2, 3), 16) :: number
	local green = tonumber(string.sub(hex, 4, 5), 16) :: number
	local blue = tonumber(string.sub(hex, 6, 7), 16) :: number
	return (0.299 * red + 0.587 * green + 0.114 * blue) / 255
end

local function within(value: number, low: number, high: number, what: string)
	T.ok(value >= low and value <= high, `{what} is {value}, outside {low}..{high}`)
end

return {
	["every zone has a look and no look is for a zone that is not there"] = function()
		for _, zone in Catalog.zones do
			T.ok(ZoneArt.zones[zone.id] ~= nil, `{zone.id} has no look`)
		end
		for id in ZoneArt.zones do
			T.ok(Catalog.zoneById[id] ~= nil, `there is a look for {id}, which is not a zone`)
		end
	end,

	["colors are hex and materials are ones Roblox has"] = function()
		for id, art in ZoneArt.zones do
			for name, color in art.palette do
				T.ok(isHex(color), `{id}: color {name} is "{color}"`)
			end
			T.ok(isHex(art.ground.color), `{id}: ground color`)
			T.ok(MATERIALS[art.ground.material] == true, `{id}: ground of {art.ground.material}`)
			if art.lane then
				T.ok(isHex(art.lane.color), `{id}: lane color`)
				T.ok(MATERIALS[art.lane.material] == true, `{id}: lane of {art.lane.material}`)
			end
			if art.sign then
				T.ok(isHex(art.sign.color), `{id}: sign color`)
				T.ok(MATERIALS[art.sign.material] == true, `{id}: sign of {art.sign.material}`)
			end
			for _, field in LIGHT_COLORS do
				local color = (art.light :: any)[field]
				T.ok(isHex(color), `{id}: light.{field} is "{color}"`)
			end
			if art.weather then
				T.ok(isHex(art.weather.color), `{id}: weather color`)
			end
		end
	end,

	["the light of every zone is within what Roblox takes"] = function()
		for id, art in ZoneArt.zones do
			local light = art.light
			within(light.clock, 0, 24, `{id} clock`)
			within(light.brightness, 0, 10, `{id} brightness`)
			within(light.exposure, -3, 3, `{id} exposure`)
			within(light.density, 0, 1, `{id} density`)
			within(light.haze, 0, 10, `{id} haze`)
			within(light.glare, 0, 10, `{id} glare`)
			within(light.offset, 0, 1, `{id} offset`)
			within(light.saturation, -1, 1, `{id} saturation`)
			within(light.contrast, -1, 1, `{id} contrast`)
			within(light.lift, -1, 1, `{id} lift`)
			within(light.bloom, 0, 3, `{id} bloom`)
			within(light.bloomSize, 0, 56, `{id} bloom size`)
			within(light.rays, 0, 1, `{id} rays`)
			within(light.raysSpread, 0, 1, `{id} rays spread`)
		end
	end,

	["weather is light enough for a phone"] = function()
		for id, art in ZoneArt.zones do
			local weather = art.weather
			if weather then
				within(weather.rate, 1, 100, `{id} weather rate`)
				within(weather.squash, 0, 3, `{id} weather squash`)
				within(weather.fade, 0, 1, `{id} weather fade`)
				-- How many particles are in the air at once.
				within(weather.rate * weather.life[2], 1, 80, `{id} particles in the air`)
				T.eq(#weather.box, 3)
				T.eq(#weather.shift, 3)
				T.eq(#weather.wind, 2)
				if weather.flash then
					T.ok(weather.flash[1] >= 3, `{id} flashes too often`)
					T.ok(weather.flash[2] >= weather.flash[1], `{id} flash gap is backwards`)
				end
			end
		end
	end,

	-- The writing on a sign is light, so its board must be dark enough to read it against.
	["every zone's sign has a dark board"] = function()
		for id, art in ZoneArt.zones do
			local sign = art.sign
			T.ok(sign ~= nil, `{id} has no board for its sign`)
			if sign then
				T.ok(brightness(sign.color) <= 0.36, `{id}: the sign's board is too pale`)
			end
		end
	end,

	-- A zone that is too dark to see is a broken zone, as Hidden Rain was at first and the
	-- cave after it. Whatever the hour, enough ambient light has to reach what stands outdoors.
	["no zone is left in the dark"] = function()
		for id, art in ZoneArt.zones do
			local bright = brightness(art.light.outdoor)
			T.ok(bright >= 0.26, `{id}: outdoor ambient is only {bright} of white`)
		end
	end,

	-- The cave is under a roof, where neither the sun nor the sky's light comes: it is seen by
	-- the indoor ambient light alone, and by its fires. So that light is strong there, and the
	-- rock it falls on is of a middle tone; the air is thin and pale, so that the far wall is
	-- seen and is not black.
	["the cave is lit from within"] = function()
		local art = ZoneArt.zones.akatsuki_lair
		local look = art.light
		T.ok(brightness(look.ambient) >= 0.6, `indoor ambient is {brightness(look.ambient)}`)
		T.ok(look.exposure >= 0.3, `exposure is {look.exposure}`)
		T.ok(look.density <= 0.3, `the air's density is {look.density}`)
		T.ok(brightness(look.air) >= 0.45, "the air itself is dark, and so is all that is far")
		T.ok(look.contrast <= 0.1, "contrast turned up makes the dark darker")
		for _, name in { "rock", "rockDark", "rockRed" } do
			local bright = brightness(art.palette[name])
			T.ok(bright >= 0.38, `{name} is {bright} of white: dark under any light`)
		end
		T.ok(brightness(art.ground.color) >= 0.3, "the ground is black")
		T.ok(art.lane ~= nil and brightness(art.lane.color) >= 0.4, "the lane is black")
		T.ok(brightness(art.palette.firelight) >= 0.6, "the fires give too little light")
	end,

	-- The owner on the cave as it was first lit: "red glows on a black background look
	-- unnatural". What gives light in it, and the air it is seen through, are not red: the
	-- red channel does not stand far above the other two.
	["nothing that lights the cave is red"] = function()
		local art = ZoneArt.zones.akatsuki_lair
		local function redness(hex: string): number
			local r = tonumber(hex:sub(2, 3), 16) :: number
			local g = tonumber(hex:sub(4, 5), 16) :: number
			local b = tonumber(hex:sub(6, 7), 16) :: number
			return (r - math.max(g, b)) / 255
		end
		local glowing = {
			firelight = art.palette.firelight,
			flame = art.palette.flame,
			ember = art.palette.ember,
			crystal = art.palette.crystal,
			shaft = art.palette.shaft,
			air = art.light.air,
			ambient = art.light.ambient,
			tint = art.light.tint,
			weather = (art.weather :: any).color,
		}
		for name, hex in glowing do
			T.ok(redness(hex) <= 0.42, `{name} is red: {hex}`)
		end
		for _, name in { "rock", "rockDark", "rockRed" } do
			T.ok(redness(art.palette[name]) <= 0.1, `{name} is red rock`)
		end
		-- A bloom above the place's own puts a halo round every fire.
		T.ok(art.light.bloom <= 1, `bloom is {art.light.bloom}`)
		T.ok(art.light.bloomThreshold >= 1.8, `bloom starts at {art.light.bloomThreshold}`)
	end,

	-- The owner's reference: the last zone is lit as it was on 2026-10-06 and is not to drift.
	-- Its scenery, lane and weather are free to change; its light, air and ground are not.
	["the last zone keeps its light, its moonlit air and its ground"] = function()
		local art = ZoneArt.zones.great_ninja_war
		local expected: { [string]: any } = {
			-- What the old Mood set for the zone.
			clock = 19.3,
			outdoor = "#6E3C5A",
			air = "#963C5A",
			decay = "#963C5A",
			density = 0.5,
			haze = 3,
			-- What the place's own Lighting holds, read out of Studio that day.
			brightness = 3,
			exposure = 0,
			ambient = "#464646",
			glare = 0,
			offset = 0.25,
			bloom = 1,
			bloomSize = 24,
			bloomThreshold = 2,
			rays = 0.01,
			raysSpread = 0.1,
			-- No color correction existed: these are the values that change nothing.
			tint = "#FFFFFF",
			saturation = 0,
			contrast = 0,
			lift = 0,
		}
		local count = 0
		for field, value in art.light :: any do
			count += 1
			T.eq(value, expected[field], `great_ninja_war light.{field}`)
		end
		for field in expected do
			T.ok((art.light :: any)[field] ~= nil, `great_ninja_war light lost {field}`)
		end
		T.eq(count, 20, "a field was added to the light without a reference value for it")
		T.eq(art.ground.color, "#3E322E")
		T.eq(art.ground.material, "Ground")
	end,

	-- The village has a day and a night, and its night is moonlit: enough of the sky's light
	-- for the plaza and the first zone, and enough light indoors for a dojo's pads.
	["the village is never left in the dark, whatever the hour"] = function()
		for index, hour in ZoneArt.day do
			local light = hour.light
			local what = `hour {index} ({hour.clock})`
			within(hour.clock, 0, 24, `{what} clock`)
			T.ok(brightness(light.outdoor) >= 0.26, `{what}: outdoor ambient {light.outdoor}`)
			T.ok(brightness(light.ambient) >= 0.26, `{what}: indoor ambient {light.ambient}`)
			within(light.brightness, 1.5, 4, `{what} brightness`)
			within(light.density, 0, 0.35, `{what} density`)
			within(light.bloom, 0, 1.3, `{what} bloom`)
			within(light.exposure, -0.2, 0.5, `{what} exposure`)
		end
	end,

	["only the village goes by the hour: every other zone keeps its own light"] = function()
		for id, art in ZoneArt.zones do
			T.eq(art.daily == true, id == "academy", `{id} and the village's clock`)
		end
	end,

	["the dojos share the first zone's morning and its colors"] = function()
		for field, value in ZoneArt.zones.academy.light :: any do
			T.eq((ZoneArt.home :: any)[field], value, `home light.{field}`)
		end
		for name, color in ZoneArt.zones.academy.palette do
			T.eq(ZoneArt.village.palette[name], color, `the village's {name}`)
		end
		T.ok(isHex(ZoneArt.village.ground.color), "the village's ground color")
		T.ok(MATERIALS[ZoneArt.village.ground.material] == true, "the village's ground")
	end,
}
