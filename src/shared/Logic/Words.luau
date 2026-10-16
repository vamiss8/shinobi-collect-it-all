--!strict
-- The game's words in a language, as plain functions of the packs of words (client/Lang), so
-- that they can be tested: client Strings holds the packs and the language in use and asks
-- these. A pack has the interface's words by key and the names of the config by their English
-- name; whatever a pack lacks is said in English.
--
-- Two things here go beyond filling a template. A name, or a shinobi's title, that the server
-- wrote in English (in a message, on a tag) is said in the language (`localize`). And the words
-- the server writes in the world (signs, tags, prompts, notices) are recognised in their
-- English and said in the language (`world`): by the keys whose words are written in the
-- world, which every pack has (those named World_*, and a few the interface shares), and by the
-- names, whatever their case.

local Catalog = require("../Config/Catalog")
local Format = require("./Format")

local Words = {}

export type Pack = {
	text: { [string]: string },
	names: { [string]: string },
}

-- What a language says the world's English as: each English phrase by its key, the patterns
-- the English templates with blanks make, and the English names by their lower case.
type World = {
	exact: { [string]: string },
	loud: { [string]: string },
	patterns: { { pattern: string, key: string, fixed: number } },
	names: { [string]: string },
}

export type Book = {
	english: Pack,
	pack: Pack?,
	world: World?,
}

-- Keys of the interface's words that are written in the world too, besides the World_* ones.
local SHARED_WITH_WORLD =
	{ "ShopTentenTitle", "SellTitle", "ShopSpeedTitle", "ShopMax", "HerbTitle" }

function Words.book(english: Pack, pack: Pack?): Book
	return { english = english, pack = pack }
end

local function template(book: Book, key: string): string?
	local pack = book.pack
	return (if pack then pack.text[key] else nil) or book.english.text[key]
end

-- A name of the config in the language, by its English name.
function Words.name(book: Book, english: string): string
	local pack = book.pack
	return (if pack then pack.names[english] else nil) or english
end

-- Words the server put together in English: a name, or a shinobi's title as Catalog.unitTitle
-- writes it ("Kakashi [Ice] ★★ Lvl 3"). Anything else is left as it is.
function Words.localize(book: Book, text: string): string
	local pack = book.pack
	if not pack then
		return text
	end
	local whole = pack.names[text]
	if whole then
		return whole
	end
	local name, mutation, tail = string.match(text, "^(.-) %[(.-)%](.*)$")
	if not name then
		name, tail = string.match(text, "^(.-)( ★.*)$")
	end
	if not name then
		name, tail = string.match(text, "^(.-)( Lvl %d+)$")
	end
	if not name or not pack.names[name] then
		return text
	end
	local level = template(book, "CardLevel") or "Lvl %s"
	local rest = string.gsub(tail or "", " Lvl (%d+)", function(number)
		return " " .. string.format(level, number)
	end)
	return Words.name(book, name)
		.. (if mutation then ` [{Words.name(book, mutation)}]` else "")
		.. rest
end

-- Fills the template named `key`; numbers are shortened and names said in the language. An
-- unknown key is shown as-is, so a typo is easy to spot.
function Words.get(book: Book, key: string, ...: any): string
	local text = template(book, key)
	if not text then
		return key
	end
	local args = table.pack(...)
	for i = 1, args.n do
		local arg = args[i]
		if typeof(arg) == "number" then
			args[i] = Format.short(arg)
		elseif typeof(arg) == "string" then
			args[i] = Words.localize(book, arg)
		end
	end
	return string.format(text, table.unpack(args, 1, args.n))
end

-- One line naming a shinobi, as Catalog.unitTitle does, in the language.
function Words.title(
	book: Book,
	characterId: string,
	mutationId: string,
	level: number,
	upgrades: number?
): string
	local character = Catalog.characterById[characterId]
	local text = if character then Words.name(book, character.name) else characterId
	local mutation = Catalog.mutationById[mutationId]
	if mutation then
		text ..= ` [{Words.name(book, mutation.name)}]`
	end
	if level > 1 then
		text ..= ` {Catalog.stars(level)}`
	end
	if upgrades and upgrades > 0 then
		text ..= " " .. Words.get(book, "CardLevel", upgrades + 1)
	end
	return text
end

-- A stretch of time as "2d 5h", "3h 20m", "45s", in the language (Format.duration's rule).
function Words.duration(book: Book, seconds: number): string
	local whole = math.max(math.floor(seconds), 0)
	local days, hours, minutes = whole // 86400, whole % 86400 // 3600, whole % 3600 // 60
	local function part(key: string, count: number): string
		return string.format(template(book, key) or "%s", tostring(count))
	end
	if days > 0 then
		return if hours > 0
			then part("TimeDays", days) .. " " .. part("TimeHours", hours)
			else part("TimeDays", days)
	elseif hours > 0 then
		return if minutes > 0
			then part("TimeHours", hours) .. " " .. part("TimeMinutes", minutes)
			else part("TimeHours", hours)
	elseif minutes > 0 then
		return part("TimeMinutes", minutes)
	end
	return part("TimeSeconds", whole)
end

-- An English template as a Lua pattern that matches what it fills, its blanks captured.
local function patternOf(english: string): string
	local escaped = string.gsub(english, "[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
	-- "%s" was left as it was ("%" is not escaped above) and "%%" stands for one percent sign:
	-- that is put by first, so that its "s" is not taken for a blank.
	escaped = string.gsub(escaped, "%%%%", "\1")
	escaped = string.gsub(escaped, "%%s", "(.-)")
	escaped = string.gsub(escaped, "\1", "%%%%")
	return "^" .. escaped .. "$"
end

-- How the world's English is recognised in this book: built when first asked.
local function worldOf(book: Book): World
	local found = book.world
	if found then
		return found
	end
	local world: World = { exact = {}, loud = {}, patterns = {}, names = {} }
	local function learn(key: string)
		local english = book.english.text[key]
		if not english then
			return
		end
		if string.find(english, "%%s") then
			local fixed = #string.gsub(english, "%%s", "")
			table.insert(world.patterns, { pattern = patternOf(english), key = key, fixed = fixed })
		else
			world.exact[english] = key
			world.loud[Format.upper(english)] = key
		end
	end
	for key in book.english.text do
		if string.sub(key, 1, 6) == "World_" then
			learn(key)
		end
	end
	for _, key in SHARED_WITH_WORLD do
		learn(key)
	end
	-- The more a template says of itself, the sooner it is tried: "%s Ryo" before "%s".
	table.sort(world.patterns, function(a, b)
		if a.fixed ~= b.fixed then
			return a.fixed > b.fixed
		end
		return a.key < b.key
	end)
	local pack = book.pack
	if pack then
		for english in pack.names do
			world.names[string.lower(english)] = english
		end
	end
	book.world = world
	return world
end

-- One piece of the world's English, between tags, in the language.
local function piece(book: Book, world: World, text: string): string
	local lead, core, trail = string.match(text, "^(%s*)(.-)(%s*)$")
	if not core or core == "" then
		return text
	end
	local function done(said: string): string
		return (lead or "") .. said .. (trail or "")
	end
	local key = world.exact[core]
	if key then
		return done(Words.get(book, key))
	end
	key = world.loud[core]
	if key then
		return done(Format.upper(Words.get(book, key)))
	end
	local named = world.names[string.lower(core)]
	if named then
		local said = Words.name(book, named)
		return done(
			if core == Format.upper(core) and core ~= string.lower(core)
				then Format.upper(said)
				else said
		)
	end
	local title = Words.localize(book, core)
	if title ~= core then
		return done(title)
	end
	for _, rule in world.patterns do
		local captures = table.pack(string.match(core, rule.pattern))
		if captures[1] ~= nil then
			return done(Words.get(book, rule.key, table.unpack(captures, 1, captures.n)))
		end
	end
	return text
end

-- Words the server wrote in the world in English, said in the language: line by line, and
-- between rich text's tags, which are kept.
function Words.world(book: Book, text: string): string
	if not book.pack then
		return text
	end
	local world = worldOf(book)
	local lines = {}
	for line in string.gmatch(text .. "\n", "(.-)\n") do
		local out = {}
		local at = 1
		while true do
			local from, to = string.find(line, "<[^>]*>", at)
			if not from or not to then
				table.insert(out, piece(book, world, string.sub(line, at)))
				break
			end
			table.insert(out, piece(book, world, string.sub(line, at, from - 1)))
			table.insert(out, string.sub(line, from, to))
			at = to + 1
		end
		table.insert(lines, table.concat(out))
	end
	return table.concat(lines, "\n")
end

return Words
