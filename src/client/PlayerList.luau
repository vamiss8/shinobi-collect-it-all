--!strict
-- The list of players, the game's own: a hanging scroll in the top right corner, where
-- Roblox's list was, with a line for everyone on the server: their rank as a seal in its color
-- stamped with the rebirths they have done, their name, and what their dojo earns a second.
-- Roblox's own list is switched off; it could show the two numbers only as bare columns, the
-- income cut to "1B".
--
-- The numbers are read off the Players themselves, where the server keeps them as attributes
-- (Services/State). Tab hides the list and brings it back, as it does Roblox's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Strings = require("./Strings")
local Ui = require("./Ui")

local PlayerList = {}

local WIDTH = 322
local HEADER = 50
local ROW = 36
local GAP = 3
local FOOT = 12
local SEAL = 28
-- The window buttons stand at the middle of the same edge (client Hud): the list keeps this
-- far above the middle of the screen, and is drawn smaller when it would not.
local CLEAR_OF_BUTTONS = 150
-- What a line's income may take of its width.
local INCOME = 104
local ROLLER = Color3.fromRGB(93, 64, 55)
local ROLLER_END = Color3.fromRGB(141, 98, 72)

type Row = {
	frame: Frame,
	edge: UIStroke,
	seal: TextLabel,
	name: TextLabel,
	income: TextLabel,
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

local function row(sheet: Frame): Row
	local frame = Ui.make("Frame", {
		Size = UDim2.new(1, -20, 0, ROW),
		BackgroundColor3 = Ui.INK,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, sheet)
	Ui.corner(frame, 8)
	local edge = Ui.stroke(frame, Ui.SEAL, 2)
	local seal = Ui.badge(frame, "0", Ui.GRAY, SEAL)
	seal.AnchorPoint = Vector2.new(0, 0.5)
	seal.Position = UDim2.new(0, 5, 0.5, 0)
	Ui.stroke(seal, Ui.INK, 2)
	local name = Ui.text(frame, {
		Position = UDim2.fromOffset(SEAL + 14, 3),
		Size = UDim2.new(1, -(SEAL + 14 + INCOME + 10), 1, -6),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 21, MinTextSize = 13 }, name)
	local income = Ui.text(frame, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 3),
		Size = UDim2.new(0, INCOME, 1, -6),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 21, MinTextSize = 13 }, income)
	return { frame = frame, edge = edge, seal = seal, name = name, income = income }
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
		Position = UDim2.new(1, -24, 0, 16),
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
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 25,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	-- A red brush stroke under the title.
	Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 42),
		Size = UDim2.new(1, -56, 0, 3),
		BackgroundColor3 = Ui.SEAL,
		BorderSizePixel = 0,
	}, sheet)

	local rows: { [Player]: Row } = {}

	-- Writes every line anew and puts them in order: the highest rank first, and among equals
	-- the richest dojo.
	local function draw()
		local listed = Players:GetPlayers()
		table.sort(listed, function(a, b)
			local rankA, rankB = number(a, Net.PLAYER_REBIRTHS), number(b, Net.PLAYER_REBIRTHS)
			if rankA ~= rankB then
				return rankA > rankB
			end
			local earnsA, earnsB = number(a, Net.PLAYER_INCOME), number(b, Net.PLAYER_INCOME)
			if earnsA ~= earnsB then
				return earnsA > earnsB
			end
			return a.UserId < b.UserId
		end)
		title.Text = Strings.get("PlayersTitle", #listed)
		for place, player in listed do
			local line = rows[player]
			if not line then
				line = row(sheet)
				rows[player] = line
			end
			local done = Rebirth.done(number(player, Net.PLAYER_REBIRTHS))
			local own = player == Players.LocalPlayer
			line.frame.Position = UDim2.fromOffset(10, HEADER + (place - 1) * (ROW + GAP))
			line.frame.BackgroundTransparency = if own then 0.9 else 1
			line.edge.Transparency = if own then 0 else 1
			line.seal.Text = tostring(done)
			line.seal.BackgroundColor3 = Color3.fromHex(Rebirth.color(done))
			line.name.Text = player.DisplayName
			-- To a tenth: "1.2B" tells two dojos apart where "1B" did not.
			line.income.Text =
				Strings.get("PlayersIncome", Format.short(number(player, Net.PLAYER_INCOME), 1))
		end
		local height = HEADER + #listed * (ROW + GAP) + FOOT
		sheet.Size = UDim2.fromOffset(WIDTH, height)
		scale.Scale = math.clamp((Ui.room().Y / 2 - CLEAR_OF_BUTTONS) / height, 0.5, 1)
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

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Tab then
			sheet.Visible = not sheet.Visible
		end
	end)
end

return PlayerList
