--!strict
-- The settings (Logic/Settings): a gear in the lower right corner of the screen (the owner's
-- place for it) and the window it opens. Music and sound effects, each a volume in tenths; the
-- language; and the face words are written in, the brush or a plain one for whoever finds the
-- brush hard to read. Every change is sent to the server, which keeps it in the save, so it
-- follows the player to any device.
--
-- The volumes are those of the two SoundGroups every sound of the game is to be put in (Music
-- and Effects in SoundService; there are no sounds yet). A face takes at once (client Fonts). A
-- language takes when the player comes back into the game, every word being written as the
-- interface is built: the window says so and offers to send them back into this same server.
--
-- Last, the village's music as a small player (owner, 2026-10-18: "a mini player like Spotify's
-- right in the settings; the whole playlist is not needed, five tracks are gone through in five
-- presses"): the track's name and its place in the playlist, a bar of how far it has played
-- (pressed, it goes there), the time played and the track's length, and buttons drawn as a
-- player's, not words: shuffle, back, play or pause, next, repeat, each saying what it does
-- under the pointer (Ui.tip). During a chase or an event their own track is heard and the
-- player says the village's waits.
--
-- The tutorial, the changelog and the questions asked often are to have rows here too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Audio = require("./Audio")
local Fonts = require("./Fonts")
local Hud = require("./Hud")
local Icons = require("./Icons")
local Language = require("./Language")
local Languages = require(ReplicatedStorage.Shared.Config.Languages)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local SettingsLogic = require(ReplicatedStorage.Shared.Logic.Settings)
local Strings = require("./Strings")
local Ui = require("./Ui")

local SettingsPanel = {}

local SIZE = Vector2.new(760, 720)
local ROW = 72
local ROW_GAP = 14
local LABEL = 236
local CONTROL = 250
local STEP = 56
-- The music player, right of its row's label: its size, where its buttons' middles stand, and
-- how often the time played is written while the window is open, seconds.
local PLAYER = Vector2.new(478, 146)
local PLAYER_BUTTONS = 114
local PLAYER_TICK = 0.2
-- A change is sent to the server once the player has stopped changing things for this long.
local SEND_AFTER = 0.4
-- The gear's tile, the size of the window tiles on the edges (Hud.sideButton). On a touch
-- screen, where Roblox's jump button has the corner, it is one of those tiles.
local TILE = Vector2.new(112, 116)
-- A volume's row: the bar of ten, and the mute button at the row's end.
local BAR = 220
local MUTE = 52

-- What a volume's row works on: the volume, whether it is muted, and its group of sounds.
type Volume = {
	read: () -> number,
	write: (value: number) -> (),
	muted: () -> boolean,
	mute: (on: boolean) -> (),
	group: () -> SoundGroup,
}

-- The two groups every sound of the game is to play in, made if they are not there.
local function group(name: string): SoundGroup
	local found = SoundService:FindFirstChild(name)
	if found and found:IsA("SoundGroup") then
		return found
	end
	local made = Instance.new("SoundGroup")
	made.Name = name
	made.Parent = SoundService
	return made
end

-- The group the game's music plays in, and the one its sound effects play in.
function SettingsPanel.music(): SoundGroup
	return group("Music")
end

function SettingsPanel.effects(): SoundGroup
	return group("Effects")
end

-- "1:05" for seconds.
local function clock(seconds: number): string
	local whole = math.max(math.floor(seconds), 0)
	return string.format("%d:%02d", whole // 60, whole % 60)
end

-- The settings as the server last put them on the player, or the defaults.
local function saved(): SettingsLogic.Settings
	local player = Players.LocalPlayer
	return SettingsLogic.clean({
		language = player:GetAttribute(Net.SETTING_LANGUAGE),
		font = player:GetAttribute(Net.SETTING_FONT),
		music = player:GetAttribute(Net.SETTING_MUSIC),
		effects = player:GetAttribute(Net.SETTING_EFFECTS),
		musicMuted = player:GetAttribute(Net.SETTING_MUSIC_MUTED),
		effectsMuted = player:GetAttribute(Net.SETTING_EFFECTS_MUTED),
	}, SettingsLogic.defaults())
end

function SettingsPanel.start()
	local settings = saved()
	SettingsPanel.music().Volume = if settings.musicMuted then 0 else settings.music
	SettingsPanel.effects().Volume = if settings.effectsMuted then 0 else settings.effects

	local window = Ui.window("Settings", SIZE)
	window.title.Text = Strings.get("SettingsTitle")
	local body = window.body

	-- The tile that opens it: a gear and the word under it, as the window tiles on the edges
	-- are drawn (the owner's own Dev tile among them). It stands in the lower right corner; on
	-- a touch screen, where the jump button is, among the window tiles (client Hud).
	local tile: TextButton
	if Ui.touch() then
		tile = Hud.sideButton(Strings.get("SettingsTitle"), Ui.MUTED, Icons.gear)
		tile.LayoutOrder = 20
	else
		local layer = Ui.screen("SettingsButton", 10)
		tile = Ui.button(layer, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -12),
			Size = UDim2.fromOffset(TILE.X, TILE.Y),
			BackgroundColor3 = Ui.PANEL,
			BackgroundTransparency = 0.08,
		})
		Ui.stroke(tile, Ui.MUTED, 3)
		local holder = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 8),
			Size = UDim2.fromOffset(68, 68),
			BackgroundTransparency = 1,
		}, tile)
		Icons.gear(holder)
		Ui.text(tile, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -8, 0, 28),
			TextColor3 = Ui.MUTED,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = Strings.get("SettingsTitle"),
		})
	end
	tile.Activated:Connect(window.toggle)

	-- Sends the settings once the player has stopped changing them.
	local sent = 0
	local function send()
		sent += 1
		local mine = sent
		task.delay(SEND_AFTER, function()
			if mine == sent then
				Remotes.Settings:FireServer(settings)
			end
		end)
	end

	local function row(index: number, key: string): number
		local top = (index - 1) * (ROW + ROW_GAP)
		Ui.text(body, {
			Position = UDim2.fromOffset(0, top),
			Size = UDim2.fromOffset(LABEL, ROW),
			TextSize = 28,
			TextColor3 = Ui.PARCHMENT,
			Text = Strings.get(key),
		})
		return top
	end

	-- A volume: -, a bar of ten, +, how much in all, and a button that mutes it (owner,
	-- 2026-10-18: "mute buttons for the effects and the music, so that one press mutes it all,
	-- and when unmuted the value comes back"). Muted, its sounds are silent and the bar keeps
	-- the volume, grayed, for when it is unmuted; a press on the bar, - or + unmutes it too.
	local function volume(index: number, key: string, the: Volume)
		local top = row(index, key)
		local plus = CONTROL + STEP + 8 + BAR + 8
		local cells: { TextButton } = {}
		local bar = Ui.make("Frame", {
			Position = UDim2.fromOffset(CONTROL + STEP + 8, top + (ROW - 30) / 2),
			Size = UDim2.fromOffset(BAR, 30),
			BackgroundTransparency = 1,
		}, body)
		for cell = 1, 10 do
			local frame: TextButton = Ui.make("TextButton", {
				Position = UDim2.new((cell - 1) / 10, 2, 0, 0),
				Size = UDim2.new(0.1, -4, 1, 0),
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
			}, bar)
			Ui.corner(frame, 4)
			cells[cell] = frame
		end
		local value = Ui.text(body, {
			Position = UDim2.fromOffset(plus + STEP + 8, top),
			Size = UDim2.fromOffset(SIZE.X - 32 - MUTE - 6 - (plus + STEP + 8), ROW),
			TextSize = 24,
			TextColor3 = Ui.GOLD,
		})
		local mute = Ui.button(body, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, top + (ROW - MUTE) / 2),
			Size = UDim2.fromOffset(MUTE, MUTE),
			BackgroundColor3 = Ui.CARD,
			Text = "",
		})
		local icon = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			BackgroundTransparency = 1,
		}, mute)
		local function draw()
			local muted = the.muted()
			local level = math.floor(the.read() * 10 + 0.5)
			for cell, frame in cells do
				frame.BackgroundColor3 = if cell > level
					then Ui.CARD
					elseif muted then Ui.GRAY
					else Ui.GOLD
			end
			value.Text = `{level * 10}%`
			value.TextColor3 = if muted then Ui.MUTED else Ui.GOLD
			mute.BackgroundColor3 = if muted then Ui.SEAL else Ui.CARD
			icon:ClearAllChildren()
			Icons.speaker(icon, muted, if muted then Ui.WHITE else Ui.PARCHMENT)
		end
		local function apply()
			the.group().Volume = if the.muted() then 0 else the.read()
			draw()
			send()
		end
		local function set(level: number)
			the.mute(false)
			the.write(math.clamp(level, 0, 1))
			apply()
		end
		-- A bar pressed sets the volume to it at once (owner, 2026-10-18: "at 30% a press on the
		-- eighth bar should make it 80%, not five presses of +"); the first, pressed again when
		-- it is the only one lit, turns the sound off.
		for cell, button in cells do
			button.Activated:Connect(function()
				local level = math.floor(the.read() * 10 + 0.5)
				local target = if cell == 1 and level == 1 and not the.muted() then 0 else cell
				Audio.play("click")
				set(target * SettingsLogic.STEP)
			end)
		end
		local less = Ui.button(body, {
			Position = UDim2.fromOffset(CONTROL, top + (ROW - STEP) / 2),
			Size = UDim2.fromOffset(STEP, STEP),
			BackgroundColor3 = Ui.CARD,
			TextSize = 32,
			Text = "-",
		})
		less.Activated:Connect(function()
			set(the.read() - SettingsLogic.STEP)
		end)
		local more = Ui.button(body, {
			Position = UDim2.fromOffset(plus, top + (ROW - STEP) / 2),
			Size = UDim2.fromOffset(STEP, STEP),
			BackgroundColor3 = Ui.CARD,
			TextSize = 32,
			Text = "+",
		})
		more.Activated:Connect(function()
			set(the.read() + SettingsLogic.STEP)
		end)
		mute.Activated:Connect(function()
			the.mute(not the.muted())
			apply()
			Ui.retip()
		end)
		Ui.tip(mute, function()
			return Strings.get(if the.muted() then "SettingsUnmute" else "SettingsMute")
		end)
		draw()
	end

	volume(1, "SettingsMusic", {
		read = function()
			return settings.music
		end,
		write = function(level)
			settings.music = level
		end,
		muted = function()
			return settings.musicMuted == true
		end,
		mute = function(on)
			settings.musicMuted = on
		end,
		group = SettingsPanel.music,
	})
	volume(2, "SettingsEffects", {
		read = function()
			return settings.effects
		end,
		write = function(level)
			settings.effects = level
		end,
		muted = function()
			return settings.effectsMuted == true
		end,
		mute = function(on)
			settings.effectsMuted = on
		end,
		group = SettingsPanel.effects,
	})

	-- The language: one of the list, stepped through, "Auto" first.
	local choices = { Languages.AUTO }
	for _, entry in Languages.list do
		table.insert(choices, entry.code)
	end
	local languageTop = row(3, "SettingsLanguage")
	local named = Ui.text(body, {
		Position = UDim2.fromOffset(CONTROL + STEP + 8, languageTop + 6),
		Size = UDim2.fromOffset(330, ROW - 12),
		BackgroundColor3 = Ui.PARCHMENT,
		BackgroundTransparency = 0,
		TextSize = 26,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.corner(named, 8)
	local note = Ui.text(body, {
		Position = UDim2.fromOffset(0, 3 * (ROW + ROW_GAP)),
		Size = UDim2.fromOffset(470, ROW),
		TextSize = 22,
		TextColor3 = Ui.GOLD,
		Text = Strings.get("SettingsRejoinNote"),
		Visible = false,
	})
	local rejoin = Ui.button(body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 3 * (ROW + ROW_GAP) + (ROW - STEP) / 2),
		Size = UDim2.fromOffset(240, STEP),
		BackgroundColor3 = Ui.SEAL,
		TextSize = 26,
		Text = Strings.get("SettingsRejoin"),
		Visible = false,
	})
	rejoin.Activated:Connect(function()
		Remotes.Rejoin:FireServer()
	end)
	local function nameOf(choice: string): string
		if choice == Languages.AUTO then
			local detected = Languages.byCode[Language.detected()]
			return Strings.get("SettingsAuto", if detected then detected.name else "")
		end
		local entry = Languages.byCode[choice]
		return if entry then entry.name else choice
	end
	local function drawLanguage()
		named.Text = nameOf(settings.language)
		local differs = (
			if settings.language == Languages.AUTO then Language.detected() else settings.language
		) ~= Language.current()
		note.Visible = differs
		rejoin.Visible = differs
	end
	local function step(by: number)
		local at = table.find(choices, settings.language) or 1
		settings.language = choices[(at - 1 + by) % #choices + 1]
		drawLanguage()
		send()
	end
	local back = Ui.button(body, {
		Position = UDim2.fromOffset(CONTROL, languageTop + (ROW - STEP) / 2),
		Size = UDim2.fromOffset(STEP, STEP),
		BackgroundColor3 = Ui.CARD,
		TextSize = 30,
		Text = "<",
	})
	back.Activated:Connect(function()
		step(-1)
	end)
	local forward = Ui.button(body, {
		Position = UDim2.fromOffset(CONTROL + STEP + 8 + 330 + 8, languageTop + (ROW - STEP) / 2),
		Size = UDim2.fromOffset(STEP, STEP),
		BackgroundColor3 = Ui.CARD,
		TextSize = 30,
		Text = ">",
	})
	forward.Activated:Connect(function()
		step(1)
	end)
	drawLanguage()

	-- The face: the brush or the plain one, each written in itself.
	local fontTop = row(5, "SettingsFont")
	local faces: { [string]: TextButton } = {}
	for index, choice in SettingsLogic.FONTS do
		local button = Ui.button(body, {
			Position = UDim2.fromOffset(CONTROL + (index - 1) * 244, fontTop + (ROW - STEP) / 2),
			Size = UDim2.fromOffset(230, STEP),
			TextSize = 28,
			Text = Strings.get(
				if choice == "plain" then "SettingsFontPlain" else "SettingsFontBrush"
			),
		})
		Fonts.keep(button, choice)
		button.Activated:Connect(function()
			if settings.font ~= choice then
				settings.font = choice
				Fonts.set(choice)
				for name, other in faces do
					other.BackgroundColor3 = if name == choice then Ui.GOLD else Ui.CARD
					other.TextColor3 = if name == choice then Ui.INK else Ui.PARCHMENT
				end
				send()
			end
		end)
		faces[choice] = button
	end
	for name, button in faces do
		button.BackgroundColor3 = if name == settings.font then Ui.GOLD else Ui.CARD
		button.TextColor3 = if name == settings.font then Ui.INK else Ui.PARCHMENT
	end

	-- The village's music: a small player.
	local playerTop = row(6, "MusicTitle")
	local player = Ui.make("Frame", {
		Position = UDim2.fromOffset(CONTROL, playerTop),
		Size = UDim2.fromOffset(PLAYER.X, PLAYER.Y),
		BackgroundTransparency = 1,
	}, body)
	local name = Ui.text(player, {
		Size = UDim2.new(1, -70, 0, 30),
		TextSize = 24,
		TextColor3 = Ui.PARCHMENT,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local place = Ui.text(player, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(70, 30),
		TextSize = 18,
		TextColor3 = Ui.MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	-- How far the track has played: pressed, the track goes to that point.
	local track: TextButton = Ui.make("TextButton", {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 10),
		BackgroundColor3 = Ui.CARD,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
	}, player)
	Ui.corner(track, 5)
	local fill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.GOLD,
		BorderSizePixel = 0,
	}, track)
	Ui.corner(fill, 5)
	track.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			local wide = track.AbsoluteSize.X
			if wide > 0 then
				Audio.seekVillage((input.Position.X - track.AbsolutePosition.X) / wide)
			end
		end
	end)
	local elapsed = Ui.text(player, {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.fromOffset(110, 22),
		TextSize = 18,
		TextColor3 = Ui.MUTED,
	})
	local total = Ui.text(player, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 56),
		Size = UDim2.fromOffset(110, 22),
		TextSize = 18,
		TextColor3 = Ui.MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	local waits = Ui.text(player, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(250, 22),
		TextSize = 16,
		TextColor3 = Ui.GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("MusicWaits"),
		Visible = false,
	})

	-- A round button with a drawn icon, `x` from the player's middle; its tip says what it does.
	local function control(
		x: number,
		size: number,
		tip: () -> string,
		press: () -> ()
	): (TextButton, Frame)
		local button = Ui.button(player, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, x, 0, PLAYER_BUTTONS),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = Ui.CARD,
		})
		local corner = button:FindFirstChildOfClass("UICorner")
		if corner then
			corner.CornerRadius = UDim.new(0.5, 0)
		end
		local holder = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.6, 0.6),
			BackgroundTransparency = 1,
		}, button)
		button.Activated:Connect(function()
			press()
			Ui.retip()
		end)
		Ui.tip(button, tip)
		return button, holder
	end
	local shuffleButton, shuffleIcon = control(-150, 44, function()
		return Strings.get("MusicShuffle")
	end, function()
		Audio.setShuffle(not Audio.shuffling())
	end)
	local _, backIcon = control(-76, 50, function()
		return Strings.get("MusicPrevious")
	end, function()
		Audio.skipVillage(-1)
	end)
	local playButton, playIcon = control(0, 62, function()
		return Strings.get(if Audio.paused() then "MusicPlay" else "MusicPause")
	end, function()
		Audio.setPaused(not Audio.paused())
	end)
	local _, nextIcon = control(76, 50, function()
		return Strings.get("MusicNext")
	end, function()
		Audio.skipVillage(1)
	end)
	local repeatButton, repeatIcon = control(150, 44, function()
		return Strings.get("MusicRepeat")
	end, function()
		Audio.setRepeat(not Audio.repeating())
	end)
	playButton.BackgroundColor3 = Ui.GOLD
	Icons.transport(backIcon, "previous", Ui.PARCHMENT)
	Icons.transport(nextIcon, "next", Ui.PARCHMENT)

	-- A switch is gold while on, its icon in ink.
	local function paint(button: TextButton, holder: Frame, kind: string, on: boolean)
		button.BackgroundColor3 = if on then Ui.GOLD else Ui.CARD
		holder:ClearAllChildren()
		Icons.transport(holder, kind, if on then Ui.INK else Ui.PARCHMENT)
	end
	local function drawPlayer()
		local at, heard = Audio.villageAt()
		local list = Audio.playlist()
		local current = if at then list[at] else nil
		name.Text = if current then current.name else "-"
		place.Text = if at then `{at} / {#list}` else ""
		waits.Visible = at ~= nil and not heard
		paint(shuffleButton, shuffleIcon, "shuffle", Audio.shuffling())
		paint(repeatButton, repeatIcon, "repeat", Audio.repeating())
		playIcon:ClearAllChildren()
		Icons.transport(playIcon, if Audio.paused() then "play" else "pause", Ui.INK)
	end
	Audio.onPlaylist(drawPlayer)
	drawPlayer()
	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < PLAYER_TICK or not window.isOpen() then
			return
		end
		since = 0
		local now, length = Audio.villageClock()
		fill.Size = UDim2.fromScale(if length > 0 then math.clamp(now / length, 0, 1) else 0, 1)
		elapsed.Text = clock(now)
		total.Text = clock(length)
	end)

	Ui.text(body, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 20,
		TextColor3 = Ui.MUTED,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("SettingsSaved"),
	})
end

return SettingsPanel
