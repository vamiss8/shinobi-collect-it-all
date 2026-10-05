--!strict
-- Kick math: the power bar, timing grades, distance and the Sage streak.
-- No Roblox APIs, so it runs under Lune tests as well as in game.

local Catalog = require("../Config/Catalog")
local Tuning = require("../Config/Tuning")

local Kick = {}

-- The spread never pushes a landing onto the next zone's line: power alone decides the zone.
local DEEPEST = 0.999

export type Grade = "Perfect" | "Great" | "Good" | "Miss"

export type Result = {
	grade: Grade,
	distance: number,
	sage: boolean, -- this kick spent a charged Sage streak
	streak: number, -- Perfects in a row after this kick
}

-- Tuning stores grade ids as plain strings; this pins them to the Grade type once.
local GRADES = (Tuning.Kick.grades :: any) :: { { id: Grade, from: number, multiplier: number } }

-- Marker position (0..1) `elapsed` seconds after the bar started.
-- It sweeps 0 -> 1 -> 0 once per period, with no jump from the top straight back to zero.
function Kick.barPosition(elapsed: number, period: number?): number
	local p = period or Tuning.Kick.barPeriod
	local phase = (elapsed % p) / p
	return if phase < 0.5 then phase * 2 else (1 - phase) * 2
end

-- Grade and distance multiplier for a marker position.
function Kick.grade(position: number): (Grade, number)
	for _, g in GRADES do
		if position >= g.from then
			return g.id, g.multiplier
		end
	end
	local last = GRADES[#GRADES]
	return last.id, last.multiplier
end

-- Where a throw of the given power (Chakra times the grade's multiplier) is headed: the
-- farthest zone whose threshold it reaches, and how deep into that zone, from 0 at its start to
-- 1 at its far end. Depth grows with the logarithm of the power, so every doubling carries the
-- kunai the same stretch farther.
function Kick.reach(power: number): (Catalog.Zone, number)
	local zone = Catalog.zoneFor(power)
	local floor, ceiling = zone.chakra, Catalog.zoneCeiling(zone)
	local depth = math.log(math.max(power, floor) / floor) / math.log(ceiling / floor)
	return zone, math.clamp(depth, 0, 1)
end

-- How far the kunai flies, in studs. `roll` is a number in [0, 1) from the caller's RNG and
-- picks a point in the random spread, which moves the landing inside its zone only.
function Kick.distance(chakra: number, multiplier: number, roll: number): number
	local zone, depth = Kick.reach(math.max(chakra, 0) * multiplier)
	depth = math.clamp(depth + (roll * 2 - 1) * Tuning.Kick.spread, 0, DEEPEST)
	return zone.startsAt + (Catalog.zoneEnd(zone) - zone.startsAt) * depth
end

-- Picks the elapsed time to grade a press by.
--
-- The client reports how long it had been watching the bar when the player pressed. The server
-- estimates the same thing as its own elapsed time minus the round trip: the start message took
-- half of it to arrive and the press took the other half to come back. An honest claim lands
-- close to the estimate and is used as-is, so the player gets exactly the grade they saw. A claim
-- further off than the tolerance is replaced with the estimate, so a cheater can shift the result
-- by at most the tolerance.
function Kick.reconcileElapsed(claimed: number, serverElapsed: number, roundTrip: number): number
	local estimate = math.max(serverElapsed - roundTrip, 0)
	if math.abs(claimed - estimate) <= Tuning.Kick.timingTolerance then
		return claimed
	end
	return estimate
end

-- Resolves one kick. A charged streak is spent on this kick; this kick's own Perfect then
-- starts counting towards the next charge.
function Kick.resolve(chakra: number, position: number, streak: number, roll: number): Result
	local cfg = Tuning.Kick
	local grade: Grade, multiplier: number = Kick.grade(position)
	local sage = streak >= cfg.sageStreak
	if sage then
		multiplier *= cfg.sageMultiplier
		streak = 0
	end
	return {
		grade = grade,
		distance = Kick.distance(chakra, multiplier, roll),
		sage = sage,
		streak = if grade == "Perfect" then streak + 1 else 0,
	}
end

return Kick
