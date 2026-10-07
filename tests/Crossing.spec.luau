--!strict
local Catalog = require("../src/shared/Config/Catalog")
local Crossing = require("../src/shared/Logic/Crossing")
local T = require("./harness")

local EPS = 1e-9
local HALF = Crossing.WIDTH / 2

return {
	["behind the lane's start is home, and past it the zone the camera is in"] = function()
		T.eq(Crossing.place(-0.01), Crossing.HOME)
		T.eq(Crossing.place(-500), Crossing.HOME)
		for _, zone in Catalog.zones do
			T.eq(Crossing.place(zone.startsAt), zone.id)
			T.eq(Crossing.place(Catalog.zoneEnd(zone) - 0.01), zone.id)
		end
	end,

	["away from every line the light is one place's own"] = function()
		for _, zone in Catalog.zones do
			local middle = (zone.startsAt + Catalog.zoneEnd(zone)) / 2
			for _, along in { zone.startsAt + HALF, middle, Catalog.zoneEnd(zone) - HALF } do
				local from, to, share = Crossing.mix(along)
				T.eq(from, zone.id, `at {along}`)
				T.eq(to, zone.id, `at {along}`)
				T.eq(share, 0)
			end
		end
		local from, to, share = Crossing.mix(-HALF)
		T.eq(from, Crossing.HOME)
		T.eq(to, Crossing.HOME)
		T.eq(share, 0)
	end,

	["on a line the two lights are mixed half and half, and wholly changed a little way on"] = function()
		local before = Crossing.HOME
		for _, zone in Catalog.zones do
			local from, to, share = Crossing.mix(zone.startsAt)
			T.eq(from, before, zone.id)
			T.eq(to, zone.id)
			T.near(share, 0.5, EPS)

			local _, nearTo, nearly = Crossing.mix(zone.startsAt + HALF - 0.01)
			T.eq(nearTo, zone.id)
			T.ok(nearly > 0.999, `{zone.id}: the light is not there {HALF} studs in`)
			local farFrom, _, hardly = Crossing.mix(zone.startsAt - HALF + 0.01)
			T.eq(farFrom, before)
			T.ok(hardly < 0.001, `{zone.id}: the light changes before its stretch begins`)
			before = zone.id
		end
	end,

	["the mix only ever moves towards the place ahead, and never jumps"] = function()
		-- What share of the light at `along` is the light of the zone numbered `index`.
		local function of(index: number, along: number): number
			local id = Catalog.zones[index].id
			local from, to, share = Crossing.mix(along)
			return (if from == id then 1 - share else 0) + (if to == id then share else 0)
		end
		for index, zone in Catalog.zones do
			local previous = of(index, zone.startsAt - HALF - 1)
			T.eq(previous, 0)
			for along = zone.startsAt - HALF - 1, zone.startsAt + HALF + 1, 0.25 do
				local now = of(index, along)
				T.ok(now >= previous - EPS, `{zone.id}: its light fades as the camera comes in`)
				T.ok(now - previous < 0.02, `{zone.id}: its light jumps at {along}`)
				previous = now
			end
			T.near(previous, 1, EPS)
		end
	end,

	["no zone is so short that two crossings meet in it"] = function()
		for _, zone in Catalog.zones do
			T.ok(
				Catalog.zoneEnd(zone) - zone.startsAt > Crossing.WIDTH,
				`{zone.id} is shorter than a crossing`
			)
		end
	end,
}
