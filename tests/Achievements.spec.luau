--!strict
-- The achievements (Config/Achievements, Logic/Achievements): each asks for a number there is,
-- has words in English, and is given when its number is reached and not before.
local Achievements = require("../src/shared/Config/Achievements")
local Catalog = require("../src/shared/Config/Catalog")
local Progress = require("../src/shared/Logic/Achievements")
local T = require("./harness")

local English = require("../src/client/Lang/en")

local function save(): Progress.Save
	return { spins = 0, rebirths = 0, speedLevel = 0, kunai = 1, padsBought = 0, found = {} }
end

return {
	["every achievement asks for a number there is, and has its words"] = function()
		local stats = Progress.stats(save())
		local seen: { [string]: boolean } = {}
		for _, achievement in Achievements do
			T.ok(not seen[achievement.id], `{achievement.id} is twice`)
			seen[achievement.id] = true
			T.ok(
				stats[achievement.stat] ~= nil,
				`{achievement.id} counts {achievement.stat}, no such`
			)
			T.ok(achievement.goal > 0, `{achievement.id} asks for nothing`)
			T.ok(achievement.badge >= 0 and achievement.badge == math.floor(achievement.badge))
			T.ok(English.text["Ach_" .. achievement.id] ~= nil, `no name for {achievement.id}`)
			T.ok(English.text["AchWhat_" .. achievement.id] ~= nil, `no words for {achievement.id}`)
		end
		T.ok(#Achievements >= 10, "the achievements are missing")
	end,

	["an achievement is given once its number is reached"] = function()
		local fresh = save()
		T.eq(#Progress.earned(fresh, {}), 0, "a new save has done nothing")
		fresh.spins = 100
		local earned = Progress.earned(fresh, {})
		T.ok(table.find(earned, "first_throw") ~= nil, "a throw is not counted")
		T.ok(table.find(earned, "throws_100") ~= nil, "a hundred throws are not counted")
		T.ok(table.find(earned, "throws_1000") == nil, "a thousand is given at a hundred")
		T.eq(#Progress.earned(fresh, { first_throw = true, throws_100 = true }), 0, "given twice")
	end,

	["a catch counts in the Bingo Book, for its mutation and for its zone"] = function()
		local fresh = save()
		local last = Catalog.zones[#Catalog.zones]
		local character = Catalog.charactersByRank[last.rank][1]
		fresh.found = { [character.id] = { six_paths = true } }
		local stats = Progress.stats(fresh)
		T.eq(stats.found, 1)
		T.eq(stats.mutations, 1)
		T.eq(stats.sixPaths, 1)
		T.eq(stats.rank, #Catalog.zones, "a catch of the last zone's rank is not the last zone")
		local earned = Progress.earned(fresh, {})
		T.ok(table.find(earned, "rank_six_paths") ~= nil)
		T.ok(table.find(earned, "six_paths") ~= nil)
	end,
}
