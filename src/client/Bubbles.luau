--!strict
-- Bonus seals that pop up while training. Breaking one with a click or a tap asks the server
-- for its multiplier; ignoring it costs nothing. A seal is a round medallion: a rim in the
-- multiplier's color around a parchment face with the multiplier written on it, and under it a
-- bar that runs out as the seal's time does. The rarer the multiplier, the larger the seal.
--
-- There is no keyboard key for it: the seal has to be found on the screen and clicked. A
-- gamepad has no pointer to click with, so its X button stands in.
--
-- A seal waiting to be broken breathes, a little larger and back, and sends a ring of its
-- color out round it, the rarer the quicker; broken, it swells and is gone in a burst of its
-- color, a ring thrown wide and sparks flying out (owner, 2026-10-17: "small pulsing
-- animations on the x2 x5 x10 buttons that come up, and animations when they are pressed").
-- How long the boost has left is shown over the bar of slots (client BoostTimer).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Audio = require("./Audio")
local Hud = require("./Hud")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local Bubbles = {}

local INK = Color3.fromRGB(58, 40, 30)

-- How each multiplier looks: the color of its rim, how wide the seal is, and how long one of
-- its breaths takes.
type Look = { color: Color3, size: number, breath: number }
local LOOKS: { [number]: Look } = {
	[2] = { color = Ui.GREEN, size = 140, breath = 1.2 },
	[5] = { color = Ui.BLUE, size = 154, breath = 1.0 },
	[10] = { color = Ui.GOLD, size = 170, breath = 0.8 },
}
-- How far from the middle of the screen a seal's middle keeps, in layout pixels.
local CLEAR_OF_MIDDLE = 250
local PLAIN: Look = { color = Ui.GREEN, size = 140, breath = 1.2 }
-- How much larger a seal grows at the top of a breath, and how far its ring goes out.
local SWELL = 1.07
local RING_OUT = 1.55
-- The burst when one is broken: how many sparks, how far they fly as a share of the seal's
-- width, and how long it lasts.
local SPARKS = 10
local SPARK_REACH = 0.95
local BURST_SECONDS = 0.5

type Shown = {
	id: number,
	multiplier: number,
	button: TextButton,
	pop: UIScale, -- the seal's own scale, which it breathes and bursts by
	breathing: Tween,
	spot: UDim2, -- where its middle is
}

-- The color of a multiplier's seal; the boost's timer goes by the same (client BoostTimer).
function Bubbles.colorOf(multiplier: number): Color3
	return (LOOKS[multiplier] or PLAIN).color
end

local function round(frame: Instance)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
end

-- Draws the seal as a button under `parent`, centered on a point given in shares of the screen,
-- and sets it breathing. Returns the button, its scale and the breath's tween.
local function draw(
	parent: Instance,
	offer: Net.Bubble,
	x: number,
	y: number
): (TextButton, UIScale, Tween)
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

	-- A ring of its color goes out from under the rim and fades, over and over.
	local ring = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 0,
	}, button)
	round(ring)
	local ringEdge = Ui.stroke(ring, look.color, 5)
	local spread = TweenInfo.new(look.breath, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1)
	TweenService:Create(ring, spread, { Size = UDim2.fromScale(RING_OUT, RING_OUT) }):Play()
	TweenService:Create(ringEdge, spread, { Transparency = 1, Thickness = 1 }):Play()

	-- The seal snaps open rather than just appearing, so it catches the eye, and then breathes.
	local pop: UIScale = Ui.make("UIScale", { Scale = 0.5 }, button)
	TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
	local breathing = TweenService:Create(
		pop,
		TweenInfo.new(look.breath / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = SWELL }
	)
	task.delay(0.2, function()
		if button.Parent then
			breathing:Play()
		end
	end)

	return button, pop, breathing
end

-- A broken seal's burst, where it stood: a ring of its color thrown wide and sparks flying
-- out from its middle, all fading. Takes care of itself.
local function burst(parent: Instance, spot: UDim2, multiplier: number)
	local look = LOOKS[multiplier] or PLAIN
	local made: { Instance } = {}
	local out = TweenInfo.new(BURST_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local ring = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = spot,
		Size = UDim2.fromOffset(look.size, look.size),
		BackgroundTransparency = 1,
	}, parent)
	round(ring)
	local edge = Ui.stroke(ring, look.color, 8)
	TweenService:Create(ring, out, {
		Size = UDim2.fromOffset(look.size * 2.2, look.size * 2.2),
	}):Play()
	TweenService:Create(edge, out, { Transparency = 1, Thickness = 1 }):Play()
	table.insert(made, ring)

	local flash = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = spot,
		Size = UDim2.fromOffset(look.size * 0.8, look.size * 0.8),
		BackgroundColor3 = Ui.PARCHMENT,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, parent)
	round(flash)
	TweenService
		:Create(flash, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(look.size * 1.3, look.size * 1.3),
			BackgroundTransparency = 1,
		})
		:Play()
	table.insert(made, flash)

	local reach = look.size * SPARK_REACH
	for index = 1, SPARKS do
		local angle = (index - 0.5) / SPARKS * 2 * math.pi
		local spark = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = spot,
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = if index % 2 == 0 then Ui.PARCHMENT else look.color,
			BorderSizePixel = 0,
		}, parent)
		round(spark)
		TweenService:Create(spark, out, {
			Position = spot + UDim2.fromOffset(math.cos(angle) * reach, math.sin(angle) * reach),
			Size = UDim2.fromOffset(4, 4),
			BackgroundTransparency = 1,
		}):Play()
		table.insert(made, spark)
	end

	task.delay(BURST_SECONDS + 0.05, function()
		for _, piece in made do
			piece:Destroy()
		end
	end)
end

function Bubbles.start()
	local screen = Ui.screen("Bubbles", 12)
	local rng = Random.new()
	local shown: Shown? = nil

	-- Takes a seal down: it shrinks away, or, broken, swells and bursts.
	local function remove(bubble: Shown, broken: boolean?)
		if shown == bubble then
			shown = nil
		end
		local button = bubble.button
		if not button.Parent then
			return
		end
		button.Active = false
		bubble.breathing:Cancel()
		if broken then
			burst(screen, bubble.spot, bubble.multiplier)
			local swell = TweenService:Create(
				bubble.pop,
				TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1.3 }
			)
			swell.Completed:Connect(function()
				TweenService:Create(
					bubble.pop,
					TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.In),
					{ Scale = 0 }
				):Play()
			end)
			swell:Play()
		else
			TweenService:Create(
				bubble.pop,
				TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{ Scale = 0 }
			):Play()
		end
		task.delay(0.25, function()
			button:Destroy()
		end)
	end

	local function pop()
		local bubble = shown
		if not bubble then
			return
		end
		remove(bubble, true)
		Remotes.BubblePop:FireServer(bubble.id)
		Audio.play("bubble")

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
		local y = rng:NextNumber(0.3, 0.5)
		local button, scale, breathing = draw(screen, offer, x, y)
		local bubble: Shown = {
			id = offer.id,
			multiplier = offer.multiplier,
			button = button,
			pop = scale,
			breathing = breathing,
			spot = UDim2.fromScale(x, y),
		}
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
