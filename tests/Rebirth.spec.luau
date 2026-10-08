--!strict
-- Rebirths (Config/Rebirths, Logic/Rebirth): what each asks, what it pays, and how they come
-- into a player's multipliers.
local Boosts = require("../src/shared/Logic/Boosts")
local Catalog = require("../src/shared/Config/Catalog")
local Rebirth = require("../src/shared/Logic/Rebirth")
local Rebirths = require("../src/shared/Config/Rebirths")
local T = require("./harness")

local EPS = 1e-9

return {
	["a player who has done none is paid nothing and is an Academy Student"] = function()
		T.eq(Rebirth.ryo(0), 1)
		T.eq(Rebirth.chakra(0), 1)
		T.eq(Rebirth.mutationLuck(0), 1)
		T.eq(Rebirth.title(0), Rebirth.FIRST_TITLE)
		T.eq(Rebirth.title(nil), Rebirth.FIRST_TITLE)
	end,

	["each asks ten times the Chakra of the one before, from a thousand"] = function()
		T.eq(Rebirths[1].chakra, 1000)
		for index = 2, #Rebirths do
			T.near(Rebirths[index].chakra / Rebirths[index - 1].chakra, 10, EPS)
		end
		-- More than up to a billion: the owner's word, with room to add to.
		T.ok(#Rebirths >= 10, `only {#Rebirths} rebirths`)
	end,

	["every rebirth pays more than the last, in all three"] = function()
		for count = 1, Rebirth.count() do
			local row = Rebirths[count]
			T.ok(Rebirth.ryo(count) > Rebirth.ryo(count - 1), `{row.title} pays no more Ryo`)
			T.ok(Rebirth.chakra(count) > Rebirth.chakra(count - 1), `{row.title}: no more Chakra`)
			T.ok(
				Rebirth.mutationLuck(count) > Rebirth.mutationLuck(count - 1),
				`{row.title}: no better luck`
			)
			T.ok(#row.title > 0, "a rebirth without a title")
		end
	end,

	-- The owner's rule for Ryo, and his word on Chakra: less than half again a rebirth, while
	-- there are kunai still to buy.
	["Ryo goes x2, x3, x4, and the early rebirths pay Chakra sparingly"] = function()
		for count = 1, Rebirth.count() do
			T.eq(Rebirth.ryo(count), count + 1)
		end
		for count = 1, 6 do
			local gain = Rebirth.chakra(count) / Rebirth.chakra(count - 1)
			T.ok(gain < 1.5, `rebirth {count} multiplies Chakra by {gain}`)
		end
	end,

	["a rebirth is offered when the Chakra it asks is there, and not past the last"] = function()
		T.ok(not Rebirth.ready(999, 0), "offered too soon")
		T.ok(Rebirth.ready(1000, 0), "not offered at its Chakra")
		T.ok(not Rebirth.ready(1000, 1), "the second offered at the first's Chakra")
		T.ok(Rebirth.ready(1e4, 1), "the second not offered")
		T.ok(not Rebirth.ready(math.huge, Rebirth.count()), "offered past the last")
		T.eq(Rebirth.next(Rebirth.count()), nil)
		T.near(Rebirth.progress(250, 0), 0.25, EPS)
		T.eq(Rebirth.progress(5e6, 0), 1)
		T.eq(Rebirth.progress(0, Rebirth.count()), 1)
	end,

	["a count that is not one is read as the nearest that is"] = function()
		T.eq(Rebirth.done(-3), 0)
		T.eq(Rebirth.done(2.9), 2)
		T.eq(Rebirth.done(1e9), Rebirth.count())
		T.eq(Rebirth.title(1e9), Rebirths[#Rebirths].title)
	end,

	-- A rebirth leaves a player able to throw: with what the first zone asks.
	["a rebirth leaves the Chakra a throw into the first zone asks"] = function()
		T.eq(Rebirth.START_CHAKRA, Catalog.zones[1].chakra)
	end,

	["rebirths come into the multipliers with everything else"] = function()
		local m = Boosts.compute({
			passes = { DoubleRyo = true },
			potions = {},
			now = 0,
			indexBonus = 0.1,
			rebirths = 3,
		})
		T.near(m.ryo, 1.1 * 2 * Rebirth.ryo(3), EPS)
		T.near(m.chakra, Rebirth.chakra(3), EPS)
		T.near(m.mutationLuck, Rebirth.mutationLuck(3), EPS)
		T.eq(m.luck, 1, "rank luck is not a rebirth's to give")
	end,
}
