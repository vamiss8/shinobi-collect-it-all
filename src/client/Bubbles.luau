--!strict
-- Bonus bubbles that pop up while training. Popping one (click, tap, F or gamepad X) asks the
-- server for its multiplier; ignoring it costs nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Hud = require("./Hud")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local Bubbles = {}

local COLORS: { [number]: Color3 } = {
	[2] = Ui.GREEN,
	[5] = Ui.BLUE,
	[10] = Ui.GOLD,
}

type Shown = { id: number, multiplier: number, button: TextButton }

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

		local button: TextButton = Ui.make("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(rng:NextNumber(0.25, 0.75), rng:NextNumber(0.3, 0.62)),
			Size = UDim2.fromOffset(92, 92),
			BackgroundColor3 = COLORS[offer.multiplier] or Ui.GREEN,
			BorderSizePixel = 0,
			Font = Ui.BRUSH,
			TextColor3 = Ui.WHITE,
			TextSize = 34,
			TextStrokeTransparency = 0.5,
			Text = Strings.get("Bubble", offer.multiplier),
		}, screen)
		Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, button)
		if UserInputService.KeyboardEnabled then
			Ui.text(button, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 2),
				Size = UDim2.fromOffset(60, 20),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextStrokeTransparency = 0.4,
				Text = Strings.get("BubbleKey"),
			})
		end

		local bubble: Shown = { id = offer.id, multiplier = offer.multiplier, button = button }
		shown = bubble
		button.Activated:Connect(pop)
		task.delay(offer.seconds, function()
			remove(bubble)
		end)
	end)

	-- A bubble belongs to the training it came up in: putting the tool away takes it down.
	Store.onChange(function(state)
		if shown and not state.training then
			remove(shown)
		end
	end)

	-- With the mouse locked (Shift Lock, first person) a bubble cannot be clicked, so it also
	-- pops from the keyboard and the gamepad.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then
			pop()
		end
	end)
end

return Bubbles
