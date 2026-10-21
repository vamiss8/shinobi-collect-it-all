--!strict
-- Promo codes (Logic/Codes, server/Codes): what a player types finds its code, a code works
-- once and not past its last day, and every code on the server is written as typed codes are
-- looked up and gives potions that exist.
local Catalog = require("../src/shared/Config/Catalog")
local Codes = require("../src/shared/Logic/Codes")
local T = require("./harness")

local LIST: { [string]: Codes.Code } = {
	HIDDENLEAF = { herbs = 200 },
	AUTUMN = { herbs = 50, ends = "2026-10-31" },
}

return {
	["what is typed is looked up in capitals, without spaces or stray marks"] = function()
		T.eq(Codes.normalize("hidden leaf"), "HIDDENLEAF")
		T.eq(Codes.normalize("  HiddenLeaf! "), "HIDDENLEAF")
		T.eq(Codes.normalize(""), "")
		T.eq(#Codes.normalize(string.rep("A", 100)), Codes.LONGEST)
	end,

	["a code works once a player"] = function()
		local used: { [string]: boolean } = {}
		local outcome, name, code = Codes.check(LIST, used, "hiddenleaf", 0)
		T.eq(outcome, "ok")
		T.eq(name, "HIDDENLEAF")
		T.ok(code ~= nil, "the code is given back")
		used[name] = true
		T.eq((Codes.check(LIST, used, "HIDDENLEAF", 0)), "used")
		T.eq((Codes.check(LIST, used, "NOSUCHCODE", 0)), "unknown")
		T.eq((Codes.check(LIST, used, "   ", 0)), "empty")
	end,

	["a code works through the whole of its last day, UTC, and not after"] = function()
		-- 2026-10-31 00:00:00 UTC.
		local lastDay = 1793404800
		T.eq(Codes.endsAt({ ends = "1970-01-01" }), 86400)
		T.eq(Codes.endsAt(LIST.AUTUMN), lastDay + 86400)
		T.eq((Codes.check(LIST, {}, "autumn", lastDay + 86399)), "ok")
		T.eq((Codes.check(LIST, {}, "autumn", lastDay + 86400)), "ended")
		T.eq(Codes.endsAt({ ends = "soon" }), nil)
		T.eq(Codes.endsAt({}), nil)
	end,

	["a code for so many players gives out as many uses and no more"] = function()
		local giveaway: Codes.Code = { herbs = 100, uses = 3 }
		T.eq(Codes.take(nil, giveaway), 1)
		T.eq(Codes.take(2, giveaway), 3)
		T.eq(Codes.take(3, giveaway), nil)
		T.eq(Codes.take(7, giveaway), nil)
		-- A code with no limit is never used up.
		T.eq(Codes.take(1e6, { herbs = 1 }), 1e6 + 1)
	end,

	["every code on the server is written as typed codes are looked up"] = function()
		local fs = require("@lune/fs")
		local source = fs.readFile("src/server/Codes.luau")
		local body = string.match(source, "local Codes: [^\n]+\n(.-)\n}\n") or ""
		local found = 0
		for name, gives in string.gmatch(body, "\n\t([%w_]+) = (%b{})") do
			found += 1
			T.eq(Codes.normalize(name), name, `{name} is not written as it is looked up`)
			for id in string.gmatch(gives, '"([%w_]+)"') do
				if not string.match(id, "^%d%d%d%d") then
					T.ok(Catalog.potionById[id] ~= nil, `{name} gives a potion that is not: {id}`)
				end
			end
			local uses = string.match(gives, "uses = ([^,}%s]+)")
			if uses then
				local count = tonumber(uses)
				T.ok(
					count ~= nil and count >= 1 and count % 1 == 0,
					`{name}'s uses are not a whole number`
				)
			end
			local day = string.match(gives, 'ends = "([^"]+)"')
			if day then
				T.ok(Codes.endsAt({ ends = day }) ~= nil, `{name}'s last day cannot be read`)
			end
		end
		T.ok(found > 0, "no code was read from server/Codes")
	end,
}
