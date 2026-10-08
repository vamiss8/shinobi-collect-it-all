--!strict
-- The legendary shinobi: three that no zone drops. Each is bought once, for Robux, with a game
-- pass of its own (Config/Products, by `pass`), and is then the player's for good: it cannot be
-- sent on a last mission, a rebirth leaves it where it stands with the levels bought for it,
-- and a save that has lost one is given it back (Services/Legends). In every other way it is a
-- shinobi like any: it stands on a pad, earns Ryo and is levelled up at the pad's console.
--
-- Listed from the cheapest to the dearest. `income` is Ryo a second at its first level, before
-- upgrades and boosts, and none earns what the weakest SSS shinobi does (tested): they are a
-- head start that every rebirth keeps, not the best the dojo can hold.
-- Ids are stored in saves, and a model is found by its id: never rename one.

export type Legend = {
	id: string,
	name: string,
	income: number,
	pass: string,
}

local Legends: { Legend } = {
	{ id = "tsunade", name = "Tsunade", income = 1200, pass = "LegendTsunade" },
	{ id = "tobirama", name = "Tobirama", income = 5000, pass = "LegendTobirama" },
	{ id = "hagoromo", name = "Hagoromo", income = 20000, pass = "LegendHagoromo" },
}

return Legends
