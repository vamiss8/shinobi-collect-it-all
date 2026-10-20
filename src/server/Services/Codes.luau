--!strict
-- Redeems the promo codes (server/Codes, Logic/Codes): a player types one in the settings
-- (client SettingsPanel), and is paid what it gives, once. The answer goes back to that
-- player alone, on the same event: what came of it and, when it worked, what it gave.
--
-- A player may try a code once a second at most, and after ten wrong ones in a row waits a
-- minute: the codes are few and short, and are not to be guessed by trying them all.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Analytics = require("./Analytics")
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local CodeList = require("../Codes")
local CodeRules = require(ReplicatedStorage.Shared.Logic.Codes)
local Daily = require(ReplicatedStorage.Shared.Logic.Daily)
local Data = require("../Data")
local Net = require(ReplicatedStorage.Shared.Net)
local Pouch = require(ReplicatedStorage.Shared.Logic.Pouch)
local Remotes = require("../Remotes")
local State = require("./State")
local Stats = require("./Stats")

local Codes = {}

local GAP = 1
local WRONG_MOST = 10
local LOCKED_FOR = 60

local GAMEPLAY = Enum.AnalyticsEconomyTransactionType.Gameplay

type Tries = { last: number, wrong: number, lockedUntil: number }
local tries: { [Player]: Tries } = {}

local function answer(player: Player, outcome: string, reward: Net.CodeReward?)
	Remotes.Code:FireClient(player, outcome, reward)
end

local function redeem(player: Player, typed: unknown)
	if typeof(typed) ~= "string" then
		return
	end
	local data = Data.get(player)
	if not data then
		return
	end
	local now = os.clock()
	local mine: Tries = tries[player] or { last = -math.huge, wrong = 0, lockedUntil = 0 }
	tries[player] = mine
	if now < mine.lockedUntil then
		answer(player, "wait")
		return
	end
	if now - mine.last < GAP then
		return
	end
	mine.last = now

	local outcome, name, code = CodeRules.check(CodeList, data.codes, typed, os.time())
	if outcome ~= "ok" or not code then
		if outcome == "unknown" then
			mine.wrong += 1
			if mine.wrong >= WRONG_MOST then
				mine.wrong = 0
				mine.lockedUntil = now + LOCKED_FOR
			end
		end
		answer(player, outcome)
		return
	end
	mine.wrong = 0

	data.codes[name] = true
	local reward: Net.CodeReward = { herbs = 0, ryo = 0, potions = {}, premium = {} }
	local herbs = code.herbs or 0
	if herbs > 0 then
		data.herbs += herbs
		reward.herbs = herbs
		Analytics.economy(player, true, "Herbs", herbs, data.herbs, GAMEPLAY, "Code")
	end
	local minutes = code.ryoMinutes or 0
	if minutes > 0 then
		local ryo = Daily.ryo(minutes, Stats.income(data))
		data.ryo += ryo
		reward.ryo = ryo
		Analytics.economy(player, true, "Ryo", ryo, data.ryo, GAMEPLAY, "Code")
	end
	local potions: { string } = code.potions or {}
	local premium: { string } = code.premium or {}
	for _, potion in potions do
		if Catalog.potionById[potion] then
			Pouch.add(data.stock, potion, 1)
			table.insert(reward.potions, potion)
		end
	end
	for _, potion in premium do
		if Catalog.potionById[potion] then
			Pouch.add(data.premium, potion, 1)
			table.insert(reward.premium, potion)
		end
	end
	Analytics.event(player, "Code", 1, name)
	State.push(player)
	answer(player, "ok", reward)
end

function Codes.start()
	Remotes.Code.OnServerEvent:Connect(redeem)
	Players.PlayerRemoving:Connect(function(player)
		tries[player] = nil
	end)
end

return Codes
