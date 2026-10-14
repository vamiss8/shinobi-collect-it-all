--!strict
-- The shop where things are bought for Robux (Config/Products): a tile on the right edge,
-- over the Inventory's, and the window it opens. Four pages under tabs: the passes, with the
-- Daimyo's VIP on a sheet of its own at the head; the potions that boost for a while; Ryo; and
-- the legendary shinobi, which stand on the plaza too.
--
-- The window only opens Roblox's own purchase window; what a purchase gives the server decides
-- (Services/Purchases, Services/Legends) and the next snapshot shows. No price is written in
-- the game: each is asked of Roblox for this very player, who may be offered a price of their
-- region's.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Hud = require("./Hud")
local Icons = require("./Icons")
local PurchaseLogic = require(ReplicatedStorage.Shared.Logic.Purchases)
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local ShopPanel = {}

local SIZE = Vector2.new(1000, 720)
-- The tabs across the top, and where the pages under them begin.
local TAB = Vector2.new(226, 54)
local TAB_GAP = 12
local PAGE_TOP = 70
-- A card: one thing for sale. Three to a row.
local CARD = Vector2.new(296, 334)
local CARD_GAP = 14
local PER_ROW = 3
local WHAT_SIZE = 20
local WHAT_ROOM = CARD.X - 28
-- The VIP's sheet at the head of the passes.
local VIP_HEIGHT = 214
local VIP_LINE = 24

type Page = string
local PAGES: { Page } = { "passes", "boosts", "ryo", "legends" }
local PAGE_WORDS: { [Page]: string } = {
	passes = "ShopTabPasses",
	boosts = "ShopTabBoosts",
	ryo = "ShopTabRyo",
	legends = "ShopTabLegends",
}

-- What a thing for sale can be shown as: not on sale yet, the player's already, had already
-- (a product sold once), not for this player now, or to be bought.
type Mode = "soon" | "owned" | "bought" | "blocked" | "buy"

-- A thing for sale as the window shows it.
type Item = {
	key: string,
	assetId: number,
	pass: boolean, -- a game pass, bought once; or else a developer product
	button: TextButton,
	status: TextLabel?,
	mode: Mode,
}

-- Prices as Roblox gives them to this player, by asset id.
local prices: { [number]: number } = {}

-- "12:05" for seconds.
local function clock(seconds: number): string
	local whole = math.max(math.floor(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- The words that say what a thing does: the minutes of a potion or a bundle, the time a pack
-- of Ryo is worth.
local function what(key: string): string
	local product = Catalog.productByKey[key]
	if not product then
		return Strings.get("GoodsWhat_" .. key)
	end
	if product.kind == "potion" and product.potion then
		local potion = Catalog.potionById[product.potion]
		return Strings.get("GoodsWhat_" .. key, if potion then potion.minutes else 0)
	elseif product.kind == "bundle" then
		return Strings.get("GoodsWhat_" .. key, product.minutes or 0)
	elseif product.kind == "ryo" then
		return Strings.get("GoodsWhat_" .. key, Format.duration((product.incomeMinutes or 0) * 60))
	end
	return Strings.get("GoodsWhat_" .. key)
end

-- A card for one thing: its icon, its name, what it does in a few short lines, a line of how
-- it stands (a potion's time, what a pack pays), and the button that buys it.
local function card(
	parent: Instance,
	key: string,
	title: string,
	words: string,
	edge: Color3,
	order: number
): (TextButton, TextLabel)
	local frame = Ui.panel(parent, {
		Size = UDim2.fromOffset(CARD.X, CARD.Y),
		BackgroundColor3 = Ui.CARD,
		BackgroundTransparency = 0,
		LayoutOrder = order,
	})
	Ui.stroke(frame, edge, 3)
	local holder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(96, 96),
		BackgroundTransparency = 1,
	}, frame)
	Icons.goods(holder, key)
	Ui.text(frame, {
		Position = UDim2.fromOffset(12, 116),
		Size = UDim2.new(1, -24, 0, 34),
		TextSize = 27,
		TextColor3 = Ui.PARCHMENT,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = title,
	})
	Ui.text(frame, {
		Position = UDim2.fromOffset(14, 154),
		Size = UDim2.new(1, -28, 0, 78),
		TextSize = WHAT_SIZE,
		TextColor3 = Ui.MUTED,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = Ui.lines(words, WHAT_SIZE, WHAT_ROOM),
	})
	local status = Ui.text(frame, {
		Position = UDim2.fromOffset(12, 234),
		Size = UDim2.new(1, -24, 0, 28),
		TextSize = 22,
		TextColor3 = Ui.GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local button = Ui.button(frame, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(CARD.X - 40, 54),
		BackgroundColor3 = Ui.GOLD,
		TextColor3 = Ui.INK,
		TextSize = 27,
	})
	return button, status
end

-- The cards of a page, three to a row, under whatever stands at its head.
local function grid(page: Instance, count: number, order: number): Frame
	local rows = math.max(math.ceil(count / PER_ROW), 1)
	local frame = Ui.make("Frame", {
		Size = UDim2.new(1, -12, 0, rows * CARD.Y + (rows - 1) * CARD_GAP),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, page)
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD.X, CARD.Y),
		CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
		FillDirectionMaxCells = PER_ROW,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	return frame
end

-- The Daimyo's VIP: a sheet of parchment in a gilt outline, its seal, what it gives in ink,
-- and the button.
local function vipSheet(page: Instance): TextButton
	local sheet = Ui.make("Frame", {
		Size = UDim2.new(1, -12, 0, VIP_HEIGHT),
		BackgroundColor3 = Ui.PARCHMENT,
		BorderSizePixel = 0,
		LayoutOrder = 1,
	}, page)
	Ui.corner(sheet, 12)
	Ui.stroke(sheet, Ui.GOLD, 4)
	local holder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 26, 0.5, 0),
		Size = UDim2.fromOffset(156, 156),
		BackgroundTransparency = 1,
	}, sheet)
	Icons.goods(holder, "Vip")
	Ui.text(sheet, {
		Position = UDim2.fromOffset(204, 18),
		Size = UDim2.new(1, -480, 0, 52),
		TextSize = 44,
		TextColor3 = Ui.INK,
		Text = Strings.get("ShopVipTitle"),
	})
	local lines = {
		Strings.get("ShopVipIncome", Tuning.Shop.vipIncome),
		Strings.get("ShopVipOffline", Tuning.Shop.vipOffline),
		Strings.get("ShopVipSeal"),
	}
	for index, words in lines do
		local top = 76 + (index - 1) * 40
		local dot = Ui.make("Frame", {
			Position = UDim2.fromOffset(206, top + 10),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = Ui.SEAL,
			BorderSizePixel = 0,
		}, sheet)
		Ui.corner(dot, 7)
		Ui.text(sheet, {
			Position = UDim2.fromOffset(230, top),
			Size = UDim2.new(1, -500, 0, 34),
			TextSize = VIP_LINE,
			TextColor3 = Ui.INK,
			Text = words,
		})
	end
	return Ui.button(sheet, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -26, 0.5, 0),
		Size = UDim2.fromOffset(236, 74),
		BackgroundColor3 = Ui.GOLD,
		TextColor3 = Ui.INK,
		TextSize = 32,
	})
end

function ShopPanel.start()
	local window = Ui.window("Shop", SIZE)
	window.title.Text = Strings.get("ShopTitle")
	local body = window.body

	local tile = Hud.sideButton(Strings.get("ShopButton"), Ui.RED, Icons.shop)
	tile.LayoutOrder = 0
	tile.Activated:Connect(window.toggle)

	local items: { Item } = {}
	local function add(
		key: string,
		assetId: number,
		pass: boolean,
		button: TextButton,
		status: TextLabel?
	)
		local item: Item = {
			key = key,
			assetId = assetId,
			pass = pass,
			button = button,
			status = status,
			mode = "soon",
		}
		table.insert(items, item)
		button.Activated:Connect(function()
			if item.mode ~= "buy" then
				return
			end
			local player = Players.LocalPlayer
			if item.pass then
				MarketplaceService:PromptGamePassPurchase(player, item.assetId)
			else
				MarketplaceService:PromptProductPurchase(player, item.assetId)
			end
		end)
	end

	-- The pages, one shown at a time.
	local pages: { [Page]: ScrollingFrame } = {}
	local tabs: { [Page]: TextButton } = {}
	local shown: Page = "passes"
	local function show(page: Page)
		shown = page
		for name, frame in pages do
			frame.Visible = name == page
			local tab = tabs[name]
			tab.BackgroundColor3 = if name == page then Ui.GOLD else Ui.CARD
			tab.TextColor3 = if name == page then Ui.INK else Ui.PARCHMENT
		end
	end
	local left = (SIZE.X - 32 - #PAGES * TAB.X - (#PAGES - 1) * TAB_GAP) / 2
	for index, page in PAGES do
		local frame = Ui.scroll(body, {
			Position = UDim2.fromOffset(0, PAGE_TOP),
			Size = UDim2.new(1, 0, 1, -PAGE_TOP),
			ScrollBarThickness = 8,
			Visible = false,
		})
		Ui.make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 16),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}, frame)
		Ui.padding(frame, 4)
		pages[page] = frame
		local tab = Ui.button(body, {
			Position = UDim2.fromOffset(left + (index - 1) * (TAB.X + TAB_GAP), 0),
			Size = UDim2.fromOffset(TAB.X, TAB.Y),
			BackgroundColor3 = Ui.CARD,
			TextSize = 28,
			Text = Strings.get(PAGE_WORDS[page]),
		})
		tab.Activated:Connect(function()
			show(page)
		end)
		tabs[page] = tab
	end

	-- The passes: the VIP at the head, the others under it.
	local vip = Catalog.passByKey.Vip
	if vip then
		add(vip.key, vip.assetId, true, vipSheet(pages.passes), nil)
	end
	local others = {}
	local legends = {}
	for _, pass in Catalog.passes do
		if pass.kind == "boost" or pass.kind == "pads" then
			table.insert(others, pass)
		elseif pass.kind == "legend" then
			table.insert(legends, pass)
		end
	end
	local passGrid = grid(pages.passes, #others, 2)
	for order, pass in others do
		local button, status = card(
			passGrid,
			pass.key,
			Strings.get("Goods_" .. pass.key),
			what(pass.key),
			Ui.GOLD,
			order
		)
		status.Text = Strings.get("ShopForGood")
		add(pass.key, pass.assetId, true, button, status)
	end

	-- The potions and the bundle; and the packs of Ryo.
	local boosts, packs = {}, {}
	for _, product in Catalog.products do
		if product.kind == "potion" or product.kind == "bundle" then
			table.insert(boosts, product)
		elseif product.kind == "ryo" then
			table.insert(packs, product)
		end
	end
	local boostGrid = grid(pages.boosts, #boosts, 1)
	for order, product in boosts do
		local button, status = card(
			boostGrid,
			product.key,
			Strings.get("Goods_" .. product.key),
			what(product.key),
			Ui.BLUE,
			order
		)
		add(product.key, product.assetId, false, button, status)
	end
	local packGrid = grid(pages.ryo, #packs, 1)
	for order, product in packs do
		local button, status = card(
			packGrid,
			product.key,
			Strings.get("Goods_" .. product.key),
			what(product.key),
			Ui.GOLD,
			order
		)
		add(product.key, product.assetId, false, button, status)
	end

	-- The legendary shinobi.
	local legendGrid = grid(pages.legends, #legends, 1)
	for order, pass in legends do
		local legend = nil
		for _, each in Catalog.legends do
			if each.pass == pass.key then
				legend = each
			end
		end
		if legend then
			local button, status = card(
				legendGrid,
				legend.id,
				legend.name,
				Strings.get("ShopLegendWhat"),
				Color3.fromHex(Catalog.legendRank.color),
				order
			)
			status.Text = Strings.get("ShopLegendIncome", legend.income)
			add(pass.key, pass.assetId, true, button, status)
		end
	end

	local function draw()
		local state = Store.get()
		if not state then
			return
		end
		local owned: { [string]: boolean } = {}
		for _, key in state.passes do
			owned[key] = true
		end
		for _, legendId in state.legends do
			local legend = Catalog.legendById[legendId]
			if legend then
				owned[legend.pass] = true
			end
		end
		local had: { [string]: boolean } = {}
		for _, key in state.bought do
			had[key] = true
		end

		for _, item in items do
			local product = Catalog.productByKey[item.key]
			local mode: Mode = "buy"
			if item.assetId <= 0 then
				mode = "soon"
			elseif item.pass and owned[item.key] then
				mode = "owned"
			elseif product and product.once and had[item.key] then
				mode = "bought"
			elseif product and product.kind == "ryo" and state.income <= 0 then
				mode = "blocked"
			end
			item.mode = mode

			local price = prices[item.assetId]
			local button = item.button
			button.Text = if mode == "soon"
				then Strings.get("GoodsSoonButton")
				elseif mode == "owned" then Strings.get("GoodsOwned")
				elseif mode == "bought" then Strings.get("GoodsBought")
				elseif price then Strings.get("GoodsPrice", tostring(price))
				else Strings.get("GoodsPriceLoading")
			button.BackgroundColor3 = if mode == "buy"
				then Ui.GOLD
				elseif mode == "owned" then Ui.GREEN
				else Ui.GRAY
			button.TextColor3 = if mode == "buy" then Ui.INK else Ui.WHITE
			button.AutoButtonColor = mode == "buy"

			local status = item.status
			if status and product then
				if product.kind == "potion" and product.potion then
					local running = state.potions[product.potion]
					status.Text = if running then Strings.get("ShopActive", clock(running)) else ""
					status.TextColor3 = Ui.GREEN
				elseif product.kind == "bundle" then
					status.Text = if mode == "bought" then "" else Strings.get("ShopOnce")
					status.TextColor3 = Ui.GOLD
				elseif product.kind == "ryo" then
					local pays = PurchaseLogic.ryoPack(state.income, product.incomeMinutes or 0)
					status.Text = if mode == "blocked"
						then Strings.get("ShopRyoNeedsIncome")
						else Strings.get("ShopRyoPays", pays)
					status.TextColor3 = if mode == "blocked" then Ui.RED else Ui.GOLD
				end
			end
		end
	end

	-- Prices are asked of Roblox the first time the window opens, and asked again for any that
	-- did not come.
	local function fetchPrices()
		for _, item in items do
			if item.assetId > 0 and not prices[item.assetId] then
				task.spawn(function()
					local ok, info = pcall(function()
						return MarketplaceService:GetProductInfo(
							item.assetId,
							if item.pass then Enum.InfoType.GamePass else Enum.InfoType.Product
						)
					end)
					local robux = if ok and typeof(info) == "table" then info.PriceInRobux else nil
					if typeof(robux) == "number" then
						prices[item.assetId] = robux
						draw()
					end
				end)
			end
		end
	end
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.frame.Visible then
			fetchPrices()
			draw()
		end
	end)

	show(shown)
	Store.onChange(function()
		if window.isOpen() then
			draw()
		end
	end)
	draw()
end

return ShopPanel
