--!strict
-- How long a broken bonus seal's boost has left (client Bubbles), on a slip of parchment
-- between the bar of slots and the Chakra Control board (owner, 2026-10-17: "take the yellow
-- writing about the boost off the left and add a timer of how the boost runs, between the
-- inventory and the Chakra Control menu"). The multiplier on a seal of its own color, what it
-- multiplies, and a bar of that color that empties with the seconds. It unrolls when a boost
-- begins, is written anew when a stronger one takes its place, and rolls up when it runs out.
-- While a shinobi is carried, the strip that names it stands where this does (client
-- InventoryPanel), so the slip stands beside that strip on its right.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bubbles = require("./Bubbles")
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local BoostTimer = {}

local SIZE = Vector2.new(330, 50)
local SEAL = 40
-- Its foot over the screen's foot: over the bar of slots (68 tall, 10 up) and under the
-- Chakra Control board (whose foot is 132 up), in the 54 between.
local FOOT = 82
-- Its middle from the screen's middle while the carried shinobi's strip (520 wide) is up.
local BESIDE = 260 + 14 + SIZE.X / 2
local TEXT_LEFT = 28 + SEAL + 12
local CLOCK = 58
-- A snapshot's seconds are taken over the client's own count only when they differ by this
-- much: one comes every second, and each is a little late.
local SLACK = 0.3

-- 0:07 for 7 seconds.
local function clock(seconds: number): string
	local whole = math.max(math.ceil(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

function BoostTimer.start()
	local layer = Ui.screen("BoostTimer", 13)
	local paper = Ui.parchment(layer, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -FOOT),
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		Visible = false,
	}, SEAL)
	local stamp = Ui.text(paper.seal, {
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		TextColor3 = Ui.PARCHMENT,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 22 }, stamp)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 4),
	}, stamp)
	local title = Ui.text(paper.page, {
		Position = UDim2.fromOffset(TEXT_LEFT, 4),
		Size = UDim2.new(1, -(TEXT_LEFT + 24 + CLOCK), 0, 22),
		TextScaled = true,
		TextColor3 = Ui.INK,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 20 }, title)
	local track = Ui.make("Frame", {
		Position = UDim2.fromOffset(TEXT_LEFT, 31),
		Size = UDim2.new(1, -(TEXT_LEFT + 24 + CLOCK), 0, 10),
		BackgroundColor3 = Ui.PANEL,
		BorderSizePixel = 0,
	}, paper.page)
	Ui.corner(track, 5)
	Ui.stroke(track, Ui.INK, 1.5)
	local fill = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, track)
	Ui.corner(fill, 5)
	local left = Ui.text(paper.page, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -22, 0.5, 0),
		Size = UDim2.fromOffset(CLOCK, 30),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 24 }, left)

	local multiplier = 1
	local endsAt = 0
	local open = false

	-- Writes the slip for a multiplier: its seal's color, the stamp, the words.
	local function write(boost: number)
		local color = Bubbles.colorOf(boost)
		paper.seal.BackgroundColor3 = color
		paper.edge.Color = color
		fill.BackgroundColor3 = color
		stamp.Text = Strings.get("Bubble", boost)
		title.Text = Strings.get("BoostChakra", boost)
	end

	Store.onChange(function(state: Net.Snapshot)
		local now = os.clock()
		-- A snapshot sent in the boost's last moments is not taken for a boost to show.
		local running = state.trainBoost > 1 and state.trainBoostLeft > SLACK
		paper.frame.Position = if state.held
			then UDim2.new(0.5, BESIDE, 1, -FOOT)
			else UDim2.new(0.5, 0, 1, -FOOT)
		if not running then
			return
		end
		local ends = now + state.trainBoostLeft
		if math.abs(ends - endsAt) > SLACK or state.trainBoost ~= multiplier then
			endsAt = ends
		end
		if not open then
			open = true
			multiplier = state.trainBoost
			write(multiplier)
			Ui.unroll(paper)
		elseif state.trainBoost ~= multiplier then
			-- A stronger seal broken while one runs: the slip shuts and opens on the new one.
			multiplier = state.trainBoost
			local boost = multiplier
			Ui.rewrite(paper, function()
				write(boost)
			end)
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
			Ui.rollUp(paper)
			return
		end
		fill.Size = UDim2.fromScale(math.clamp(remaining / Tuning.Training.boostSeconds, 0, 1), 1)
		left.Text = clock(remaining)
	end)
end

return BoostTimer
