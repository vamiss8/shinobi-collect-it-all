--!strict
local Catalog = require("../src/shared/Config/Catalog")
local Kick = require("../src/shared/Logic/Kick")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

local EPS = 1e-9
local NO_SPREAD = 0.5 -- a roll of 0.5 lands exactly in the middle of the spread

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
				for _, roll in { 0, NO_SPREAD, 0.999999 } do
					local distance = Kick.distance(power, 1, roll)
					T.eq(Catalog.zoneAt(distance).id, zone.id, `{zone.id} at {power}`)
					T.ok(distance < Tuning.Kick.trackLength, "past the end of the lane")
				end
			end
		end
		T.eq(Kick.distance(-5, 1, NO_SPREAD), 0, "negative chakra")
	end,

	["more power never lands nearer"] = function()
		local last = Catalog.zones[#Catalog.zones]
		local power, previous = 1, -1
		while power < last.chakra * Tuning.Kick.lastZoneSpan * 2 do
			local distance = Kick.distance(power, 1, NO_SPREAD)
			T.ok(distance >= previous, `{power} Chakra lands nearer than less of it`)
			previous = distance
			power *= 1.3
		end
	end,

	["random spread shifts the landing by a share of the zone"] = function()
		local zone = Catalog.zones[3]
		local length = Catalog.zoneEnd(zone) - zone.startsAt
		local power = math.sqrt(zone.chakra * Catalog.zoneCeiling(zone))
		local middle = Kick.distance(power, 1, NO_SPREAD)
		T.near(middle, zone.startsAt + length / 2, EPS)
		T.near(Kick.distance(power, 1, 0), middle - length * Tuning.Kick.spread, EPS)
		T.ok(
			Kick.distance(power, 1, 0.999999) < middle + length * Tuning.Kick.spread,
			"upper bound"
		)
		T.eq(Kick.distance(zone.chakra, 1, 0), zone.startsAt, "never back into the zone before")
	end,

	["a missed throw falls back by less than a whole zone"] = function()
		local grades = Tuning.Kick.grades
		local miss = grades[#grades].multiplier
		for i = 2, #Catalog.zones do
			local zone = Catalog.zones[i]
			local landed = Kick.reach(zone.chakra * miss)
			T.eq(landed.id, Catalog.zones[i - 1].id, `a miss from the edge of {zone.id}`)
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
			local r = Kick.resolve(chakra, 1, streak, NO_SPREAD)
			T.eq(r.sage, false, `kick {i}`)
			streak = r.streak
		end
		T.eq(streak, Tuning.Kick.sageStreak)

		local plain = Kick.resolve(chakra, 1, 0, NO_SPREAD)
		local sage = Kick.resolve(chakra, 1, streak, NO_SPREAD)
		T.eq(sage.sage, true)
		T.near(sage.distance, Kick.distance(chakra, Tuning.Kick.sageMultiplier, NO_SPREAD), EPS)
		T.ok(sage.distance > plain.distance, "a Sage kick must fly farther")
		T.eq(sage.streak, 1, "the Sage kick's own Perfect starts a new streak")
	end,

	["anything but Perfect resets the streak"] = function()
		T.eq(Kick.resolve(1, 0.9, 3, NO_SPREAD).streak, 0)
	end,
}
