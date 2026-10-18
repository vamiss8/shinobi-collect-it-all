--!strict
-- The achievements (Config/Achievements, Logic/Achievements): every few seconds each player's
-- save is looked over, and what it has reached and was not given yet is given for good
-- (Data.achievements), told to their client, which names it on the scroll (client
-- AchievementsPanel), and given as the Roblox badge that goes with it, once there is one. A
-- badge made after a player earned its achievement is given the next time they come in.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require("../Data")
local Progress = require(ReplicatedStorage.Shared.Logic.Achievements)
local Remotes = require("../Remotes")
local State = require("./State")

local Achievements = {}

-- How often every save is looked over, seconds.
local EVERY = 4

-- Gives the player the Roblox badge of an achievement, if it has one and they have not.
local function award(player: Player, id: string)
	local achievement = Progress.byId[id]
	if not achievement or achievement.badge <= 0 then
		return
	end
	task.spawn(function()
		local asked, has = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, achievement.badge)
		end)
		if asked and has then
			return
		end
		pcall(function()
			BadgeService:AwardBadgeAsync(player.UserId, achievement.badge)
		end)
	end)
end

local function check(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local new = Progress.earned(data, data.achievements)
	if #new == 0 then
		return
	end
	for _, id in new do
		data.achievements[id] = true
		Remotes.Achievement:FireClient(player, id)
		award(player, id)
	end
	State.push(player)
end

function Achievements.start()
	-- Badges for what was earned before they existed, or before a player had them.
	Data.onLoaded(function(player, data)
		for id in data.achievements do
			award(player, id)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(EVERY)
			for _, player in Players:GetPlayers() do
				check(player)
			end
		end
	end)
end

return Achievements
