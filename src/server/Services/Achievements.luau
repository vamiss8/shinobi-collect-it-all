--!strict
-- The achievements (Config/Achievements, Logic/Achievements): every few seconds each player's
-- save is looked over, and the tiers it has reached and was not given yet are given for good
-- (Data.achievements), told to their client, which shows a small notice by the Awards tile
-- (client AchievementsPanel), and given as the Roblox badges that go with them, once there
-- are some. A tier's reward is paid when the player claims it in the Awards window.
--
-- WHAT A PLAYER HAD REACHED BEFORE IS GIVEN WITHOUT A WORD when their save loads (owner,
-- 2026-10-18: "let achievements already earned not light up for old testers when they come
-- in"): the tiers are marked, their rewards wait in the window, the tile shows its "!", and
-- nothing is announced. So it goes too for what a new achievement or tier finds done.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Data = require("../Data")
local Pouch = require(ReplicatedStorage.Shared.Logic.Pouch)
local Progress = require(ReplicatedStorage.Shared.Logic.Achievements)
local Remotes = require("../Remotes")
local State = require("./State")
local Stats = require("./Stats")

local Achievements = {}

-- How often every save is looked over, seconds.
local EVERY = 4

-- Gives the player the Roblox badges of an achievement's tiers up to `tier`, those that have
-- one and that they do not have yet.
local function award(player: Player, id: string, tier: number)
	local achievement = Progress.byId[id]
	if not achievement then
		return
	end
	for index = 1, math.min(tier, #achievement.tiers) do
		local badge = achievement.tiers[index].badge
		if badge > 0 then
			task.spawn(function()
				local asked, has = pcall(function()
					return BadgeService:UserHasBadgeAsync(player.UserId, badge)
				end)
				if asked and has then
					return
				end
				pcall(function()
					BadgeService:AwardBadgeAsync(player.UserId, badge)
				end)
			end)
		end
	end
end

-- Keeps the best Chakra and income the save has seen: both are lost at a rebirth, and the
-- achievements that count them are for having had them.
local function remember(data: Data.Data)
	local counts = data.counts
	counts.chakra = math.max(counts.chakra or 0, data.chakra)
	counts.income = math.max(counts.income or 0, Stats.income(data))
end

-- Marks what the save has reached and was not given; tells the client unless `quiet`.
local function check(player: Player, quiet: boolean)
	local data = Data.get(player)
	if not data then
		return
	end
	remember(data)
	local new = Progress.earned(data, data.achievements)
	if next(new) == nil then
		return
	end
	for _, achievement in Progress.list do
		local tier = new[achievement.id]
		if tier then
			data.achievements[achievement.id] = tier
			if not quiet then
				Remotes.Achievement:FireClient(player, achievement.id, tier)
			end
			award(player, achievement.id, tier)
		end
	end
	State.push(player)
end

-- Pays the rewards of the tiers reached and not claimed, of one achievement or of all ("*").
local function claim(player: Player, which: unknown)
	local data = Data.get(player)
	if not data or typeof(which) ~= "string" then
		return
	end
	local herbs, potions = 0, 0
	for _, achievement in Progress.list do
		if which == "*" or which == achievement.id then
			local reached = data.achievements[achievement.id] or 0
			local claimed = data.claimed[achievement.id] or 0
			if reached > claimed then
				local reward = Progress.reward(achievement, claimed, reached)
				data.claimed[achievement.id] = reached
				data.herbs += reward.herbs
				herbs += reward.herbs
				for potionId, count in reward.potions do
					if Catalog.potionById[potionId] then
						Pouch.add(data.stock, potionId, count)
						potions += count
					end
				end
			end
		end
	end
	if herbs == 0 and potions == 0 then
		return
	end
	if potions > 0 then
		State.notify(player, "AchievementClaimedPotions", herbs, potions)
	else
		State.notify(player, "AchievementClaimed", herbs)
	end
	State.push(player)
end

function Achievements.start()
	Data.onLoaded(function(player, data)
		-- A save of the first build of the achievements kept them as true by id, and some of
		-- those ids are gone: what is not a tier of an achievement there is is let go, and
		-- comes back below as the tier it is.
		local kept: { [string]: any } = data.achievements
		for id, tier in kept do
			if typeof(tier) ~= "number" or not Progress.byId[id] then
				kept[id] = nil
			end
		end
		check(player, true)
		-- The snapshot sent as the save loaded (Services/State) went before this.
		State.push(player)
		-- Badges for what was reached before they existed, or before a player had them.
		for id, tier in data.achievements do
			award(player, id, tier)
		end
	end)
	Remotes.ClaimAchievement.OnServerEvent:Connect(claim)
	task.spawn(function()
		while true do
			task.wait(EVERY)
			for _, player in Players:GetPlayers() do
				check(player, false)
			end
		end
	end)
end

return Achievements
