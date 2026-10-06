--!strict
local Catalog = require("../src/shared/Config/Catalog")
local T = require("./harness")
local ZoneArt = require("../src/shared/Config/ZoneArt")

-- The names of Enum.Material the looks may use.
local MATERIALS = {
	Concrete = true,
	DiamondPlate = true,
	Glass = true,
	Grass = true,
	Ground = true,
	LeafyGrass = true,
	Sand = true,
	Slate = true,
	SmoothPlastic = true,
	WoodPlanks = true,
}

local LIGHT_COLORS = { "ambient", "outdoor", "air", "decay", "tint" }

local function isHex(text: string): boolean
	return string.match(text, "^#%x%x%x%x%x%x$") ~= nil
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

	-- The owner's reference: the last zone looks as it did on 2026-10-06 and is not to drift.
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
		T.eq(art.weather, nil, "the last zone has no weather")
		T.eq(art.lane, nil, "the last zone's lane stays as the Hub built it")
		T.eq(art.ground.color, "#3E322E")
		T.eq(art.ground.material, "Ground")
	end,

	["the dojos share the first zone's morning"] = function()
		for field, value in ZoneArt.zones.academy.light :: any do
			T.eq((ZoneArt.home :: any)[field], value, `home light.{field}`)
		end
	end,
}
