--!strict
-- Chakra control, the active way to train. A ring closes in on a fixed target ring; the player
-- clicks or taps as the two meet. The server grades the press by its own clock (the same way it
-- grades a throw) and its answer starts the next ring.
--
-- It is drawn in the style of the game: a dark board with a gilt line inside its edge, a scroll
-- across the top with the hint in ink, and under it a round sheet of parchment like a target
-- painted by hand, ticked round its rim, with Chakra gathering blue at its heart under a red
-- seal. The two rings are strokes of a brush, heavier on one side than the other and turning
-- as a hand would have drawn them: the target in ink, the one that closes on it in seal red.
-- A press is answered on the sheet itself, by a ring of the grade's color going out from the
-- target, and in words, ink on a slip whose outline and seal take that color.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Focus = require(ReplicatedStorage.Shared.Logic.Focus)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local FocusPanel = {}

-- Diameter of the closing ring when it appears and when it has closed all the way, pixels.
local OPEN = 200
local CLOSED = 28
-- The sheet the rings are drawn on, and the board it lies on.
local SHEET = OPEN + 34
local BOARD = Vector2.new(SHEET + 56, SHEET + 150)
-- If the server has not answered a press after this long, the ring starts moving again anyway.
local ANSWER_TIMEOUT = 1.5
-- How fast the two brush strokes turn, degrees a second, and how long the Chakra at the heart
-- of the sheet takes to swell and sink again, seconds.
local TARGET_TURNS = 14
local CLOSING_TURNS = -150
local BREATH = 2.4
-- A hit sends a ring this much wider than the target out from it, over this many seconds.
local BURST_GROWS = 70
local BURST_SECONDS = 0.38
-- Ticks round the rim of the sheet; every sixth is longer and red.
local TICKS = 24

local GRADE_COLORS: { [string]: Color3 } = {
	Perfect = Color3.fromRGB(255, 202, 40),
	Great = Color3.fromRGB(102, 187, 106),
	Good = Color3.fromRGB(66, 165, 245),
	Miss = Color3.fromRGB(189, 189, 189),
}

local function diameterAt(phase: number): number
	return OPEN + (CLOSED - OPEN) * phase
end

-- A filled circle in the middle of `parent`.
local function disc(parent: Instance, diameter: number, color: Color3): Frame
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, parent)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	return frame
end

-- An empty circle drawn with an outline. Returns the circle and its outline.
local function ring(
	parent: Instance,
	diameter: number,
	color: Color3,
	thickness: number
): (Frame, UIStroke)
	local frame = disc(parent, diameter, color)
	frame.BackgroundTransparency = 1
	return frame, Ui.stroke(frame, color, thickness)
end

-- Makes an outline a stroke of the brush: full on one side and thinning out to `thin` on the
-- other. Returns the gradient that does it, which is turned to turn the stroke.
local function brushed(outline: UIStroke, thin: number): UIGradient
	return Ui.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0.05),
			NumberSequenceKeypoint.new(1, thin),
		}),
	}, outline)
end

function FocusPanel.start()
	local screen = Ui.screen("Focus", 14)
	local holder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -132),
		Size = UDim2.fromOffset(BOARD.X, BOARD.Y),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
		Visible = false,
	}, screen)
	Ui.corner(holder, 16)
	Ui.stroke(holder, Ui.EDGE, 3)
	-- A gilt line inside the board's edge.
	local gilt = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -14, 1, -14),
		BackgroundTransparency = 1,
	}, holder)
	Ui.corner(gilt, 11)
	Ui.stroke(gilt, Ui.GOLD, 1).Transparency = 0.5

	-- The hint: a scroll with its rollers, a seal marked "ki", and the words in ink.
	local scroll = Ui.parchment(holder, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 22),
		Size = UDim2.new(1, -64, 0, 40),
	}, 26)
	Ui.text(scroll.seal, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.72, 0.72),
		TextScaled = true,
		TextColor3 = Ui.PARCHMENT,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "気",
	})
	Ui.text(scroll.frame, {
		Position = UDim2.fromOffset(62, 5),
		Size = UDim2.new(1, -82, 1, -10),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("FocusHint"),
	})

	-- The sheet: parchment, ticked round its rim like the face of an instrument.
	local arena = disc(holder, SHEET, Ui.PARCHMENT)
	arena.AnchorPoint = Vector2.new(0.5, 0)
	arena.Position = UDim2.new(0.5, 0, 0, 78)
	Ui.stroke(arena, Ui.EDGE, 4)
	for index = 0, TICKS - 1 do
		local angle = index / TICKS * 2 * math.pi
		local long = index % 6 == 0
		local reach = SHEET / 2 - (if long then 10 else 8)
		Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.cos(angle) * reach, 0.5, math.sin(angle) * reach),
			Size = UDim2.fromOffset(if long then 3 else 2, if long then 12 else 7),
			Rotation = math.deg(angle) + 90,
			BackgroundColor3 = if long then Ui.SEAL else Ui.INK,
			BackgroundTransparency = if long then 0 else 0.45,
			BorderSizePixel = 0,
		}, arena)
	end
	-- Faint rings of ink, as a hand would rule them before painting.
	for _, share in { 0.75, 0.5, 0.25 } do
		local _, line = ring(arena, OPEN * share, Ui.INK, 1)
		line.Transparency = 0.8
	end
	-- Chakra gathering at the heart of the sheet: two washes of blue that swell and sink.
	local haze = disc(arena, CLOSED + 46, Ui.BLUE)
	haze.BackgroundTransparency = 0.82
	local wash = disc(arena, CLOSED + 18, Ui.BLUE)
	wash.BackgroundTransparency = 0.6

	local target, targetLine = ring(arena, OPEN, Ui.INK, 9)
	local targetBrush = brushed(targetLine, 0.6)
	local closing, closingLine = ring(arena, OPEN, Ui.SEAL, 5)
	local closingBrush = brushed(closingLine, 0.55)

	local heart = disc(arena, 18, Ui.SEAL)
	Ui.stroke(heart, Ui.INK, 2)
	local heartScale: UIScale = Ui.make("UIScale", {}, heart)

	-- What a hit sends out from the target: two rings, the second for a Perfect only.
	local bursts: { { frame: Frame, line: UIStroke } } = {}
	for _ = 1, 2 do
		local frame, line = ring(arena, OPEN, Ui.GOLD, 6)
		frame.Visible = false
		table.insert(bursts, { frame = frame, line = line })
	end

	-- The verdict: ink on a slip, the grade's color on its outline and its seal.
	local slip = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(1, -72, 0, 42),
		BackgroundColor3 = Ui.PARCHMENT,
		BorderSizePixel = 0,
		Visible = false,
	}, holder)
	Ui.corner(slip, 5)
	local slipEdge = Ui.stroke(slip, Ui.EDGE, 3)
	local slipScale: UIScale = Ui.make("UIScale", {}, slip)
	local slipSeal = disc(slip, 22, Ui.SEAL)
	slipSeal.AnchorPoint = Vector2.new(0, 0.5)
	slipSeal.Position = UDim2.new(0, 10, 0.5, 0)
	Ui.stroke(slipSeal, Ui.INK, 2)
	local result = Ui.text(slip, {
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -48, 1, 0),
		TextSize = 25,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local period = Tuning.Training.ringPeriodMax
	local startedAt = os.clock()
	-- False until the first round arrives.
	local hasRound = false
	-- When the last press was sent, while its answer is pending; the ring holds still meanwhile.
	local pressedAt: number? = nil

	-- Every round has its own speed and its own target size.
	local function begin(round: Net.RingRound)
		period = round.period
		local diameter = diameterAt(round.target)
		target.Size = UDim2.fromOffset(diameter, diameter)
		startedAt = os.clock()
		hasRound = true
		pressedAt = nil
	end

	-- Answers a press on the sheet: a ring of the grade's color goes out from where the target
	-- was and fades, a second after it for a Perfect, and the seal at the heart jumps.
	local function answer(grade: string, color: Color3, hit: boolean)
		local from = target.Size.X.Offset
		for index, burst in bursts do
			local shown = hit and (index == 1 or grade == "Perfect")
			burst.frame.Visible = shown
			if shown then
				local style = TweenInfo.new(
					BURST_SECONDS,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.Out,
					0,
					false,
					(index - 1) * 0.09
				)
				burst.frame.Size = UDim2.fromOffset(from, from)
				burst.line.Color = color
				burst.line.Transparency = 0
				local wide = from + BURST_GROWS
				TweenService:Create(burst.frame, style, { Size = UDim2.fromOffset(wide, wide) })
					:Play()
				TweenService:Create(burst.line, style, { Transparency = 1 }):Play()
			end
		end
		heartScale.Scale = if hit then 1.7 else 0.7
		TweenService:Create(
			heartScale,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end

	Remotes.Ring.OnClientEvent:Connect(function(round: Net.RingRound)
		slip.Visible = false
		begin(round)
	end)

	Remotes.RingResult.OnClientEvent:Connect(function(hit: Net.RingResult)
		local color = GRADE_COLORS[hit.grade] or Ui.EDGE
		answer(hit.grade, color, hit.gain > 0)
		result.Text = if hit.gain > 0
			then Strings.get("FocusHit", hit.grade, hit.gain)
			else Strings.get("FocusMiss")
		-- The grade's color goes to the slip's outline and its seal; the words stay ink.
		slipEdge.Color = color
		slipSeal.BackgroundColor3 = color
		slip.Visible = true
		slipScale.Scale = 0.7
		TweenService:Create(
			slipScale,
			TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
		begin(hit.next)
	end)

	RunService.RenderStepped:Connect(function()
		if not holder.Visible then
			return
		end
		local now = os.clock()
		-- The sheet is alive whether or not a ring is on its way: the strokes turn and the
		-- Chakra at its heart breathes.
		targetBrush.Rotation = (now * TARGET_TURNS) % 360
		closingBrush.Rotation = (now * CLOSING_TURNS) % 360
		local breath = 0.5 + 0.5 * math.sin(now / BREATH * 2 * math.pi)
		local wide = CLOSED + 14 + 10 * breath
		wash.Size = UDim2.fromOffset(wide, wide)
		wash.BackgroundTransparency = 0.66 - 0.14 * breath
		haze.Size = UDim2.fromOffset(wide + 26, wide + 26)

		if not hasRound then
			return
		end
		if pressedAt then
			if now - pressedAt < ANSWER_TIMEOUT then
				return
			end
			-- No answer came. Start the ring over rather than leave it frozen.
			pressedAt = nil
			startedAt = now
		end
		local diameter = diameterAt(Focus.phase(now - startedAt, period))
		closing.Size = UDim2.fromOffset(diameter, diameter)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		-- A click that landed on a button or a window is not a press.
		if processed or not holder.Visible or not hasRound or pressedAt then
			return
		end
		local isPress = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonR2
		if isPress then
			local now = os.clock()
			pressedAt = now
			Remotes.RingPress:FireServer(now - startedAt)
		end
	end)

	Store.onChange(function(state)
		holder.Visible = state.training == "focus"
	end)

	-- A window opening ends the exercise: the board stands where windows do, and a click
	-- meant for a window is not a press on the ring. The tool is put away, as moving would
	-- put it away. Meditation is left alone: it asks nothing of the player.
	Ui.onWindowOpened(function()
		local state = Store.get()
		local character = Players.LocalPlayer.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if state and state.training == "focus" and humanoid then
			humanoid:UnequipTools()
		end
	end)
end

return FocusPanel
