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
-- The tutorial, the changelog and the questions asked often are to have rows here too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

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

local SIZE = Vector2.new(760, 560)
local ROW = 72
local ROW_GAP = 14
local LABEL = 236
local CONTROL = 250
local STEP = 56
-- A change is sent to the server once the player has stopped changing things for this long.
local SEND_AFTER = 0.4
-- The gear's tile, the size of the window tiles on the edges (Hud.sideButton). On a touch
-- screen, where Roblox's jump button has the corner, it is one of those tiles.
local TILE = Vector2.new(112, 116)

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

-- The settings as the server last put them on the player, or the defaults.
local function saved(): SettingsLogic.Settings
	local player = Players.LocalPlayer
	return SettingsLogic.clean({
		language = player:GetAttribute(Net.SETTING_LANGUAGE),
		font = player:GetAttribute(Net.SETTING_FONT),
		music = player:GetAttribute(Net.SETTING_MUSIC),
		effects = player:GetAttribute(Net.SETTING_EFFECTS),
	}, SettingsLogic.defaults())
end

function SettingsPanel.start()
	local settings = saved()
	SettingsPanel.music().Volume = settings.music
	SettingsPanel.effects().Volume = settings.effects

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

	-- A volume: -, a bar of ten, +, and how much in all.
	local function volume(
		index: number,
		key: string,
		read: () -> number,
		write: (value: number) -> ()
	)
		local top = row(index, key)
		local cells: { Frame } = {}
		local bar = Ui.make("Frame", {
			Position = UDim2.fromOffset(CONTROL + STEP + 8, top + (ROW - 30) / 2),
			Size = UDim2.fromOffset(260, 30),
			BackgroundTransparency = 1,
		}, body)
		for cell = 1, 10 do
			local frame = Ui.make("Frame", {
				Position = UDim2.new((cell - 1) / 10, 2, 0, 0),
				Size = UDim2.new(0.1, -4, 1, 0),
				BorderSizePixel = 0,
			}, bar)
			Ui.corner(frame, 4)
			cells[cell] = frame
		end
		local value = Ui.text(body, {
			Position = UDim2.fromOffset(CONTROL + STEP + 8 + 260 + 8 + STEP + 10, top),
			Size = UDim2.fromOffset(90, ROW),
			TextSize = 24,
			TextColor3 = Ui.GOLD,
		})
		local function draw()
			local level = math.floor(read() * 10 + 0.5)
			for cell, frame in cells do
				frame.BackgroundColor3 = if cell <= level then Ui.GOLD else Ui.CARD
			end
			value.Text = `{level * 10}%`
		end
		local function change(by: number)
			write(math.clamp(read() + by * SettingsLogic.STEP, 0, 1))
			draw()
			send()
		end
		local less = Ui.button(body, {
			Position = UDim2.fromOffset(CONTROL, top + (ROW - STEP) / 2),
			Size = UDim2.fromOffset(STEP, STEP),
			BackgroundColor3 = Ui.CARD,
			TextSize = 32,
			Text = "-",
		})
		less.Activated:Connect(function()
			change(-1)
		end)
		local more = Ui.button(body, {
			Position = UDim2.fromOffset(CONTROL + STEP + 8 + 260 + 8, top + (ROW - STEP) / 2),
			Size = UDim2.fromOffset(STEP, STEP),
			BackgroundColor3 = Ui.CARD,
			TextSize = 32,
			Text = "+",
		})
		more.Activated:Connect(function()
			change(1)
		end)
		draw()
	end

	volume(1, "SettingsMusic", function()
		return settings.music
	end, function(value)
		settings.music = value
		SettingsPanel.music().Volume = value
	end)
	volume(2, "SettingsEffects", function()
		return settings.effects
	end, function(value)
		settings.effects = value
		SettingsPanel.effects().Volume = value
	end)

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
