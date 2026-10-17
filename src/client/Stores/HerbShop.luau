--!strict
-- The window of Kabuto's Remedies (World/PotionStall), the potions' shop: the Herbs the player
-- has at the top, and under them every potion with how many are in the pouch and how long the
-- one running has left, and three buttons: buy one for Herbs, buy one for Robux, drink one.
-- Last, the bundle, for Robux.
-- What is bought goes into the pouch (Logic/Pouch); the server checks the Herbs, and that the
-- player is at the counter for a purchase in Herbs. Drinking is the same as from the Shop
-- window's Boosts page, which works anywhere.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Icons = require("../Icons")
local Prices = require("../Prices")
local Remotes = require("../Remotes")
local Store = require("../Store")
local Strings = require("../Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("../Ui")

local HerbShop = {}

local SIZE = Vector2.new(900, 740)
local HINT_HEIGHT = Ui.NOTE_HEIGHT + 6
local HEADER_HEIGHT = 112
local HEADER_ICON = 88
local ROW_HEIGHT = 128
local ROW_GAP = 8
local ROW_ICON = 88
-- The buttons at a row's right: buying for Herbs over buying for Robux, drinking beside them.
local BUY = Vector2.new(180, 52)
local DRINK = Vector2.new(150, 112)
local BUTTON_GAP = 8
local TEXT_LEFT = 116
local TEXT_ROOM = SIZE.X - 32 - 16 - TEXT_LEFT - BUY.X - DRINK.X - BUTTON_GAP - 36
local WHAT_SIZE = 20

-- "12:05" for seconds.
local function clock(seconds: number): string
	local whole = math.max(math.floor(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

type Row = {
	potion: Catalog.Potion?, -- none for the bundle
	product: Catalog.Product?,
	status: TextLabel,
	herbs: TextButton?,
	robux: TextButton,
	drink: TextButton?,
}

-- The product that sells a potion for Robux.
local function productOf(potionId: string): Catalog.Product?
	for _, product in Catalog.products do
		if product.kind == "potion" and product.potion == potionId then
			return product
		end
	end
	return nil
end

-- Paints a button as one that would do something, or not.
local function ready(button: TextButton, can: boolean, color: Color3)
	button.BackgroundColor3 = if can then color else Ui.GRAY
	button.TextColor3 = if can and color == Ui.GOLD then Ui.INK else Ui.WHITE
	button.AutoButtonColor = can
end

function HerbShop.build(): Ui.Window
	local window = Ui.window("HerbShop", SIZE)
	window.title.Text = Strings.get("HerbTitle")
	local body = window.body

	Ui.note(body, {}, SIZE.X - 32, Strings.get("HerbHint"))

	-- The Herbs the player has, and how they are earned.
	local header = Ui.panel(body, {
		Position = UDim2.fromOffset(0, HINT_HEIGHT + 4),
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundColor3 = Ui.CARD,
		BackgroundTransparency = 0,
	})
	Ui.stroke(header, Ui.GREEN, 2)
	local inset = (HEADER_HEIGHT - HEADER_ICON) / 2
	local icon = Ui.make("Frame", {
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.fromOffset(HEADER_ICON, HEADER_ICON),
		BackgroundTransparency = 1,
	}, header)
	Icons.herb(icon)
	local left = inset * 2 + HEADER_ICON
	Ui.text(header, {
		Position = UDim2.fromOffset(left, 10),
		Size = UDim2.new(1, -left - 16, 0, 22),
		TextSize = 20,
		TextColor3 = Ui.GOLD,
		Text = Strings.get("HerbYours"),
	})
	local amount = Ui.text(header, {
		Position = UDim2.fromOffset(left, 32),
		Size = UDim2.new(1, -left - 16, 0, 42),
		TextSize = 36,
		TextColor3 = Ui.PARCHMENT,
	})
	Ui.text(header, {
		Position = UDim2.fromOffset(left, 76),
		Size = UDim2.new(1, -left - 16, 0, 26),
		TextSize = 21,
		TextColor3 = Ui.GREEN,
		Text = Strings.get(
			"HerbEarn",
			Tuning.Herbs.perZone,
			Tuning.Herbs.perZone * 5,
			Tuning.Herbs.perfect
		),
	})

	local listTop = HINT_HEIGHT + HEADER_HEIGHT + 14
	local list = Ui.scroll(body, {
		Position = UDim2.fromOffset(0, listTop),
		Size = UDim2.new(1, 0, 1, -listTop),
		ScrollBarThickness = 8,
	})
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, ROW_GAP),
	}, list)
	Ui.padding(list, 3)

	local rows: { Row } = {}
	local function row(order: number, key: string, words: string, potion: Catalog.Potion?): Row
		local product = if potion then productOf(potion.id) else Catalog.productByKey[key]
		local frame = Ui.panel(list, {
			LayoutOrder = order,
			Size = UDim2.new(1, -16, 0, ROW_HEIGHT),
			BackgroundColor3 = Ui.CARD,
			BackgroundTransparency = 0,
		})
		Ui.stroke(frame, Ui.BLUE, 2)
		local holder = Ui.make("Frame", {
			Position = UDim2.fromOffset(14, (ROW_HEIGHT - ROW_ICON) / 2),
			Size = UDim2.fromOffset(ROW_ICON, ROW_ICON),
			BackgroundTransparency = 1,
		}, frame)
		Icons.goods(holder, key)
		Ui.text(frame, {
			Position = UDim2.fromOffset(TEXT_LEFT, 8),
			Size = UDim2.fromOffset(TEXT_ROOM, 32),
			TextSize = 26,
			TextColor3 = Ui.PARCHMENT,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = Strings.get("Goods_" .. key),
		})
		Ui.text(frame, {
			Position = UDim2.fromOffset(TEXT_LEFT, 42),
			Size = UDim2.fromOffset(TEXT_ROOM, 50),
			TextSize = WHAT_SIZE,
			TextColor3 = Ui.MUTED,
			TextYAlignment = Enum.TextYAlignment.Top,
			Text = Ui.lines(words, WHAT_SIZE, TEXT_ROOM),
		})
		local status = Ui.text(frame, {
			Position = UDim2.fromOffset(TEXT_LEFT, 94),
			Size = UDim2.fromOffset(TEXT_ROOM, 26),
			TextSize = 21,
			TextColor3 = Ui.GOLD,
			RichText = true,
		})

		local right = -14
		local drink: TextButton? = nil
		if potion then
			local button = Ui.button(frame, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, right, 0.5, 0),
				Size = UDim2.fromOffset(DRINK.X, DRINK.Y),
				TextSize = 25,
			})
			button.Activated:Connect(function()
				local state = Store.get()
				if state and (state.stock[potion.id] or 0) > 0 then
					Remotes.Drink:FireServer(potion.id)
				end
			end)
			drink = button
			right -= DRINK.X + BUTTON_GAP
		end
		local herbs: TextButton? = nil
		if potion then
			local button = Ui.button(frame, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, right, 0, (ROW_HEIGHT - DRINK.Y) / 2),
				Size = UDim2.fromOffset(BUY.X, BUY.Y),
				TextSize = 24,
				Text = Strings.get("HerbBuy", potion.herbs),
			})
			button.Activated:Connect(function()
				local state = Store.get()
				if state and state.herbs >= potion.herbs then
					Remotes.BuyPotion:FireServer(potion.id)
				end
			end)
			herbs = button
		end
		local robux = Ui.button(frame, {
			AnchorPoint = Vector2.new(1, if potion then 1 else 0.5),
			Position = if potion
				then UDim2.new(1, right, 1, -(ROW_HEIGHT - DRINK.Y) / 2)
				else UDim2.new(1, right, 0.5, 0),
			Size = UDim2.fromOffset(BUY.X, BUY.Y),
			TextSize = 24,
		})
		robux.Activated:Connect(function()
			if product and product.assetId > 0 then
				MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.assetId)
			end
		end)
		local entry: Row = {
			potion = potion,
			product = product,
			status = status,
			herbs = herbs,
			robux = robux,
			drink = drink,
		}
		table.insert(rows, entry)
		return entry
	end

	for order, potion in Catalog.potions do
		local product = productOf(potion.id)
		local key = if product then product.key else potion.id
		row(order, key, Strings.get("GoodsWhat_" .. key, potion.minutes), potion)
	end
	local bundle = Catalog.productByKey.AcademyBundle
	if bundle then
		row(
			#Catalog.potions + 1,
			bundle.key,
			Strings.get("GoodsWhat_" .. bundle.key, bundle.each or 0),
			nil
		)
	end

	local function draw()
		local state = Store.get()
		if not state then
			return
		end
		amount.Text = Strings.get("HerbAmount", state.herbs)
		for _, entry in rows do
			local potion = entry.potion
			local product = entry.product
			if potion then
				local count = state.stock[potion.id] or 0
				local running = state.potions[potion.id]
				local text = Strings.get("PouchCount", count)
				if running then
					local active = Strings.get("ShopActive", clock(running))
					text ..= `     <font color="#{Ui.GREEN:ToHex()}">{active}</font>`
				end
				entry.status.Text = text
				local drink = entry.drink
				if drink then
					drink.Text = if count > 0
						then Strings.get("PotionDrinkCount", count)
						else Strings.get("PotionDrink")
					ready(drink, count > 0, Ui.GREEN)
				end
				local herbs = entry.herbs
				if herbs then
					ready(herbs, state.herbs >= potion.herbs, Ui.GOLD)
				end
			end
			local robux = entry.robux
			local on = product ~= nil and product.assetId > 0
			local price = if product and on then Prices.get(product.assetId) else nil
			robux.Text = if not on
				then Strings.get("GoodsSoonButton")
				elseif price then Strings.get("GoodsPrice", tostring(price))
				else Strings.get("GoodsPriceLoading")
			ready(robux, on, Ui.GOLD)
		end
	end

	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if window.frame.Visible then
			for _, entry in rows do
				local product = entry.product
				if product then
					Prices.ask(product.assetId, false)
				end
			end
			draw()
		end
	end)
	Prices.onChange(function()
		if window.isOpen() then
			draw()
		end
	end)
	Store.onChange(function()
		if window.isOpen() then
			draw()
		end
	end)
	draw()
	return window
end

return HerbShop
