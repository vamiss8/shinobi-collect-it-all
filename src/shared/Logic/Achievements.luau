--!strict
-- The achievements' progress (Config/Achievements): the numbers they are measured by, reckoned
-- from a save or from what a client is sent of one (the snapshot and the Bingo Book), and which
-- of them a save has reached that it was not given yet. The server gives them
-- (Services/Achievements); the client shows how far each is (client AchievementsPanel).

local Achievements = require("../Config/Achievements")
local Catalog = require("../Config/Catalog")
local Index = require("./Index")

local Progress = {}

-- What the numbers are reckoned from: a save, or the snapshot with the Bingo Book beside it.
export type Save = {
	spins: number,
	rebirths: number,
	speedLevel: number,
	kunai: number,
	padsBought: number,
	found: Index.Found,
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
	local found, mutations, sixPaths, farthest = 0, 0, 0, 0
	for characterId, kinds in save.found do
		local character = Catalog.characterById[characterId]
		local zone = if character then zoneOfRank[character.rank] else nil
		for mutationId, has in kinds do
			if has then
				found += 1
				if mutationId ~= Catalog.NONE then
					mutations += 1
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
	return {
		throws = save.spins,
		found = found,
		pages = pages,
		mutations = mutations,
		sixPaths = sixPaths,
		rank = farthest,
		speed = save.speedLevel,
		kunai = save.kunai,
		pads = save.padsBought,
		rebirths = save.rebirths,
	}
end

-- How far an achievement is, 0 to its goal, by the numbers of `stats`.
function Progress.reached(
	achievement: Achievements.Achievement,
	stats: { [string]: number }
): number
	return math.clamp(stats[achievement.stat] or 0, 0, achievement.goal)
end

-- The achievements a save has reached that are not among `have`, in the config's order.
function Progress.earned(save: Save, have: { [string]: boolean }): { string }
	local stats = Progress.stats(save)
	local new: { string } = {}
	for _, achievement in Achievements do
		if
			not have[achievement.id]
			and Progress.reached(achievement, stats) >= achievement.goal
		then
			table.insert(new, achievement.id)
		end
	end
	return new
end

return Progress
