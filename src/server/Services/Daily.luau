--!strict
-- The daily rewards (Config/Daily, Logic/Daily): a player claims today's from their window
-- (client DailyPanel), and is paid what that day of their week gives.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Analytics = require("./Analytics")
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Data = require("../Data")
local Days = require(ReplicatedStorage.Shared.Config.Daily)
local DailyLogic = require(ReplicatedStorage.Shared.Logic.Daily)
local Pouch = require(ReplicatedStorage.Shared.Logic.Pouch)
local Remotes = require("../Remotes")
local State = require("./State")
local Stats = require("./Stats")

local Daily = {}

local TIMED = Enum.AnalyticsEconomyTransactionType.TimedReward

local function claim(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local index = DailyLogic.claim(data.daily, os.time())
	local day = if index then Days.days[index] else nil
	if not index or not day then
		return
	end
	local herbs = day.herbs or 0
	if herbs > 0 then
		data.herbs += herbs
		Analytics.economy(player, true, "Herbs", herbs, data.herbs, TIMED, "Daily")
	end
	local minutes = day.ryoMinutes
	if minutes then
		local ryo = DailyLogic.ryo(minutes, Stats.income(data))
		data.ryo += ryo
		Analytics.economy(player, true, "Ryo", ryo, data.ryo, TIMED, "Daily")
	end
	local potion = day.potion
	if potion and Catalog.potionById[potion] then
		Pouch.add(data.stock, potion, 1)
	end
	local premium = day.premium
	if premium and Catalog.potionById[premium] then
		Pouch.add(data.premium, premium, 1)
	end
	Analytics.event(player, "Daily", 1, tostring(index), tostring(data.daily.streak))
	State.notify(player, "DailyClaimed", index)
	State.push(player)
end

function Daily.start()
	Remotes.Daily.OnServerEvent:Connect(claim)
end

return Daily
