--!strict
-- The guide (owner, 2026-10-19: "cover literally everything: a base tutorial at the very start
-- and mini tutorials when something is met for the first time; mutations, say, are mentioned
-- in passing in the base one, and when a player first catches one with a mutation Iruka
-- explains it in more detail; so with every mechanic"). Iruka speaks (client Guide): the base
-- tutorial is `steps`, in order, at the first visit, and cannot be skipped then (replayed from
-- the settings it can); a tip is said once, when what it is about is first met.
--
-- A step's words are Guide_<id> and a tip's Tip_<id> in the language packs, marked for color as
-- the FAQ is ({r|...}). A step is done when what it waits for happens, or by its button when it
-- waits for nothing:
--   chakra      ten Chakra more than when the step began
--   aim         the power bar comes up (the player is on the strip)
--   throw       the throw is made
--   home        the catch is brought home (caught: said, and back to the strip)
--   place       a shinobi is set on a pad
--   slider      the throw power slider is opened; sliderShut: and shut again
--   near        the player stands in the ring at the first place `point` names
--   window      the window named `window` (Ui.window's name) is opened and shut again
-- `point` is what is shown: a part of the interface by its name (Ui.target), which the screen
-- is dimmed round and an arrow points at; or a place in the world ("strip", "pad", "gift",
-- "board", or a shop's id), which a trail on the ground leads to from the player's feet.
-- `silent` steps say nothing (the run home, which the game tells itself).
-- STEPS ARE SAVED BY THEIR PLACE (Data.guide, the steps done): add new ones at the end; a
-- reordering needs a rule in Logic/Saves (version 6 is one).

export type Step = {
	id: string,
	wait: string?,
	point: { string }?,
	window: string?,
	silent: boolean?,
}

export type Tip = {
	id: string,
	point: { string }?,
	-- Said also to those who played before the guide existed (Logic/Saves version 5): what is
	-- new to everyone. The other tips are taken as known to them.
	everyone: boolean?,
}

local Guide = {}

-- The base tutorial, rebuilt at the owner's word of 2026-10-19 after he went through the first
-- one: one place or one button at a time; walk to each place, and the step waits until the
-- player is there; press each window, and it waits until it has been opened and shut.
Guide.steps = {
	{ id = "hello" },
	{ id = "train", wait = "chakra", point = { "slot1", "slot2" } },
	{ id = "strip", wait = "aim", point = { "strip" } },
	{ id = "bar", wait = "throw" },
	{ id = "run", wait = "home", silent = true },
	{ id = "place", wait = "place", point = { "pad" } },
	{ id = "income", point = { "ryo" } },
	{ id = "power", wait = "slider", point = { "chakra" } },
	{ id = "slider", wait = "sliderShut", point = { "slider" } },
	{ id = "tenten", wait = "near", point = { "tenten" } },
	{ id = "speed", wait = "near", point = { "speed" } },
	{ id = "sell", wait = "near", point = { "sell" } },
	{ id = "herbs", wait = "near", point = { "herbs" } },
	{ id = "inventory", wait = "window", window = "Inventory", point = { "inventory" } },
	{ id = "book", wait = "window", window = "Index", point = { "book" } },
	{ id = "shop", wait = "window", window = "Shop", point = { "shop" } },
	{ id = "awards", wait = "window", window = "Achievements", point = { "awards" } },
	{ id = "board", wait = "near", point = { "board" } },
	{ id = "settings", wait = "window", window = "Settings", point = { "settings" } },
	{ id = "group", wait = "near", point = { "gift" } },
	{ id = "bye" },
} :: { Step }

-- Every tip, in the order they would most likely come.
Guide.tips = {
	{ id = "seal" },
	{ id = "ring" },
	{ id = "mutation", point = { "book" } },
	{ id = "nextRank" },
	{ id = "caught", point = { "speed" } },
	{ id = "herbs", point = { "herbsChip" } },
	{ id = "twin", point = { "inventory" } },
	{ id = "merged" },
	{ id = "upgrade" },
	{ id = "kunai", point = { "tenten" } },
	{ id = "speed", point = { "speed" } },
	{ id = "pads" },
	{ id = "floor" },
	{ id = "potion", point = { "shop" } },
	{ id = "lucky" },
	{ id = "sage" },
	{ id = "event" },
	{ id = "awards", point = { "awards" }, everyone = true },
	{ id = "page", point = { "book" } },
	{ id = "rebirth", point = { "rebirth" } },
	{ id = "reborn" },
	{ id = "offline" },
	{ id = "legend", everyone = true },
	{ id = "leaders", everyone = true },
	{ id = "daily", everyone = true },
	-- The Discord server and its codes, said a while into a visit once the tutorial is done
	-- (client Guide COMMUNITY_AFTER), only while Tuning.Social.server is on.
	{ id = "community", point = { "settings" }, everyone = true },
} :: { Tip }

-- What Data.guide holds once the base tutorial is done.
Guide.DONE = #Guide.steps

-- How many steps the first base tutorial had (2026-10-19, before it was rebuilt), for
-- Logic/Saves version 6.
Guide.FIRST_DONE = 14

return Guide
