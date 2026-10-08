--!strict
-- Throw power: how much Chakra the next throw uses. By default it is all of it; a slider lets
-- the player dial it down to land in a nearer zone on purpose, and the amount can be typed in
-- for a number the slider is too coarse for. The row with the current setting sits in the
-- Chakra readout and opens the slider above it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Chase = require(ReplicatedStorage.Shared.Logic.Chase)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Kick = require(ReplicatedStorage.Shared.Logic.Kick)
local Remotes = require("./Remotes")
local Roll = require(ReplicatedStorage.Shared.Logic.Roll)
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local ThrowPower = {}

-- A slider this close to its right end snaps to "all of it", which also keeps up as Chakra grows.
local FULL_AT = 0.985

-- How long a choice is shown before the server has confirmed it, seconds.
local UNCONFIRMED_SECONDS = 1.5
-- How long the amount's outline stays red after something that is not a number was typed.
local REFUSAL_SECONDS = 0.8

-- The slider is linear: its middle is half the Chakra. It used to be logarithmic, which suits
-- how distance grows but not what a slider is taken to mean: with millions of Chakra its
-- middle stood at a thousand and a half. The small amounts a nearer zone takes are typed in.
local function amountAt(position: number, total: number): number
	if position >= FULL_AT or total <= 1 then
		return 0
	end
	return math.max(1, math.floor(total * position))
end

local function positionOf(amount: number, total: number): number
	if amount <= 0 or amount >= total or total <= 1 then
		return 1
	end
	return math.clamp(amount / total, 0, 1)
end

-- Adds the throw power row to the Chakra readout, and the slider that opens above it. Returns
-- the slider's panel, so whatever sits above the readout can make way while it is open.
function ThrowPower.attach(pill: Frame): Frame
	local row = Ui.button(pill, {
		Position = UDim2.new(0, 10, 1, -52),
		Size = UDim2.new(1, -20, 0, 42),
		BackgroundColor3 = Ui.CARD,
		TextSize = 23,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local popup = Ui.panel(pill, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(0, -8),
		Size = UDim2.new(1, 0, 0, 250),
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	Ui.stroke(popup, Ui.BLUE, 2)
	Ui.padding(popup, 12)
	Ui.text(popup, {
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 24,
		Text = Strings.get("ThrowTitle"),
	})
	-- The amount is a box to type in: clicking it clears it for a number.
	local amountBox: TextBox = Ui.make("TextBox", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Ui.CARD,
		BorderSizePixel = 0,
		Font = Ui.FONT,
		TextSize = 30,
		TextColor3 = Ui.BLUE,
		TextXAlignment = Enum.TextXAlignment.Left,
		PlaceholderText = Strings.get("ThrowType"),
		PlaceholderColor3 = Ui.MUTED,
		ClearTextOnFocus = true,
		Text = "",
	}, popup)
	Ui.corner(amountBox, 8)
	local amountEdge = Ui.stroke(amountBox, Ui.EDGE, 2)
	Ui.make(
		"UIPadding",
		{ PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) },
		amountBox
	)
	local typeHint = Ui.text(amountBox, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 17,
		TextColor3 = Ui.MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = Strings.get("ThrowTypeHint"),
	})
	-- Two lines: the zone and what the next one takes do not fit in one.
	local reachLabel = Ui.text(popup, {
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 0, 52),
		TextSize = 21,
		TextColor3 = Ui.MUTED,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	-- The track is taller than it looks, so it is easy to grab; the bar and knob are drawn in it.
	local track = Ui.make("TextButton", {
		Position = UDim2.fromOffset(10, 134),
		Size = UDim2.new(1, -20, 0, 34),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}, popup)
	local bar = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Ui.CARD,
		BorderSizePixel = 0,
	}, track)
	Ui.corner(bar, 5)
	local fill = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.BLUE,
		BorderSizePixel = 0,
	}, bar)
	Ui.corner(fill, 4)
	local knob = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Ui.WHITE,
		BorderSizePixel = 0,
	}, track)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, knob)

	local useAll = Ui.button(popup, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(124, 44),
		BackgroundColor3 = Ui.GRAY,
		TextSize = 22,
		Text = Strings.get("ThrowMax"),
	})
	Ui.text(popup, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -136, 0, 44),
		TextSize = 18,
		TextColor3 = Ui.MUTED,
		TextWrapped = true,
		Text = Strings.get("ThrowHint"),
	})

	-- While the knob is being dragged the slider shows the draft; the server is told on release.
	local dragging = false
	local draft = 0
	-- A choice that was sent and not yet confirmed is shown as if it were, so the slider does
	-- not jump back to the old amount for the moment the answer takes.
	local unconfirmed: number? = nil
	local sentAt = 0

	local function redraw()
		local state = Store.get()
		if not state then
			return
		end
		local total = state.chakra
		local chosen = if dragging
			then draft
			elseif unconfirmed ~= nil then unconfirmed
			else state.throwChakra
		local isFull = chosen <= 0 or chosen >= total
		local used = if isFull then total else chosen

		row.Text = if isFull
			then Strings.get("ThrowButtonFull", total)
			else Strings.get("ThrowButton", used, total)
		-- Not while it is being typed in.
		if not amountBox:IsFocused() then
			amountBox.Text = if isFull
				then Strings.get("ThrowAmountFull", total)
				else Strings.get("ThrowAmount", used)
		end

		-- Where a throw at the very top of the bar lands with this much Chakra, and what the
		-- next zone takes; in
		-- the last zone, the mutation luck its depth earns. A charged Sage throw carries
		-- farther. If the enemy out there would catch the player, the line says so instead:
		-- dialing the power down is what the slider is for.
		local sage = if state.streak >= Tuning.Kick.sageStreak
			then Tuning.Kick.sageMultiplier
			else 1
		local distance = Kick.distance(used * sage)
		local zone = Catalog.zoneAt(distance)
		local following = Catalog.zoneAfter(zone)
		local safe = Chase.escapesFrom(Economy.walkSpeed(state.runLevel), distance)
		reachLabel.Text = if not safe
			then Strings.get("ThrowReachDanger", zone.name)
			elseif following then Strings.get("ThrowReachNext", zone.name, following.chakra)
			else Strings.get(
				"ThrowReachDeep",
				zone.name,
				Roll.depthMutationLuck(zone, distance)
			)
		reachLabel.TextColor3 = if safe then Ui.MUTED else Ui.RED

		local position = positionOf(if isFull then 0 else chosen, total)
		fill.Size = UDim2.fromScale(position, 1)
		knob.Position = UDim2.fromScale(position, 0.5)
	end

	-- Tells the server how much Chakra to throw with, 0 for all of it.
	local function choose(amount: number)
		unconfirmed = amount
		sentAt = os.clock()
		Remotes.ThrowChakra:FireServer(amount)
		redraw()
	end

	local function dragTo(x: number)
		local state = Store.get()
		if not state then
			return
		end
		local position = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		draft = amountAt(position, state.chakra)
		redraw()
	end

	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			dragTo(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			dragging
			and (
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			dragging = false
			choose(draft)
		end
	end)

	amountBox.Focused:Connect(function()
		typeHint.Visible = false
	end)
	amountBox.FocusLost:Connect(function()
		typeHint.Visible = true
		local state = Store.get()
		local typed = amountBox.Text
		-- Left empty, the amount stays as it was.
		if state and typed ~= "" then
			local value = Format.parse(typed)
			if value and value >= 1 then
				local amount = math.floor(value)
				choose(if amount >= state.chakra then 0 else amount)
			else
				amountEdge.Color = Ui.RED
				task.delay(REFUSAL_SECONDS, function()
					amountEdge.Color = Ui.EDGE
				end)
			end
		end
		redraw()
	end)

	useAll.Activated:Connect(function()
		choose(0)
	end)
	-- It rises out of the readout it belongs to, rather than being there all at once.
	local rise: UIScale = Ui.make("UIScale", {}, popup)
	row.Activated:Connect(function()
		popup.Visible = not popup.Visible
		if popup.Visible then
			rise.Scale = 0.86
			TweenService:Create(
				rise,
				TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
	end)

	Store.onChange(function(state)
		local confirmed = state.throwChakra == unconfirmed
		if unconfirmed ~= nil and (confirmed or os.clock() - sentAt > UNCONFIRMED_SECONDS) then
			unconfirmed = nil
		end
		redraw()
	end)
	return popup
end

return ThrowPower
