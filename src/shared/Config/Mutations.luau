--!strict
-- Mutations roll independently of rank when a scroll is opened.
-- `chance` is "1 in N" at x1 mutation luck. Event mutations only drop while their event runs.
-- Ids are stored in player saves: never rename or reuse one.

export type Mutation = {
	id: string,
	name: string,
	multiplier: number,
	chance: number,
	color: string,
	event: string?,
}

local Mutations: { Mutation } = {
	{ id = "chakra", name = "Chakra", multiplier = 1.5, chance = 10, color = "#4FC3F7" },
	{ id = "kurama", name = "Kurama", multiplier = 2, chance = 25, color = "#FFB300" },
	{ id = "ice", name = "Ice", multiplier = 3, chance = 60, color = "#B3E5FC" },
	{ id = "lava", name = "Lava", multiplier = 4, chance = 120, color = "#FF5722" },
	{ id = "storm", name = "Storm", multiplier = 6, chance = 300, color = "#7C4DFF" },
	{ id = "rinnegan", name = "Rinnegan", multiplier = 10, chance = 800, color = "#B39DDB" },
	{ id = "six_paths", name = "Six Paths", multiplier = 20, chance = 2500, color = "#FFFFFF" },

	-- Event-only
	{
		id = "tsukuyomi",
		name = "Tsukuyomi",
		multiplier = 8,
		chance = 50,
		color = "#D50000",
		event = "blood_moon",
	},
	{
		id = "akatsuki",
		name = "Akatsuki",
		multiplier = 5,
		chance = 40,
		color = "#B71C1C",
		event = "akatsuki_raid",
	},
	{
		id = "leaf_festival",
		name = "Leaf Festival",
		multiplier = 3,
		chance = 20,
		color = "#FFD54F",
		event = "leaf_festival",
	},
}

return Mutations
