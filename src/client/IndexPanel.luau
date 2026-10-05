--!strict
-- The Bingo Book window. Pages down the left side, one per mutation ("None" first), each with
-- how many of its shinobi have been found. A page lists every character with the income it
-- would earn with that mutation; the ones not found yet are black silhouettes. A complete page
-- gives a permanent income bonus.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Hud = require("./Hud")
local Icons = require("./Icons")
local Index = require(ReplicatedStorage.Shared.Logic.Index)
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")
local UnitCard = require("./UnitCard")

local IndexPanel = {}

local TAB_WIDTH = 230

-- Display name and color of a page.
local function pageLook(page: string): (string, Color3)
	local mutation = Catalog.mutationById[page]
	if mutation then
		return mutation.name, Color3.fromHex(mutation.color)
	end
	return Strings.get("IndexPlain"), Ui.WHITE
end

function IndexPanel.start()
	local window = Ui.window("Index", Vector2.new(1010, 640))
	window.title.Text = Strings.get("IndexTitle")

	local opener = Hud.sideButton(Strings.get("IndexButton"), Ui.BLUE, Icons.book)
	opener.LayoutOrder = 2
	opener.Activated:Connect(window.toggle)

	local tabs = Ui.scroll(window.body, {
		Size = UDim2.new(0, TAB_WIDTH, 1, 0),
	})
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, tabs)
	Ui.padding(tabs, 3)

	local header = Ui.text(window.body, {
		Position = UDim2.fromOffset(TAB_WIDTH + 12, 0),
		Size = UDim2.new(1, -TAB_WIDTH - 12, 0, 38),
		TextSize = 21,
		TextWrapped = true,
	})
	local grid = Ui.scroll(window.body, {
		Position = UDim2.fromOffset(TAB_WIDTH + 12, 46),
		Size = UDim2.new(1, -TAB_WIDTH - 12, 1, -46),
	})
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(UnitCard.SIZE.X, UnitCard.SIZE.Y),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	Ui.padding(grid, 3)

	local selected = Index.pages[1]
	local tabButtons: { [string]: TextButton } = {}
	local cards: { TextButton } = {}
	local bonusPercent = Tuning.Index.pageCompleteBonus * 100

	local function redraw()
		local found = Store.found()
		local total = #Catalog.characters

		for page, button in tabButtons do
			local name = pageLook(page)
			local count = Index.count(found, page)
			button.Text = Strings.get("IndexTab", name, count, total)
			button.BackgroundColor3 = if page == selected then Ui.EDGE else Ui.CARD
		end

		local name, color = pageLook(selected)
		local count = Index.count(found, selected)
		header.Text = if count == total
			then Strings.get("IndexComplete", name, bonusPercent)
			else Strings.get("IndexProgress", name, count, total, bonusPercent)
		header.TextColor3 = if count == total then Ui.GOLD else color

		for _, card in cards do
			card:Destroy()
		end
		cards = {}
		-- Characters are listed in config order, which runs from the lowest rank up.
		for order, character in Catalog.characters do
			local unit = { character = character.id, mutation = selected, level = 1 }
			local card = UnitCard.build(grid, unit, Index.has(found, character.id, selected))
			card.LayoutOrder = order
			card.AutoButtonColor = false
			table.insert(cards, card)
		end
	end

	for order, page in Index.pages do
		local _, color = pageLook(page)
		local button = Ui.button(tabs, {
			LayoutOrder = order,
			Size = UDim2.new(1, -8, 0, 50),
			BackgroundColor3 = Ui.CARD,
			TextColor3 = color,
			TextSize = 21,
		})
		button.Activated:Connect(function()
			selected = page
			redraw()
		end)
		tabButtons[page] = button
	end

	Store.onIndex(redraw)
end

return IndexPanel
