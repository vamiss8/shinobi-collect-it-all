--!strict
-- How long a broken bonus seal's boost has left (client Bubbles), written between the bar of
-- slots and the Chakra Control board (owner, 2026-10-17: "take the yellow writing about the
-- boost off the left and add a timer of how the boost runs, between the inventory and the
-- Chakra Control menu"). A line and no more: "x2 Chakra  0:04" in the seal's color, edged in
-- ink so that it reads over the world. It was a scroll at first, and its rollers lay over the
-- bar of slots ("the menu gets in the way; no scroll, just the writing between them"). It
-- fades in when a boost begins, springs when a stronger one takes its place, and fades out
-- when it runs out. While a shinobi is carried, the strip that names it stands where this
-- does (client InventoryPanel), so the line stands beside that strip on its right.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Bubbles = require("./Bubbles")
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require("./Store")
local Strings = require("./Strings")
local Ui = require("./Ui")

local BoostTimer = {}

local SIZE = Vector2.new(300, 26)
-- Its foot over the screen's foot: over the bar of slots (68 tall, 10 up) and under the
-- Chakra Control board (whose foot is 132 up), in the middle of the 54 between.
local FOOT = 92
-- Its middle from the screen's middle while the carried shinobi's strip (520 wide) is up.
local BESIDE = 260 + 14 + SIZE.X / 2
-- A snapshot's seconds are taken over the client's own count only when they differ by this
-- much: one comes every second, and each is a little late.
local SLACK = 0.3
local FADE = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- 0:07 for 7 seconds.
local function clock(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function BoostTimer.start()
	local layer = Ui.screen("BoostTimer", 13)
	local line = Ui.text(layer, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -FOOT),
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
	})
	local edge = Ui.make("UIStroke", {
		Color = Ui.INK,
		Thickness = 2,
		Transparency = 1,
	}, line)
	local spring: UIScale = Ui.make("UIScale", {}, line)

	local multiplier = 1
	local endsAt = 0
	local open = false

	local function show(seen: boolean)
		local goal = if seen then 0 else 1
		TweenService:Create(line, FADE, { TextTransparency = goal }):Play()
		TweenService:Create(edge, FADE, { Transparency = goal }):Play()
	end

	Store.onChange(function(state: Net.Snapshot)
		local now = os.clock()
		line.Position = if state.held
			then UDim2.new(0.5, BESIDE, 1, -FOOT)
			else UDim2.new(0.5, 0, 1, -FOOT)
		-- A snapshot sent in the boost's last moments is not taken for a boost to show.
		if state.trainBoost <= 1 or state.trainBoostLeft <= SLACK then
			return
		end
		local ends = now + state.trainBoostLeft
		if math.abs(ends - endsAt) > SLACK or state.trainBoost ~= multiplier then
			endsAt = ends
		end
		if state.trainBoost ~= multiplier then
			multiplier = state.trainBoost
			line.TextColor3 = Bubbles.colorOf(multiplier)
			if open then
				-- A stronger seal broken while one runs: the line springs.
				spring.Scale = 1.25
				TweenService:Create(
					spring,
					TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Scale = 1 }
				):Play()
			end
		end
		if not open then
			open = true
			show(true)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if not open then
			return
		end
		local remaining = endsAt - os.clock()
		if remaining <= 0 then
			open = false
			multiplier = 1
			show(false)
			return
		end
		line.Text = `{Strings.get("BoostChakra", multiplier)}   {clock(remaining)}`
	end)
end

return BoostTimer
