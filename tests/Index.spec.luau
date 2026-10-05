--!strict
local Catalog = require("../src/shared/Config/Catalog")
local Index = require("../src/shared/Logic/Index")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

return {
	["a pair is new only the first time"] = function()
		local found: Index.Found = {}
		T.eq(Index.record(found, "iruka", Catalog.NONE), true)
		T.eq(Index.record(found, "iruka", Catalog.NONE), false)
		T.eq(Index.record(found, "iruka", "ice"), true, "same character, new mutation")
	end,

	["the book has a page per mutation, plain first, and none for events"] = function()
		T.eq(Index.pages[1], Catalog.NONE)
		for _, page in Index.pages do
			local mutation = Catalog.mutationById[page]
			T.ok(mutation == nil or mutation.event == nil, `{page} is an event mutation`)
		end
		T.ok(table.find(Index.pages, "ice") ~= nil, "regular mutations have a page")
	end,

	["a page counts finds of its own mutation only"] = function()
		local found: Index.Found = {}
		Index.record(found, "iruka", Catalog.NONE)
		Index.record(found, "konohamaru", Catalog.NONE)
		Index.record(found, "iruka", "ice")
		T.eq(Index.count(found, Catalog.NONE), 2)
		T.eq(Index.count(found, "ice"), 1)
		T.eq(Index.count(found, "lava"), 0)
	end,

	["a page completes when every character is found with its mutation"] = function()
		local found: Index.Found = {}
		for i, character in Catalog.characters do
			T.eq(Index.isPageComplete(found, "ice"), false, `before character {i}`)
			Index.record(found, character.id, "ice")
		end
		T.eq(Index.isPageComplete(found, "ice"), true)
		T.eq(Index.isPageComplete(found, Catalog.NONE), false, "other pages are untouched")
		T.eq(Index.incomeBonus(found), Tuning.Index.pageCompleteBonus)
	end,

	["discovery pays a set stretch of the unit's income"] = function()
		local seconds = Tuning.Index.discoveryRewardSeconds
		local income = Catalog.characterById.iruka.income
		local ice = Catalog.mutationMultiplier("ice")
		T.eq(Index.discoveryReward("iruka", Catalog.NONE), math.floor(income * seconds))
		T.eq(Index.discoveryReward("iruka", "ice"), math.floor(income * ice * seconds))
	end,
}
