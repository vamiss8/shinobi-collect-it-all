--!strict
-- The achievements (owner, 2026-10-18: "achievements: Roblox badges plus a list in the game
-- with progress, icons from my prompts"): what each asks, measured by one of the numbers
-- Logic/Achievements reckons from a save (`stat`), and the Roblox badge it gives, by the
-- badge's id, 0 until the owner makes it in Creator Hub (Engagement > Badges; five a day are
-- free) and sends the id. Its words are Ach_<id> and AchWhat_<id> in the language packs, its
-- picture Art.achievements[id] (0: drawn). WHICH THEY ARE IS MY CALL, told to him: things the
-- saves already count, so that a player who has done them is given them at once.
--
-- AN ACHIEVEMENT'S id IS KEPT IN SAVES (Data.achievements): never renamed, only added.

local Kunai = require("./Kunai")
local Rebirths = require("./Rebirths")
local Tuning = require("./Tuning")

export type Achievement = {
	id: string,
	-- What is counted: throws, found (Bingo Book entries), pages (full pages of it),
	-- mutations (entries with a mutation), sixPaths (entries with the Six Paths mutation),
	-- rank (the farthest zone whose rank a catch has had), speed (the run speed level
	-- bought), kunai (the best kunai's place), pads (pads bought), rebirths.
	stat: string,
	goal: number,
	-- The Roblox badge, 0 until made.
	badge: number,
	-- The drawn stand-in for a picture: a seal of this color with this mark on it.
	color: string,
	mark: string,
}

local Achievements: { Achievement } = {
	{ id = "first_throw", stat = "throws", goal = 1, badge = 0, color = "#4FC3F7", mark = "投" },
	{ id = "throws_100", stat = "throws", goal = 100, badge = 0, color = "#29B6F6", mark = "百" },
	{
		id = "throws_1000",
		stat = "throws",
		goal = 1000,
		badge = 0,
		color = "#0288D1",
		mark = "千",
	},
	{ id = "mutation", stat = "mutations", goal = 1, badge = 0, color = "#BA68C8", mark = "変" },
	{ id = "found_10", stat = "found", goal = 10, badge = 0, color = "#81C784", mark = "書" },
	{ id = "found_50", stat = "found", goal = 50, badge = 0, color = "#43A047", mark = "集" },
	{ id = "full_page", stat = "pages", goal = 1, badge = 0, color = "#2E7D32", mark = "頁" },
	{ id = "six_paths", stat = "sixPaths", goal = 1, badge = 0, color = "#ECEFF1", mark = "仙" },
	-- The fifth zone (Valley of the End) and the last (Great Ninja War), by the rank of
	-- what was caught there.
	{ id = "rank_a_plus", stat = "rank", goal = 5, badge = 0, color = "#FFB74D", mark = "谷" },
	{ id = "rank_six_paths", stat = "rank", goal = 10, badge = 0, color = "#E53935", mark = "戦" },
	-- Run speed: the Gate of Opening, the first Gate, and the Gate of Death, the last
	-- (Config/SpeedStages).
	{ id = "gate_1", stat = "speed", goal = 12, badge = 0, color = "#66BB6A", mark = "門" },
	{ id = "gate_8", stat = "speed", goal = 40, badge = 0, color = "#C62828", mark = "八" },
	{
		id = "kunai_last",
		stat = "kunai",
		goal = #Kunai,
		badge = 0,
		color = "#FFD54F",
		mark = "雷",
	},
	{
		id = "full_dojo",
		stat = "pads",
		goal = Tuning.Dojo.buyablePads,
		badge = 0,
		color = "#8D6E63",
		mark = "道",
	},
	{ id = "rebirth_1", stat = "rebirths", goal = 1, badge = 0, color = "#9575CD", mark = "転" },
	{
		id = "rebirth_last",
		stat = "rebirths",
		goal = #Rebirths,
		badge = 0,
		color = "#212121",
		mark = "神",
	},
}

return Achievements
