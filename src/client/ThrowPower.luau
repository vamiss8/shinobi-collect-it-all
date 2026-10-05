--!strict
-- Throw power: how much Chakra the next throw uses. By default it is all of it; a slider lets
-- the player dial it down to land in a nearer zone on purpose. The row with the current setting
-- sits in the Chakra readout and opens the slider above it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Chase = require(ReplicatedStorage.Shared.Logic.Chase)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
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

-- The slider is logarithmic: Chakra spans many orders of magnitude and distance grows with its
-- logarithm, so equal steps along the track should multiply the amount rather than add to it.
local function amountAt(position: number, total: number): number
	if position >= FULL_AT or total <= 1 then
		return 0
	end
	return math.max(1, math.floor(total ^ position))
end

local function positionOf(amount: number, total: number): number
	if amount <= 0 or amount >= total or total <= 1 then
		return 1
	end
	return math.clamp(math.log(amount) / math.log(total), 0, 1)
end

-- Adds the throw power row to the Chakra readout, and the slider that opens above it.
function ThrowPower.attach(pill: Frame)
	local row = Ui.button(pill, {
		Position = UDim2.new(0, 10, 1, -40),
		Size = UDim2.new(1, -20, 0, 30),
		BackgroundColor3 = Ui.CARD,
		TextSize = 14,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local popup = Ui.panel(pill, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromOffset(0, -8),
		Size = UDim2.new(1, 0, 0, 168),
		BackgroundTransparency = 0.05,
		Visible = false,
	})
	Ui.stroke(popup, Ui.BLUE, 2)
	Ui.padding(popup, 12)
	Ui.text(popup, {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		Text = Strings.get("ThrowTitle"),
	})
	local amountLabel = Ui.text(popup, {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 22,
		TextColor3 = Ui.BLUE,
	})
	local reachLabel = Ui.text(popup, {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 18),
		TextSize = 13,
		TextColor3 = Ui.MUTED,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	-- The track is taller than it looks, so it is easy to grab; the bar and knob are drawn in it.
	local track = Ui.make("TextButton", {
		Position = UDim2.fromOffset(8, 78),
		Size = UDim2.new(1, -16, 0, 28),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
	}, popup)
	local bar = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = Ui.CARD,
		BorderSizePixel = 0,
	}, track)
	Ui.corner(bar, 4)
	local fill = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.BLUE,
		BorderSizePixel = 0,
	}, bar)
	Ui.corner(fill, 4)
	local knob = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Ui.WHITE,
		BorderSizePixel = 0,
	}, track)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, knob)

	local useAll = Ui.button(popup, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(96, 28),
		BackgroundColor3 = Ui.GRAY,
		TextSize = 14,
		Text = Strings.get("ThrowMax"),
	})
	Ui.text(popup, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -106, 0, 28),
		TextSize = 12,
		TextColor3 = Ui.MUTED,
		TextWrapped = true,
		Text = Strings.get("ThrowHint"),
	})

	-- While the knob is being dragged the slider shows the draft; the server is told on release.
	local dragging = false
	local draft = 0

	local function redraw()
		local state = Store.get()
		if not state then
			return
		end
		local total = state.chakra
		local chosen = if dragging then draft else state.throwChakra
		local isFull = chosen <= 0 or chosen >= total
		local used = if isFull then total else chosen

		row.Text = if isFull
			then Strings.get("ThrowButtonFull", total)
			else Strings.get("ThrowButton", used, total)
		amountLabel.Text = if isFull
			then Strings.get("ThrowAmountFull", total)
			else Strings.get("ThrowAmount", used)

		-- Where a Perfect throw with this much Chakra lands, and what the next zone takes; in
		-- the last zone, the mutation luck its depth earns. A charged Sage throw carries
		-- farther. If the enemy out there would catch the player, the line says so instead:
		-- dialing the power down is what the slider is for.
		local sage = if state.streak >= Tuning.Kick.sageStreak
			then Tuning.Kick.sageMultiplier
			else 1
		local distance = Kick.distance(used, sage, 0.5)
		local zone = Catalog.zoneAt(distance)
		local following = Catalog.zoneAfter(zone)
		local safe = Chase.escapesFrom(Economy.walkSpeed(state.speedLevel), distance)
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
			Remotes.ThrowChakra:FireServer(draft)
		end
	end)

	useAll.Activated:Connect(function()
		Remotes.ThrowChakra:FireServer(0)
	end)
	row.Activated:Connect(function()
		popup.Visible = not popup.Visible
	end)

	Store.onChange(redraw)
end

return ThrowPower
