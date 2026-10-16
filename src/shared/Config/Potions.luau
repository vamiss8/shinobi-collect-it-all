--!strict
-- Boosts that run for a while once drunk. A player keeps them in a pouch (Data `stock`) and
-- drinks one when they like (Logic/Pouch); drinking one while the same is running adds its
-- minutes to it. They come into the pouch two ways: bought for Herbs at the Herb Shop on the
-- plaza, Herbs being earned by every throw (Tuning.Herbs), or bought for Robux as developer
-- products (Config/Products).
--
-- `herbs` is what one costs at the Herb Shop: the Chakra one dearest, Chakra being what holds
-- a player back late in the game; the luck ones cheapest, being for the hunt more than for the
-- pace. An average player earns about fifty Herbs an hour of play (`lune run sim` prints it),
-- so one potion an hour or so is theirs without Robux.

export type Effect = "ryo" | "chakra" | "luck" | "mutationLuck"

export type Potion = {
	id: string,
	name: string,
	effect: Effect,
	multiplier: number,
	minutes: number,
	herbs: number,
}

local Potions: { Potion } = {
	{
		id = "soldier_pill",
		name = "Soldier Pill",
		effect = "chakra",
		multiplier = 2,
		minutes = 15,
		herbs = 60,
	},
	{
		id = "ichiraku_ramen",
		name = "Ichiraku Ramen",
		effect = "ryo",
		multiplier = 2,
		minutes = 15,
		herbs = 50,
	},
	{
		id = "gama_charm",
		name = "Gama-chan Charm",
		effect = "luck",
		multiplier = 2,
		minutes = 15,
		herbs = 30,
	},
	{
		id = "sage_oil",
		name = "Sage Oil",
		effect = "mutationLuck",
		multiplier = 2,
		minutes = 15,
		herbs = 40,
	},
}

return Potions
