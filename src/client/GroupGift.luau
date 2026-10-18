--!strict
-- The gift for joining the game's group, as this player sees it (Services/GroupGift): the box
-- behind the fountain is there until they have taken it, and then it is gone from their world
-- (the owner: "once the gift is taken, take it away, the spawn is cluttered enough"), others
-- still seeing theirs; Roblox's prompt to join the group when the server says they are not in
-- it; and now and then a word on the message scroll that the gift waits, a few times a visit,
-- never in the middle of a throw or over an open window.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Cinematic = require("./Cinematic")
local Hud = require("./Hud")
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local GroupGift = {}

local GROUP = Tuning.Group.id
-- The first reminder after this long in the game, seconds, then one every REMIND_EVERY, at
-- most REMINDERS a visit; a reminder that finds the player busy waits RETRY and looks again.
local REMIND_FIRST = 120
local REMIND_EVERY = 900
local REMINDERS = 3
local RETRY = 20
local GOLD = Color3.fromRGB(255, 202, 40)

local claimed = false

-- Whether this player is in the group, as this client is told (it keeps its first answer, but
-- forgets it when the player joins from Roblox's prompt here).
local function inGroup(): boolean
	local player = Players.LocalPlayer
	local ok, inside = pcall(function()
		return (player :: any):IsInGroupAsync(GROUP)
	end)
	return ok and inside == true
end

local function remind()
	for _ = 1, REMINDERS do
		if claimed then
			return
		end
		while Cinematic.staging() or Ui.windowOpen() do
			task.wait(RETRY)
		end
		if claimed then
			return
		end
		Hud.toast(
			if inGroup()
				then Strings.get("GroupGiftRemindClaim")
				else Strings.get("GroupGiftRemindJoin"),
			GOLD
		)
		task.wait(REMIND_EVERY)
	end
end

function GroupGift.start()
	-- The box, kept to be put back should the gift be given back (the developer console's
	-- reset), and taken out of this player's world once they have had it.
	task.spawn(function()
		local plaza = Workspace:WaitForChild("Plaza", 60)
		local gift = if plaza then plaza:WaitForChild("GroupGift", 60) else nil
		if not (gift and plaza) then
			return
		end
		local home = gift.Parent
		Store.onChange(function(state)
			claimed = state.groupGift == true
			gift.Parent = if claimed then nil else home
		end)
	end)

	Remotes.GroupGift.OnClientEvent:Connect(function(what: string)
		if what ~= "join" then
			return
		end
		Hud.toast(Strings.get("GroupGiftJoin"), GOLD)
		task.spawn(function()
			pcall(function()
				local service: any = GroupService
				service:PromptJoinAsync(GROUP)
			end)
			-- Joined, the gift is asked for again, and the server looks for itself; the prompt
			-- shut without joining, it is left there (asking again would only prompt again).
			if inGroup() then
				Remotes.GroupGift:FireServer("claim")
			end
		end)
	end)

	task.delay(REMIND_FIRST, remind)
end

return GroupGift
