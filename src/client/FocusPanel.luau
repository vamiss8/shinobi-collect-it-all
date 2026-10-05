--!strict
-- Chakra control, the active way to train. A ring closes in on a fixed target ring; the player
-- clicks or taps as the two meet. The server grades the press by its own clock (the same way it
-- grades a throw) and its answer starts the next ring.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
local OPEN = 190
local CLOSED = 26
-- If the server has not answered a press after this long, the ring starts moving again anyway.
local ANSWER_TIMEOUT = 1.5

local GRADE_COLORS: { [string]: Color3 } = {
	Perfect = Color3.fromRGB(255, 202, 40),
	Great = Color3.fromRGB(102, 187, 106),
	Good = Color3.fromRGB(66, 165, 245),
	Miss = Color3.fromRGB(189, 189, 189),
}

local function diameterAt(phase: number): number
	return OPEN + (CLOSED - OPEN) * phase
end

-- An empty circle drawn with an outline.
local function ring(parent: Instance, diameter: number, color: Color3, thickness: number): Frame
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundTransparency = 1,
	}, parent)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	Ui.stroke(frame, color, thickness)
	return frame
end

function FocusPanel.start()
	local screen = Ui.screen("Focus", 14)
	local holder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -120),
		Size = UDim2.fromOffset(OPEN + 20, OPEN + 50),
		BackgroundTransparency = 1,
		Visible = false,
	}, screen)

	Ui.text(holder, {
		Size = UDim2.new(1, 0, 0, 24),
		Font = Ui.BRUSH,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Text = Strings.get("FocusHint"),
	})
	local arena = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
	}, holder)

	local target = ring(arena, OPEN, GRADE_COLORS.Perfect, 5)
	local closing = ring(arena, OPEN, Ui.WHITE, 3)
	local result = Ui.text(arena, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(OPEN, 40),
		Font = Ui.BRUSH,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
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

	Remotes.Ring.OnClientEvent:Connect(function(round: Net.RingRound)
		result.Text = ""
		begin(round)
	end)

	Remotes.RingResult.OnClientEvent:Connect(function(hit: Net.RingResult)
		result.Text = if hit.gain > 0
			then Strings.get("FocusHit", hit.grade, hit.gain)
			else Strings.get("FocusMiss")
		result.TextColor3 = GRADE_COLORS[hit.grade] or Ui.WHITE
		begin(hit.next)
	end)

	RunService.RenderStepped:Connect(function()
		if not holder.Visible or not hasRound then
			return
		end
		local now = os.clock()
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
end

return FocusPanel
