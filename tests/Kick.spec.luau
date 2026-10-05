--!strict
local Catalog = require("../src/shared/Config/Catalog")
local Kick = require("../src/shared/Logic/Kick")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

local EPS = 1e-9

return {
	["bar sweeps 0 -> 1 -> 0 every period"] = function()
		T.near(Kick.barPosition(0, 2), 0, EPS)
		T.near(Kick.barPosition(0.5, 2), 0.5, EPS)
		T.near(Kick.barPosition(1, 2), 1, EPS)
		T.near(Kick.barPosition(1.5, 2), 0.5, EPS)
		T.near(Kick.barPosition(2, 2), 0, EPS)
		T.near(Kick.barPosition(3, 2), 1, EPS, "second period")
	end,

	["positions map to grades at the window edges"] = function()
		T.eq(Kick.grade(1), "Perfect")
		T.eq(Kick.grade(0.94), "Perfect")
		T.eq(Kick.grade(0.939), "Great")
		T.eq(Kick.grade(0.8), "Great")
		T.eq(Kick.grade(0.799), "Good")
		T.eq(Kick.grade(0.55), "Good")
		T.eq(Kick.grade(0.549), "Miss")
		T.eq(Kick.grade(0), "Miss")
	end,

	["power picks the zone by its Chakra threshold"] = function()
		for i, zone in Catalog.zones do
			T.eq((Kick.reach(zone.chakra)).id, zone.id, "right on the threshold")
			if i > 1 then
				local short = Kick.reach(zone.chakra * 0.999)
				T.eq(short.id, Catalog.zones[i - 1].id, `just short of {zone.id}`)
			end
		end
		T.eq((Kick.reach(0)).id, Catalog.zones[1].id, "no power at all")
		T.eq((Kick.reach(1e30)).id, Catalog.zones[#Catalog.zones].id, "more than any zone asks")
	end,

	["depth in a zone grows with the logarithm of the power"] = function()
		local zone = Catalog.zones[2]
		local floor, ceiling = zone.chakra, Catalog.zoneCeiling(zone)
		local _, atStart = Kick.reach(floor)
		local _, halfway = Kick.reach(math.sqrt(floor * ceiling))
		local _, doubled = Kick.reach(floor * 2)
		local _, quadrupled = Kick.reach(floor * 4)
		T.near(atStart, 0, EPS)
		T.near(halfway, 0.5, EPS, "the geometric middle of the thresholds")
		T.near(quadrupled, doubled * 2, EPS, "every doubling is the same step")
	end,

	["the last zone ends at a set multiple of its threshold"] = function()
		local last = Catalog.zones[#Catalog.zones]
		local _, full = Kick.reach(last.chakra * Tuning.Kick.lastZoneSpan)
		local _, beyond = Kick.reach(last.chakra * Tuning.Kick.lastZoneSpan * 100)
		T.near(full, 1, EPS)
		T.near(beyond, 1, EPS, "nothing lies past the far end")
	end,

	["a throw lands inside the zone its power reaches"] = function()
		for _, zone in Catalog.zones do
			local ceiling = Catalog.zoneCeiling(zone)
			for _, power in { zone.chakra, math.sqrt(zone.chakra * ceiling), ceiling * 0.999 } do
				local distance = Kick.distance(power)
				T.eq(Catalog.zoneAt(distance).id, zone.id, `{zone.id} at {power}`)
				T.ok(distance < Tuning.Kick.trackLength, "past the end of the lane")
			end
		end
		T.eq(Kick.distance(Catalog.zones[2].chakra), Catalog.zones[2].startsAt, "on the line")
		T.eq(Kick.distance(-5), 0, "negative power")
		T.ok(Kick.distance(1e30) < Tuning.Kick.trackLength, "nothing flies past the lane's end")
	end,

	["more power never lands nearer"] = function()
		local last = Catalog.zones[#Catalog.zones]
		local power, previous = 1, -1
		while power < last.chakra * Tuning.Kick.lastZoneSpan * 2 do
			local distance = Kick.distance(power)
			T.ok(distance >= previous, `{power} Chakra lands nearer than less of it`)
			previous = distance
			power *= 1.3
		end
	end,

	["a press puts a share of the Chakra into the throw"] = function()
		local curve = Tuning.Kick.powerCurve
		T.near(Kick.share(1), 1, EPS, "the top of the bar is all of it")
		T.near(Kick.share(0.5), 0.5 ^ curve, EPS)
		T.eq(Kick.share(0), 0)
		T.eq(Kick.share(-1), 0, "below the bar")
		T.eq(Kick.share(2), 1, "above the bar")

		local chakra = Catalog.zones[5].chakra
		T.near(Kick.resolve(chakra, 1, 0).distance, Kick.distance(chakra), EPS, "the whole of it")
		for _, position in { 0.9, 0.5, 0.1 } do
			local result = Kick.resolve(chakra, position, 0)
			T.near(result.share, Kick.share(position), EPS)
			T.near(result.distance, Kick.distance(chakra * Kick.share(position)), EPS)
		end
		T.eq(Kick.resolve(chakra, 0, 0).distance, 0, "a press at the bottom throws nothing")
	end,

	["a sloppy press costs distance"] = function()
		local grades = Tuning.Kick.grades
		local perfectFrom, greatFrom, goodFrom = grades[1].from, grades[2].from, grades[3].from
		-- Past the first zone, with just enough Chakra for a press from the top of the bar to
		-- reach the far end of a zone.
		for i = 2, #Catalog.zones do
			local zone = Catalog.zones[i]
			local span = Catalog.zoneEnd(zone) - zone.startsAt
			local chakra = Catalog.zoneCeiling(zone) * 0.999
			local best = Kick.resolve(chakra, 1, 0).distance
			local function lost(position: number): number
				return (best - Kick.resolve(chakra, position, 0).distance) / span
			end
			T.ok(lost(perfectFrom) < 0.12, `{zone.id}: a Perfect is next to nothing short`)
			T.ok(lost(greatFrom) > 0.25, `{zone.id}: the worst Great is a good way short`)
			T.ok(lost(greatFrom) < 0.5, `{zone.id}: a Great is still in the far half`)
			T.ok(lost(goodFrom) > 0.8, `{zone.id}: the worst Good is back at the zone's start`)
			-- The best press that is still a Miss, and one from the middle of the bar.
			T.ok(
				lost(goodFrom - 0.001) > 0.8,
				`{zone.id}: a Miss does not reach where a Perfect lands`
			)
			local sloppy = Kick.resolve(chakra, 0.4, 0).distance
			T.ok(sloppy < zone.startsAt, `{zone.id}: a press from the middle falls a zone short`)
		end
	end,

	["a higher press never lands nearer, whatever its grade"] = function()
		-- Stepping across every grade's edge with the same Chakra.
		for _, zone in Catalog.zones do
			local chakra = zone.chakra * 3
			local previous = -1
			for step = 0, 200 do
				local distance = Kick.resolve(chakra, step / 200, 0).distance
				T.ok(
					distance >= previous,
					`a press at {step / 200} lands nearer than a lower one with {chakra} Chakra`
				)
				previous = distance
			end
		end
	end,

	["the same press always lands on the same spot"] = function()
		local chakra = Catalog.zones[3].chakra * 2
		local first = Kick.resolve(chakra, 0.83, 0).distance
		for _ = 1, 20 do
			T.eq(Kick.resolve(chakra, 0.83, 0).distance, first)
		end
	end,

	["an honest timing claim is used as-is"] = function()
		-- Server saw 0.80s pass with a 0.10s round trip, so it estimates 0.70s.
		T.near(Kick.reconcileElapsed(0.75, 0.80, 0.10), 0.75, EPS)
		T.near(Kick.reconcileElapsed(0.60, 0.80, 0.10), 0.60, EPS)
	end,

	["a timing claim too far off falls back to the server estimate"] = function()
		T.near(Kick.reconcileElapsed(0.20, 0.80, 0.10), 0.70, EPS)
		T.near(Kick.reconcileElapsed(5.00, 0.80, 0.10), 0.70, EPS)
	end,

	["five Perfects in a row charge a Sage kick"] = function()
		local chakra = Catalog.zones[2].chakra
		local streak = 0
		for i = 1, Tuning.Kick.sageStreak do
			local r = Kick.resolve(chakra, 1, streak)
			T.eq(r.sage, false, `kick {i}`)
			streak = r.streak
		end
		T.eq(streak, Tuning.Kick.sageStreak)

		local plain = Kick.resolve(chakra, 1, 0)
		local sage = Kick.resolve(chakra, 1, streak)
		T.eq(sage.sage, true)
		T.near(sage.distance, Kick.distance(chakra * Tuning.Kick.sageMultiplier), EPS)
		T.ok(sage.distance > plain.distance, "a Sage kick must fly farther")
		T.eq(sage.streak, 1, "the Sage kick's own Perfect starts a new streak")
	end,

	["anything but Perfect resets the streak"] = function()
		T.eq(Kick.resolve(1, 0.9, 3).streak, 0)
	end,
}
