--!strict
-- What changed in the game, newest first, as the notice board's window tells it (client
-- InfoPanel, the tab "What's new"; owner, 2026-10-18: "a FAQ and a changelog on the notice
-- board and in the settings"). An entry is its date and its words, Change_<key> in the
-- language packs. A new entry goes at the top, with its words in all six packs.

export type Entry = { date: string, key: string }

local Changelog: { Entry } = {
	{ date = "2026-10-22", key = "Community" },
	{ date = "2026-10-21", key = "Loading" },
	{ date = "2026-10-20", key = "Codes" },
	{ date = "2026-10-20", key = "Phone" },
	{ date = "2026-10-19", key = "InventoryMerge" },
	{ date = "2026-10-19", key = "Guide" },
	{ date = "2026-10-18", key = "Plaza" },
	{ date = "2026-10-18", key = "Sound" },
	{ date = "2026-10-17", key = "Herbs" },
	{ date = "2026-10-16", key = "Shop" },
	{ date = "2026-10-13", key = "Ranks" },
	{ date = "2026-10-09", key = "Events" },
}

return Changelog
