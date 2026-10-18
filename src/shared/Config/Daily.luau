--!strict
-- The daily rewards (owner, 2026-10-19: "daily rewards, do them"). One a day, a new one from
-- midnight UTC; seven days in a row, each better than the one before, and then the week starts
-- again; a day missed starts it again from the first. WHAT EACH DAY GIVES IS MY CALL, told to
-- him: Herbs, Ryo as minutes of what the dojo earns (at least `ryoFloor` a minute, so that a
-- player whose dojo is empty is paid too), a potion of the Herbs kind into the pouch, and on
-- the seventh day a premium one, as bought for Robux (Config/Potions `premiumMinutes`).
-- Logic/Daily says which day is due; Services/Daily pays it.

export type Day = {
	herbs: number?,
	ryoMinutes: number?,
	potion: string?, -- one of the Herbs kind (Config/Potions id)
	premium: string?, -- one premium (Config/Potions id)
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

return Daily
