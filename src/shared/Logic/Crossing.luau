--!strict
-- Where one place's light gives way to the next. Every zone has a light of its own, and so has
-- the village behind the lane's start (Config/ZoneArt); a camera near the line between two
-- places sees the two mixed, by where it is and not by how long ago it crossed. So the light is
-- right the moment the camera is past the line, however fast it got there.
--
-- It used to change over a second and a half from the moment the line was crossed, checked
-- three times a second: a runner at full speed was half way through a zone before its light
-- was there.

local Catalog = require("../Config/Catalog")

local Crossing = {}

-- Where the camera is when it is behind the lane's start: the dojos, the plaza, the strip.
Crossing.HOME = "home"
-- The stretch of the lane over which one light turns into the next, studs: half of it either
-- side of the line. Shorter than any zone, so that two crossings never meet.
Crossing.WIDTH = 60

-- The place a camera `along` studs down the lane is in: a zone's id, or home.
function Crossing.place(along: number): string
	return if along < 0 then Crossing.HOME else Catalog.zoneAt(along).id
end

-- The two places whose light a camera `along` studs down the lane sees, and how much of the
-- second there is in it, from 0 to 1. Away from every line the two are the same place.
function Crossing.mix(along: number): (string, string, number)
	local half = Crossing.WIDTH / 2
	local before = Crossing.HOME
	for _, zone in Catalog.zones do
		local off = along - zone.startsAt
		if math.abs(off) < half then
			-- Eased at both ends, so that the change neither starts nor stops with a jolt.
			local t = (off + half) / Crossing.WIDTH
			return before, zone.id, t * t * (3 - 2 * t)
		end
		before = zone.id
	end
	local place = Crossing.place(along)
	return place, place, 0
end

return Crossing
