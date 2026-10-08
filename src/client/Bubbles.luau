--!strict
-- Bonus seals that pop up while training. Breaking one with a click or a tap asks the server
-- for its multiplier; ignoring it costs nothing. A seal is a round medallion: a rim in the
-- multiplier's color around a parchment face with the multiplier written on it, and under it a
-- bar that runs out as the seal's time does. The rarer the multiplier, the larger the seal.
--
-- There is no keyboard key for it: the seal has to be found on the screen and clicked. A
-- gamepad has no pointer to click with, so its X button stands in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Hud = require("./Hud")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local Bubbles = {}

local INK = Color3.fromRGB(58, 40, 30)

-- How each multiplier looks: the color of its rim and how wide the seal is.
local LOOKS: { [number]: { color: Color3, size: number } } = {
	[2] = { color = Ui.GREEN, size = 140 },
	[5] = { color = Ui.BLUE, size = 154 },
	[10] = { color = Ui.GOLD, size = 170 },
}
-- How far from the middle of the screen a seal's middle keeps, in layout pixels.
local CLEAR_OF_MIDDLE = 250
local PLAIN = { color = Ui.GREEN, size = 140 }

type Shown = { id: number, multiplier: number, button: TextButton }

local function round(frame: Instance)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
end

-- Draws the seal as a button under `parent`, centered on a point given in shares of the screen.
local function draw(parent: Instance, offer: Net.Bubble, x: number, y: number): TextButton
	local look = LOOKS[offer.multiplier] or PLAIN

	local button: TextButton = Ui.make("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromOffset(look.size, look.size),
		BackgroundColor3 = look.color,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
	}, parent)
	round(button)
	Ui.stroke(button, INK, 4)

	-- The face and what is written on it take no clicks of their own: they fall through to
	-- the button underneath.
	local face = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.78, 0.78),
		BackgroundColor3 = Ui.PARCHMENT,
		BorderSizePixel = 0,
	}, button)
	round(face)
	Ui.stroke(face, INK, 2)
	local amount = Ui.text(face, {
		Position = UDim2.fromScale(0.08, 0.1),
		Size = UDim2.fromScale(0.84, 0.56),
		TextScaled = true,
		TextColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("Bubble", offer.multiplier),
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 70 }, amount)
	local caption = Ui.text(face, {
		Position = UDim2.fromScale(0.14, 0.64),
		Size = UDim2.fromScale(0.72, 0.2),
		TextScaled = true,
		TextColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("BubbleCaption"),
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 22 }, caption)

	-- The time left, as a bar under the seal that empties.
	local timer = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 12),
		Size = UDim2.new(0.9, 0, 0, 10),
		BackgroundColor3 = Ui.PANEL,
		BorderSizePixel = 0,
	}, button)
	Ui.corner(timer, 5)
	Ui.stroke(timer, INK, 2)
	local left = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = look.color,
		BorderSizePixel = 0,
	}, timer)
	Ui.corner(left, 5)
	TweenService:Create(left, TweenInfo.new(offer.seconds, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(0, 1),
	}):Play()

	-- The seal snaps open rather than just appearing, so it catches the eye.
	local pop: UIScale = Ui.make("UIScale", { Scale = 0.5 }, button)
	TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	return button
end

function Bubbles.start()
	local screen = Ui.screen("Bubbles", 12)
	local rng = Random.new()
	local shown: Shown? = nil

	local function remove(bubble: Shown)
		bubble.button:Destroy()
		if shown == bubble then
			shown = nil
		end
	end

	local function pop()
		local bubble = shown
		if not bubble then
			return
		end
		remove(bubble)
		Remotes.BubblePop:FireServer(bubble.id)

		-- The server keeps a stronger boost that is still running; only announce a real change.
		local state = Store.get()
		if not state or bubble.multiplier >= state.trainBoost then
			Hud.toast(
				Strings.get("BoostStarted", bubble.multiplier, Tuning.Training.boostSeconds),
				Ui.GOLD
			)
		end
	end

	Remotes.Bubble.OnClientEvent:Connect(function(offer: Net.Bubble)
		if shown then
			remove(shown)
		end

		-- Somewhere in the middle of the screen: clear of the message scroll above and of the
		-- ring and the power bar below.
		-- To one side of the screen's middle or the other, never over it: the Chakra Control
		-- board stands there, in a layer above this one, and a seal behind it cannot be seen
		-- or broken. The gap is half the board, half a seal and a little room.
		local gap = math.min(CLEAR_OF_MIDDLE / Ui.room().X, 0.2)
		local side = if rng:NextInteger(0, 1) == 0 then -1 else 1
		local x = 0.5 + side * rng:NextNumber(gap, math.max(gap, 0.3))
		local button = draw(screen, offer, x, rng:NextNumber(0.3, 0.5))
		local bubble: Shown = { id = offer.id, multiplier = offer.multiplier, button = button }
		shown = bubble
		button.Activated:Connect(pop)
		task.delay(offer.seconds, function()
			remove(bubble)
		end)
	end)

	-- A seal belongs to the training it came up in: putting the tool away takes it down.
	Store.onChange(function(state)
		if shown and not state.training then
			remove(shown)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.ButtonX then
			pop()
		end
	end)
end

return Bubbles
