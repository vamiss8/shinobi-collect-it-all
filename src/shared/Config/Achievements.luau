--!strict
-- The achievements (owner, 2026-10-18: "achievements: Roblox badges plus a list in the game
-- with progress, icons from my prompts"; then: "let throw 100 and throw 1000 be one
-- achievement with different tiers, think up more, and for every achievement or tier a
-- modest but pleasant reward"). Each counts one number (`stat`, reckoned by
-- Logic/Achievements from a save) and has tiers, each reached at its `goal`, each paying a
-- reward that is claimed in the Awards window (Herbs, and on the higher tiers a potion of the
-- Herbs kind into the pouch) and giving its Roblox badge, by the badge's id, 0 until the owner
-- makes it in Creator Hub (Engagement > Badges; five a day are free) and sends the id. Words
-- are Ach_<id> (the name) and AchWhat_<id> (what a tier asks, the goal in its blank) in the
-- language packs, the picture Art.achievements[id] (none: drawn, a seal of `color` with
-- `mark`). WHICH THEY ARE, THEIR TIERS AND REWARDS ARE MY CALL, told to him.
--
-- AN ACHIEVEMENT'S id IS KEPT IN SAVES (Data.achievements, Data.claimed): never renamed, only
-- added. Its tiers may be added to at the end; an earlier tier's goal is not to be raised.

local Kunai = require("./Kunai")
local Rebirths = require("./Rebirths")
local Tuning = require("./Tuning")

export type Tier = {
	goal: number,
	herbs: number, -- what claiming it pays
	potion: string?, -- and one potion of the Herbs kind into the pouch (Config/Potions id)
	badge: number, -- the Roblox badge it gives, 0 until made
}

export type Achievement = {
	id: string,
	-- What is counted (Logic/Achievements.stats): throws; home (catches brought home); caught
	-- (by a zone's enemy); perfect (Perfect presses of the throw); sage (Sage throws); found
	-- (Bingo Book entries); pages (full pages of it); mutations (entries with a mutation);
	-- events (entries with an event's mutation); sixPaths (entries with Six Paths); zone (the
	-- farthest zone whose rank a catch has had); speed (the run speed level bought); kunai (the
	-- best kunai's place); pads (pads bought); rebirths; merges; stars (the most stars a
	-- shinobi has had); upgrades (levels bought on the consoles); topLevel (the highest Lvl a
	-- shinobi has had); sent (shinobi sent at the Mission Desk); potions (drunk); ring
	-- (Perfects of Chakra Control); seals (bonus seals broken); chakra (the most Chakra held);
	-- income (the most Ryo a second the dojo has earned).
	stat: string,
	tiers: { Tier },
	-- The drawn stand-in for a picture: a seal of this color with this mark on it.
	color: string,
	mark: string,
}

local Achievements: { Achievement } = {
	{
		id = "throws",
		stat = "throws",
		color = "#4FC3F7",
		mark = "投",
		tiers = {
			{ goal = 1, herbs = 20, badge = 2259520049685889 },
			{ goal = 100, herbs = 50, badge = 0 },
			{ goal = 1000, herbs = 150, badge = 0 },
			{ goal = 10000, herbs = 400, potion = "soldier_pill", badge = 0 },
		},
	},
	{
		id = "home",
		stat = "home",
		color = "#81C784",
		mark = "帰",
		tiers = {
			{ goal = 10, herbs = 25, badge = 605915299069720 },
			{ goal = 100, herbs = 75, badge = 0 },
			{ goal = 1000, herbs = 200, badge = 0 },
			{ goal = 5000, herbs = 400, potion = "ichiraku_ramen", badge = 0 },
		},
	},
	{
		id = "caught",
		stat = "caught",
		color = "#A1887F",
		mark = "捕",
		tiers = {
			{ goal = 1, herbs = 15, badge = 1451615730080915 },
			{ goal = 25, herbs = 50, badge = 0 },
			{ goal = 100, herbs = 120, badge = 0 },
		},
	},
	{
		id = "perfect",
		stat = "perfect",
		color = "#E57373",
		mark = "的",
		tiers = {
			{ goal = 10, herbs = 30, badge = 4031126799922882 },
			{ goal = 100, herbs = 100, badge = 0 },
			{ goal = 1000, herbs = 300, potion = "gama_charm", badge = 0 },
		},
	},
	{
		id = "sage",
		stat = "sage",
		color = "#FFB74D",
		mark = "仙",
		tiers = {
			{ goal = 1, herbs = 40, badge = 2339066422148129 },
			{ goal = 25, herbs = 120, badge = 0 },
			{ goal = 250, herbs = 300, potion = "sage_oil", badge = 0 },
		},
	},
	{
		id = "zone",
		stat = "zone",
		color = "#E53935",
		mark = "路",
		-- The third zone (Forest of Death), the fifth (Valley of the End), the eighth (Hidden
		-- Rain) and the last (Great Ninja War), by the rank of what was caught there.
		tiers = {
			{ goal = 3, herbs = 40, badge = 0 },
			{ goal = 5, herbs = 100, badge = 0 },
			{ goal = 8, herbs = 200, badge = 0 },
			{ goal = 10, herbs = 400, potion = "soldier_pill", badge = 0 },
		},
	},
	{
		id = "found",
		stat = "found",
		color = "#43A047",
		mark = "書",
		tiers = {
			{ goal = 10, herbs = 30, badge = 0 },
			{ goal = 50, herbs = 100, badge = 0 },
			{ goal = 150, herbs = 250, badge = 0 },
			{ goal = 300, herbs = 500, potion = "gama_charm", badge = 0 },
		},
	},
	{
		id = "pages",
		stat = "pages",
		color = "#2E7D32",
		mark = "頁",
		tiers = {
			{ goal = 1, herbs = 150, badge = 0 },
			{ goal = 3, herbs = 300, badge = 0 },
			{ goal = 6, herbs = 600, potion = "soldier_pill", badge = 0 },
		},
	},
	{
		id = "mutations",
		stat = "mutations",
		color = "#BA68C8",
		mark = "変",
		tiers = {
			{ goal = 1, herbs = 25, badge = 0 },
			{ goal = 25, herbs = 100, badge = 0 },
			{ goal = 100, herbs = 250, potion = "sage_oil", badge = 0 },
		},
	},
	{
		id = "events",
		stat = "events",
		color = "#F06292",
		mark = "祭",
		tiers = {
			{ goal = 1, herbs = 50, badge = 0 },
			{ goal = 10, herbs = 150, badge = 0 },
			{ goal = 30, herbs = 300, potion = "sage_oil", badge = 0 },
		},
	},
	{
		id = "six_paths",
		stat = "sixPaths",
		color = "#ECEFF1",
		mark = "六",
		tiers = {
			{ goal = 1, herbs = 300, potion = "sage_oil", badge = 1384176942992724 },
		},
	},
	{
		id = "merges",
		stat = "merges",
		color = "#4DB6AC",
		mark = "合",
		tiers = {
			{ goal = 1, herbs = 30, badge = 4424924598507362 },
			{ goal = 25, herbs = 100, badge = 0 },
			{ goal = 250, herbs = 250, badge = 0 },
		},
	},
	{
		id = "stars",
		stat = "stars",
		color = "#FFD54F",
		mark = "星",
		tiers = {
			{ goal = 1, herbs = 30, badge = 2090275732979569 },
			{ goal = 2, herbs = 80, badge = 0 },
			{ goal = 4, herbs = 250, potion = "ichiraku_ramen", badge = 0 },
		},
	},
	{
		id = "upgrades",
		stat = "upgrades",
		color = "#FFA726",
		mark = "上",
		tiers = {
			{ goal = 10, herbs = 25, badge = 518877346851904 },
			{ goal = 100, herbs = 75, badge = 0 },
			{ goal = 1000, herbs = 200, badge = 0 },
		},
	},
	{
		id = "top_level",
		stat = "topLevel",
		color = "#FB8C00",
		mark = "極",
		tiers = {
			{ goal = 10, herbs = 40, badge = 4503406041987847 },
			{ goal = 50, herbs = 120, badge = 0 },
			{ goal = 100, herbs = 300, potion = "ichiraku_ramen", badge = 0 },
		},
	},
	{
		id = "pads",
		stat = "pads",
		color = "#8D6E63",
		mark = "館",
		-- The second floor (the eleventh pad, the sixth bought), the third, and every pad sold
		-- for Ryo.
		tiers = {
			{ goal = 6, herbs = 50, badge = 0 },
			{ goal = 16, herbs = 120, badge = 0 },
			{ goal = Tuning.Dojo.buyablePads, herbs = 300, badge = 0 },
		},
	},
	{
		id = "kunai",
		stat = "kunai",
		color = "#90A4AE",
		mark = "刃",
		tiers = {
			{ goal = 5, herbs = 40, badge = 0 },
			{ goal = 10, herbs = 100, badge = 0 },
			{ goal = 15, herbs = 200, badge = 0 },
			{ goal = #Kunai, herbs = 400, potion = "ichiraku_ramen", badge = 0 },
		},
	},
	{
		id = "speed",
		stat = "speed",
		color = "#66BB6A",
		mark = "門",
		-- The Gate of Opening, the Gate of Pain and the Gate of Death (Config/SpeedStages).
		tiers = {
			{ goal = 12, herbs = 60, badge = 0 },
			{ goal = 24, herbs = 150, badge = 0 },
			{ goal = 40, herbs = 400, potion = "soldier_pill", badge = 0 },
		},
	},
	{
		id = "chakra",
		stat = "chakra",
		color = "#42A5F5",
		mark = "気",
		tiers = {
			{ goal = 1e3, herbs = 25, badge = 0 },
			{ goal = 1e6, herbs = 75, badge = 0 },
			{ goal = 1e9, herbs = 200, badge = 0 },
			{ goal = 1e10, herbs = 500, potion = "soldier_pill", badge = 0 },
		},
	},
	{
		id = "income",
		stat = "income",
		color = "#FDD835",
		mark = "富",
		tiers = {
			{ goal = 1e3, herbs = 25, badge = 0 },
			{ goal = 1e6, herbs = 100, badge = 0 },
			{ goal = 1e9, herbs = 250, badge = 0 },
			{ goal = 1e12, herbs = 500, potion = "gama_charm", badge = 0 },
		},
	},
	{
		id = "rebirths",
		stat = "rebirths",
		color = "#9575CD",
		mark = "転",
		tiers = {
			{ goal = 1, herbs = 100, badge = 0 },
			{ goal = 3, herbs = 200, badge = 0 },
			{ goal = 6, herbs = 400, badge = 0 },
			{ goal = #Rebirths, herbs = 800, potion = "sage_oil", badge = 0 },
		},
	},
	{
		id = "ring",
		stat = "ring",
		color = "#29B6F6",
		mark = "練",
		tiers = {
			{ goal = 10, herbs = 25, badge = 0 },
			{ goal = 100, herbs = 75, badge = 0 },
			{ goal = 1000, herbs = 200, badge = 0 },
		},
	},
	{
		id = "seals",
		stat = "seals",
		color = "#AED581",
		mark = "封",
		tiers = {
			{ goal = 10, herbs = 25, badge = 0 },
			{ goal = 100, herbs = 75, badge = 0 },
			{ goal = 500, herbs = 200, badge = 0 },
		},
	},
	{
		id = "potions",
		stat = "potions",
		color = "#7E57C2",
		mark = "薬",
		tiers = {
			{ goal = 1, herbs = 30, badge = 0 },
			{ goal = 10, herbs = 100, badge = 0 },
			{ goal = 50, herbs = 250, badge = 0 },
		},
	},
	{
		id = "sent",
		stat = "sent",
		color = "#78909C",
		mark = "任",
		tiers = {
			{ goal = 10, herbs = 25, badge = 0 },
			{ goal = 100, herbs = 75, badge = 0 },
			{ goal = 1000, herbs = 200, badge = 0 },
		},
	},
}

return Achievements
