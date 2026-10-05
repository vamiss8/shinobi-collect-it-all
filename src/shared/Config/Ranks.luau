--!strict
-- Rarity ranks, ordered from most common to rarest. Named after Bingo Book threat ranks.
-- Colors are hex strings rather than Color3 so this module also loads under Lune.

export type Rank = {
	id: string,
	name: string,
	color: string,
}

local Ranks: { Rank } = {
	{ id = "D", name = "D Rank", color = "#9E9E9E" },
	{ id = "C", name = "C Rank", color = "#4CAF50" },
	{ id = "B", name = "B Rank", color = "#2196F3" },
	{ id = "A", name = "A Rank", color = "#9C27B0" },
	{ id = "A+", name = "A+ Rank", color = "#E040FB" },
	{ id = "S", name = "S Rank", color = "#FFC107" },
	{ id = "S+", name = "S+ Rank", color = "#FF6D00" },
	{ id = "SS", name = "SS Rank", color = "#F44336" },
	{ id = "SSS", name = "SSS Rank", color = "#00E5FF" },
	{ id = "SixPaths", name = "Six Paths", color = "#FFFFFF" },
}

return Ranks
