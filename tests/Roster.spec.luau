--!strict
local Catalog = require("../src/shared/Config/Catalog")
local Economy = require("../src/shared/Logic/Economy")
local Index = require("../src/shared/Logic/Index")
local Roster = require("../src/shared/Logic/Roster")
local T = require("./harness")

return {
	["every replacement is on the roster and nobody replaced is"] = function()
		local count = 0
		for old, new in Catalog.replaced do
			count += 1
			T.ok(Catalog.characterById[old] == nil, `{old} was replaced but is still a character`)
			T.ok(Catalog.characterById[new] ~= nil, `{old} was replaced by {new}, who is not one`)
			T.eq(Roster.current(old), new)
		end
		T.ok(count > 0, "nothing to test with")
		T.eq(Roster.current("iruka"), "iruka", "a character still on the roster keeps its id")
		T.eq(Roster.current("no_such_one"), "no_such_one", "an unknown id is left alone")
	end,

	["a replaced character's units become its replacement"] = function()
		local units: { [string]: Economy.Unit } = {
			u1 = { character = "mizuki", mutation = "ice", level = 2, upgrade = 3 },
			u2 = { character = "iruka", mutation = Catalog.NONE, level = 1 },
			u3 = { character = "obito", mutation = Catalog.NONE, level = 1 },
		}
		T.eq(Roster.migrate(units, {}), 2)
		T.eq(units.u1.character, "ebisu")
		T.eq(units.u1.mutation, "ice", "only the character changes")
		T.eq(units.u1.level, 2)
		T.eq(units.u1.upgrade, 3)
		T.eq(units.u2.character, "iruka")
		T.eq(units.u3.character, "shisui")
		T.ok(Economy.unitIncome(units.u1) > 0, "the unit earns again")
	end,

	["what was found for a replaced character counts for the new one"] = function()
		local found: Index.Found = {
			zabuza = { [Catalog.NONE] = true, ice = true },
			tazuna = { lava = true },
			haku = { [Catalog.NONE] = true },
		}
		T.eq(Roster.migrate({}, found), 1)
		T.eq(found.zabuza, nil, "the old entry is gone")
		T.eq(Index.has(found, "tazuna", Catalog.NONE), true)
		T.eq(Index.has(found, "tazuna", "ice"), true)
		T.eq(Index.has(found, "tazuna", "lava"), true, "what the new one already had stays")
		T.eq(Index.has(found, "haku", Catalog.NONE), true)
		T.eq(Index.has(found, "haku", "ice"), false)
	end,

	["a save already in step is left alone"] = function()
		local units: { [string]: Economy.Unit } = {
			u1 = { character = "pain", mutation = Catalog.NONE, level = 1 },
		}
		local found: Index.Found = { pain = { [Catalog.NONE] = true } }
		T.eq(Roster.migrate(units, found), 2)
		T.eq(Roster.migrate(units, found), 0, "the second pass finds nothing to do")
		T.eq(units.u1.character, "hinata_shippuden")
		T.eq(Index.has(found, "hinata_shippuden", Catalog.NONE), true)
	end,
}
