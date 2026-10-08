--!strict
-- The window of Tenten's Ninja Tools (World/TentenShop): the kunai in use at the top, with how
-- close the next one is, and under it every kunai, cheapest first. They are bought in order,
-- and the newest one owned is the one in use: it sets how much Chakra training gives and how the
-- throw looks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Icons = require("../Icons")
local Remotes = require("../Remotes")
local Store = require("../Store")
local Strings = require("../Strings")
local Ui = require("../Ui")

local TentenShop = {}

local HINT_HEIGHT = 48
local HEADER_HEIGHT = 128
local HEADER_ICON = 100
local ROW_HEIGHT = 86
local ROW_GAP = 8
local ROW_ICON = 62
local BUTTON = Vector2.new(204, 58)
-- Where a row's texts start, past its icon.
local TEXT_LEFT = 90
local GAIN_COLOR = "#FFCA28"

type Row = {
	frame: Frame,
	edge: UIStroke,
	perRep: TextLabel,
	button: TextButton,
}

-- A kunai's icon on a plate of its trail's color, dimmed so that a pale blade and a black one
-- both stand out on it.
local function plate(parent: Instance, kunai: Catalog.Kunai, at: UDim2, side: number): Frame
	local trail = Color3.fromHex(kunai.trail)
	local color = trail:Lerp(Ui.PANEL, 0.55)
	local frame = Ui.make("Frame", {
		Position = at,
		Size = UDim2.fromOffset(side, side),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, parent)
	Ui.corner(frame, math.floor(side * 0.18))
	Ui.stroke(frame, trail:Lerp(Ui.PANEL, 0.2), 2)
	local holder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.92),
		BackgroundTransparency = 1,
	}, frame)
	Icons.kunai(holder, kunai.id, color)
	return frame
end

function TentenShop.build(): Ui.Window
	local window = Ui.window("TentenShop", Vector2.new(900, 740))
	window.title.Text = Strings.get("ShopTentenTitle")
	local body = window.body

	Ui.text(body, {
		Size = UDim2.new(1, 0, 0, HINT_HEIGHT),
		TextSize = 19,
		TextColor3 = Ui.MUTED,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = Strings.get("ShopTentenHint"),
	})

	-- The kunai in use on the left, the way to the next one on the right.
	local header = Ui.panel(body, {
		Position = UDim2.fromOffset(0, HINT_HEIGHT + 4),
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundColor3 = Ui.CARD,
		BackgroundTransparency = 0,
	})
	Ui.stroke(header, Ui.EDGE, 2)
	local headerLeft = (HEADER_HEIGHT - HEADER_ICON) / 2
	local headerText = headerLeft + HEADER_ICON + 16
	Ui.text(header, {
		Position = UDim2.fromOffset(headerText, 12),
		Size = UDim2.new(0.5, -headerText, 0, 22),
		TextSize = 18,
		TextColor3 = Ui.MUTED,
		Text = Strings.get("ShopYourKunai"),
	})
	local currentName = Ui.text(header, {
		Position = UDim2.fromOffset(headerText, 34),
		Size = UDim2.new(0.5, -headerText, 0, 42),
		TextSize = 30,
		TextColor3 = Ui.PARCHMENT,
		TextScaled = true,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 18 }, currentName)
	local currentChakra = Ui.text(header, {
		Position = UDim2.fromOffset(headerText, 80),
		Size = UDim2.new(0.5, -headerText, 0, 30),
		TextSize = 23,
		TextColor3 = Ui.BLUE,
	})

	local nextName = Ui.text(header, {
		Position = UDim2.new(0.5, 12, 0, 18),
		Size = UDim2.new(0.5, -28, 0, 40),
		TextSize = 24,
		TextScaled = true,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 16 }, nextName)
	-- How much of the next kunai's price the player has.
	local progress = Ui.make("Frame", {
		Position = UDim2.new(0.5, 12, 0, 68),
		Size = UDim2.new(0.5, -28, 0, 40),
		BackgroundColor3 = Ui.PANEL,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, header)
	Ui.corner(progress, 8)
	local progressFill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.GOLD,
		BorderSizePixel = 0,
	}, progress)
	local progressText = Ui.text(progress, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		ZIndex = 2,
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
	for index, kunai in Catalog.kunai do
		local frame = Ui.panel(list, {
			LayoutOrder = index,
			Size = UDim2.new(1, -16, 0, ROW_HEIGHT),
			BackgroundColor3 = Ui.CARD,
			BackgroundTransparency = 0,
		})
		local edge = Ui.stroke(frame, Ui.GOLD, 2)
		local inset = (ROW_HEIGHT - ROW_ICON) / 2
		plate(frame, kunai, UDim2.fromOffset(inset, inset), ROW_ICON)

		Ui.text(frame, {
			Position = UDim2.fromOffset(TEXT_LEFT, 10),
			Size = UDim2.new(1, -(TEXT_LEFT + BUTTON.X + 28), 0, 34),
			TextSize = 26,
			TextColor3 = Ui.PARCHMENT,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = kunai.name,
		})
		local perRep = Ui.text(frame, {
			Position = UDim2.fromOffset(TEXT_LEFT, 46),
			Size = UDim2.new(1, -(TEXT_LEFT + BUTTON.X + 28), 0, 28),
			TextSize = 21,
			TextColor3 = Ui.BLUE,
			RichText = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local button = Ui.button(frame, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
			TextSize = 24,
		})
		button.Activated:Connect(function()
			local state = Store.get()
			if state and index == state.kunai + 1 then
				Remotes.Buy:FireServer("kunai")
			end
		end)
		rows[index] = { frame = frame, edge = edge, perRep = perRep, button = button }
	end

	-- The window opens on the kunai in use, with the next one right under it.
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		local state = Store.get()
		if window.frame.Visible and state then
			local above = math.max(state.kunai - 1, 0)
			list.CanvasPosition = Vector2.new(0, above * (ROW_HEIGHT + ROW_GAP))
		end
	end)

	-- The kunai the header shows, so its icon is only redrawn when a new one is bought.
	local shown = 0
	local shownPlate: Frame? = nil

	Store.onChange(function(state)
		local owned = math.clamp(state.kunai, 1, #Catalog.kunai)
		local current = Catalog.kunai[owned]
		local following = Catalog.kunai[owned + 1]

		if owned ~= shown then
			shown = owned
			if shownPlate then
				shownPlate:Destroy()
			end
			shownPlate =
				plate(header, current, UDim2.fromOffset(headerLeft, headerLeft), HEADER_ICON)
			currentName.Text = current.name
			currentChakra.Text = Strings.get("ShopKunaiChakra", current.chakraPerRep)
		end

		if following then
			local share = math.clamp(state.ryo / following.price, 0, 1)
			nextName.Text = Strings.get("ShopNextKunai", following.name)
			nextName.TextColor3 = Ui.WHITE
			progress.Visible = true
			progressFill.Size = UDim2.fromScale(share, 1)
			-- Gold whether full or not: green is the button that buys, right beside it.
			progressFill.BackgroundColor3 = Ui.GOLD
			progressText.Text = Strings.get(
				"ShopNextProgress",
				math.min(state.ryo, following.price),
				following.price
			)
		else
			nextName.Text = Strings.get("ShopAllKunai")
			nextName.TextColor3 = Ui.GOLD
			progress.Visible = false
		end

		for index, row in rows do
			local kunai = Catalog.kunai[index]
			local button = row.button
			local isNext = index == owned + 1
			local text = Strings.get("ShopKunaiChakra", kunai.chakraPerRep)
			if index == owned then
				button.Text = Strings.get("ShopInUse")
				button.BackgroundColor3 = Ui.BLUE
			elseif index < owned then
				button.Text = Strings.get("ShopOwned")
				button.BackgroundColor3 = Ui.GRAY
			else
				-- Only the next kunai can be bought; the ones after it show their price.
				button.Text = Strings.get("ShopPrice", kunai.price)
				button.BackgroundColor3 = if isNext and state.ryo >= kunai.price
					then Ui.GREEN
					else Ui.GRAY
				-- What it would multiply training by, against the kunai in use.
				local gain = Strings.get("ShopKunaiGain", kunai.chakraPerRep / current.chakraPerRep)
				text ..= `   <font color="{GAIN_COLOR}">{gain}</font>`
			end
			row.perRep.Text = text
			button.AutoButtonColor = isNext
			row.frame.BackgroundTransparency = if index <= owned + 1 then 0 else 0.5
			row.edge.Color = if index == owned then Ui.BLUE else Ui.GOLD
			row.edge.Transparency = if index == owned or isNext then 0 else 1
		end
	end)

	return window
end

return TentenShop
