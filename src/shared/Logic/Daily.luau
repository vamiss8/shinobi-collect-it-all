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

-- How many times its day's Herbs and Ryo a claim at `streak` days in a row pays: a little more
-- for every whole week claimed before it (Config/Daily `weekBonus`), and no more than
-- `weekBonusMost` more.
function Daily.multiplier(streak: number): number
	local weeks = (math.max(streak, 1) - 1) // #Days.days
	return 1 + math.min(weeks * Days.weekBonus, Days.weekBonusMost)
end

-- The bonus a claim at `streak` days in a row brings on top of its day's reward, if any.
function Daily.milestone(streak: number): Days.Milestone?
	for _, milestone in Days.milestones do
		if milestone.streak == streak then
			return milestone
		end
	end
	local last = Days.milestones[#Days.milestones]
	if last and streak > last.streak and (streak - last.streak) % Days.milestoneEvery == 0 then
		return last
	end
	return nil
end

-- The day of a streak after `streak` that brings the next bonus.
function Daily.nextMilestone(streak: number): number
	for _, milestone in Days.milestones do
		if milestone.streak > streak then
			return milestone.streak
		end
	end
	local last = Days.milestones[#Days.milestones].streak
	return last + (((streak - last) // Days.milestoneEvery) + 1) * Days.milestoneEvery
end

-- What a claim at `streak` days in a row pays: its day of the week's reward, Herbs and Ryo
-- grown by the weeks in a row, and a streak's bonus on top. `bonus` says whether one came.
export type Reward = {
	herbs: number,
	ryoMinutes: number,
	potion: string?,
	premium: { string },
	bonus: boolean,
}
function Daily.reward(streak: number): Reward
	local day = Days.days[Daily.dayOf(streak)]
	local grown = Daily.multiplier(streak)
	local reward: Reward = {
		herbs = math.floor((day.herbs or 0) * grown + 0.5),
		ryoMinutes = math.floor((day.ryoMinutes or 0) * grown + 0.5),
		potion = day.potion,
		premium = {},
		bonus = false,
	}
	if day.premium then
		table.insert(reward.premium, day.premium)
	end
	local extra = Daily.milestone(streak)
	if extra then
		reward.herbs += extra.herbs
		for _, potion in extra.premium do
			table.insert(reward.premium, potion)
		end
		reward.bonus = true
	end
	return reward
end

-- The days in a row the reward due now belongs to (the next claim's, or today's if claimed).
function Daily.count(kept: Kept, now: number): number
	if Daily.ready(kept, now) then
		return Daily.nextStreak(kept, now)
	end
	return math.max(kept.streak, 1)
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
