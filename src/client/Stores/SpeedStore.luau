--!strict
-- The window of the Youth Training Ground (World/TrainingGround), the shop "speed". It is laid
-- out like the window of Tenten's shop, at the same sizes: the player's speed stage
-- (Config/SpeedStages) and run speed on the left of a header, the next level with how close its
-- price is and the button that buys it on the right; under it the speed the player runs at,
-- which they may set lower than they have bought; and then one of two lists, chosen by the
-- buttons over it. "Styles" has every speed stage with what it adds to the runner's look and a
-- button to wear it, which is to run at that stage's speed. "Who you can outrun" has every
-- zone's enemy with whether the player gets away from it at the speed they run at: run speed is
-- what decides if a shinobi from a zone can be brought home. An enemy speeds up towards the far
-- end of its zone, so a zone can be safe on its near side only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Chase = require(ReplicatedStorage.Shared.Logic.Chase)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Remotes = require("../Remotes")
local SpeedStages = require(ReplicatedStorage.Shared.Config.SpeedStages)
local Store = require("../Store")
local Strings = require("../Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("../Ui")

local SpeedStore = {}

local HINT_HEIGHT = 48
local HEADER_HEIGHT = 150
local HEADER_SEAL = 100
local PACE_HEIGHT = 62
local TAB_HEIGHT = 46
local GAP = 8
local ROW_HEIGHT = 92
local ROW_SEAL = 62
local ENEMY_HEIGHT = 54
local BUTTON = Vector2.new(204, 58)
-- Where a row's texts start, past its seal.
local TEXT_LEFT = 90
-- The fastest bought, as the server takes it: not a level, so that it follows the next purchase.
local FASTEST = -1

type StyleRow = {
	frame: Frame,
	edge: UIStroke,
	seal: TextLabel,
	button: TextButton,
}

-- The seal of a stage the player has not reached: pale gray, like the lanterns of the Gates not
-- yet opened on the training ground's gate (client GateLanterns).
local UNREACHED = Color3.fromRGB(176, 178, 174)

-- What a stage's seal is stamped with: its Gate's number, or the first letter of its name.
local function markOf(stage: SpeedStages.Stage): string
	return if stage.gate > 0 then tostring(stage.gate) else string.sub(stage.name, 1, 1)
end

-- What the stage at `index` adds to a runner's look, in words.
local function addsOf(index: number): string
	local words = {}
	for _, wear in SpeedStages.adds(index) do
		table.insert(words, Strings.get("Wear_" .. wear))
	end
	return if #words > 0
		then Strings.get("StyleAdds", table.concat(words, ", "))
		else Strings.get("StyleNothing")
end

function SpeedStore.build(): Ui.Window
	local window = Ui.window("SpeedStore", Vector2.new(900, 740))
	window.title.Text = Strings.get("ShopSpeedTitle")
	local body = window.body

	Ui.text(body, {
		Size = UDim2.new(1, 0, 0, HINT_HEIGHT),
		TextSize = 19,
		TextColor3 = Ui.MUTED,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = Strings.get("ShopSpeedHint"),
	})

	-- The stage reached on the left, the way to the next level on the right.
	local header = Ui.panel(body, {
		Position = UDim2.fromOffset(0, HINT_HEIGHT + 4),
		Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		BackgroundColor3 = Ui.CARD,
		BackgroundTransparency = 0,
	})
	Ui.stroke(header, Ui.EDGE, 2)
	local sealLeft = (HEADER_HEIGHT - HEADER_SEAL) / 2
	local headerText = sealLeft + HEADER_SEAL + 16
	local headerSeal = Ui.badge(header, "", Ui.GOLD, HEADER_SEAL)
	headerSeal.Position = UDim2.fromOffset(sealLeft, sealLeft)
	Ui.text(header, {
		Position = UDim2.fromOffset(headerText, 16),
		Size = UDim2.new(0.5, -headerText, 0, 22),
		TextSize = 18,
		TextColor3 = Ui.MUTED,
		Text = Strings.get("ShopSpeedStage"),
	})
	local stageName = Ui.text(header, {
		Position = UDim2.fromOffset(headerText, 40),
		Size = UDim2.new(0.5, -headerText, 0, 44),
		TextSize = 30,
		TextColor3 = Ui.PARCHMENT,
		TextScaled = true,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 18 }, stageName)
	local levelLabel = Ui.text(header, {
		Position = UDim2.fromOffset(headerText, 90),
		Size = UDim2.new(0.5, -headerText, 0, 30),
		TextSize = 23,
		TextColor3 = Ui.BLUE,
	})

	local nextName = Ui.text(header, {
		Position = UDim2.new(0.5, 12, 0, 12),
		Size = UDim2.new(0.5, -28, 0, 34),
		TextSize = 24,
		TextScaled = true,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 16 }, nextName)
	-- How far the next stage is; in its color when the next level reaches it.
	local toStage = Ui.text(header, {
		Position = UDim2.new(0.5, 12, 0, 48),
		Size = UDim2.new(0.5, -28, 0, 26),
		TextSize = 20,
		TextColor3 = Ui.MUTED,
		RichText = true,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	-- How much of the next level's price the player has, and the button that buys it.
	local progress = Ui.make("Frame", {
		Position = UDim2.new(0.5, 12, 0, 80),
		Size = UDim2.new(0.5, -(28 + BUTTON.X + 12), 0, BUTTON.Y),
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
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		ZIndex = 2,
	})
	local buy = Ui.button(header, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 80),
		Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
		TextSize = 24,
	})
	buy.Activated:Connect(function()
		Remotes.Buy:FireServer("speed")
	end)

	-- The speed the player runs at: a step down, a step up, or back to the fastest bought.
	local paceTop = HINT_HEIGHT + 4 + HEADER_HEIGHT + GAP
	local pace = Ui.panel(body, {
		Position = UDim2.fromOffset(0, paceTop),
		Size = UDim2.new(1, 0, 0, PACE_HEIGHT),
		BackgroundColor3 = Ui.CARD,
		BackgroundTransparency = 0,
	})
	Ui.text(pace, {
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(0, 230, 1, 0),
		TextSize = 23,
		TextColor3 = Ui.PARCHMENT,
		Text = Strings.get("ShopSpeedRunAt"),
	})
	local slower = Ui.button(pace, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 250, 0.5, 0),
		Size = UDim2.fromOffset(58, 46),
		TextSize = 30,
		Text = "-",
	})
	local paceLabel = Ui.text(pace, {
		Position = UDim2.fromOffset(308, 0),
		Size = UDim2.new(0, 96, 1, 0),
		TextSize = 32,
		TextColor3 = Ui.GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local faster = Ui.button(pace, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 404, 0.5, 0),
		Size = UDim2.fromOffset(58, 46),
		TextSize = 30,
		Text = "+",
	})
	local fastest = Ui.button(pace, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 478, 0.5, 0),
		Size = UDim2.fromOffset(170, 46),
		TextSize = 21,
		Text = Strings.get("ShopSpeedFastest"),
	})
	local paceNote = Ui.text(pace, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 0),
		Size = UDim2.new(1, -680, 1, 0),
		TextSize = 19,
		TextColor3 = Ui.MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local function runAt(level: number)
		Remotes.RunAt:FireServer(level)
	end
	slower.Activated:Connect(function()
		local state = Store.get()
		if state and state.runLevel > 0 then
			runAt(state.runLevel - 1)
		end
	end)
	faster.Activated:Connect(function()
		local state = Store.get()
		if state and state.runLevel < state.speedLevel then
			runAt(state.runLevel + 1)
		end
	end)
	fastest.Activated:Connect(function()
		runAt(FASTEST)
	end)

	-- Two lists share the rest of the window; the buttons over them say which is shown.
	local tabsTop = paceTop + PACE_HEIGHT + GAP
	local listTop = tabsTop + TAB_HEIGHT + GAP
	local function tab(left: boolean, text: string): TextButton
		return Ui.button(body, {
			AnchorPoint = Vector2.new(if left then 0 else 1, 0),
			Position = UDim2.new(if left then 0 else 1, 0, 0, tabsTop),
			Size = UDim2.new(0.5, -GAP / 2, 0, TAB_HEIGHT),
			TextSize = 22,
			Text = text,
		})
	end
	local stylesTab = tab(true, Strings.get("ShopSpeedStyles"))
	local enemiesTab = tab(false, Strings.get("ShopSpeedEnemies"))
	local function list(): ScrollingFrame
		local frame = Ui.scroll(body, {
			Position = UDim2.fromOffset(0, listTop),
			Size = UDim2.new(1, 0, 1, -listTop),
			ScrollBarThickness = 8,
		})
		Ui.make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, GAP),
		}, frame)
		Ui.padding(frame, 3)
		return frame
	end
	local styles = list()
	local enemies = list()
	local function show(which: ScrollingFrame)
		styles.Visible = which == styles
		enemies.Visible = which == enemies
		stylesTab.BackgroundColor3 = if which == styles then Ui.BLUE else Ui.GRAY
		enemiesTab.BackgroundColor3 = if which == enemies then Ui.BLUE else Ui.GRAY
	end
	stylesTab.Activated:Connect(function()
		show(styles)
	end)
	enemiesTab.Activated:Connect(function()
		show(enemies)
	end)
	show(styles)

	-- One row per speed stage: its seal, its name, the level it comes at with what it adds to
	-- the runner, and a button that wears it.
	local styleRows: { StyleRow } = {}
	for index, stage in SpeedStages.list do
		local frame = Ui.panel(styles, {
			LayoutOrder = index,
			Size = UDim2.new(1, -16, 0, ROW_HEIGHT),
			BackgroundColor3 = Ui.CARD,
			BackgroundTransparency = 0,
		})
		local edge = Ui.stroke(frame, Ui.GOLD, 2)
		local inset = (ROW_HEIGHT - ROW_SEAL) / 2
		local seal = Ui.badge(frame, markOf(stage), Color3.fromHex(stage.color), ROW_SEAL)
		seal.Position = UDim2.fromOffset(inset, inset)

		-- Three lines: the name, the level it comes at with its speed, and what it adds. The
		-- last is the long one (up to 53 characters) and is drawn smaller if it has to be.
		local wide = UDim2.new(1, -(TEXT_LEFT + BUTTON.X + 28), 0, 0)
		Ui.text(frame, {
			Position = UDim2.fromOffset(TEXT_LEFT, 6),
			Size = wide + UDim2.fromOffset(0, 32),
			TextSize = 26,
			TextColor3 = Ui.PARCHMENT,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = stage.name,
		})
		Ui.text(frame, {
			Position = UDim2.fromOffset(TEXT_LEFT, 38),
			Size = wide + UDim2.fromOffset(0, 24),
			TextSize = 20,
			TextColor3 = Ui.BLUE,
			Text = Strings.get("StyleLine", stage.level, Economy.walkSpeed(stage.level)),
		})
		local adds = Ui.text(frame, {
			Position = UDim2.fromOffset(TEXT_LEFT, 62),
			Size = wide + UDim2.fromOffset(0, 24),
			TextSize = 20,
			TextColor3 = Ui.MUTED,
			TextScaled = true,
			Text = addsOf(index),
		})
		Ui.make("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 14 }, adds)
		local button = Ui.button(frame, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
			TextSize = 24,
		})
		button.Activated:Connect(function()
			local state = Store.get()
			local level = if state then SpeedStages.fastest(index, state.speedLevel) else nil
			if state and level then
				-- The stage the player has reached is worn at the fastest they have.
				runAt(if level >= state.speedLevel then FASTEST else level)
			end
		end)
		styleRows[index] = { frame = frame, edge = edge, seal = seal, button = button }
	end

	-- One row per zone: its enemy and the zone on the left, the verdict on the right.
	local verdicts: { TextLabel } = {}
	for index, zone in Catalog.zones do
		local row = Ui.panel(enemies, {
			LayoutOrder = index,
			Size = UDim2.new(1, -16, 0, ENEMY_HEIGHT),
			BackgroundColor3 = Ui.CARD,
			BackgroundTransparency = 0,
		})
		Ui.text(row, {
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(0.66, -16, 1, 0),
			TextSize = 21,
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
			Position = UDim2.new(1, -16, 0, 0),
			Size = UDim2.new(0.34, -16, 1, 0),
			TextSize = 21,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end

	-- The window opens on its styles, at the one the player wears.
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		local state = Store.get()
		if window.frame.Visible and state then
			show(styles)
			local _, worn = SpeedStages.at(state.runLevel)
			styles.CanvasPosition = Vector2.new(0, math.max(worn - 2, 0) * (ROW_HEIGHT + GAP))
		end
	end)

	Store.onChange(function(state)
		local bought = state.speedLevel
		local run = state.runLevel
		local maxLevel = Tuning.Speed.maxLevel
		local stage = SpeedStages.at(bought)
		local color = Color3.fromHex(stage.color)

		headerSeal.Text = markOf(stage)
		headerSeal.BackgroundColor3 = color
		stageName.Text = stage.name
		stageName.TextColor3 = if stage.gate > 0 then color else Ui.PARCHMENT
		levelLabel.Text = Strings.get("ShopSpeedLevel", Economy.walkSpeed(bought), bought, maxLevel)

		if bought >= maxLevel then
			nextName.Text = Strings.get("ShopSpeedMaxed")
			nextName.TextColor3 = Ui.GOLD
			toStage.Text = ""
			progress.Visible = false
			buy.Text = Strings.get("ShopMax")
			buy.BackgroundColor3 = Ui.GRAY
			buy.AutoButtonColor = false
		else
			local price = Economy.speedPrice(bought)
			local share = math.clamp(state.ryo / price, 0, 1)
			nextName.Text = Strings.get(
				"ShopSpeedNext",
				Economy.walkSpeed(bought),
				Economy.walkSpeed(bought + 1)
			)
			nextName.TextColor3 = Ui.WHITE
			local following = SpeedStages.after(bought)
			if following then
				local left = following.level - bought
				toStage.Text = if left == 1
					then `<font color="{following.color}">{Strings.get(
						"ShopSpeedOpens",
						following.name
					)}</font>`
					else Strings.get("ShopSpeedToStage", following.name, left)
			else
				toStage.Text = ""
			end
			progress.Visible = true
			progressFill.Size = UDim2.fromScale(share, 1)
			-- Gold whether full or not: green is the button that buys, right beside it.
			progressFill.BackgroundColor3 = Ui.GOLD
			progressText.Text = Strings.get("ShopNextProgress", math.min(state.ryo, price), price)
			buy.Text = Strings.get("ShopPrice", price)
			buy.BackgroundColor3 = if state.ryo >= price then Ui.GREEN else Ui.GRAY
			buy.AutoButtonColor = true
		end

		-- The speed the player runs at.
		local speed = Economy.walkSpeed(run)
		paceLabel.Text = tostring(speed)
		slower.BackgroundColor3 = if run > 0 then Ui.BLUE else Ui.GRAY
		faster.BackgroundColor3 = if run < bought then Ui.BLUE else Ui.GRAY
		fastest.BackgroundColor3 = if run < bought then Ui.GREEN else Ui.GRAY
		paceNote.Text = if run < bought
			then Strings.get("ShopSpeedHeldBack", Economy.walkSpeed(bought))
			else Strings.get("ShopSpeedAtFastest")

		local _, worn = SpeedStages.at(run)
		for index, row in styleRows do
			local reached = SpeedStages.list[index].level <= bought
			local button = row.button
			if index == worn then
				button.Text = Strings.get("StyleWorn")
				button.BackgroundColor3 = Ui.BLUE
			elseif reached then
				button.Text = Strings.get("StyleWear")
				button.BackgroundColor3 = Ui.GREEN
			else
				button.Text = Strings.get("StyleLocked", SpeedStages.list[index].level)
				button.BackgroundColor3 = Ui.GRAY
			end
			button.AutoButtonColor = reached and index ~= worn
			row.seal.BackgroundColor3 = if reached
				then Color3.fromHex(SpeedStages.list[index].color)
				else UNREACHED
			row.frame.BackgroundTransparency = if reached then 0 else 0.5
			row.edge.Color = if index == worn then Ui.BLUE else Ui.GOLD
			row.edge.Transparency = if index == worn then 0 else 1
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
