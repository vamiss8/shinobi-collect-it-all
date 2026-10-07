--!strict
-- The market's three shops. Tenten's Ninja Tools sells kunai, the Speed Store sells run speed,
-- and the Sell stall buys shinobi out of the inventory. The windows live on the client; the
-- server only accepts a request from a player who is actually standing at that shop's counter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Data = require("../Data")
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Inventory = require("./Inventory")
local Loadout = require("./Loadout")
local Market = require("../World/Market")
local Remotes = require("../Remotes")
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
			data.speedLevel += 1
			local character = player.Character
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			-- A frozen player (mid-throw) gets the new speed when they are released.
			if humanoid and humanoid.WalkSpeed > 0 then
				humanoid.WalkSpeed = Economy.walkSpeed(data.speedLevel)
			end
		end
	end

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
	Remotes.Sell.OnServerEvent:Connect(sell)

	-- Not a tool, but the same moment: every fresh character gets the bought run speed.
	Loadout.register(function(player, _character, _backpack, humanoid)
		local data = Data.get(player)
		if data then
			humanoid.WalkSpeed = Economy.walkSpeed(data.speedLevel)
		end
	end)
end

return Shop
