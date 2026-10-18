--!strict
-- The achievements (Config/Achievements, Logic/Achievements): each counts a number there is,
-- its tiers ask for more and more and pay something, it has words in every pack's English,
-- and a tier is given when its number is reached and not before.
local Achievements = require("../src/shared/Config/Achievements")
local Catalog = require("../src/shared/Config/Catalog")
local Progress = require("../src/shared/Logic/Achievements")
local T = require("./harness")

local English = require("../src/client/Lang/en")

local function save(): Progress.Save
	return {
		spins = 0,
		rebirths = 0,
		speedLevel = 0,
		kunai = 1,
		padsBought = 0,
		found = {},
		units = {},
		counts = {},
	}
end

return {
	["every achievement counts a number there is, in tiers that ask more and pay"] = function()
		local stats = Progress.stats(save())
		local seen: { [string]: boolean } = {}
		for _, achievement in Achievements do
			local id = achievement.id
			T.ok(not seen[id], `{id} is twice`)
			seen[id] = true
			T.ok(stats[achievement.stat] ~= nil, `{id} counts {achievement.stat}, no such`)
			T.ok(#achievement.tiers >= 1, `{id} has no tier`)
			local last = 0
			for index, tier in achievement.tiers do
				T.ok(tier.goal > last, `{id}'s tier {index} asks no more than the one before`)
				last = tier.goal
				T.ok(tier.herbs > 0, `{id}'s tier {index} pays nothing`)
				T.ok(tier.badge >= 0 and tier.badge == math.floor(tier.badge))
				local potion = tier.potion
				if potion then
					T.ok(Catalog.potionById[potion] ~= nil, `{id} pays a potion there is not`)
				end
			end
			T.ok(English.text["Ach_" .. id] ~= nil, `no name for {id}`)
			T.ok(English.text["AchWhat_" .. id] ~= nil, `no words for {id}`)
		end
		T.ok(#Achievements >= 20, "the achievements are missing")
	end,

	["a tier is given once its number is reached, and once"] = function()
		local fresh = save()
		T.ok(next(Progress.earned(fresh, {})) == nil, "a new save has done nothing")
		fresh.spins = 150
		local earned = Progress.earned(fresh, {})
		T.eq(earned.throws, 2, "150 throws are the second tier of throws")
		T.ok(next(Progress.earned(fresh, { throws = 2 })) == nil, "given twice")
		T.eq(Progress.earned(fresh, { throws = 1 }).throws, 2, "the next tier is not given")
	end,

	["claiming pays the tiers between the claimed and the reached"] = function()
		local throws = Progress.byId.throws
		local reward = Progress.reward(throws, 0, 2)
		T.eq(reward.herbs, throws.tiers[1].herbs + throws.tiers[2].herbs)
		T.eq(Progress.reward(throws, 2, 2).herbs, 0, "a claimed tier pays again")
		T.ok(Progress.unclaimed({ throws = 2 }, { throws = 1 }))
		T.ok(not Progress.unclaimed({ throws = 2 }, { throws = 2 }))
	end,

	["counts, units and the Bingo Book are counted"] = function()
		local fresh = save()
		local last = Catalog.zones[#Catalog.zones]
		local character = Catalog.charactersByRank[last.rank][1]
		fresh.found = { [character.id] = { six_paths = true } }
		fresh.units =
			{ u1 = { character = character.id, mutation = Catalog.NONE, level = 3, upgrade = 9 } }
		fresh.counts = { home = 7 }
		local stats = Progress.stats(fresh)
		T.eq(stats.found, 1)
		T.eq(stats.mutations, 1)
		T.eq(stats.sixPaths, 1)
		T.eq(stats.zone, #Catalog.zones, "a catch of the last zone's rank is not the last zone")
		T.eq(stats.stars, 2, "a unit of merge level 3 has two stars")
		T.eq(stats.topLevel, 10, "nine levels bought is Lvl 10")
		T.eq(stats.home, 7)
		T.eq(stats.merges, 0, "a number never counted is not 0")
		local earned = Progress.earned(fresh, {})
		T.eq(earned.zone, #Progress.byId.zone.tiers)
		T.eq(earned.six_paths, 1)
	end,
}
