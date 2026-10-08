--!strict
-- The Mission Desk window (World/MissionDesk), the shop "sell": every shinobi in the inventory
-- with the reward the desk pays for sending it on its last mission. That is a sale by another
-- name, and the code calls it one: the shinobi is gone and the Ryo is paid. A click sends one;
-- "Send all" sends the lot and asks to be clicked twice, since it cannot be undone. Shinobi
-- standing on pads are not listed: they have to be taken off first. The legendary shinobi are
-- not listed either: the desk does not take them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("../Remotes")
local Store = require("../Store")
local Strings = require("../Strings")
local Ui = require("../Ui")
local UnitCard = require("../UnitCard")

local SellStall = {}

-- How long "Send all" stays armed after the first click, seconds.
local CONFIRM_SECONDS = 3

function SellStall.build(): Ui.Window
	local window = Ui.window("SellStall", Vector2.new(770, 620))
	window.title.Text = Strings.get("SellTitle")

	local hint = Ui.text(window.body, {
		Size = UDim2.new(1, -300, 0, 44),
		TextSize = 19,
		TextColor3 = Ui.MUTED,
		TextWrapped = true,
	})
	local sellAll = Ui.button(window.body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(290, 42),
		BackgroundColor3 = Ui.RED,
		TextSize = 19,
	})
	local list = Ui.scroll(window.body, {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
	})
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(UnitCard.SIZE.X, UnitCard.SIZE.Y),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
	Ui.padding(list, 3)

	local cards: { TextButton } = {}
	local ids: { string } = {}
	local total = 0
	-- Counts the arming of "Sell all", so an old timer cannot disarm a newer click.
	local armed = 0
	local isArmed = false

	local function drawSellAll()
		sellAll.Visible = #ids > 0
		sellAll.Text = if isArmed
			then Strings.get("SellAllConfirm", #ids, total)
			else Strings.get("SellAll")
	end

	-- Rebuilds the grid, cheapest first: those are the ones a player wants rid of.
	local function redraw(inventory: Net.Inventory)
		for _, card in cards do
			card:Destroy()
		end
		cards = {}
		ids = {}
		total = 0
		isArmed = false

		for unitId, unit in inventory do
			if not Catalog.isLegend(unit.character) then
				table.insert(ids, unitId)
			end
		end
		table.sort(ids, function(a, b)
			local priceA = Economy.sellPrice(inventory[a])
			local priceB = Economy.sellPrice(inventory[b])
			if priceA ~= priceB then
				return priceA < priceB
			end
			return a < b
		end)

		for order, unitId in ids do
			local unit = inventory[unitId]
			local price = Economy.sellPrice(unit)
			total += price
			local card = UnitCard.build(list, unit, true, Strings.get("SellPrice", price))
			card.LayoutOrder = order
			card.Activated:Connect(function()
				Remotes.Sell:FireServer({ unitId })
			end)
			table.insert(cards, card)
		end

		hint.Text = if #ids == 0 then Strings.get("SellEmpty") else Strings.get("SellHint")
		drawSellAll()
	end

	sellAll.Activated:Connect(function()
		if #ids == 0 then
			return
		end
		if isArmed then
			isArmed = false
			Remotes.Sell:FireServer(ids)
		else
			isArmed = true
			armed += 1
			local mine = armed
			task.delay(CONFIRM_SECONDS, function()
				if armed == mine and isArmed then
					isArmed = false
					drawSellAll()
				end
			end)
		end
		drawSellAll()
	end)

	Store.onInventory(redraw)
	return window
end

return SellStall
