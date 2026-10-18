--!strict
-- The achievements as this player sees them (Config/Achievements, Logic/Achievements): a tile
-- in the left column, under Rebirth, and the window it opens, every achievement in a row with
-- its picture (Art.achievements, else a drawn seal), its name, what it asks, a bar of how far
-- the player is and the count, or DONE; and, when the server gives one (Services/Achievements),
-- its name on the scroll in its turn, a sound, and a "!" on the tile until the window is
-- opened. How far each is goes by the snapshot and the Bingo Book, as the server reckons it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Audio = require("./Audio")
local Hud = require("./Hud")
local Icons = require("./Icons")
local Progress = require(ReplicatedStorage.Shared.Logic.Achievements)
local Remotes = require("./Remotes")
local StageFlash = require("./StageFlash")
local Store = require("./Store")
local Strings = require("./Strings")
local Ui = require("./Ui")

local AchievementsPanel = {}

local SIZE = Vector2.new(900, 700)
local LIST_TOP = 50
local ROW = Vector2.new(840, 100)
local ICON = 76
local WORDS_LEFT = 106
local WORDS_WIDE = 520
local BAR_HEIGHT = 14

type Row = {
	frame: Frame,
	edge: UIStroke,
	shade: Frame,
	name: TextLabel,
	fill: Frame,
	count: TextLabel,
}

function AchievementsPanel.start()
	local window = Ui.window("Achievements", SIZE)
	window.title.Text = Strings.get("AchievementsTitle")
	local body = window.body

	local tile, mark =
		Hud.sideButton(Strings.get("AchievementsButton"), Ui.GREEN, Icons.award, true)
	tile.LayoutOrder = 1
	mark.Text = ""
	tile.Activated:Connect(function()
		mark.Text = ""
		window.toggle()
	end)

	local total = Ui.text(body, {
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 26,
		TextColor3 = Ui.GOLD,
	})
	local list = Ui.scroll(body, {
		Position = UDim2.fromOffset(0, LIST_TOP),
		Size = UDim2.new(1, 0, 1, -LIST_TOP),
		ScrollBarThickness = 8,
	})
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, list)
	Ui.padding(list, 4)

	local rows: { [string]: Row } = {}
	for order, achievement in Progress.list do
		local frame = Ui.make("Frame", {
			Size = UDim2.fromOffset(ROW.X, ROW.Y),
			BackgroundColor3 = Ui.CARD,
			LayoutOrder = order,
		}, list)
		Ui.corner(frame, 10)
		local edge = Ui.stroke(frame, Ui.EDGE, 2)
		local holder = Ui.make("Frame", {
			Position = UDim2.fromOffset(12, (ROW.Y - ICON) / 2),
			Size = UDim2.fromOffset(ICON, ICON),
			BackgroundTransparency = 1,
		}, frame)
		Icons.achievement(holder, achievement.id)
		-- Not done yet, the picture is shaded.
		local shade = Ui.make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.5,
			ZIndex = 8,
		}, holder)
		Ui.corner(shade, ICON / 2)
		local name = Ui.text(frame, {
			Position = UDim2.fromOffset(WORDS_LEFT, 10),
			Size = UDim2.fromOffset(WORDS_WIDE, 32),
			TextSize = 26,
			TextColor3 = Ui.PARCHMENT,
			Text = Strings.get(`Ach_{achievement.id}`),
		})
		Ui.text(frame, {
			Position = UDim2.fromOffset(WORDS_LEFT, 44),
			Size = UDim2.fromOffset(WORDS_WIDE, 24),
			TextSize = 19,
			TextColor3 = Ui.MUTED,
			Text = Strings.get(`AchWhat_{achievement.id}`),
		})
		local bar = Ui.make("Frame", {
			Position = UDim2.fromOffset(WORDS_LEFT, 74),
			Size = UDim2.fromOffset(WORDS_WIDE, BAR_HEIGHT),
			BackgroundColor3 = Ui.PANEL,
		}, frame)
		Ui.corner(bar, BAR_HEIGHT / 2)
		local fill = Ui.make("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Ui.GREEN,
		}, bar)
		Ui.corner(fill, BAR_HEIGHT / 2)
		local count = Ui.text(frame, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -20, 0.5, 0),
			Size = UDim2.fromOffset(180, 40),
			TextSize = 26,
			TextColor3 = Ui.PARCHMENT,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		rows[achievement.id] = {
			frame = frame,
			edge = edge,
			shade = shade,
			name = name,
			fill = fill,
			count = count,
		}
	end

	local function draw()
		local state = Store.get()
		if not state then
			return
		end
		local done: { [string]: boolean } = {}
		for _, id in state.achievements do
			done[id] = true
		end
		local stats = Progress.stats({
			spins = state.spins,
			rebirths = state.rebirths,
			speedLevel = state.speedLevel,
			kunai = state.kunai,
			padsBought = state.padsBought,
			found = Store.found(),
		})
		local finished = 0
		for _, achievement in Progress.list do
			local row = rows[achievement.id]
			local reached = Progress.reached(achievement, stats)
			local complete = done[achievement.id] == true
			if complete then
				finished += 1
			end
			row.edge.Color = if complete then Ui.GOLD else Ui.EDGE
			row.shade.Visible = not complete
			row.name.TextColor3 = if complete then Ui.GOLD else Ui.PARCHMENT
			row.fill.Size = UDim2.fromScale(if complete then 1 else reached / achievement.goal, 1)
			row.fill.BackgroundColor3 = if complete then Ui.GOLD else Ui.GREEN
			row.count.Text = if complete
				then Strings.get("AchievementDone")
				else Strings.get(
					"AchievementProgress",
					tostring(reached),
					tostring(achievement.goal)
				)
			row.count.TextColor3 = if complete then Ui.GOLD else Ui.PARCHMENT
		end
		total.Text = Strings.get("AchievementsCount", tostring(finished), tostring(#Progress.list))
	end
	Store.onChange(draw)
	Store.onIndex(function()
		draw()
	end)

	-- One given: named on the scroll in its turn, heard, and marked on the tile.
	Remotes.Achievement.OnClientEvent:Connect(function(id: string)
		local achievement = Progress.byId[id]
		if not achievement then
			return
		end
		Audio.play("pass")
		if not window.isOpen() then
			mark.Text = "!"
		end
		StageFlash.queue(Color3.fromHex(achievement.color), function(holder: Instance)
			Icons.achievement(holder, id)
		end, Strings.get("AchievementEarned"), Strings.get(`Ach_{id}`))
	end)
end

return AchievementsPanel
