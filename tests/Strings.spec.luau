--!strict
-- The interface's words (src/client/Strings) against what asks for them. A key that is not
-- there is shown as the key itself, which nothing else would catch outside Studio.
local fs = require("@lune/fs")

local SpeedStages = require("../src/shared/Config/SpeedStages")
local T = require("./harness")

local source = fs.readFile("src/client/Strings.luau")

-- Whether Strings has a line that sets `key`.
local function has(key: string): boolean
	return string.find(source, "\n\t" .. key .. " = ", 1, true) ~= nil
end

-- What `key` is set to, when that is one string written on the key's own line.
local function value(key: string): string?
	return string.match(source, "\n\t" .. key .. ' = "([^"\n]*)",')
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
		T.eq(count, 3, "a shop without a pitch")
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
