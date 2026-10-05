--!strict
-- The Bingo Book: which character + mutation pairs a player has found, and what that pays.
-- The book has one page per mutation (the first is "no mutation"); every page lists every
-- character. Finding a pair for the first time pays Ryo, and a complete page gives a permanent
-- income bonus.

local Catalog = require("../Config/Catalog")
local Economy = require("./Economy")
local Tuning = require("../Config/Tuning")

local Index = {}

-- character id -> set of mutation ids found for it
export type Found = { [string]: { [string]: boolean } }

-- The book's pages as mutation ids, in order. Event mutations get no page: they cannot be
-- collected outside their event.
local pages: { string } = { Catalog.NONE }
for _, mutation in Catalog.mutations do
	if mutation.event == nil then
		table.insert(pages, mutation.id)
	end
end
Index.pages = pages

function Index.has(found: Found, character: string, mutation: string): boolean
	local mutations = found[character]
	return mutations ~= nil and mutations[mutation] == true
end

-- Records a find. Returns true when the pair is new.
function Index.record(found: Found, character: string, mutation: string): boolean
	if Index.has(found, character, mutation) then
		return false
	end
	local mutations = found[character]
	if not mutations then
		mutations = {}
		found[character] = mutations
	end
	mutations[mutation] = true
	return true
end

-- How many characters have been found with the given mutation.
function Index.count(found: Found, mutation: string): number
	local count = 0
	for _, character in Catalog.characters do
		if Index.has(found, character.id, mutation) then
			count += 1
		end
	end
	return count
end

-- A page is complete when every character has been found with its mutation.
function Index.isPageComplete(found: Found, mutation: string): boolean
	return Index.count(found, mutation) == #Catalog.characters
end

-- Permanent income bonus from completed pages, e.g. 0.2 for +20%.
function Index.incomeBonus(found: Found): number
	local completed = 0
	for _, mutation in pages do
		if Index.isPageComplete(found, mutation) then
			completed += 1
		end
	end
	return completed * Tuning.Index.pageCompleteBonus
end

-- Ryo paid for finding a pair for the first time.
function Index.discoveryReward(character: string, mutation: string): number
	local unit = { character = character, mutation = mutation, level = 1 }
	return math.floor(Economy.unitIncome(unit) * Tuning.Index.discoveryRewardSeconds)
end

return Index
