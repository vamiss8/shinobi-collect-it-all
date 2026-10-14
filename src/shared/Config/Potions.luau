--!strict
-- Timed boosts sold as developer products. Buying one while it is active extends it.

export type Effect = "ryo" | "chakra" | "luck" | "mutationLuck"

export type Potion = {
	id: string,
	name: string,
	effect: Effect,
	multiplier: number,
	minutes: number,
}

local Potions: { Potion } = {
	{ id = "soldier_pill", name = "Soldier Pill", effect = "chakra", multiplier = 2, minutes = 15 },
	{
		id = "ichiraku_ramen",
		name = "Ichiraku Ramen",
		effect = "ryo",
		multiplier = 2,
		minutes = 15,
	},
	{ id = "gama_charm", name = "Gama-chan Charm", effect = "luck", multiplier = 2, minutes = 15 },
	{ id = "sage_oil", name = "Sage Oil", effect = "mutationLuck", multiplier = 2, minutes = 15 },
}

return Potions
