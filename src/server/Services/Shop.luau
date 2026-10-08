--!strict
-- The market's three shops. Tenten's Ninja Tools (the shop "tenten") sells kunai, the Youth
-- Training Ground (the shop "speed") sells run speed, and the Mission Desk (the shop "sell")
-- buys shinobi out of the inventory. The windows live on the client; the server only accepts a
-- request from a player who is actually standing at that shop's counter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Data = require("../Data")
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Inventory = require("./Inventory")
local Loadout = require("./Loadout")
local Market = require("../World/Market")
local Remotes = require("../Remotes")
local SpeedLook = require("./SpeedLook")
local SpeedStages = require(ReplicatedStorage.Shared.Config.SpeedStages)
local State = require("./State")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Shop = {}

-- Which shop sells which item.
local STALL_OF = {
	kunai = "tenten",
	speed = "speed",
}

-- A sell request may name at most this many units; a whole inventory fits comfortably.
local MAX_SOLD_AT_ONCE = 500

-- Takes the price from the player's Ryo. Returns false, and tells the player, if they are short.
local function pay(player: Player, data: Data.Data, price: number): boolean
	if data.ryo < price then
		State.notify(player, "NotEnoughRyo")
		return false
	end
	data.ryo -= price
	return true
end

-- The speed level the player runs at: what they bought, or less if they chose so.
local function runLevel(data: Data.Data): number
	return Economy.runLevel(data.speedLevel, data.runAt)
end

-- Gives the player's character the run speed and the speed stage's look that go with the level
-- they run at; `was` is the level they ran at until now. A frozen player (mid-throw) gets the
-- speed when they are released. The look is put on anew only when the stage changes: putting
-- it on cuts every ribbon and starts every particle over.
local function suit(player: Player, data: Data.Data, was: number)
	local level = runLevel(data)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.WalkSpeed > 0 then
		humanoid.WalkSpeed = Economy.walkSpeed(level)
	end
	if character and SpeedStages.at(was) ~= SpeedStages.at(level) then
		SpeedLook.apply(character, level)
	end
end

local function buy(player: Player, item: unknown)
	local data = Data.get(player)
	local stall = if typeof(item) == "string" then STALL_OF[item] else nil
	if not data or not stall or not Market.playerAt(player, stall) then
		return
	end

	if item == "kunai" then
		-- Kunai are bought in order; the newest one is the one in use.
		local nextKunai = Catalog.kunai[data.kunai + 1]
		if nextKunai and pay(player, data, nextKunai.price) then
			data.kunai += 1
		end
	elseif item == "speed" then
		if
			data.speedLevel < Tuning.Speed.maxLevel
			and pay(player, data, Economy.speedPrice(data.speedLevel))
		then
			local before = SpeedStages.at(data.speedLevel)
			local was = runLevel(data)
			data.speedLevel += 1
			-- Whoever buys a level means to run at it, whatever they had chosen before.
			data.runAt = -1
			suit(player, data, was)
			-- A Gate opening is news for everyone.
			local stage = SpeedStages.at(data.speedLevel)
			if stage ~= before and stage.gate > 0 then
				for _, other in Players:GetPlayers() do
					if other ~= player then
						State.notify(other, "GateOpenedBy", player.DisplayName, stage.name)
					end
				end
			end
		end
	end

	State.push(player)
end

-- A player may run slower than they have bought: the plaza is small for the top speeds, and
-- an earlier stage's look goes with its speed. Chosen at the training ground's counter, like a
-- purchase; the fastest bought is not kept as a choice, so that it follows the next purchase.
local function runAt(player: Player, level: unknown)
	local data = Data.get(player)
	-- `level == level` is false only for NaN.
	local sane = typeof(level) == "number" and level == level
	if not data or not sane or not Market.playerAt(player, "speed") then
		return
	end
	local was = runLevel(data)
	local chosen = math.floor(level :: number)
	data.runAt = if chosen < 0 or chosen >= data.speedLevel then -1 else chosen
	suit(player, data, was)
	State.push(player)
end

-- Sells the named units out of the inventory. Units standing on a pad are not for sale: they
-- have to be taken off first.
local function sell(player: Player, unitIds: unknown)
	local data = Data.get(player)
	if not data or typeof(unitIds) ~= "table" or not Market.playerAt(player, "sell") then
		return
	end

	local onPad: { [string]: boolean } = {}
	for _, unitId in data.pads do
		onPad[unitId] = true
	end

	local sold, earned = 0, 0
	local lastTitle = ""
	for index, unitId in unitIds :: { unknown } do
		if index > MAX_SOLD_AT_ONCE then
			break
		end
		local unit = if typeof(unitId) == "string" then data.units[unitId] else nil
		if typeof(unitId) == "string" and unit and not onPad[unitId] then
			data.units[unitId] = nil
			if Inventory.held(player) == unitId then
				Inventory.hold(player, nil)
			end
			sold += 1
			earned += Economy.sellPrice(unit)
			lastTitle = Catalog.unitTitle(unit.character, unit.mutation, unit.level, unit.upgrade)
		end
	end
	if sold == 0 then
		return
	end

	data.ryo += earned
	Inventory.sync(player)
	if sold == 1 then
		State.notify(player, "Sold", lastTitle, earned)
	else
		State.notify(player, "SoldMany", sold, earned)
	end
	State.push(player)
end

function Shop.start()
	Remotes.Buy.OnServerEvent:Connect(buy)
	Remotes.RunAt.OnServerEvent:Connect(runAt)
	Remotes.Sell.OnServerEvent:Connect(sell)

	-- Not a tool, but the same moment: every fresh character gets the bought run speed.
	Loadout.register(function(player, _character, _backpack, humanoid)
		local data = Data.get(player)
		if data then
			humanoid.WalkSpeed = Economy.walkSpeed(runLevel(data))
		end
	end)
end

return Shop
