--!strict
-- The leaderboards on the plaza (owner, 2026-10-18: "leaderboards by Ryo and by Chakra on the
-- spawn, in a fitting place; me, of course, not on them"): two boards in the plaza's front
-- quarters, facing the plaza with their backs to the throwing strip (World/Plaza,
-- Logic/PlazaPlan `leaderboards`). Each names the ten players with the most Ryo,
-- or the most Chakra, they hold now, of everyone who has played, not only those on this
-- server: the numbers are kept in a Roblox OrderedDataStore, so every server shows the same
-- boards. What a rebirth takes off a player, it takes off their place too.
--
-- Every minute each player's Ryo and Chakra are written (and once more as they leave), and
-- the boards are read and drawn anew. The game's developers (server/Developers) are written
-- nowhere and shown nowhere. The stores are named by the save store (Data.STORE), so the
-- testers' boards stay behind with their saves when the release starts afresh.
--
-- In Studio nothing is written to Roblox: a test run's saves are not the real ones (Data), and
-- the boards there show the players of the run, from what they hold.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Data = require("../Data")
local Developers = require("../Developers")
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Leaders = require(ReplicatedStorage.Shared.Logic.Leaders)
local Net = require(ReplicatedStorage.Shared.Net)
local Plaza = require("../World/Plaza")

local Leaderboards = {}

-- How often the players' numbers are written and the boards read, seconds.
local EVERY = 60
-- The boards, by the board's id in Logic/PlazaPlan: what each counts and is called.
type Board = { title: string, seal: string, of: (data: Data.Data) -> number }
local BOARDS: { [string]: Board } = {
	ryo = {
		title = "TOP RYO",
		seal = "両",
		of = function(data)
			return data.ryo
		end,
	},
	chakra = {
		title = "TOP CHAKRA",
		seal = "気",
		of = function(data)
			return data.chakra
		end,
	},
}
local NO_ONE = "No one yet"

local INK = Color3.fromRGB(58, 40, 30)
local SEAL = Color3.fromRGB(198, 40, 40)
local WHITE = Color3.new(1, 1, 1)
-- The first three places' seals: gold, silver, bronze; the others are written in ink.
local PLACES = {
	Color3.fromRGB(214, 168, 40),
	Color3.fromRGB(150, 150, 156),
	Color3.fromRGB(166, 98, 52),
}
-- How large a board's writing is drawn, pixels a stud.
local PIXELS = 40

local left: { [number]: boolean } = {}
for _, userId in Developers do
	left[userId] = true
end

local studio = RunService:IsStudio()
local stores: { [string]: OrderedDataStore } = {}
-- The names of players by user id, asked of Roblox once.
local names: { [number]: string } = {}

type Row = { place: TextLabel, seal: Frame, name: TextLabel, value: TextLabel }
local drawn: { [string]: { Row } } = {}

local function store(id: string): OrderedDataStore?
	if studio then
		return nil
	end
	local found = stores[id]
	if not found then
		local ok, made = pcall(function()
			return DataStoreService:GetOrderedDataStore(`{Data.STORE}_Top_{id}`)
		end)
		if not ok then
			return nil
		end
		found = made
		stores[id] = made
	end
	return found
end

local function label(parent: Instance, properties: { [string]: any }): TextLabel
	local made = Instance.new("TextLabel")
	made.BackgroundTransparency = 1
	made.Font = Enum.Font.PermanentMarker
	made.TextScaled = true
	made.TextColor3 = INK
	for key, value in properties do
		(made :: any)[key] = value
	end
	made.Parent = parent
	return made
end

-- Writes the board's title and its ten empty lines on its sheet.
local function build(id: string, sheet: BasePart)
	local board = BOARDS[id]
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Leaderboard"
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS
	gui.LightInfluence = 1
	gui.Parent = sheet

	local seal = Instance.new("Frame")
	seal.AnchorPoint = Vector2.new(0, 0.5)
	seal.Position = UDim2.fromScale(0.05, 0.095)
	seal.Size = UDim2.fromScale(0.12, 0.12)
	seal.BackgroundColor3 = SEAL
	seal.BorderSizePixel = 0
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.DominantAxis = Enum.DominantAxis.Height
	square.Parent = seal
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = seal
	seal.Parent = gui
	label(seal, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		TextColor3 = WHITE,
		Text = board.seal,
	})
	label(gui, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.2, 0.095),
		Size = UDim2.fromScale(0.75, 0.12),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = board.title,
	})
	local stroke = Instance.new("Frame")
	stroke.Position = UDim2.fromScale(0.05, 0.17)
	stroke.Size = UDim2.fromScale(0.9, 0.008)
	stroke.BackgroundColor3 = SEAL
	stroke.BorderSizePixel = 0
	stroke.Parent = gui

	local rows: { Row } = {}
	for index = 1, Leaders.SHOWN do
		local top = 0.195 + (index - 1) * 0.078
		local mark = Instance.new("Frame")
		mark.Position = UDim2.fromScale(0.05, top + 0.006)
		mark.Size = UDim2.fromScale(0.066, 0.066)
		mark.BackgroundColor3 = PLACES[index] or INK
		mark.BackgroundTransparency = if PLACES[index] then 0 else 1
		mark.BorderSizePixel = 0
		local fit = Instance.new("UIAspectRatioConstraint")
		fit.AspectRatio = 1
		fit.DominantAxis = Enum.DominantAxis.Height
		fit.Parent = mark
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = mark
		mark.Parent = gui
		local place = label(mark, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			TextColor3 = if PLACES[index] then WHITE else INK,
			Text = tostring(index),
		})
		local named = label(gui, {
			Position = UDim2.fromScale(0.16, top),
			Size = UDim2.fromScale(0.5, 0.072),
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
		})
		local value = label(gui, {
			Position = UDim2.fromScale(0.66, top),
			Size = UDim2.fromScale(0.29, 0.072),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = SEAL,
			Text = "",
		})
		rows[index] = { place = place, seal = mark, name = named, value = value }
	end
	drawn[id] = rows
end

-- The names of these players, asked of Roblox for those not known yet.
local function learn(userIds: { number })
	local unknown: { number } = {}
	for _, userId in userIds do
		if not names[userId] then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				names[userId] = player.DisplayName
			else
				table.insert(unknown, userId)
			end
		end
	end
	if #unknown == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(unknown)
	end)
	if ok and typeof(infos) == "table" then
		for _, info in infos :: { any } do
			if typeof(info.Id) == "number" and typeof(info.DisplayName) == "string" then
				names[info.Id] = info.DisplayName
			end
		end
	end
	for _, userId in unknown do
		if not names[userId] then
			local found, name = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if found and typeof(name) == "string" then
				names[userId] = name
			end
		end
	end
end

local function draw(id: string, shown: { Leaders.Entry })
	local rows = drawn[id]
	if not rows then
		return
	end
	local ids: { number } = {}
	for _, entry in shown do
		table.insert(ids, entry.userId)
	end
	learn(ids)
	for index, row in rows do
		local entry = shown[index]
		row.seal.Visible = entry ~= nil
		row.name.Visible = entry ~= nil or index == 1
		row.value.Visible = entry ~= nil
		if entry then
			-- A player's name is theirs, not a word for a client to translate.
			row.name:SetAttribute(Net.VERBATIM_ATTRIBUTE, true)
			row.name.Text = names[entry.userId] or `#{entry.userId}`
			row.value.Text = Format.short(entry.value)
		elseif index == 1 then
			-- An empty board says so, in the player's language.
			row.name:SetAttribute(Net.VERBATIM_ATTRIBUTE, nil)
			row.name.Text = NO_ONE
		end
	end
end

-- The players on this server who may be on the boards, with what they hold.
local function standing(of: (data: Data.Data) -> number): { Leaders.Entry }
	local list: { Leaders.Entry } = {}
	for _, player in Players:GetPlayers() do
		local data = Data.get(player)
		if data and not left[player.UserId] then
			table.insert(list, { userId = player.UserId, value = of(data) })
		end
	end
	return list
end

-- Writes what a player holds now into every board's store.
local function write(player: Player, data: Data.Data)
	if left[player.UserId] then
		return
	end
	for id, board in BOARDS do
		local kept = store(id)
		if kept then
			local value = Leaders.encode(board.of(data))
			pcall(function()
				kept:SetAsync(tostring(player.UserId), value)
			end)
		end
	end
end

-- Reads every board and draws it.
local function refresh()
	for id, board in BOARDS do
		local kept = store(id)
		local shown: { Leaders.Entry }
		if kept then
			local ok, pages = pcall(function()
				return kept:GetSortedAsync(false, Leaders.SHOWN + #Developers + 2)
			end)
			if not ok then
				continue
			end
			local entries = (pages :: DataStorePages):GetCurrentPage() :: any
			shown = Leaders.ranked(entries, left, Leaders.SHOWN)
		else
			shown = standing(board.of)
			table.sort(shown, function(a, b)
				return a.value > b.value
			end)
			while #shown > Leaders.SHOWN do
				table.remove(shown)
			end
		end
		draw(id, shown)
	end
end

function Leaderboards.start()
	for id, sheet in Plaza.leaderboards do
		if BOARDS[id] then
			build(id, sheet)
			draw(id, {})
		end
	end

	Data.onLeaving(function(player, data)
		task.spawn(write, player, data)
	end)

	task.spawn(function()
		-- The first round once the first saves have loaded.
		task.wait(10)
		while true do
			for _, player in Players:GetPlayers() do
				local data = Data.get(player)
				if data then
					write(player, data)
				end
			end
			refresh()
			task.wait(EVERY)
		end
	end)
end

return Leaderboards
