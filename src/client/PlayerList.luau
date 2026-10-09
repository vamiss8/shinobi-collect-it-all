--!strict
-- The list of players, the game's own: a hanging scroll in the top right corner, where
-- Roblox's list was. Under "ONLINE 4/6" the players stand BY RANK (owner, 2026-10-09: "take
-- the 'Shinobi 1' line away and leave the ranks on the right; with two Jonin, an ANBU, an ANBU
-- Captain, an Academy Student and a Sage of Six Paths there are five sub-columns with the
-- players' names in them, and 'online: 6/6' on top; and the ranks glow there as they do
-- elsewhere"): every rank somebody on the server holds has a band with its emblem and its
-- name, in its color and lettered as over its holders' heads (Config/Lettering `titles`), the
-- highest rank first; under a band are the names of those who hold it and what their dojos
-- earn a second, the richest first. Roblox's own list is switched off.
--
-- The numbers are read off the Players themselves, where the server keeps them as attributes
-- (Services/State). Tab hides the list and brings it back, as it does Roblox's.
--
-- WHERE IT HANGS. The window buttons stand at the middle of the same edge (client Hud), and
-- the corner over them has room for nine lines or so. A list that fits there, at its size or
-- a little smaller, hangs in the corner. One that does not (six players of five ranks are
-- eleven lines) hangs just left of the buttons instead, where it may be as long as it likes,
-- rather than be drawn too small to read.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Icons = require("./Icons")
local Lettering = require("./Lettering")
local Looks = require(ReplicatedStorage.Shared.Config.Lettering)
local Net = require(ReplicatedStorage.Shared.Net)
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Strings = require("./Strings")
local Ui = require("./Ui")

local PlayerList = {}

local WIDTH = 322
local HEADER = 48
-- A rank's band and a player's line, and the gap under each.
local BAND = 30
local ROW = 28
local GAP = 2
local FOOT = 12
local SEAL = 24
-- A player's line stands in from its rank's band by this much.
local INDENT = 14
-- What a line's income may take of its width, and a band's count of holders.
local INCOME = 96
local COUNT = 38
-- The window buttons stand at the middle of the same edge (client Hud): a list in the corner
-- keeps this far above the middle of the screen. It may be drawn this much smaller to fit;
-- smaller than that it hangs beside the buttons instead, BESIDE from the right edge, and
-- keeps LOW clear at the foot of the screen.
local CLEAR_OF_BUTTONS = 150
local CORNER_LEAST = 0.85
local BESIDE = -140
local LOW = 190
local BESIDE_LEAST = 0.6
local ROLLER = Color3.fromRGB(93, 64, 55)
local ROLLER_END = Color3.fromRGB(141, 98, 72)
-- Where the list hangs in the corner, from the screen's right edge, and where it is when put
-- away: off that edge. It slides between the two, in and out, this long each way, seconds, and
-- from the corner to beside the buttons in MOVE.
local HUNG = -24
local AWAY = WIDTH + 60
local SLIDE_IN = 0.3
local SLIDE_OUT = 0.22
local MOVE = 0.2

type Row = {
	frame: Frame,
	edge: UIStroke,
	name: TextLabel,
	income: TextLabel,
}

-- The band of a rank.
type Band = {
	frame: Frame,
	count: TextLabel,
}

-- A number the server keeps on a player, or nothing yet.
local function number(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

-- One of the scroll's two rods, across its top or its foot, with a knob on each end.
local function rod(sheet: Frame, at: number)
	local bar = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, at),
		Size = UDim2.new(1, 18, 0, 18),
		BackgroundColor3 = ROLLER,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, sheet)
	Ui.corner(bar, 9)
	for _, tip in { 0, 1 } do
		local knob = Ui.make("Frame", {
			AnchorPoint = Vector2.new(tip, 0.5),
			Position = UDim2.fromScale(tip, 0.5),
			Size = UDim2.fromOffset(8, 12),
			BackgroundColor3 = ROLLER_END,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, bar)
		Ui.corner(knob, 4)
	end
end

-- The band of the rank held after `done` rebirths: a strip of ink with the rank's emblem, its
-- name in its color, lettered if the rank is, and how many on the server hold it.
local function band(sheet: Frame, done: number): Band
	local frame = Ui.make("Frame", {
		Size = UDim2.new(1, -16, 0, BAND),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.06,
		BorderSizePixel = 0,
	}, sheet)
	Ui.corner(frame, 7)
	local seal = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 4, 0.5, 0),
		Size = UDim2.fromOffset(SEAL, SEAL),
		BackgroundTransparency = 1,
	}, frame)
	Icons.rank(seal, done)
	-- At a size of its own, not fitted to its box: the lettering of the highest rank draws
	-- copies of the word, and a copy has to come out the size of the word.
	local name = Ui.text(frame, {
		Position = UDim2.fromOffset(SEAL + 12, 0),
		Size = UDim2.new(1, -(SEAL + 12 + COUNT + 6), 1, 0),
		TextSize = 19,
		TextColor3 = Color3.fromHex(Rebirth.color(done)),
		Text = string.upper(Rebirth.title(done)),
	})
	Lettering.dress(name, Looks.key("title", tostring(done)))
	local count = Ui.text(frame, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0, COUNT, 1, 0),
		TextSize = 17,
		TextColor3 = Ui.MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	return { frame = frame, count = count }
end

local function row(sheet: Frame): Row
	local frame = Ui.make("Frame", {
		Size = UDim2.new(1, -(16 + INDENT), 0, ROW),
		BackgroundColor3 = Ui.INK,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, sheet)
	Ui.corner(frame, 7)
	local edge = Ui.stroke(frame, Ui.SEAL, 2)
	local name = Ui.text(frame, {
		Position = UDim2.fromOffset(8, 2),
		Size = UDim2.new(1, -(8 + INCOME + 12), 1, -4),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 13 }, name)
	local income = Ui.text(frame, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 2),
		Size = UDim2.new(0, INCOME, 1, -4),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 13 }, income)
	return { frame = frame, edge = edge, name = name, income = income }
end

function PlayerList.start()
	-- Roblox's list goes. The call fails until its interface is up, so it is tried for a
	-- while.
	task.spawn(function()
		for _ = 1, 30 do
			local done = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			end)
			if done then
				return
			end
			task.wait(0.5)
		end
	end)

	local screen = Ui.screen("Players", 9)
	-- A phone has no room for it beside the buttons, and no Tab to bring it back with.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local sheet: Frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, HUNG, 0, 16),
		Size = UDim2.fromOffset(WIDTH, HEADER + FOOT),
		BackgroundColor3 = Ui.PARCHMENT,
		BorderSizePixel = 0,
		Visible = not touch,
	}, screen)
	Ui.corner(sheet, 4)
	Ui.stroke(sheet, Ui.EDGE, 3)
	rod(sheet, 0)
	rod(sheet, 1)
	local scale: UIScale = Ui.make("UIScale", {}, sheet)

	local title = Ui.text(sheet, {
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 24,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	-- A red brush stroke under the title.
	Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 40),
		Size = UDim2.new(1, -56, 0, 3),
		BackgroundColor3 = Ui.SEAL,
		BorderSizePixel = 0,
	}, sheet)

	local rows: { [Player]: Row } = {}
	-- A band for every rank that has been held on this server, by the rebirths it takes.
	local bands: { [number]: Band } = {}
	-- Whether the list is on the screen (Tab puts it away), and where it hangs from the right
	-- edge when it is.
	local hung = sheet.Visible
	local hangs = HUNG

	-- Writes every line anew and puts them in order: the highest rank first, and under each
	-- rank the richest dojo first.
	local function draw()
		local listed = Players:GetPlayers()
		local ranks: { [Player]: number } = {}
		local holders: { [number]: number } = {}
		for _, player in listed do
			local done = Rebirth.done(number(player, Net.PLAYER_REBIRTHS))
			ranks[player] = done
			holders[done] = (holders[done] or 0) + 1
		end
		table.sort(listed, function(a, b)
			if ranks[a] ~= ranks[b] then
				return ranks[a] > ranks[b]
			end
			local earnsA, earnsB = number(a, Net.PLAYER_INCOME), number(b, Net.PLAYER_INCOME)
			if earnsA ~= earnsB then
				return earnsA > earnsB
			end
			return a.UserId < b.UserId
		end)
		title.Text = Strings.get("PlayersTitle", #listed, Players.MaxPlayers)

		for done, strip in bands do
			strip.frame.Visible = holders[done] ~= nil
		end
		local y = HEADER
		local last: number? = nil
		for _, player in listed do
			local done = ranks[player]
			if done ~= last then
				last = done
				local strip = bands[done]
				if not strip then
					strip = band(sheet, done)
					bands[done] = strip
				end
				strip.frame.Position = UDim2.fromOffset(8, y)
				strip.count.Text = Strings.get("PlayersCount", holders[done])
				y += BAND + GAP
			end
			local line = rows[player]
			if not line then
				line = row(sheet)
				rows[player] = line
			end
			local own = player == Players.LocalPlayer
			line.frame.Position = UDim2.fromOffset(8 + INDENT, y)
			line.frame.BackgroundTransparency = if own then 0.9 else 1
			line.edge.Transparency = if own then 0 else 1
			line.name.Text = player.DisplayName
			-- To a tenth: "1.2B" tells two dojos apart where "1B" did not.
			line.income.Text =
				Strings.get("PlayersIncome", Format.short(number(player, Net.PLAYER_INCOME), 1))
			y += ROW + GAP
		end

		local height = y + FOOT
		sheet.Size = UDim2.fromOffset(WIDTH, height)
		local room = Ui.room()
		local corner = (room.Y / 2 - CLEAR_OF_BUTTONS) / height
		local was = hangs
		if corner >= CORNER_LEAST then
			hangs = HUNG
			scale.Scale = math.min(corner, 1)
		else
			hangs = BESIDE
			scale.Scale = math.clamp((room.Y - LOW) / height, BESIDE_LEAST, 1)
		end
		if hangs ~= was and hung then
			TweenService:Create(
				sheet,
				TweenInfo.new(MOVE, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.new(1, hangs, 0, 16) }
			):Play()
		end
	end
	Ui.onResize(draw)

	local function adopt(player: Player)
		player:GetAttributeChangedSignal(Net.PLAYER_REBIRTHS):Connect(draw)
		player:GetAttributeChangedSignal(Net.PLAYER_INCOME):Connect(draw)
		draw()
	end
	Players.PlayerAdded:Connect(adopt)
	Players.PlayerRemoving:Connect(function(player)
		local line = rows[player]
		if line then
			line.frame:Destroy()
			rows[player] = nil
		end
		-- The one leaving is still listed while this runs.
		task.defer(draw)
	end)
	for _, player in Players:GetPlayers() do
		adopt(player)
	end

	-- Tab slides it off the edge and back. Counted, so that a list on its way out that is
	-- called back is not hidden when it would have arrived.
	local slides = 0
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.KeyCode ~= Enum.KeyCode.Tab then
			return
		end
		hung = not hung
		slides += 1
		local mine = slides
		if hung then
			if not sheet.Visible then
				sheet.Position = UDim2.new(1, AWAY, 0, 16)
				sheet.Visible = true
			end
			TweenService:Create(
				sheet,
				TweenInfo.new(SLIDE_IN, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = UDim2.new(1, hangs, 0, 16) }
			):Play()
		else
			TweenService:Create(
				sheet,
				TweenInfo.new(SLIDE_OUT, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.new(1, AWAY, 0, 16) }
			):Play()
			task.delay(SLIDE_OUT, function()
				if slides == mine then
					sheet.Visible = false
				end
			end)
		end
	end)
end

return PlayerList
