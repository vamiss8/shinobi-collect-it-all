--!strict
-- The village's music as a player (owner, 2026-10-18: "let the village's tracks be switched in
-- the settings: next, previous, repeat and so on, and the whole playlist, so that I know for
-- sure which to point at"). Opened from the settings' row of the village's music (client
-- SettingsPanel): the track under way, by the name the Creator Store gives it, and how far it
-- has played; the buttons back, next, repeat (the one track over and over) and shuffle; and
-- every track of the playlist, the one under way in gold. A track pressed plays from its start.
-- During a chase or an event their own track is heard and the village's waits for the player to
-- be home, which the window says. Nothing of it is saved: a visit begins with shuffle on and
-- repeat off.

local RunService = game:GetService("RunService")

local Audio = require("./Audio")
local Strings = require("./Strings")
local Ui = require("./Ui")

local MusicPanel = {}

local SIZE = Vector2.new(640, 620)
local ROW = 54
local BUTTON = Vector2.new(140, 56)
local BUTTON_GAP = 12
-- How often the time played is written while the window is open, seconds.
local TICK = 0.25

local window: Ui.Window? = nil

-- "1:05" for seconds.
local function clock(seconds: number): string
	local whole = math.max(math.floor(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- A switch is gold while on.
local function paint(button: TextButton, on: boolean)
	button.BackgroundColor3 = if on then Ui.GOLD else Ui.CARD
	button.TextColor3 = if on then Ui.INK else Ui.PARCHMENT
end

local function build(): Ui.Window
	local made = Ui.window("Music", SIZE)
	made.title.Text = Strings.get("MusicTitle")
	local body = made.body

	-- What plays now.
	Ui.text(body, {
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 20,
		TextColor3 = Ui.GOLD,
		Text = Strings.get("MusicNow"),
	})
	local name = Ui.text(body, {
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, -130, 0, 44),
		TextSize = 34,
		TextColor3 = Ui.PARCHMENT,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local played = Ui.text(body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 28),
		Size = UDim2.fromOffset(130, 44),
		TextSize = 24,
		TextColor3 = Ui.MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local waits = Ui.text(body, {
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 19,
		TextColor3 = Ui.MUTED,
		Text = Strings.get("MusicWaits"),
		Visible = false,
	})

	-- The buttons.
	local top = 106
	local function control(index: number, key: string, press: () -> ()): TextButton
		local button = Ui.button(body, {
			Position = UDim2.fromOffset((index - 1) * (BUTTON.X + BUTTON_GAP), top),
			Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
			BackgroundColor3 = Ui.CARD,
			TextSize = 24,
			Text = Strings.get(key),
		})
		button.Activated:Connect(press)
		return button
	end
	control(1, "MusicPrevious", function()
		Audio.skipVillage(-1)
	end)
	control(2, "MusicNext", function()
		Audio.skipVillage(1)
	end)
	local repeating = control(3, "MusicRepeat", function()
		Audio.setRepeat(not Audio.repeating())
	end)
	local shuffling = control(4, "MusicShuffle", function()
		Audio.setShuffle(not Audio.shuffling())
	end)

	-- Every track of the playlist.
	local listTop = top + BUTTON.Y + 18
	local list = Ui.scroll(body, {
		Position = UDim2.fromOffset(0, listTop),
		Size = UDim2.new(1, 0, 1, -listTop),
		ScrollBarThickness = 8,
	})
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8),
	}, list)
	Ui.padding(list, 3)
	local rows: { { button: TextButton, length: TextLabel } } = {}
	for index, track in Audio.playlist() do
		local button = Ui.button(list, {
			LayoutOrder = index,
			Size = UDim2.new(1, -16, 0, ROW),
			BackgroundColor3 = Ui.CARD,
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = `   {index}.  {track.name}`,
		})
		local length = Ui.text(button, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -16, 0.5, 0),
			Size = UDim2.fromOffset(80, ROW),
			TextSize = 22,
			TextColor3 = Ui.MUTED,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = clock(track.length),
		})
		button.Activated:Connect(function()
			Audio.playVillage(index)
		end)
		table.insert(rows, { button = button, length = length })
	end

	local function draw()
		local at, heard = Audio.villageAt()
		local track = if at then Audio.playlist()[at] else nil
		name.Text = if track then track.name else "-"
		waits.Visible = at ~= nil and not heard
		for index, row in rows do
			local on = index == at
			paint(row.button, on)
			row.length.TextColor3 = if on then Ui.INK else Ui.MUTED
		end
		paint(repeating, Audio.repeating())
		paint(shuffling, Audio.shuffling())
	end
	Audio.onPlaylist(draw)
	made.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if made.frame.Visible then
			draw()
		end
	end)

	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < TICK or not made.isOpen() then
			return
		end
		since = 0
		local now, length = Audio.villageClock()
		played.Text = `{clock(now)} / {clock(length)}`
	end)
	draw()
	return made
end

-- Opens the music window, built the first time.
function MusicPanel.open()
	local built = window or build()
	window = built
	built.open()
end

return MusicPanel
