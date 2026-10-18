--!strict
-- Which daily reward is due (Config/Daily). A day is a day of UTC, counted from 1970; the
-- save keeps the day the last reward was claimed and how many days in a row it has been.

local Days = require("../Config/Daily")

local Daily = {}

local DAY = 86400

-- What a save keeps: the day of the last claim (0 for never) and the days in a row.
export type Kept = { last: number, streak: number }

-- The day it is at `now`, unix seconds.
function Daily.today(now: number): number
	return math.floor(now / DAY)
end

-- Whether a reward can be claimed today.
function Daily.ready(kept: Kept, now: number): boolean
	return kept.last < Daily.today(now)
end

-- The days in a row the next claim makes: one more if the last was yesterday (or today), else
-- the week starts again.
function Daily.nextStreak(kept: Kept, now: number): number
	local today = Daily.today(now)
	if kept.last >= today - 1 and kept.last > 0 then
		return kept.streak + (if kept.last < today then 1 else 0)
	end
	return 1
end

-- The place in the week (1 to 7) of the reward for a streak of `streak` days.
function Daily.dayOf(streak: number): number
	return (math.max(streak, 1) - 1) % #Days.days + 1
end

-- The place in the week of the reward due now, or that was claimed today.
function Daily.due(kept: Kept, now: number): number
	if Daily.ready(kept, now) then
		return Daily.dayOf(Daily.nextStreak(kept, now))
	end
	return Daily.dayOf(kept.streak)
end

-- Seconds until the next reward can be claimed: 0 if one can be now.
function Daily.wait(kept: Kept, now: number): number
	if Daily.ready(kept, now) then
		return 0
	end
	return (Daily.today(now) + 1) * DAY - now
end

-- The Ryo a reward of `minutes` pays, for a dojo earning `income` a second.
function Daily.ryo(minutes: number, income: number): number
	return math.floor(math.max(income * 60, Days.ryoFloor) * minutes)
end

-- Marks today's reward as claimed; returns the place in the week of what was claimed, or nil
-- if today's was claimed already.
function Daily.claim(kept: Kept, now: number): number?
	if not Daily.ready(kept, now) then
		return nil
	end
	kept.streak = Daily.nextStreak(kept, now)
	kept.last = Daily.today(now)
	return Daily.dayOf(kept.streak)
end

return Daily
