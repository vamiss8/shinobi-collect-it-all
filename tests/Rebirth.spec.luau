--!strict
-- Rebirths (Config/Rebirths, Logic/Rebirth): what each asks, what it pays, and how they come
-- into a player's multipliers.
local Boosts = require("../src/shared/Logic/Boosts")
local Catalog = require("../src/shared/Config/Catalog")
local Kick = require("../src/shared/Logic/Kick")
local Rebirth = require("../src/shared/Logic/Rebirth")
local Rebirths = require("../src/shared/Config/Rebirths")
local SpeedStages = require("../src/shared/Config/SpeedStages")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

local EPS = 1e-9

return {
	["a player who has done none is paid nothing and is an Academy Student"] = function()
		T.eq(Rebirth.ryo(0), 1)
		T.eq(Rebirth.chakra(0), 1)
		T.eq(Rebirth.mutationLuck(0), 1)
		T.eq(Rebirth.title(0), Rebirth.FIRST_TITLE)
		T.eq(Rebirth.title(nil), Rebirth.FIRST_TITLE)
	end,

	-- Tenfold to the sixth; the owner's shorter steps after it (500M, 1.5B, 4B, 10B).
	["each asks ten times the Chakra of the one before to the sixth, and more after it"] = function()
		T.eq(Rebirths[1].chakra, 1000)
		for index = 2, #Rebirths do
			local step = Rebirths[index].chakra / Rebirths[index - 1].chakra
			if index <= 6 then
				T.near(step, 10, EPS)
			else
				T.ok(
					step > 1 and step <= 10,
					`{Rebirths[index].title} asks {step} times the one before`
				)
			end
		end
		-- More than up to a billion: the owner's word, with room to add to.
		T.ok(#Rebirths >= 10, `only {#Rebirths} rebirths`)
		T.ok(Rebirths[#Rebirths].chakra >= 1e10, "the last asks less than ten billion")
	end,

	-- The owner: a tester with 450M Chakra reached the last zone only with a Sage throw. The last
	-- zone is reached before a rebirth that asks more Chakra than it: with what that rebirth
	-- asks, every Perfect lands in it.
	["the last zone is reached with any Perfect before a rebirth asks more than it"] = function()
		local last = Catalog.zones[#Catalog.zones]
		local perfect = Kick.share(Tuning.Kick.grades[1].from)
		local first: Rebirths.Rebirth? = nil
		for _, row in Rebirths do
			if row.chakra > last.chakra then
				first = row
				break
			end
		end
		assert(first, "no rebirth asks more Chakra than the last zone")
		T.ok(
			first.chakra * perfect >= last.chakra,
			`{first.title} comes before a Perfect reaches the last zone`
		)
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

	-- The owner's rule: a rebirth starts the player over, but for what they built to last.
	-- The owner's word: at certain ranks a certain run speed is bought already.
	["a rank starts with run speed that is a stage's, and no rank with less than the one before"] = function()
		T.eq(Rebirth.startSpeed(0), 0)
		T.eq(Rebirth.startSpeed(nil), 0)
		-- The first rebirth comes minutes into the game: there is nothing to skip yet.
		T.eq(Rebirth.startSpeed(1), 0)
		local stageLevels: { [number]: boolean } = {}
		for _, stage in SpeedStages.list do
			stageLevels[stage.level] = true
		end
		local given = false
		for count = 1, Rebirth.count() do
			local level = Rebirth.startSpeed(count)
			T.ok(
				stageLevels[level] == true,
				`{Rebirth.title(count)} starts at level {level}, which no stage is`
			)
			T.ok(level >= Rebirth.startSpeed(count - 1), `{Rebirth.title(count)} starts slower`)
			T.ok(level < Tuning.Speed.maxLevel, `{Rebirth.title(count)} starts with all of it`)
			given = given or level > 0
		end
		T.ok(given, "no rank starts with any run speed")
	end,

	["a rebirth takes Chakra, shinobi, Ryo and run speed, and nothing else"] = function()
		local save = {
			rebirths = 2,
			chakra = 3e5,
			ryo = 7e6,
			speedLevel = 14,
			runAt = 9,
			units = { u1 = { character = "kakashi" }, u2 = { character = "iruka" } },
			pads = { ["1"] = "u1" },
			kunai = 8,
			padsBought = 12,
			found = { kakashi = true },
			spins = 400,
		}
		Rebirth.apply(save)
		T.eq(save.rebirths, 3)
		T.eq(save.chakra, Rebirth.START_CHAKRA)
		T.eq(save.ryo, 0)
		T.eq(
			save.speedLevel,
			Rebirth.startSpeed(3),
			"the run speed is not what the rank starts with"
		)
		T.ok(save.speedLevel < 14, "the run speed was kept")
		T.eq(save.runAt, -1, "the speed chosen to run at was of levels now gone")
		T.eq(next(save.units), nil, "a shinobi was kept")
		T.eq(next(save.pads), nil, "a pad is still taken")
		T.eq(save.kunai, 8, "the kunai went")
		T.eq(save.padsBought, 12, "the floors bought went")
		T.eq(save.found.kakashi, true, "the Bingo Book went")
		T.eq(save.spins, 400)
	end,

	-- The owner's word on the shinobi bought for Robux: they stay, and so do their levels.
	["the legendary shinobi stay through a rebirth, on their pads and at their levels"] = function()
		local first, last = Catalog.legends[1], Catalog.legends[#Catalog.legends]
		local save = {
			rebirths = 0,
			chakra = 1e3,
			ryo = 50,
			speedLevel = 3,
			runAt = -1,
			units = {
				u1 = { character = "kakashi", mutation = "none", level = 1 },
				u2 = { character = last.id, mutation = "none", level = 1, upgrade = 7 },
				u3 = { character = first.id, mutation = "none", level = 1 },
				u4 = { character = "iruka", mutation = "ice", level = 2 },
			},
			pads = { ["1"] = "u1", ["4"] = "u2" },
		}
		Rebirth.apply(save)
		T.eq(save.units.u1, nil, "a thrown-for shinobi on a pad was kept")
		T.eq(save.units.u4, nil, "a thrown-for shinobi in the inventory was kept")
		T.eq(save.units.u2.upgrade, 7, "a legendary shinobi lost its levels")
		T.eq(save.pads["4"], "u2", "a legendary shinobi was taken off its pad")
		T.eq(save.pads["1"], nil, "a pad is taken by a shinobi that is gone")
		T.ok(save.units.u3 ~= nil, "a legendary shinobi in the inventory went")
		T.eq(save.ryo, 0)
	end,

	["every rank has a color of its own"] = function()
		local seen = { [string.upper(Rebirth.FIRST_COLOR)] = true }
		for count = 1, Rebirth.count() do
			local color = Rebirth.color(count)
			T.ok(string.match(color, "^#%x%x%x%x%x%x$") ~= nil, `{color} is not a color`)
			T.ok(not seen[string.upper(color)], `{Rebirth.title(count)} shares its color`)
			seen[string.upper(color)] = true
		end
		T.eq(Rebirth.color(0), Rebirth.FIRST_COLOR)
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
