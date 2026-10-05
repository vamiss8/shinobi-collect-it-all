--!strict
-- The power bar. The server says when it starts; the client animates the marker from its own
-- clock and reports how long the player watched before pressing. The server grades the press.
--
-- It is drawn as a scroll unrolled on a dark board: the grades are bands of ink across the
-- paper, the marker is the player's own kunai hanging over it, and under the scroll a row of
-- seals counts the Perfects in a row that charge the Sage throw.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Hud = require("./Hud")
local Icons = require("./Icons")
local Kick = require(ReplicatedStorage.Shared.Logic.Kick)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local KickBar = {}

-- Presses this soon after the bar appears are ignored, so the input that started the kick
-- cannot also end it.
local ARM_DELAY = 0.2
-- After a press the bar stays this long: the marker where it stopped, what the press was worth
-- and the seal it earned.
local RESULT_SECONDS = 1.2

-- The board, in layout pixels; it shrinks as a whole on a screen it does not fit.
local WIDTH = 780
local HEIGHT = 232
local PAD = 16
-- Room the board leaves under itself for the bar of slots.
local BOTTOM = 132
local TITLE_HEIGHT = 40
local GAUGE_TOP = 84
local GAUGE_HEIGHT = 76
local ROLLER_WIDTH = 24
local PAPER_INSET = 7 -- bare paper around the bands
local TOKEN = 54 -- the round paper tag the marker's kunai is drawn on
local STREAK_TOP = 172
local STREAK_HEIGHT = 48
local SEAL = 42

-- The colors grades are named in, on the board and on the message scroll.
local GRADE_COLORS: { [string]: Color3 } = {
	Perfect = Color3.fromRGB(255, 202, 40),
	Great = Color3.fromRGB(102, 187, 106),
	Good = Color3.fromRGB(66, 165, 245),
	Miss = Color3.fromRGB(189, 189, 189),
}
-- The same grades as washes of ink on the paper.
local BAND_COLORS: { [string]: Color3 } = {
	Perfect = Color3.fromRGB(245, 186, 44),
	Great = Color3.fromRGB(104, 178, 100),
	Good = Color3.fromRGB(84, 152, 214),
	Miss = Color3.fromRGB(160, 151, 142),
}
local INK = Color3.fromRGB(40, 28, 22)
local WOOD = Color3.fromRGB(141, 98, 72)
local DARK_WOOD = Color3.fromRGB(93, 64, 55)
local DEEP_RED = Color3.fromRGB(140, 24, 24)
-- A band narrower than this share of the bar has no room for its name.
local NAMED_BAND = 0.12

type Seal = {
	stamp: Frame,
	rim: Frame,
	scale: UIScale,
}

local function zoneName(zoneId: string): string
	for _, zone in Catalog.zones do
		if zone.id == zoneId then
			return zone.name
		end
	end
	return zoneId
end

local function disc(parent: Instance, properties: { [string]: any }): Frame
	local frame = Ui.make("Frame", { BorderSizePixel = 0 }, parent)
	for name, value in properties do
		frame[name] = value
	end
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	return frame
end

-- The scroll: paper between two wooden rollers, with one band of ink per grade. Returns the
-- frame the marker moves in, which spans the bands exactly.
local function buildGauge(board: Frame): Frame
	local gauge = Ui.make("Frame", {
		Position = UDim2.fromOffset(PAD, GAUGE_TOP),
		Size = UDim2.new(1, -2 * PAD, 0, GAUGE_HEIGHT),
		BackgroundTransparency = 1,
	}, board)

	local paperLeft = ROLLER_WIDTH - 6
	local paper = Ui.make("Frame", {
		Position = UDim2.fromOffset(paperLeft, 6),
		Size = UDim2.new(1, -2 * paperLeft, 1, -12),
		BackgroundColor3 = Ui.PARCHMENT,
		BorderSizePixel = 0,
	}, gauge)
	Ui.stroke(paper, INK, 2)

	local track = Ui.make("Frame", {
		Position = UDim2.fromOffset(PAPER_INSET, PAPER_INSET),
		Size = UDim2.new(1, -2 * PAPER_INSET, 1, -2 * PAPER_INSET),
		BackgroundColor3 = BAND_COLORS.Miss,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, paper)

	-- One band per grade window, from its start up to where the better one begins.
	local windowEnd = 1
	for _, grade in Tuning.Kick.grades do
		local width = windowEnd - grade.from
		local band = Ui.make("Frame", {
			Position = UDim2.fromScale(grade.from, 0),
			Size = UDim2.fromScale(width, 1),
			BackgroundColor3 = BAND_COLORS[grade.id] or BAND_COLORS.Miss,
			BorderSizePixel = 0,
		}, track)
		-- Lighter at the top, as a brush leaves it.
		Ui.make("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 190, 184)),
		}, band)
		if width >= NAMED_BAND then
			Ui.text(band, {
				Size = UDim2.fromScale(1, 1),
				TextSize = 22,
				TextColor3 = INK,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = Strings.get("Grade" .. grade.id),
			})
		else
			-- The best band is too narrow for a word: it gets a red seal.
			Ui.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(16, 16),
				Rotation = 45,
				BackgroundColor3 = Ui.SEAL,
				BorderSizePixel = 0,
			}, band)
		end
		if grade.from > 0 then
			Ui.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(grade.from, 0),
				Size = UDim2.new(0, 2, 1, 0),
				BackgroundColor3 = INK,
				BorderSizePixel = 0,
			}, track)
		end
		windowEnd = grade.from
	end

	for _, right in { false, true } do
		local roller = Ui.make("Frame", {
			AnchorPoint = Vector2.new(if right then 1 else 0, 0),
			Position = UDim2.new(if right then 1 else 0, 0, 0, -6),
			Size = UDim2.new(0, ROLLER_WIDTH, 1, 12),
			BackgroundColor3 = DARK_WOOD,
			BorderSizePixel = 0,
		}, gauge)
		Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, roller)
		Ui.stroke(roller, INK, 2)
		local shine = Ui.make("Frame", {
			Position = UDim2.fromOffset(6, 12),
			Size = UDim2.new(0, 5, 1, -24),
			BackgroundColor3 = WOOD,
			BorderSizePixel = 0,
		}, roller)
		Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shine)
	end

	local railLeft = paperLeft + PAPER_INSET
	return Ui.make("Frame", {
		Position = UDim2.fromOffset(railLeft, 0),
		Size = UDim2.new(1, -2 * railLeft, 1, 0),
		BackgroundTransparency = 1,
	}, gauge)
end

-- A seal of the streak row: an empty socket, and the stamp that fills it for a Perfect.
local function buildSeal(parent: Instance, order: number): Seal
	local socket = disc(parent, {
		LayoutOrder = order,
		Size = UDim2.fromOffset(SEAL, SEAL),
		BackgroundColor3 = Ui.CARD,
	})
	Ui.stroke(socket, Ui.EDGE, 2)

	local rim = disc(socket, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = DEEP_RED,
		Visible = false,
	})
	local scale: UIScale = Ui.make("UIScale", {}, rim)
	local stamp = disc(rim, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.82, 0.82),
		BackgroundColor3 = Ui.SEAL,
	})
	-- A check brushed across the stamp: a short stroke down and a long one up.
	for _, stroke in
		{
			{ x = 0.34, y = 0.60, length = 0.30, turn = 45 },
			{ x = 0.58, y = 0.47, length = 0.56, turn = -52 },
		}
	do
		local bar = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(stroke.x, stroke.y),
			Size = UDim2.fromScale(stroke.length, 0.13),
			Rotation = stroke.turn,
			BackgroundColor3 = Ui.PARCHMENT,
			BorderSizePixel = 0,
		}, stamp)
		Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, bar)
	end
	return { stamp = stamp, rim = rim, scale = scale }
end

function KickBar.start()
	local screen = Ui.screen("KickBar", 15)
	local board = Ui.panel(screen, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -BOTTOM),
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	Ui.stroke(board, Ui.EDGE, 2)
	local fit: UIScale = Ui.make("UIScale", {}, board)
	Ui.onResize(function()
		local room = Ui.room()
		fit.Scale =
			math.clamp(math.min((room.X - 24) / WIDTH, (room.Y - BOTTOM - 80) / HEIGHT), 0.45, 1)
	end)

	-- Above the scroll: what to do, and after a press what it was worth.
	local title = Ui.text(board, {
		Position = UDim2.fromOffset(PAD, 8),
		Size = UDim2.new(1, -2 * PAD, 0, TITLE_HEIGHT),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("KickHint"),
	})

	local rail = buildGauge(board)

	-- The marker: a line across the bands under a paper tag with the player's own kunai, tip
	-- down. Paper, because a black kunai would be lost on anything dark.
	-- It has no width of its own, so its position on the rail is exactly the bar position.
	local marker = Ui.make("Frame", {
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
	}, rail)
	local bandsTop = 6 + PAPER_INSET
	local bandsHeight = GAUGE_HEIGHT - 2 * bandsTop
	Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, bandsTop - 2),
		Size = UDim2.fromOffset(9, bandsHeight + 4),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
	}, marker)
	Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(0, bandsTop),
		Size = UDim2.fromOffset(5, bandsHeight),
		BackgroundColor3 = Ui.WHITE,
		BorderSizePixel = 0,
	}, marker)
	local token = disc(marker, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset(0, bandsTop + 9),
		Size = UDim2.fromOffset(TOKEN, TOKEN),
		BackgroundColor3 = Ui.PARCHMENT,
	})
	Ui.stroke(token, INK, 3)
	local tokenIcon = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.94),
		BackgroundTransparency = 1,
	}, token)

	-- Under the scroll: one seal per Perfect in a row, and what a full row is for.
	local streakRow = Ui.make("Frame", {
		Position = UDim2.fromOffset(PAD, STREAK_TOP),
		Size = UDim2.new(1, -2 * PAD, 0, STREAK_HEIGHT),
		BackgroundTransparency = 1,
	}, board)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 14),
	}, streakRow)
	local streakLabel = Ui.text(streakRow, {
		LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = 24,
	})
	local needed = Tuning.Kick.sageStreak
	local sealRow = Ui.make("Frame", {
		LayoutOrder = 2,
		Size = UDim2.fromOffset(needed * SEAL + (needed - 1) * 8, SEAL),
		BackgroundTransparency = 1,
	}, streakRow)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, sealRow)
	local seals: { Seal } = {}
	for i = 1, needed do
		seals[i] = buildSeal(sealRow, i)
	end
	local streakGoal = Ui.text(streakRow, {
		LayoutOrder = 3,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		TextSize = 22,
	})

	local shownKunai = 0
	local shownStreak = 0
	Store.onChange(function(state)
		if state.kunai ~= shownKunai then
			shownKunai = state.kunai
			tokenIcon:ClearAllChildren()
			local kunai = Catalog.kunai[math.clamp(state.kunai, 1, #Catalog.kunai)]
			Icons.kunai(tokenIcon, kunai.id, Ui.PARCHMENT, 180)
		end

		local ready = state.streak >= needed
		for i, seal in seals do
			local stamped = i <= state.streak
			seal.rim.Visible = stamped
			seal.rim.BackgroundColor3 = if ready then Color3.fromRGB(204, 142, 20) else DEEP_RED
			seal.stamp.BackgroundColor3 = if ready then Ui.GOLD else Ui.SEAL
			-- A seal that was just earned lands with a thump.
			if stamped and i > shownStreak then
				seal.scale.Scale = 1.7
				TweenService:Create(
					seal.scale,
					TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
			end
		end
		shownStreak = state.streak

		local multiplier = Tuning.Kick.sageMultiplier
		streakLabel.Text = Strings.get(if ready then "KickSageLabel" else "KickStreakLabel")
		streakLabel.TextColor3 = if ready then Ui.GOLD else Ui.PARCHMENT
		streakGoal.Text = if ready
			then Strings.get("KickSageGoal", multiplier)
			else Strings.get("KickStreakGoal", needed, multiplier)
		streakGoal.TextColor3 = if ready then Ui.GOLD else Ui.MUTED
	end)

	local active = false
	local pressed = false
	local startedAt = 0
	local period = Tuning.Kick.barPeriod

	Remotes.KickStart.OnClientEvent:Connect(function(barPeriod: number)
		period = barPeriod
		startedAt = os.clock()
		active = true
		pressed = false
		title.Text = Strings.get("KickHint")
		title.TextColor3 = Ui.WHITE
		title.TextSize = 30
		board.Visible = true
	end)

	RunService.RenderStepped:Connect(function()
		if active and not pressed then
			local position = Kick.barPosition(os.clock() - startedAt, period)
			marker.Position = UDim2.fromScale(position, 0)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		-- A click that landed on a button or a window is not a throw.
		if processed then
			return
		end
		local isPress = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.ButtonA
		if not isPress or not active or pressed then
			return
		end
		local elapsed = os.clock() - startedAt
		if elapsed < ARM_DELAY then
			return
		end
		pressed = true
		Remotes.KickPress:FireServer(elapsed)
	end)

	Remotes.KickResult.OnClientEvent:Connect(function(result: Net.KickResult?)
		active = false
		-- A bar that was cancelled (the player stepped off the strip) just goes away.
		if not result then
			board.Visible = false
			return
		end

		local color = GRADE_COLORS[result.grade]
		local percent = math.floor(result.power * 100 + 0.5)
		title.Text = Strings.get("KickGrade", Strings.get("Grade" .. result.grade), percent)
		title.TextColor3 = color or Ui.WHITE
		title.TextSize = 34
		-- The frozen marker stays on screen for a moment so the player sees where they hit.
		task.delay(RESULT_SECONDS, function()
			if not active then
				board.Visible = false
			end
		end)

		local text = Strings.get("KickResult", result.grade, result.distance, zoneName(result.zone))
		if result.luck > 1 then
			text = Strings.get("KickLucky", result.luck) .. text
		end
		if result.sage then
			text = Strings.get("KickSage") .. text
		end
		Hud.toast(text, color)
	end)
end

return KickBar
