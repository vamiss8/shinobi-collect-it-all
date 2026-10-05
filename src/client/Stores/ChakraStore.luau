--!strict
-- The Chakra Store window: every kunai, cheapest first. They are bought in order, and the
-- newest one owned is the one in use: it sets how much Chakra training gives and how the throw
-- looks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Remotes = require("../Remotes")
local Store = require("../Store")
local Strings = require("../Strings")
local Ui = require("../Ui")

local ChakraStore = {}

type Row = {
	button: TextButton,
	frame: Frame,
}

function ChakraStore.build(): Ui.Window
	local window = Ui.window("ChakraStore", Vector2.new(560, 440))
	window.title.Text = Strings.get("ShopChakraTitle")

	Ui.text(window.body, {
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 14,
		TextColor3 = Ui.MUTED,
		TextWrapped = true,
		Text = Strings.get("ShopChakraHint"),
	})
	local list = Ui.scroll(window.body, {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -40),
	})
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, list)
	Ui.padding(list, 3)

	local rows: { Row } = {}
	for index, kunai in Catalog.kunai do
		local frame = Ui.panel(list, {
			LayoutOrder = index,
			Size = UDim2.new(1, -10, 0, 56),
			BackgroundColor3 = Ui.CARD,
			BackgroundTransparency = 0,
		})

		-- A swatch in the kunai's own colors: blade over trail.
		local swatch = Ui.make("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(36, 36),
			BackgroundColor3 = Color3.fromHex(kunai.trail),
			BorderSizePixel = 0,
		}, frame)
		Ui.corner(swatch, 8)
		local blade = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(26, 8),
			Rotation = -45,
			BackgroundColor3 = Color3.fromHex(kunai.color),
			BorderSizePixel = 0,
		}, swatch)
		Ui.corner(blade, 3)

		Ui.text(frame, {
			Position = UDim2.fromOffset(56, 8),
			Size = UDim2.new(1, -206, 0, 20),
			Font = Ui.BRUSH,
			TextSize = 17,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = kunai.name,
		})
		Ui.text(frame, {
			Position = UDim2.fromOffset(56, 30),
			Size = UDim2.new(1, -206, 0, 18),
			TextSize = 13,
			TextColor3 = Ui.BLUE,
			Text = Strings.get("ShopKunaiChakra", kunai.chakraPerRep),
		})
		local button = Ui.button(frame, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(134, 36),
			TextSize = 15,
		})
		button.Activated:Connect(function()
			local state = Store.get()
			if state and index == state.kunai + 1 then
				Remotes.Buy:FireServer("kunai")
			end
		end)
		rows[index] = { button = button, frame = frame }
	end

	Store.onChange(function(state)
		for index, row in rows do
			local kunai = Catalog.kunai[index]
			local button = row.button
			if index == state.kunai then
				button.Text = Strings.get("ShopInUse")
				button.BackgroundColor3 = Ui.BLUE
			elseif index < state.kunai then
				button.Text = Strings.get("ShopOwned")
				button.BackgroundColor3 = Ui.GRAY
			else
				-- Only the next kunai can be bought; the ones after it show their price.
				local isNext = index == state.kunai + 1
				button.Text = Strings.get("ShopPrice", kunai.price)
				button.BackgroundColor3 = if isNext and state.ryo >= kunai.price
					then Ui.GREEN
					else Ui.GRAY
			end
			button.AutoButtonColor = index == state.kunai + 1
			row.frame.BackgroundTransparency = if index <= state.kunai + 1 then 0 else 0.5
		end
	end)

	return window
end

return ChakraStore
