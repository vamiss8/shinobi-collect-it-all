--!strict
local Catalog = require("../src/shared/Config/Catalog")
local DojoPlan = require("../src/shared/Logic/DojoPlan")
local Economy = require("../src/shared/Logic/Economy")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

local EPS = 1e-9

-- The roster's numbers are expected to change, so the cases read them from the config.
local KAKASHI = Catalog.characterById.kakashi.income
local IRUKA = Catalog.characterById.iruka.income
local ICE = Catalog.mutationMultiplier("ice")

local function unit(character: string, mutation: string, level: number): Economy.Unit
	return { character = character, mutation = mutation, level = level }
end

return {
	-- The owner's word: a shinobi grows as it is levelled up.
	["a shinobi stands taller for its levels, most of all for the first, and not past a bound"] = function()
		T.eq(Economy.growth(0), 1)
		T.eq(Economy.growth(nil), 1)
		local before, step = 1, math.huge
		for upgrades = 1, Tuning.Upgrade.maxUpgrades do
			local growth = Economy.growth(upgrades)
			T.ok(growth > before, `level {upgrades + 1} stands no taller`)
			T.ok(
				growth - before <= step + 1e-12,
				`level {upgrades + 1} grows by more than the last`
			)
			step, before = growth - before, growth
		end
		T.ok(before < Tuning.Upgrade.tallest, "the last level stands past the bound")
		T.ok(before > Tuning.Upgrade.tallest - 0.01, "the last level stands well short of it")
		-- Ten levels are plainly seen, the owner's word: an eighth of the height or more.
		T.ok(Economy.growth(10) >= 1.125, `ten levels add {Economy.growth(10) - 1}`)
		-- And there is a bound, the dojo's: a floor is 14 studs from the next and a stud
		-- thick. Under it stand the tallest shinobi, 4.8 studs grown, and over a gap of 0.4
		-- its tag of five lines, which View/Figure writes lower over a tall one, though never
		-- under 0.8 of a stud a line.
		local under = DojoPlan.STOREY - DojoPlan.SLAB - 0.5
		local line = (under - 4.8 * Tuning.Upgrade.tallest - 0.4) / 5
		T.ok(line >= 0.8, `the tallest shinobi leaves its tag lines of {line} studs`)
	end,

	["income multiplies base, mutation and merge level"] = function()
		local merge = Tuning.Dojo.mergeMultiplier
		T.ok(ICE > 1, "the ice mutation must boost income for this case to mean anything")
		T.near(Economy.unitIncome(unit("kakashi", Catalog.NONE, 1)), KAKASHI, EPS)
		T.near(Economy.unitIncome(unit("kakashi", "ice", 1)), KAKASHI * ICE, EPS)
		T.near(Economy.unitIncome(unit("kakashi", Catalog.NONE, 2)), KAKASHI * merge, EPS)
		T.near(Economy.unitIncome(unit("kakashi", Catalog.NONE, 3)), KAKASHI * merge ^ 2, EPS)
	end,

	["an unknown character earns nothing instead of erroring"] = function()
		T.eq(Economy.unitIncome(unit("removed_character", Catalog.NONE, 1)), 0)
	end,

	["only identical units merge"] = function()
		local a = unit("iruka", "lava", 1)
		T.ok(Economy.canMerge(a, unit("iruka", "lava", 1)), "same unit")
		T.ok(not Economy.canMerge(a, unit("iruka", "ice", 1)), "different mutation")
		T.ok(not Economy.canMerge(a, unit("iruka", "lava", 2)), "different level")
		T.ok(not Economy.canMerge(a, unit("konohamaru", "lava", 1)), "different character")
		T.eq(Economy.merged(a, a).level, 2)
	end,

	["a merged unit out-earns the pair it replaces"] = function()
		local a = unit("sakura", "kurama", 1)
		local pair = Economy.unitIncome(a) * 2
		local merged = Economy.unitIncome(Economy.merged(a, a))
		T.near(merged / pair, Tuning.Dojo.mergeMultiplier / 2, EPS)
		T.ok(merged > pair, "merging must be worth it")
	end,

	["upgrades reproduce the numbers seen in Kick an Uma"] = function()
		-- A level 57 unit there earned 657.5B/s with the next upgrade at 89.33Qa; one upgrade
		-- later it earned 821.88B/s with the next at 134Qa.
		local growth, cost = Tuning.Upgrade.incomeGrowth, Tuning.Upgrade.costGrowth
		T.near(657.5 * growth, 821.875, 1e-6, "income per level")
		T.near(89.33 * cost, 134, 0.01, "price per level")
	end,

	["each upgrade multiplies the income"] = function()
		local a = unit("kakashi", Catalog.NONE, 1)
		local once = Economy.upgraded(a)
		local twice = Economy.upgraded(once)
		T.near(Economy.unitIncome(once), KAKASHI * Tuning.Upgrade.incomeGrowth, EPS)
		T.near(Economy.unitIncome(twice), KAKASHI * Tuning.Upgrade.incomeGrowth ^ 2, EPS)
	end,

	["upgrade prices follow the unit's income and grow with every upgrade"] = function()
		local cheap = unit("iruka", Catalog.NONE, 1)
		local rare = unit("kakashi", Catalog.NONE, 1)
		T.near(Economy.upgradePrice(cheap) :: number, IRUKA * Tuning.Upgrade.costSeconds, EPS)
		T.near(Economy.upgradePrice(rare) :: number, KAKASHI * Tuning.Upgrade.costSeconds, EPS)

		local first = Economy.upgradePrice(rare) :: number
		local second = Economy.upgradePrice(Economy.upgraded(rare)) :: number
		T.near(second / first, Tuning.Upgrade.costGrowth, EPS)
	end,

	["several upgrades at once cost what they cost one by one"] = function()
		local a = unit("kakashi", "ice", 2)
		a.upgrade = 3
		local total, stepped = 0, a
		for _ = 1, 10 do
			total += Economy.upgradePrice(stepped) :: number
			stepped = Economy.upgraded(stepped)
		end
		local price, levels = Economy.upgradesPrice(a, 10)
		T.eq(levels, 10)
		T.near(price / total, 1, EPS)
		T.eq(Economy.upgraded(a, 10).upgrade, 13)

		local one = Economy.upgradesPrice(a, 1)
		T.near(one, Economy.upgradePrice(a) :: number, EPS, "one level is the plain price")
	end,

	["a batch of upgrades stops at the top level"] = function()
		local a = unit("iruka", Catalog.NONE, 1)
		a.upgrade = Tuning.Upgrade.maxUpgrades - 4
		local _, levels = Economy.upgradesPrice(a, 10)
		T.eq(levels, 4, "only four levels are left")
		a.upgrade = Tuning.Upgrade.maxUpgrades
		local price, none = Economy.upgradesPrice(a, 10)
		T.eq(none, 0)
		T.eq(price, 0)
		T.eq((Economy.affordableUpgrades(a, 1e30)), 0, "nothing left to buy")
	end,

	["Ryo buys as many upgrades as it covers and no more"] = function()
		local a = unit("kakashi", Catalog.NONE, 1)
		local first = Economy.upgradePrice(a) :: number
		T.eq((Economy.affordableUpgrades(a, first * 0.99)), 0, "short of the first one")
		T.eq((Economy.affordableUpgrades(a, first)), 1, "exactly the first one")

		for _, count in { 1, 2, 7, 25 } do
			local price = Economy.upgradesPrice(a, count)
			local levels, spent = Economy.affordableUpgrades(a, price)
			T.eq(levels, count, `Ryo for exactly {count}`)
			T.near(spent / price, 1, EPS)
			T.eq(
				(Economy.affordableUpgrades(a, price * 0.999)),
				count - 1,
				`a hair short of {count}`
			)
		end

		local levels = Economy.affordableUpgrades(a, 1e300)
		T.eq(levels, Tuning.Upgrade.maxUpgrades, "never past the top level")
	end,

	["a unit of an unknown character cannot be upgraded for free"] = function()
		local gone = unit("removed_character", Catalog.NONE, 1)
		T.eq((Economy.affordableUpgrades(gone, 1e9)), 0)
	end,

	["a maxed-out unit has no upgrade price"] = function()
		local maxed = unit("iruka", Catalog.NONE, 1)
		maxed.upgrade = Tuning.Upgrade.maxUpgrades
		T.eq(Economy.upgradePrice(maxed), nil)
	end,

	["merging ignores upgrades and keeps the better of the two"] = function()
		local a = unit("iruka", "lava", 1)
		local b = unit("iruka", "lava", 1)
		a.upgrade = 2
		b.upgrade = 5
		T.ok(Economy.canMerge(a, b), "upgrades do not have to match")
		T.eq(Economy.merged(a, b).upgrade, 5)
		T.eq(Economy.merged(b, a).upgrade, 5)
	end,

	["selling pays a fixed stretch of the unit's income"] = function()
		T.eq(
			Economy.sellPrice(unit("kakashi", "ice", 1)),
			math.floor(KAKASHI * ICE * Tuning.Dojo.sellSeconds)
		)
	end,

	["prices grow geometrically"] = function()
		T.eq(Economy.padPrice(0), Tuning.Dojo.padBasePrice)
		T.eq(
			Economy.padPrice(1),
			math.floor(Tuning.Dojo.padBasePrice * Tuning.Dojo.padPriceGrowth + 0.5)
		)
		T.ok(Economy.speedPrice(5) > Economy.speedPrice(4), "speed gets pricier")
	end,

	["a player runs as fast as they bought, or as slow as they chose"] = function()
		T.eq(Economy.runLevel(12), 12, "nothing chosen")
		T.eq(Economy.runLevel(12, -1), 12, "the fastest bought")
		T.eq(Economy.runLevel(12, 5), 5, "a level of their own")
		T.eq(Economy.runLevel(12, 0), 0, "a walk")
		T.eq(Economy.runLevel(12, 30), 12, "no faster than bought")
		T.eq(Economy.runLevel(12, 5.9), 5, "whole levels")
		T.eq(Economy.runLevel(0, -1), 0)
	end,

	["walk speed is capped at the max level"] = function()
		T.eq(Economy.walkSpeed(0), Tuning.Speed.base)
		local max = Economy.walkSpeed(Tuning.Speed.maxLevel)
		T.eq(Economy.walkSpeed(Tuning.Speed.maxLevel + 50), max)
	end,

	["pad pass adds its pads on top"] = function()
		T.eq(Economy.maxPads(true) - Economy.maxPads(false), Tuning.Dojo.gamePassPads)
	end,

	["offline earnings are a share of the income and stop at the cap"] = function()
		local rate = Tuning.Dojo.offlineRate
		T.ok(rate > 0 and rate <= 1, "away from the game a dojo earns less, not more")
		T.near(Economy.offlineEarnings(10, 100), 1000 * rate, EPS)
		T.near(
			Economy.offlineEarnings(10, 1e9),
			10 * rate * Tuning.Dojo.offlineCapHours * 3600,
			EPS
		)
		T.eq(Economy.offlineEarnings(10, -50), 0, "clock skew")
	end,

	["base income leaves the bought levels out and keeps everything else"] = function()
		local a = unit("kakashi", "ice", 2)
		local fresh = Economy.unitIncome(a)
		a.upgrade = 12
		T.near(Economy.baseIncome(a), fresh, EPS, "what it earned at level 1")
		T.near(Economy.baseIncome(a), KAKASHI * ICE * Tuning.Dojo.mergeMultiplier, EPS)
		T.ok(Economy.unitIncome(a) > Economy.baseIncome(a), "levels add on top")
	end,

	["the kunai index is clamped to a real kunai"] = function()
		T.eq(Economy.chakraPerRep(1), Catalog.kunai[1].chakraPerRep)
		T.eq(Economy.chakraPerRep(999), Catalog.kunai[#Catalog.kunai].chakraPerRep)
	end,
}
