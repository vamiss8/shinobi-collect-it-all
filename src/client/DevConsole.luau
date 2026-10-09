--!strict
-- The developer console, on the screen: a window from which a developer gives themselves
-- whatever there is to look at in the game, without playing up to it. It is built only on the
-- client of a player the server has marked as a developer, with a tile of its own on the left
-- edge (F2 opens it too); for everyone else this module does nothing at all.
--
-- The window only asks. Whether the asker may is decided on the server, for every command, by
-- the account it comes from (Services/DevConsole): a client that built this window without
-- being a developer would be asking a server that does not answer.
--
-- A tool for one, so its words are written here and not in client/Strings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Events = require(ReplicatedStorage.Shared.Logic.Events)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Hud = require("./Hud")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Ui = require("./Ui")

local DevConsole = {}

local SIZE = Vector2.new(860, 640)
local ROW = 46
local GAP = 10
local LABEL = 92
-- "Reset save" asks to be pressed twice, this long apart at most, seconds.
local ARMED_SECONDS = 3

local function send(...: any)
	Remotes.Dev:FireServer(...)
end

-- A gear: what the tile is marked with.
local function drawIcon(holder: Instance)
	local ring = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.66, 0.66),
		BackgroundColor3 = Ui.MUTED,
		BorderSizePixel = 0,
	}, holder)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
	for turn = 0, 135, 45 do
		Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.18, 0.96),
			Rotation = turn,
			BackgroundColor3 = Ui.MUTED,
			BorderSizePixel = 0,
		}, holder)
	end
	local hole = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.28, 0.28),
		BackgroundColor3 = Ui.PANEL,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, holder)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, hole)
end

local function build()
	local window = Ui.window("DevConsole", SIZE)
	window.title.Text = "Developer console"
	local body = window.body

	local tile = Hud.sideButton("Dev", Ui.MUTED, drawIcon, true)
	tile.Activated:Connect(window.toggle)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			window.toggle()
		end
	end)

	-- The rows stand one under another; a row is filled from the left.
	local rows = 0
	local function row(name: string): (Frame, (width: number) -> number)
		local frame = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, rows * (ROW + GAP)),
			Size = UDim2.new(1, 0, 0, ROW),
			BackgroundTransparency = 1,
		}, body)
		rows += 1
		Ui.text(frame, {
			Size = UDim2.new(0, LABEL, 1, 0),
			TextSize = 21,
			TextColor3 = Ui.PARCHMENT,
			Text = name,
		})
		local x = LABEL
		-- Where the next piece of the row goes, given how wide it is.
		local function take(width: number): number
			local at = x
			x += width + 8
			return at
		end
		return frame, take
	end

	local function caption(frame: Frame, at: number, width: number, text: string)
		Ui.text(frame, {
			Position = UDim2.fromOffset(at, 0),
			Size = UDim2.new(0, width, 1, 0),
			TextSize = 19,
			TextColor3 = Ui.MUTED,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = text,
		})
	end

	local function box(frame: Frame, at: number, width: number, text: string): TextBox
		local field: TextBox = Ui.make("TextBox", {
			Position = UDim2.fromOffset(at, 3),
			Size = UDim2.new(0, width, 1, -6),
			BackgroundColor3 = Ui.CARD,
			BorderSizePixel = 0,
			Font = Ui.FONT,
			TextSize = 21,
			TextColor3 = Ui.WHITE,
			PlaceholderColor3 = Ui.GRAY,
			ClearTextOnFocus = false,
			Text = text,
		}, frame)
		Ui.corner(field, 6)
		Ui.stroke(field, Ui.EDGE, 2)
		return field
	end

	local function press(
		frame: Frame,
		at: number,
		width: number,
		text: string,
		color: Color3,
		act: () -> ()
	): TextButton
		local button = Ui.button(frame, {
			Position = UDim2.fromOffset(at, 3),
			Size = UDim2.new(0, width, 1, -6),
			BackgroundColor3 = color,
			TextSize = 20,
			Text = text,
		})
		button.Activated:Connect(act)
		return button
	end

	-- A choice out of a list, stepped through with an arrow on either side. Returns what
	-- reads the place chosen and what gives it another list to choose from.
	local function stepper(
		frame: Frame,
		at: number,
		width: number,
		names: { string },
		changed: (() -> ())?
	): (() -> number, (names: { string }) -> ())
		local listed = names
		local chosen = 1
		local shown = Ui.text(frame, {
			Position = UDim2.fromOffset(at + 40, 3),
			Size = UDim2.new(0, width - 80, 1, -6),
			BackgroundColor3 = Ui.CARD,
			BackgroundTransparency = 0,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Ui.make("UITextSizeConstraint", { MaxTextSize = 21 }, shown)
		Ui.corner(shown, 6)
		local function show()
			shown.Text = listed[chosen] or ""
		end
		local function step(by: number)
			chosen = (chosen - 1 + by) % math.max(#listed, 1) + 1
			show()
			if changed then
				changed()
			end
		end
		press(frame, at, 36, "<", Ui.GRAY, function()
			step(-1)
		end)
		press(frame, at + width - 36, 36, ">", Ui.GRAY, function()
			step(1)
		end)
		show()
		return function()
			return chosen
		end, function(other: { string })
			listed = other
			chosen = 1
			show()
		end
	end

	-- What a field holds as a number, or what it holds when it is not one.
	local function typed(field: TextBox, otherwise: number): number
		return Format.parse(field.Text) or otherwise
	end

	-- Ryo and Chakra: an amount as a player types one ("1.5M"), put in place of what is there
	-- or added to it.
	for _, what in { { "Ryo", "ryo" }, { "Chakra", "chakra" } } do
		local frame, take = row(what[1])
		local field = box(frame, take(240), 240, "1M")
		press(frame, take(110), 110, "Set", Ui.GREEN, function()
			send(what[2], typed(field, 0), false)
		end)
		press(frame, take(110), 110, "Add", Ui.BLUE, function()
			send(what[2], typed(field, 0), true)
		end)
	end

	-- The numbers of a save that are counts.
	do
		local frame, take = row("Save")
		for _, what in
			{
				{ "rebirths", "Rebirths", "0" },
				{ "speed", "Speed", "0" },
				{ "kunai", "Kunai", "1" },
				{ "pads", "Pads +", "0" },
			}
		do
			caption(frame, take(66), 66, what[2])
			local field = box(frame, take(48), 48, what[3])
			press(frame, take(44), 44, "Set", Ui.GREEN, function()
				send(what[1], typed(field, 0))
			end)
		end
	end

	-- A shinobi: its zone, which of the zone's five, and its mutation.
	local zones, mutations, mutationIds = {}, { "No mutation" }, { Catalog.NONE }
	for number, zone in Catalog.zones do
		table.insert(zones, `{number}. {zone.name}`)
	end
	for _, mutation in Catalog.mutations do
		table.insert(mutations, mutation.name)
		table.insert(mutationIds, mutation.id)
	end
	local function roster(zoneNumber: number): { Catalog.Character }
		return Catalog.charactersByRank[Catalog.zones[zoneNumber].rank]
	end
	local function names(zoneNumber: number): { string }
		local list = {}
		for _, character in roster(zoneNumber) do
			table.insert(list, character.name)
		end
		return list
	end

	local whoFrame, whoTake = row("Shinobi")
	local zoneAt: () -> number
	local setWho: (names: { string }) -> ()
	zoneAt = stepper(whoFrame, whoTake(330), 330, zones, function()
		setWho(names(zoneAt()))
	end)
	local whoAt
	whoAt, setWho = stepper(whoFrame, whoTake(330), 330, names(1))

	local unitFrame, unitTake = row("")
	local mutationAt = stepper(unitFrame, unitTake(220), 220, mutations)
	caption(unitFrame, unitTake(50), 50, "Stars")
	local stars = box(unitFrame, unitTake(44), 44, "0")
	caption(unitFrame, unitTake(36), 36, "Lvl")
	local level = box(unitFrame, unitTake(52), 52, "1")
	caption(unitFrame, unitTake(20), 20, "x")
	local count = box(unitFrame, unitTake(44), 44, "1")
	press(unitFrame, unitTake(80), 80, "Give", Ui.GREEN, function()
		local character = roster(zoneAt())[whoAt()]
		if character then
			send(
				"unit",
				character.id,
				mutationIds[mutationAt()],
				typed(stars, 0),
				typed(level, 1),
				typed(count, 1)
			)
		end
	end)
	press(unitFrame, unitTake(112), 112, "Whole zone", Ui.BLUE, function()
		send("zone", zoneAt(), mutationIds[mutationAt()])
	end)

	-- What is done to the dojo as a whole.
	do
		local frame, take = row("Dojo")
		press(frame, take(220), 220, "Place on pads", Ui.GREEN, function()
			send("place")
		end)
		press(frame, take(220), 220, "Clear shinobi", Ui.RED, function()
			send("clear")
		end)
		local armed = 0
		local reset: TextButton
		reset = press(frame, take(220), 220, "Reset save", Ui.RED, function()
			if reset.Text == "Press again" then
				reset.Text = "Reset save"
				send("reset")
				return
			end
			armed += 1
			local mine = armed
			reset.Text = "Press again"
			task.delay(ARMED_SECONDS, function()
				if armed == mine then
					reset.Text = "Reset save"
				end
			end)
		end)
	end

	-- The legendary shinobi: given without Robux, and taken away again.
	do
		local frame, take = row("Legends")
		for _, legend in Catalog.legends do
			local give = press(frame, take(162), 162, `+ {legend.name}`, Ui.GOLD, function()
				send("legend", legend.id, true)
			end)
			give.TextColor3 = Ui.PANEL
			press(frame, take(40), 40, "-", Ui.GRAY, function()
				send("legend", legend.id, false)
			end)
		end
	end

	-- An event started by hand, for everyone on this server, and stopped again.
	do
		local frame, take = row("Event")
		for _, event in Events.list do
			press(frame, take(176), 176, event.name, Ui.SEAL, function()
				send("event", event.id)
			end)
		end
		press(frame, take(100), 100, "Stop", Ui.GRAY, function()
			send("event")
		end)
	end

	-- What the server said of the last command.
	local log = Ui.text(body, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundColor3 = Ui.CARD,
		BackgroundTransparency = 0,
		TextSize = 22,
		TextColor3 = Ui.GOLD,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "Amounts are typed as in the game: 3000, 3K, 1.5M, 2Qa. F2 opens this window.",
	})
	Ui.corner(log, 8)
	Remotes.Dev.OnClientEvent:Connect(function(said: unknown)
		if typeof(said) == "string" then
			log.Text = said
		end
	end)
end

function DevConsole.start()
	local player = Players.LocalPlayer
	local built = false
	local function check()
		if not built and player:GetAttribute(Net.DEVELOPER_ATTRIBUTE) == true then
			built = true
			build()
		end
	end
	player:GetAttributeChangedSignal(Net.DEVELOPER_ATTRIBUTE):Connect(check)
	check()
end

return DevConsole
