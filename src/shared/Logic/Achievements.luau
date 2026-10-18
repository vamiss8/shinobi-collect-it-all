--!strict
-- The achievements' progress (Config/Achievements): the numbers they are measured by,
-- reckoned from a save, how many of an achievement's tiers a number has reached, which tiers
-- a save has reached that it was not given yet, and what claiming tiers pays. The server
-- gives and pays them (Services/Achievements) and sends the numbers to the client (the
-- snapshot's `progress`), which shows how far each is (client AchievementsPanel).

local Achievements = require("../Config/Achievements")
local Catalog = require("../Config/Catalog")
local Economy = require("./Economy")
local Index = require("./Index")

local Progress = {}

-- What the numbers are reckoned from: a save's own fields, and `counts`, the numbers no
-- field of the save keeps (Data.counts: catches brought home, merges, potions drunk...).
export type Save = {
	spins: number,
	rebirths: number,
	speedLevel: number,
	kunai: number,
	padsBought: number,
	found: Index.Found,
	units: { [string]: Economy.Unit },
	counts: { [string]: number },
}

-- What claiming pays: Herbs, and potions into the pouch by potion id.
export type Reward = { herbs: number, potions: { [string]: number } }

-- The numbers kept in a save's `counts`, each 0 until the first is counted: what the
-- services count as it happens (Data.count), and the best Chakra and income the
-- achievements' own round has seen (Services/Achievements).
Progress.COUNTED = {
	"home",
	"caught",
	"perfect",
	"sage",
	"merges",
	"upgrades",
	"sent",
	"potions",
	"ring",
	"seals",
	"chakra",
	"income",
}

Progress.list = Achievements
Progress.byId = {} :: { [string]: Achievements.Achievement }
for _, achievement in Achievements do
	Progress.byId[achievement.id] = achievement
end

-- A zone's place down the lane, by its rank: a catch of that rank was made there at the
-- farthest.
local zoneOfRank: { [string]: number } = {}
for order, zone in Catalog.zones do
	zoneOfRank[zone.rank] = order
end

-- Every number an achievement can ask for, by its name (Config/Achievements `stat`).
function Progress.stats(save: Save): { [string]: number }
	local found, mutations, events, sixPaths, farthest = 0, 0, 0, 0, 0
	for characterId, kinds in save.found do
		local character = Catalog.characterById[characterId]
		local zone = if character then zoneOfRank[character.rank] else nil
		for mutationId, has in kinds do
			if has then
				found += 1
				if mutationId ~= Catalog.NONE then
					mutations += 1
				end
				local mutation = Catalog.mutationById[mutationId]
				if mutation and mutation.event then
					events += 1
				end
				if mutationId == "six_paths" then
					sixPaths += 1
				end
				if zone then
					farthest = math.max(farthest, zone)
				end
			end
		end
	end
	local pages = 0
	for _, page in Index.pages do
		if Index.isPageComplete(save.found, page) then
			pages += 1
		end
	end
	local stars, topLevel = 0, 0
	for _, unit in save.units do
		stars = math.max(stars, unit.level - 1)
		topLevel = math.max(topLevel, (unit.upgrade or 0) + 1)
	end
	local stats: { [string]: number } = {
		throws = save.spins,
		found = found,
		pages = pages,
		mutations = mutations,
		events = events,
		sixPaths = sixPaths,
		zone = farthest,
		speed = save.speedLevel,
		kunai = save.kunai,
		pads = save.padsBought,
		rebirths = save.rebirths,
		stars = stars,
		topLevel = topLevel,
	}
	for _, name in Progress.COUNTED do
		stats[name] = save.counts[name] or 0
	end
	return stats
end

-- How many of an achievement's tiers a number has reached, 0 to all of them.
function Progress.tier(achievement: Achievements.Achievement, value: number): number
	local reached = 0
	for index, tier in achievement.tiers do
		if value >= tier.goal then
			reached = index
		end
	end
	return reached
end

-- The tiers a save has reached that are not among `have` (achievement id -> tiers given), as
-- achievement id -> the highest tier reached, in no order.
function Progress.earned(save: Save, have: { [string]: number }): { [string]: number }
	local stats = Progress.stats(save)
	local new: { [string]: number } = {}
	for _, achievement in Achievements do
		local tier = Progress.tier(achievement, stats[achievement.stat] or 0)
		if tier > (have[achievement.id] or 0) then
			new[achievement.id] = tier
		end
	end
	return new
end

-- What the tiers of an achievement after `claimed` up to `reached` pay together.
function Progress.reward(
	achievement: Achievements.Achievement,
	claimed: number,
	reached: number
): Reward
	local reward: Reward = { herbs = 0, potions = {} }
	for index = claimed + 1, math.min(reached, #achievement.tiers) do
		local tier = achievement.tiers[index]
		reward.herbs += tier.herbs
		local potion = tier.potion
		if potion then
			reward.potions[potion] = (reward.potions[potion] or 0) + 1
		end
	end
	return reward
end

-- Whether a save has tiers reached and not claimed: the Awards tile is marked then.
function Progress.unclaimed(have: { [string]: number }, claimed: { [string]: number }): boolean
	for id, tier in have do
		if Progress.byId[id] and tier > (claimed[id] or 0) then
			return true
		end
	end
	return false
end

return Progress
