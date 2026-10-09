--!strict
-- Rebirth, on the player's side: a tile on the left edge of the screen, where the games this
-- one is kin to keep theirs, and the window it opens. On the window's left stand all the ranks
-- in their colors, the player's own marked; on its right, the rank to come on a scroll, how
-- far the player's Chakra is towards it, what it pays for good, what it resets and what stays,
-- and the one button that does it. The server decides whether it may be done
-- (Services/Rebirth); a rebirth that went through is celebrated on the same scroll a new speed
-- stage is (client StageFlash).
--
-- Everything here is large and short: the owner found the first window small and wordy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Hud = require("./Hud")
local Icons = require("./Icons")
local Lettering = require("./Lettering")
local Looks = require(ReplicatedStorage.Shared.Config.Lettering)
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Rebirths = require(ReplicatedStorage.Shared.Config.Rebirths)
local Remotes = require("./Remotes")
local StageFlash = require("./StageFlash")
local Store = require("./Store")
local Strings = require("./Strings")
local Ui = require("./Ui")

local RebirthPanel = {}

-- How long the button stays armed after its first press, seconds: a rebirth cannot be undone,
-- so it is pressed twice.
local ARMED_SECONDS = 4
-- The mark on the tile, when a rebirth comes within reach: it rocks to one side and the other
-- this many times, this far, each swing this long, and then stands still. Enough to be
-- noticed once; nothing that goes on nagging a player who is not after a rebirth.
local NUDGES = 3
local NUDGE_DEGREES = 22
local NUDGE_SECONDS = 0.13
-- What a rebirth pays, in the order of its cards: the caption, the color of the numbers, and
-- the multiplier `count` rebirths give.
local PAYS: { { caption: string, color: Color3, of: (count: number) -> number } } = {
	{ caption = "RebirthRyo", color = Ui.GOLD, of = Rebirth.ryo },
	{ caption = "RebirthPower", color = Ui.BLUE, of = Rebirth.chakra },
	{ caption = "RebirthLuck", color = Ui.GREEN, of = Rebirth.mutationLuck },
}

-- The window, and the list of ranks down its left side.
local SIZE = Vector2.new(1040, 700)
local LIST_WIDTH = 340
local ROW_HEIGHT = 48
local ROW_GAP = 4
-- The right side, top to bottom: where each piece begins and how tall it is.
local RIGHT = LIST_WIDTH + 16
local SCROLL = { top = 14, height = 120 }
local BAR = { top = 156, height = 62 }
local CARDS = { top = 236, height = 150 }
local RESETS_TOP = 404
local STAYS_TOP = 446
local LINE_HEIGHT = 38
local BUTTON = { top = 504, height = 110 }
local GAP = 12

type Row = { frame: Frame, edge: UIStroke }

-- One rank in the list: its number on a seal of its color, its name in that color (lettered,
-- for the highest), and the Chakra its rebirth asks.
local function rankRow(list: Instance, count: number): Row
	local color = Color3.fromHex(Rebirth.color(count))
	local frame = Ui.panel(list, {
		Position = UDim2.fromOffset(8, 52 + count * (ROW_HEIGHT + ROW_GAP)),
		Size = UDim2.new(1, -16, 0, ROW_HEIGHT),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 1,
	})
	local edge = Ui.stroke(frame, Ui.GOLD, 2)
	local seal = Ui.make("Frame", {
		Position = UDim2.fromOffset(5, 5),
		Size = UDim2.fromOffset(38, 38),
		BackgroundTransparency = 1,
	}, frame)
	Icons.rank(seal, count)
	local name = Ui.text(frame, {
		Position = UDim2.fromOffset(50, 4),
		Size = UDim2.new(1, -118, 1, -8),
		TextScaled = true,
		TextColor3 = color,
		Text = string.upper(Rebirth.title(count)),
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 15 }, name)
	Lettering.dress(name, Looks.key("title", tostring(count)))
	local asks = Rebirths[count]
	Ui.text(frame, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0, 58, 1, 0),
		TextSize = 21,
		TextColor3 = Ui.MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = if asks then Format.short(asks.chakra) else "",
	})
	return { frame = frame, edge = edge }
end

function RebirthPanel.start()
	local window = Ui.window("Rebirth", SIZE)
	window.title.Text = Strings.get("RebirthTitle")
	local body = window.body

	-- The tile says only that the next rebirth can be done: how many are behind the player
	-- their rank tells them.
	local tile, mark = Hud.sideButton(Strings.get("RebirthButton"), Ui.GOLD, Icons.rebirth, true)
	tile.Activated:Connect(window.toggle)
	local tileEdge = tile:FindFirstChildOfClass("UIStroke")
	mark.Text = "!"
	-- Rocks the mark, and grows it for as long as it rocks. Counted, so that one set off
	-- while another is still going takes over from it.
	local grown: UIScale = Ui.make("UIScale", {}, mark)
	local nudged = 0
	local function nudge()
		nudged += 1
		local mine = nudged
		local swing =
			TweenInfo.new(NUDGE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.spawn(function()
			TweenService:Create(grown, swing, { Scale = 1.4 }):Play()
			for _ = 1, NUDGES do
				for _, side in { -1, 1 } do
					if nudged ~= mine then
						return
					end
					TweenService:Create(mark, swing, { Rotation = side * NUDGE_DEGREES }):Play()
					task.wait(NUDGE_SECONDS)
				end
			end
			if nudged == mine then
				TweenService:Create(mark, swing, { Rotation = 0 }):Play()
				TweenService:Create(grown, swing, { Scale = 1 }):Play()
			end
		end)
	end
	local wasReady = false

	-- All the ranks, from the one every player starts with.
	local list = Ui.panel(body, {
		Size = UDim2.new(0, LIST_WIDTH, 1, 0),
		BackgroundColor3 = Ui.CARD,
		BackgroundTransparency = 0,
	})
	Ui.text(list, {
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 28,
		TextColor3 = Ui.PARCHMENT,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("RebirthRanks"),
	})
	local rows: { [number]: Row } = {}
	for count = 0, Rebirth.count() do
		rows[count] = rankRow(list, count)
	end

	-- The rank to come: a scroll, the rebirth's number on its seal; the rank's color goes to
	-- the seal and the outline, the words are ink.
	local scroll = Ui.parchment(body, {
		Position = UDim2.fromOffset(RIGHT + 12, SCROLL.top),
		Size = UDim2.new(1, -(RIGHT + 24), 0, SCROLL.height),
	}, 78)
	scroll.edge.Thickness = 4
	-- The rank's emblem lies over the seal, and is drawn anew when the rank shown changes.
	local emblem = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, scroll.seal)
	local drawn: number? = nil
	local title = Ui.text(scroll.page, {
		Position = UDim2.fromOffset(124, 8),
		Size = UDim2.new(1, -154, 0, 64),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 56 }, title)
	local now = Ui.text(scroll.page, {
		Position = UDim2.fromOffset(124, 74),
		Size = UDim2.new(1, -154, 0, 38),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 29 }, now)

	-- How far the player's Chakra is towards it.
	local track = Ui.make("Frame", {
		Position = UDim2.fromOffset(RIGHT, BAR.top),
		Size = UDim2.new(1, -RIGHT, 0, BAR.height),
		BackgroundColor3 = Ui.PANEL,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, body)
	Ui.corner(track, 10)
	Ui.stroke(track, Ui.EDGE, 2)
	local fill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.BLUE,
		BorderSizePixel = 0,
	}, track)
	local progress = Ui.text(track, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 31,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		ZIndex = 2,
	})

	-- What it pays: a card for each multiplier, what it is now and what it becomes.
	local changes: { TextLabel } = {}
	local cards = Ui.make("Frame", {
		Position = UDim2.fromOffset(RIGHT, CARDS.top),
		Size = UDim2.new(1, -RIGHT, 0, CARDS.height),
		BackgroundTransparency = 1,
	}, body)
	for index, pay in PAYS do
		-- Three across, a gap between each two.
		local card = Ui.panel(cards, {
			Position = UDim2.new((index - 1) / #PAYS, (index - 1) * GAP / #PAYS, 0, 0),
			Size = UDim2.new(1 / #PAYS, -GAP * (#PAYS - 1) / #PAYS, 1, 0),
			BackgroundColor3 = Ui.CARD,
			BackgroundTransparency = 0,
		})
		Ui.stroke(card, pay.color, 3)
		Ui.text(card, {
			Position = UDim2.fromOffset(0, 16),
			Size = UDim2.new(1, 0, 0, 36),
			TextSize = 28,
			TextColor3 = Ui.PARCHMENT,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = Strings.get(pay.caption),
		})
		changes[index] = Ui.text(card, {
			Position = UDim2.fromOffset(8, 62),
			Size = UDim2.new(1, -16, 0, 68),
			TextScaled = true,
			TextColor3 = pay.color,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Ui.make("UITextSizeConstraint", { MaxTextSize = 46 }, changes[index])
	end

	-- What it resets and what stays, a line each.
	local function line(top: number, key: string)
		local words = Ui.text(body, {
			Position = UDim2.fromOffset(RIGHT, top),
			Size = UDim2.new(1, -RIGHT, 0, LINE_HEIGHT),
			TextScaled = true,
			TextColor3 = Ui.PARCHMENT,
			RichText = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = Strings.get(key),
		})
		Ui.make("UITextSizeConstraint", { MaxTextSize = 27 }, words)
	end
	line(RESETS_TOP, "RebirthLoses")
	line(STAYS_TOP, "RebirthKeeps")

	local button = Ui.button(body, {
		Position = UDim2.fromOffset(RIGHT, BUTTON.top),
		Size = UDim2.new(1, -RIGHT, 0, BUTTON.height),
		TextScaled = true,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 46 }, button)
	Ui.padding(button, 14)
	-- Counts the arming of the button, so an old timer cannot disarm a newer press.
	local armed = 0
	local isArmed = false

	local function draw()
		local state = Store.get()
		if not state then
			return
		end
		local done = Rebirth.done(state.rebirths)
		local following = Rebirth.next(done)
		local ready = Rebirth.ready(state.chakra, done)

		mark.Visible = ready
		if ready and not wasReady then
			nudge()
		end
		wasReady = ready
		if tileEdge then
			tileEdge.Color = if ready then Ui.GOLD else Ui.EDGE
		end
		for count, row in rows do
			row.frame.BackgroundTransparency = if count == done then 0 else 1
			row.edge.Transparency = if count == done then 0 else 1
		end
		for index, pay in PAYS do
			changes[index].Text = if following
				then Strings.get("RebirthChange", pay.of(done), pay.of(done + 1))
				else Strings.get("RebirthHolds", pay.of(done))
		end
		fill.Size = UDim2.fromScale(Rebirth.progress(state.chakra, done), 1)
		fill.BackgroundColor3 = if ready then Ui.GREEN else Ui.BLUE

		-- The scroll names the rank to come, or the last one once it is reached.
		local shown = if following then done + 1 else done
		local color = Color3.fromHex(Rebirth.color(shown))
		scroll.edge.Color = color
		scroll.seal.BackgroundColor3 = color
		if drawn ~= shown then
			drawn = shown
			emblem:ClearAllChildren()
			Icons.rank(emblem, shown)
		end
		title.Text = string.upper(Rebirth.title(shown))
		if not following then
			now.Text = Strings.get("RebirthAllDone")
			progress.Text = Strings.get("HudChakra", state.chakra)
			button.Text = Strings.get("RebirthNoMore")
			button.BackgroundColor3 = Ui.GRAY
			button.AutoButtonColor = false
			return
		end
		now.Text = Strings.get("RebirthStep", Rebirth.title(done))
		progress.Text = Strings.get(
			"RebirthProgress",
			math.min(state.chakra, following.chakra),
			following.chakra
		)
		button.Text = if not ready
			then Strings.get("RebirthNeed", following.chakra - state.chakra)
			elseif isArmed then Strings.get("RebirthSure")
			else Strings.get("RebirthDo")
		button.BackgroundColor3 = if ready then Ui.SEAL else Ui.GRAY
		button.AutoButtonColor = ready
	end

	button.Activated:Connect(function()
		local state = Store.get()
		if not state or not Rebirth.ready(state.chakra, state.rebirths) then
			return
		end
		if isArmed then
			isArmed = false
			Remotes.Rebirth:FireServer()
		else
			isArmed = true
			armed += 1
			local mine = armed
			task.delay(ARMED_SECONDS, function()
				if armed == mine and isArmed then
					isArmed = false
					draw()
				end
			end)
		end
		draw()
	end)

	-- A rebirth that went through: the count went up since the last snapshot.
	local known: number? = nil
	Store.onChange(function(state)
		local done = Rebirth.done(state.rebirths)
		if known ~= nil and done > known then
			isArmed = false
			StageFlash.show(
				Color3.fromHex(Rebirth.color(done)),
				function(holder)
					Icons.rank(holder, done)
				end,
				string.upper(Rebirth.title(done)),
				Strings.get(
					"RebirthDone",
					Rebirth.ryo(done),
					Rebirth.chakra(done),
					Rebirth.mutationLuck(done)
				)
			)
			window.close()
		end
		known = done
		draw()
	end)
end

return RebirthPanel
