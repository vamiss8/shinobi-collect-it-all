--!strict
-- Every piece of UI text, in English (client/Lang/en), and the way to it in the player's
-- language: client/Lang has a pack a language (Config/Languages), the same keys with the words
-- of that language, and the names of the config (zones, shinobi, mutations, ranks, kunai,
-- stages...) by their English name. A key or a name a pack lacks is shown in English.
-- Templates use %s only, in the same
-- order in every language; numbers are shortened (1250 -> "1.25K") before they are put in, and
-- a name put in is shown in the language too, the names the server sends with a message among
-- them.
--
-- The language is chosen once, before anything is written (client Language): a new one takes
-- when the player comes back into the game. What the words do is Logic/Words, which the tests
-- can reach; this holds the packs and the language in use.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Words = require(ReplicatedStorage.Shared.Logic.Words)

local Strings = {}

export type Pack = Words.Pack

local PACKS: { [string]: Pack } = {
	ru = require("./Lang/ru"),
	es = require("./Lang/es"),
	pt = require("./Lang/pt"),
	fr = require("./Lang/fr"),
	de = require("./Lang/de"),
}

local ENGLISH: Pack = require("./Lang/en")

-- The words in use: English with the pack of the language chosen.
local book: Words.Book = Words.book(ENGLISH)
local code = "en"

-- Writes in that language from now on (a code of Config/Languages; English for any other).
function Strings.use(language: string)
	local pack = PACKS[language]
	book = Words.book(ENGLISH, pack)
	code = if pack then language else "en"
end

-- The language written in.
function Strings.language(): string
	return code
end

-- A name of the config (a zone, a shinobi, a mutation, a rank...) in the language, by its
-- English name.
function Strings.name(english: string): string
	return Words.name(book, english)
end

-- Words the server put together in English and sent: a name, or a shinobi's title.
function Strings.localize(text: string): string
	return Words.localize(book, text)
end

-- Fills the template named `key`. An unknown key is shown as-is, so a typo is easy to spot.
function Strings.get(key: string, ...: any): string
	return Words.get(book, key, ...)
end

-- One line naming a shinobi, as Catalog.unitTitle does, in the language: "Kakashi [Ice] **
-- Lvl 3".
function Strings.title(
	characterId: string,
	mutationId: string,
	level: number,
	upgrades: number?
): string
	return Words.title(book, characterId, mutationId, level, upgrades)
end

-- Words in capitals, for any letter of the languages here (Format.upper).
Strings.upper = Format.upper

-- A stretch of time as "2d 5h", "3h 20m", "45s", in the language.
function Strings.duration(seconds: number): string
	return Words.duration(book, seconds)
end

-- Words the server wrote in the world in English (signs, tags, prompts, notices), said in the
-- language (client WorldWords).
function Strings.world(text: string): string
	return Words.world(book, text)
end

return Strings
