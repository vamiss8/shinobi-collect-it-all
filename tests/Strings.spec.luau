--!strict
-- The interface's words (src/client/Lang/en and the other languages beside it) against what
-- asks for them. A key that is not there is shown as the key itself, which nothing else would
-- catch outside Studio.
local fs = require("@lune/fs")

local Catalog = require("../src/shared/Config/Catalog")
local Events = require("../src/shared/Config/Events")
local Languages = require("../src/shared/Config/Languages")
local Rebirth = require("../src/shared/Logic/Rebirth")
local Rebirths = require("../src/shared/Config/Rebirths")
local SpeedStages = require("../src/shared/Config/SpeedStages")
local T = require("./harness")

type Pack = { text: { [string]: string }, names: { [string]: string } }

local English: Pack = require("../src/client/Lang/en")
local PACKS: { [string]: Pack } = {
	ru = require("../src/client/Lang/ru"),
	es = require("../src/client/Lang/es"),
	pt = require("../src/client/Lang/pt"),
	fr = require("../src/client/Lang/fr"),
	de = require("../src/client/Lang/de"),
}

-- Whether there are English words for `key`.
local function has(key: string): boolean
	return English.text[key] ~= nil
end

-- The English words of `key`.
local function value(key: string): string?
	return English.text[key]
end

-- The blanks of a template in order ("s" for %s, "%" for %%): what string.format fills.
local function blanks(template: string): string
	local found = {}
	for mark in string.gmatch(template, "%%(.)") do
		table.insert(found, mark)
	end
	return table.concat(found)
end

-- Every name the game shows from its config, and the training tools' names and tips, which the
-- server gives in English: what a pack's `names` may translate.
local function shownNames(): { [string]: boolean }
	local names: { [string]: boolean } = {}
	local function add(name: string)
		names[name] = true
	end
	for _, zone in Catalog.zones do
		add(zone.name)
		add(zone.enemy.name)
		-- A wanted poster names the enemy without what is in brackets (World/Notices).
		add((string.gsub(zone.enemy.name, "%s*%(.*%)", "")))
	end
	for _, character in Catalog.characters do
		add(character.name)
	end
	for _, legend in Catalog.legends do
		add(legend.name)
	end
	for _, mutation in Catalog.mutations do
		add(mutation.name)
	end
	for _, rank in Catalog.ranks do
		add(rank.name)
	end
	add(Catalog.legendRank.name)
	for _, kunai in Catalog.kunai do
		add(kunai.name)
	end
	for _, stage in SpeedStages.list do
		add(stage.name)
	end
	add(Rebirth.FIRST_TITLE)
	for _, rebirth in Rebirths do
		add(rebirth.title)
	end
	for _, event in Events.list do
		add(event.name)
	end
	for _, keeper in Catalog.keepers do
		add(keeper.name)
	end
	for _, potion in Catalog.potions do
		add(potion.name)
	end
	for _, words in
		{
			"Meditate",
			"Chakra Control",
			"Stand still to gather Chakra",
			"Stand still and press as the rings meet",
		}
	do
		add(words)
	end
	return names
end

-- Every key a client module asks Strings for by name: Strings.get("Key", ...).
local function asked(path: string, into: { [string]: string })
	for _, name in fs.readDir(path) do
		local full = path .. "/" .. name
		if fs.isDir(full) then
			asked(full, into)
		elseif string.match(name, "%.luau$") then
			-- A key written out whole: one put together from pieces ("Grade" .. id) is not.
			for key in string.gmatch(fs.readFile(full), 'Strings%.get%(%s*"([%w_]+)"%s*[,%)]') do
				into[key] = full
			end
		end
	end
end

return {
	["every word a client module asks for by name is there"] = function()
		local keys: { [string]: string } = {}
		asked("src/client", keys)
		local count = 0
		for key, where in keys do
			count += 1
			T.ok(has(key), `{where} asks for "{key}", which Strings does not have`)
		end
		T.ok(count > 60, `only {count} keys were found: the search is broken`)
	end,

	["everything a speed stage can show has its words"] = function()
		for index, stage in SpeedStages.list do
			for _, wear in stage.wears do
				T.ok(has("Wear_" .. wear), `no words for {wear}, which {stage.name} shows`)
			end
			T.ok(index == 1 or #SpeedStages.adds(index) > 0, `{stage.name} has nothing to name`)
		end
	end,

	["every keeper has what to say, and what the shop is for"] = function()
		local shops = fs.readFile("src/client/Shops.luau")
		local count = 0
		for key in string.gmatch(shops, '"(Pitch%w+)"') do
			count += 1
			T.ok(has(key), `no words for {key}`)
		end
		T.eq(count, 4, "a shop without a pitch")
		for key in string.gmatch(shops, '"(%w+Hello%d)"') do
			T.ok(has(key), `no words for {key}`)
		end
	end,

	-- A keeper's words hang over the counter on a scroll (client Speech), each of the two in two
	-- lines: longer ones are drawn too small to read from where they are first seen.
	["what a keeper says fits its scroll"] = function()
		local shops = fs.readFile("src/client/Shops.luau")
		for key in string.gmatch(shops, '"(Pitch%w+)"') do
			local words = value(key)
			T.ok(words ~= nil and #words <= 38, `{key} is too long for the scroll's large line`)
		end
		for key in string.gmatch(shops, '"(%w+Hello%d)"') do
			local words = value(key)
			T.ok(words ~= nil and #words <= 62, `{key} is too long for the scroll's small line`)
		end
	end,

	-- The shop names everything it sells by key (client ShopPanel: "Goods_" .. key).
	["everything sold for Robux has a name and says what it does"] = function()
		for _, pass in Catalog.passes do
			if pass.kind ~= "legend" then
				T.ok(has("Goods_" .. pass.key), `no name for {pass.key}`)
				T.ok(has("GoodsWhat_" .. pass.key), `nothing says what {pass.key} does`)
			end
		end
		for _, product in Catalog.products do
			T.ok(has("Goods_" .. product.key), `no name for {product.key}`)
			T.ok(has("GoodsWhat_" .. product.key), `nothing says what {product.key} does`)
		end
	end,

	-- The owner's word: every language looks right, none half in English.
	["every language says every word, with the same blanks in the same order"] = function()
		for code, pack in PACKS do
			for key, english in English.text do
				local words = pack.text[key]
				T.ok(words ~= nil, `{code} has no words for {key}`)
				if words then
					T.eq(
						blanks(words),
						blanks(english),
						`{code} {key} does not fill as the English does`
					)
					local _, tags = string.gsub(english, "<font", "")
					local _, theirs = string.gsub(words, "<font", "")
					T.eq(theirs, tags, `{code} {key} lost its colors`)
				end
			end
			for key in pack.text do
				T.ok(has(key), `{code} has words for {key}, which nothing asks for`)
			end
		end
	end,

	["a pack names only what the game shows, and Russian names all of it"] = function()
		local shown = shownNames()
		for code, pack in PACKS do
			for name, translated in pack.names do
				T.ok(shown[name], `{code} translates "{name}", which the game does not show`)
				T.ok(translated ~= "", `{code} translates "{name}" to nothing`)
			end
		end
		-- Russian is not written in the Latin letters every other language shares.
		for name in shown do
			T.ok(PACKS.ru.names[name] ~= nil, `ru does not name "{name}"`)
		end
		T.ok(#Languages.list == 6, "a language was added: give it a pack here")
	end,

	["what the server tells a player by name is there"] = function()
		local count = 0
		for _, name in fs.readDir("src/server/Services") do
			local text = fs.readFile("src/server/Services/" .. name)
			for key in string.gmatch(text, 'State%.notify%([%w_]+,%s*"([%w_]+)"') do
				count += 1
				T.ok(has(key), `Services/{name} notifies "{key}", which Strings does not have`)
			end
		end
		T.ok(count > 3, `only {count} notifications were found: the search is broken`)
	end,
}
