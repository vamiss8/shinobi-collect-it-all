--!strict
-- The Speed Store window: the player's run speed, the next level and its price, and a list of
-- every zone's enemy with whether the player gets away from it. Run speed is what decides if a
-- shinobi from a zone can be brought home, so the list is the reason to buy. An enemy speeds up
-- towards the far end of its zone, so a zone can be safe on its near side only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Chase = require(ReplicatedStorage.Shared.Logic.Chase)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Remotes = require("../Remotes")
local Store = require("../Store")
local Strings = require("../Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("../Ui")

local SpeedStore = {}

function SpeedStore.build(): Ui.Window
	local window = Ui.window("SpeedStore", Vector2.new(520, 470))
	window.title.Text = Strings.get("ShopSpeedTitle")
	local body = window.body

	local speedLabel = Ui.text(body, {
		Size = UDim2.new(0.6, 0, 0, 32),
		Font = Ui.BRUSH,
		TextSize = 28,
		TextColor3 = Ui.GOLD,
	})
	local levelLabel = Ui.text(body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.4, 0, 0, 32),
		TextSize = 15,
		TextColor3 = Ui.MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	-- How far along the levels the player is.
	local bar = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Ui.CARD,
		BorderSizePixel = 0,
	}, body)
	Ui.corner(bar, 5)
	local fill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.GOLD,
		BorderSizePixel = 0,
	}, bar)
	Ui.corner(fill, 5)

	local offer = Ui.panel(body, {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = Ui.CARD,
		BackgroundTransparency = 0,
	})
	local offerLabel = Ui.text(offer, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -170, 1, 0),
		TextSize = 16,
	})
	local buy = Ui.button(offer, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(140, 38),
		TextSize = 15,
	})
	buy.Activated:Connect(function()
		Remotes.Buy:FireServer("speed")
	end)

	Ui.text(body, {
		Position = UDim2.fromOffset(0, 128),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		Text = Strings.get("ShopSpeedEnemies"),
	})
	local list = Ui.scroll(body, {
		Position = UDim2.fromOffset(0, 154),
		Size = UDim2.new(1, 0, 1, -154),
	})
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, list)
	Ui.padding(list, 3)

	-- One row per zone: its enemy and the zone on the left, the verdict on the right.
	local verdicts: { TextLabel } = {}
	for index, zone in Catalog.zones do
		local row = Ui.panel(list, {
			LayoutOrder = index,
			Size = UDim2.new(1, -10, 0, 34),
			BackgroundColor3 = Ui.CARD,
			BackgroundTransparency = 0,
		})
		Ui.text(row, {
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0.62, -12, 1, 0),
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = Strings.get(
				"ShopSpeedEnemy",
				zone.enemy.name,
				zone.enemy.speed,
				Chase.farSpeed(zone),
				zone.name
			),
		})
		verdicts[index] = Ui.text(row, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 0),
			Size = UDim2.new(0.38, -12, 1, 0),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end

	Store.onChange(function(state)
		local level = state.speedLevel
		local maxLevel = Tuning.Speed.maxLevel
		local speed = Economy.walkSpeed(level)
		speedLabel.Text = Strings.get("ShopSpeedNow", speed)
		levelLabel.Text = Strings.get("ShopSpeedLevel", level, maxLevel)
		fill.Size = UDim2.fromScale(level / maxLevel, 1)

		if level >= maxLevel then
			offerLabel.Text = Strings.get("ShopSpeedMaxed")
			buy.Text = Strings.get("ShopMax")
			buy.BackgroundColor3 = Ui.GRAY
		else
			local price = Economy.speedPrice(level)
			offerLabel.Text = Strings.get("ShopSpeedNext", speed, Economy.walkSpeed(level + 1))
			buy.Text = Strings.get("ShopPrice", price)
			buy.BackgroundColor3 = if state.ryo >= price then Ui.GREEN else Ui.GRAY
		end

		for index, zone in Catalog.zones do
			-- Home from the zone's far end means home from anywhere in it.
			local fromFar = Chase.escapes(speed, Chase.farSpeed(zone), Catalog.zoneEnd(zone))
			local fromNear = Chase.escapes(speed, zone.enemy.speed, zone.startsAt)
			verdicts[index].Text = if fromFar
				then Strings.get("ShopSpeedSafe")
				elseif fromNear then Strings.get("ShopSpeedPartly")
				else Strings.get("ShopSpeedSlower")
			verdicts[index].TextColor3 = if fromFar
				then Ui.GREEN
				elseif fromNear then Ui.GOLD
				else Ui.RED
		end
	end)

	return window
end

return SpeedStore
