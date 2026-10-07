--!strict
-- The village's clock. Its day and its night are each twelve hours on the clock and so many
-- seconds of play (Config/ZoneArt): the hour is worked out from how long ago the day began,
-- the light is the mix of the two hours of ZoneArt.day the clock stands between, and the
-- lanterns burn by the hour too. No Roblox APIs: the client's Mood and Lanterns ask here.

local Looks = require("../Config/ZoneArt")

local Daylight = {}

-- The clock's hours of sunrise and sunset. Roblox's sun keeps them.
Daylight.SUNRISE = 6
Daylight.SUNSET = 18

-- The hour on the village's clock, 0..24, `seconds` after its day began.
function Daylight.clock(seconds: number): number
	local time = Looks.daytime
	local half = Daylight.SUNSET - Daylight.SUNRISE
	-- The day begins some way into the daylight.
	local already = (time.begins - Daylight.SUNRISE) / half * time.daylight
	local into = (seconds + already) % (time.daylight + time.night)
	if into < time.daylight then
		return Daylight.SUNRISE + half * into / time.daylight
	end
	return (Daylight.SUNSET + (24 - half) * (into - time.daylight) / time.night) % 24
end

-- How many hours on from one hour another is, going the shorter way round the clock: from
-- -12 to 12, negative when the shorter way is back.
function Daylight.onward(from: number, to: number): number
	return (to - from + 12) % 24 - 12
end

-- The hour that is `share` of the way from one hour to another, the shorter way round. Two
-- lights are mixed so: from an hour before midnight to dawn the clock goes on through the
-- night, and does not run back through the whole day.
function Daylight.toward(from: number, to: number, share: number): number
	return (from + Daylight.onward(from, to) * share) % 24
end

-- The two hours of ZoneArt.day whose light the village is seen by at `clock`, as their places
-- in that list, and how much of the second there is in it, 0..1.
function Daylight.mix(clock: number): (number, number, number)
	local hours = Looks.day
	local now = clock % 24
	for index = 1, #hours - 1 do
		local from, to = hours[index].clock, hours[index + 1].clock
		if now >= from and now < to then
			return index, index + 1, (now - from) / (to - from)
		end
	end
	return #hours, #hours, 0
end

-- Eased between 0 and 1 as `value` goes from `low` to `high`.
local function eased(value: number, low: number, high: number): number
	local t = math.clamp((value - low) / (high - low), 0, 1)
	return t * t * (3 - 2 * t)
end

-- How brightly the village's lanterns burn at `clock`: 1 by night, the low they are kept at by
-- day, and in between over the evening and the morning.
function Daylight.glow(clock: number): number
	local lanterns = Looks.lanterns
	local now = clock % 24
	local lit: number
	if now >= lanterns.lightUp[1] then
		lit = eased(now, lanterns.lightUp[1], lanterns.lightUp[2])
	else
		lit = 1 - eased(now, lanterns.dieDown[1], lanterns.dieDown[2])
	end
	return lanterns.low + (1 - lanterns.low) * lit
end

-- How much of its night-time brightness a lantern's shade shows for a given glow, 0..1: none of
-- it by day, all of it by night.
function Daylight.shade(glow: number): number
	local low = Looks.lanterns.low
	return math.clamp((glow - low) / (1 - low), 0, 1)
end

return Daylight
