--!strict
-- The daily rewards (owner, 2026-10-19: "daily rewards, do them"). One a day, a new one from
-- midnight UTC; seven days in a row, each better than the one before, and then the week starts
-- again; a day missed starts it again from the first. WHAT EACH DAY GIVES IS MY CALL, told to
-- him: Herbs, Ryo as minutes of what the dojo earns (at least `ryoFloor` a minute, so that a
-- player whose dojo is empty is paid too), a potion of the Herbs kind into the pouch, and on
-- the seventh day a premium one, as bought for Robux (Config/Potions `premiumMinutes`).
-- Logic/Daily says which day is due; Services/Daily pays it.
--
-- A STREAK IS REWARDED PAST THE WEEK (owner, 2026-10-19: "what after the seventh day, does it
-- start again? Not right: streaks must be rewarded, without anything overpowered"). The week
-- goes round again, and every whole week claimed in a row before it adds `weekBonus` to the
-- Herbs and the Ryo of its days, up to `weekBonusMost` (from the sixth week on, twice the
-- first week's); and some days of a streak bring a bonus on top of their day's reward
-- (`milestones`), the last of them again every `milestoneEvery` days after it. Herbs and
-- premium potions only: nothing a player could not buy. MY CALL, told to him.

export type Day = {
	herbs: number?,
	ryoMinutes: number?,
	potion: string?, -- one of the Herbs kind (Config/Potions id)
	premium: string?, -- one premium (Config/Potions id)
}

export type Milestone = {
	streak: number, -- the day of a streak it is paid on
	herbs: number,
	premium: { string }, -- premium potions (Config/Potions ids), one each
}

local Daily = {}

Daily.days = {
	{ herbs = 40 },
	{ ryoMinutes = 10 },
	{ potion = "gama_charm" },
	{ herbs = 100 },
	{ ryoMinutes = 30 },
	{ potion = "ichiraku_ramen", herbs = 50 },
	{ herbs = 250, premium = "soldier_pill" },
} :: { Day }

-- Ryo a minute that a Ryo day pays at the least.
Daily.ryoFloor = 50

-- What each whole week in a row adds to the Herbs and Ryo of the days after it, and the most
-- it adds up to.
Daily.weekBonus = 0.2
Daily.weekBonusMost = 1

Daily.milestones = {
	{ streak = 14, herbs = 300, premium = { "sage_oil" } },
	{ streak = 30, herbs = 600, premium = { "soldier_pill", "ichiraku_ramen" } },
	{
		streak = 60,
		herbs = 1200,
		premium = { "soldier_pill", "ichiraku_ramen", "sage_oil", "gama_charm" },
	},
	{
		streak = 100,
		herbs = 2500,
		premium = {
			"soldier_pill",
			"ichiraku_ramen",
			"sage_oil",
			"gama_charm",
			"soldier_pill",
			"ichiraku_ramen",
		},
	},
} :: { Milestone }

-- After the last milestone, it comes again every this many days of the streak.
Daily.milestoneEvery = 100

return Daily
