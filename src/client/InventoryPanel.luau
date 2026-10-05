--!strict
-- The inventory window: every shinobi the player owns that is not standing on a pad. Clicking
-- one makes the character carry it, which is what pads and the selling stall act on; clicking
-- the carried one again, or "Put away", frees the hands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Hud = require("./Hud")
local Icons = require("./Icons")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Ui = require("./Ui")
local UnitCard = require("./UnitCard")

local InventoryPanel = {}

function InventoryPanel.start()
	local window = Ui.window("Inventory", Vector2.new(580, 420))
	window.title.Text = Strings.get("InventoryTitle")

	local opener, counter = Hud.sideButton(Strings.get("InventoryButton"), Ui.GOLD, Icons.scroll)
	opener.LayoutOrder = 1
	opener.Activated:Connect(window.toggle)

	-- While a shinobi is carried, a strip above the hotbar names it and puts it away in one
	-- click or key press, without opening the window.
	local carried = Ui.panel(Ui.screen("Carried", 11), {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -78),
		Size = UDim2.fromOffset(380, 36),
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	Ui.stroke(carried, Ui.GOLD, 2)
	local carriedName = Ui.text(carried, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -160, 1, 0),
		Font = Ui.BRUSH,
		TextSize = 17,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local stow = Ui.button(carried, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -5, 0.5, 0),
		Size = UDim2.fromOffset(140, 26),
		BackgroundColor3 = Ui.GRAY,
		TextSize = 14,
		Text = if UserInputService.KeyboardEnabled
			then Strings.get("CarriedPutAwayKey")
			else Strings.get("InventoryPutAway"),
	})
	local function putCarriedAway()
		Remotes.Hold:FireServer(nil)
	end
	stow.Activated:Connect(putCarriedAway)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and carried.Visible and input.KeyCode == Enum.KeyCode.G then
			putCarriedAway()
		end
	end)

	local hint = Ui.text(window.body, {
		Size = UDim2.new(1, -150, 0, 30),
		TextSize = 14,
		TextColor3 = Ui.MUTED,
		TextWrapped = true,
		Text = Strings.get("InventoryHint"),
	})
	local putAway = Ui.button(window.body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(136, 30),
		BackgroundColor3 = Ui.GRAY,
		TextSize = 15,
		Text = Strings.get("InventoryPutAway"),
		Visible = false,
	})
	putAway.Activated:Connect(function()
		Remotes.Hold:FireServer(nil)
	end)

	local list = Ui.scroll(window.body, {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -40),
	})
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(UnitCard.SIZE.X, UnitCard.SIZE.Y),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
	Ui.padding(list, 3)

	local cards: { TextButton } = {}
	local shownHeld: string? = nil

	-- Rebuilds the grid: the carried unit first, then the rest from richest to poorest.
	local function redraw()
		local inventory: Net.Inventory = Store.inventory()
		local state = Store.get()
		local held = if state then state.held else nil
		shownHeld = held

		for _, card in cards do
			card:Destroy()
		end
		cards = {}

		local ids: { string } = {}
		for unitId in inventory do
			table.insert(ids, unitId)
		end
		table.sort(ids, function(a, b)
			if (a == held) ~= (b == held) then
				return a == held
			end
			local incomeA = Economy.unitIncome(inventory[a])
			local incomeB = Economy.unitIncome(inventory[b])
			if incomeA ~= incomeB then
				return incomeA > incomeB
			end
			return a < b
		end)

		for order, unitId in ids do
			local card = UnitCard.build(list, inventory[unitId], true)
			card.LayoutOrder = order
			-- The carried one gets a thick gold outline in place of its rank-colored one.
			local outline = card:FindFirstChildOfClass("UIStroke")
			if unitId == held and outline then
				outline.Color = Ui.GOLD
				outline.Thickness = 4
			end
			card.Activated:Connect(function()
				-- Carrying is how a shinobi gets to a pad, so the window gets out of the way.
				if unitId == held then
					Remotes.Hold:FireServer(nil)
				else
					Remotes.Hold:FireServer(unitId)
					window.close()
				end
			end)
			table.insert(cards, card)
		end

		hint.Text = if #ids == 0
			then Strings.get("InventoryEmpty")
			else Strings.get("InventoryHint")
		putAway.Visible = held ~= nil
		counter.Text = tostring(#ids)
		counter.Visible = #ids > 0

		local heldUnit = if held then inventory[held] else nil
		carried.Visible = heldUnit ~= nil
		if heldUnit then
			local title = Catalog.unitTitle(
				heldUnit.character,
				heldUnit.mutation,
				heldUnit.level,
				heldUnit.upgrade
			)
			carriedName.Text = Strings.get("CarriedName", title)
		end
	end

	Store.onInventory(redraw)
	Store.onChange(function(state)
		if state.held ~= shownHeld then
			redraw()
		end
	end)
end

return InventoryPanel
