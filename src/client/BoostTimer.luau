--!strict
-- How long a broken bonus seal's boost has left (client Bubbles), written between the bar of
-- slots and the Chakra Control board (owner, 2026-10-17: "take the yellow writing about the
-- boost off the left and add a timer of how the boost runs, between the inventory and the
-- Chakra Control menu"). "x2 Chakra  0:04" in ink on a small scroll whose seal and outline
-- carry the seal's color. The first scroll here was a full one, and its rollers lay over the
-- bar of slots; then it was a bare line ("no scroll, just the writing"); then "the writing is
-- good, but add a light ground, a mini scroll with an opening animation, so long as it runs
-- into nothing". So a small scroll (Ui.parchment `small`: slim rollers, 4 past the sheet): 30
-- tall and 38 with its rollers, in the 54 between the bar (its top 78 up) and the board (its
-- foot 132 up), 8 clear of each. It unrolls when a boost begins, shuts and opens on the new
-- one when a stronger seal takes over, and rolls up when it runs out. While a shinobi is
-- carried, the strip that names it stands where this does (client InventoryPanel), so the
-- scroll stands beside that strip on its right.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Bubbles = require("./Bubbles")
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require("./Store")
local Strings = require("./Strings")
local Ui = require("./Ui")

local BoostTimer = {}

local SIZE = Vector2.new(250, 30)
local SEAL = 20
-- The sheet's foot over the screen's foot: its rollers then stand from 86 to 124 up.
local FOOT = 90
-- Its middle from the screen's middle while the carried shinobi's strip (520 wide) is up.
local BESIDE = 260 + 14 + SIZE.X / 2
-- Where the words begin: past the seal, which a small scroll puts 16 in from its left end.
local TEXT_LEFT = 16 + SEAL + 8
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
	}, SEAL, true)
	local line = Ui.text(paper.page, {
		Position = UDim2.fromOffset(TEXT_LEFT, 2),
		Size = UDim2.new(1, -(TEXT_LEFT + 12), 1, -4),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 22 }, line)

	local multiplier = 1
	local endsAt = 0
	local open = false

	-- The seal's color on the scroll's seal and outline; the words are ink.
	local function dress(boost: number)
		local color = Bubbles.colorOf(boost)
		paper.seal.BackgroundColor3 = color
		paper.edge.Color = color
	end

	local function write()
		line.Text = `{Strings.get("BoostChakra", multiplier)}   {clock(endsAt - os.clock())}`
	end

	Store.onChange(function(state: Net.Snapshot)
		local now = os.clock()
		paper.frame.Position = if state.held
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
		if not open then
			open = true
			multiplier = state.trainBoost
			dress(multiplier)
			write()
			Ui.unroll(paper)
		elseif state.trainBoost ~= multiplier then
			-- A stronger seal broken while one runs: the scroll shuts and opens on the new one.
			multiplier = state.trainBoost
			local boost = multiplier
			Ui.rewrite(paper, function()
				dress(boost)
				write()
			end)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if not open then
			return
		end
		if endsAt - os.clock() <= 0 then
			open = false
			multiplier = 1
			Ui.rollUp(paper)
			return
		end
		write()
	end)
end

return BoostTimer
