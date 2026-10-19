--!strict
-- The achievements as this player sees them (Config/Achievements, Logic/Achievements): a tile
-- in the left column, over Rebirth, and the window it opens, an achievement a row: its
-- picture (Art.achievements, else a drawn seal) in a ring of the metal of the highest tier
-- reached, its name, what its next tier asks, a bar and the count, a pip a tier, what the
-- next reward is and, for tiers reached and not claimed, a Claim button (and Claim all at the
-- top). A "!" stands on the tile while anything is left to claim.
--
-- A TIER REACHED IS TOLD BY A SMALL NOTICE BY THE TILE, NOT ACROSS THE SCREEN (owner,
-- 2026-10-18: "not over the whole screen, a pleasant notice somewhere in a corner"): a card
-- of parchment slides out of the Awards tile, says what was reached and that its reward
-- waits, and slides back in. Notices wait while a window is open and come one at a time.
-- What the numbers are comes from the server (the snapshot's `progress`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Audio = require("./Audio")
local DailyPanel = require("./DailyPanel")
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Hud = require("./Hud")
local Icons = require("./Icons")
local Net = require(ReplicatedStorage.Shared.Net)
local Progress = require(ReplicatedStorage.Shared.Logic.Achievements)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Ui = require("./Ui")

local AchievementsPanel = {}

local SIZE = Vector2.new(960, 760)
-- The two pages' tabs at the window's top.
local TABS_TALL = 54
local TAB_WIDE = 300
local LIST_TOP = 60
local ROW = Vector2.new(840, 112)
local RING = 86
local ICON = 72
local WORDS_LEFT = 118
local WORDS_WIDE = 430
local BAR = Vector2.new(330, 14)
local PIP = 16
local PIP_GAP = 6
local CLAIM = Vector2.new(170, 38)

-- The notice by the tile: its size, how far it stands off the tile, how long it stays.
local NOTE = Vector2.new(372, 92)
local NOTE_GAP = 10
local NOTE_SECONDS = 4.5

-- The metal of a tier, by its place: bronze, silver, gold, and jade for a fourth.
local METALS = {
	Color3.fromRGB(196, 128, 72),
	Color3.fromRGB(196, 206, 214),
	Color3.fromRGB(255, 202, 40),
	Color3.fromRGB(102, 204, 170),
}
local NUMERALS = { "I", "II", "III", "IV", "V", "VI" }

type Row = {
	frame: Frame,
	edge: UIStroke,
	ring: UIStroke,
	shade: Frame,
	name: TextLabel,
	what: TextLabel,
	fill: Frame,
	count: TextLabel,
	pips: { Frame },
	reward: TextLabel,
	claim: TextButton,
	done: TextLabel,
}

-- A number as an achievement's words give it: the zone's name for a zone, else short.
local function goalWords(stat: string, goal: number): string
	if stat == "zone" then
		local zone = Catalog.zones[goal]
		return if zone then zone.name else tostring(goal)
	end
	return Format.short(goal)
end

-- What a tier pays, in words.
local function rewardWords(reward: Progress.Reward): string
	local name, count = nil :: string?, 0
	for potionId, many in reward.potions do
		local potion = Catalog.potionById[potionId]
		if potion then
			name = potion.name
			count += many
		end
	end
	if count == 1 and name then
		return Strings.get("AchRewardPotion", Format.short(reward.herbs), name)
	elseif count > 1 then
		return Strings.get("AchRewardPotions", Format.short(reward.herbs), tostring(count))
	end
	return Strings.get("AchReward", Format.short(reward.herbs))
end

-- A tier from what the snapshot says: a number, else none.
local function tierIn(map: { [string]: number }?, id: string): number
	local value = if map then map[id] else nil
	return if typeof(value) == "number" then value else 0
end

function AchievementsPanel.start()
	local window = Ui.window("Achievements", SIZE, true)
	window.title.Text = Strings.get("AchievementsButton")
	local whole = window.body

	local tile, mark =
		Hud.sideButton(Strings.get("AchievementsButton"), Ui.GREEN, Icons.award, true, "awards")
	tile.LayoutOrder = 1
	mark.Text = "!"
	mark.Visible = false

	-- Two pages under two tabs (owner, 2026-10-19: "take daily into awards, two sub-menus,
	-- achievements and daily; with a '!', show at the top in which of them something waits"):
	-- the achievements and the daily reward (client DailyPanel), a red "!" on the tab of each
	-- that has something to claim.
	type Tab = { button: TextButton, mark: TextLabel, page: Frame }
	local tabs: { [string]: Tab } = {}
	local current = "achievements"
	for index, name in { "achievements", "daily" } do
		local page: Frame = Ui.make("Frame", {
			Position = UDim2.fromOffset(0, TABS_TALL + 12),
			Size = UDim2.new(1, 0, 1, -TABS_TALL - 12),
			BackgroundTransparency = 1,
			Visible = index == 1,
		}, whole)
		local tabButton = Ui.button(whole, {
			Position = UDim2.fromOffset((index - 1) * (TAB_WIDE + 14), 0),
			Size = UDim2.fromOffset(TAB_WIDE, TABS_TALL),
			BackgroundColor3 = Ui.CARD,
			TextSize = 26,
			Text = Strings.get(if name == "daily" then "DailyTitle" else "AchievementsTitle"),
		})
		local tabMark = Ui.text(tabButton, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = Ui.SEAL,
			BackgroundTransparency = 0,
			TextSize = 20,
			TextColor3 = Ui.PARCHMENT,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "!",
			Visible = false,
			ZIndex = 5,
		})
		Ui.corner(tabMark, 15)
		tabs[name] = { button = tabButton, mark = tabMark, page = page }
	end
	local function showPage(name: string)
		current = name
		for each, tab in tabs do
			tab.page.Visible = each == name
			tab.button.BackgroundColor3 = if each == name then Ui.GOLD else Ui.CARD
			tab.button.TextColor3 = if each == name then Ui.INK else Ui.PARCHMENT
		end
	end
	showPage("achievements")
	local body = tabs.achievements.page

	-- Whether something waits to be claimed on each page, and so on the tile.
	local achievementsWaiting = false
	local daily: DailyPanel.Page? = nil
	local function marks()
		local dailyWaiting = daily ~= nil and daily.ready()
		tabs.achievements.mark.Visible = achievementsWaiting
		tabs.daily.mark.Visible = dailyWaiting
		mark.Visible = achievementsWaiting or dailyWaiting
	end
	daily = DailyPanel.build(
		tabs.daily.page,
		SIZE.X - 32,
		function(): boolean
			return window.isOpen() and current == "daily"
		end,
		marks,
		function()
			showPage("daily")
			window.open()
		end
	)
	for name, tab in tabs do
		tab.button.Activated:Connect(function()
			showPage(name)
			if name == "daily" and daily then
				daily.toToday()
			end
		end)
	end
	-- The tile opens the window on the page that has something waiting, else on the last one.
	tile.Activated:Connect(function()
		if window.isOpen() then
			window.close()
			return
		end
		local dailyWaiting = daily ~= nil and daily.ready()
		if achievementsWaiting then
			showPage("achievements")
		elseif dailyWaiting then
			showPage("daily")
		end
		window.open()
		if current == "daily" and daily then
			daily.toToday()
		end
	end)

	local total = Ui.text(body, {
		Size = UDim2.new(1, -CLAIM.X - 20, 0, 44),
		TextSize = 26,
		TextColor3 = Ui.GOLD,
	})
	local claimAll = Ui.button(body, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 2),
		Size = UDim2.fromOffset(CLAIM.X, 42),
		BackgroundColor3 = Ui.GREEN,
		TextSize = 22,
		Text = Strings.get("AchievementClaimAll"),
		Visible = false,
	})
	claimAll.Activated:Connect(function()
		Remotes.ClaimAchievement:FireServer("*")
	end)
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

		-- The picture in a ring of the metal of the highest tier reached.
		local ringFrame = Ui.make("Frame", {
			Position = UDim2.fromOffset(16, (ROW.Y - RING) / 2),
			Size = UDim2.fromOffset(RING, RING),
			BackgroundColor3 = Ui.PANEL,
		}, frame)
		Ui.corner(ringFrame, RING / 2)
		local ring = Ui.stroke(ringFrame, Ui.EDGE, 4)
		local holder = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(ICON, ICON),
			BackgroundTransparency = 1,
		}, ringFrame)
		Icons.achievement(holder, achievement.id)
		-- Nothing reached yet: the picture is shaded.
		local shade = Ui.make("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
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
		local what = Ui.text(frame, {
			Position = UDim2.fromOffset(WORDS_LEFT, 44),
			Size = UDim2.fromOffset(WORDS_WIDE, 26),
			TextSize = 19,
			TextColor3 = Ui.MUTED,
		})
		local bar = Ui.make("Frame", {
			Position = UDim2.fromOffset(WORDS_LEFT, 82),
			Size = UDim2.fromOffset(BAR.X, BAR.Y),
			BackgroundColor3 = Ui.PANEL,
		}, frame)
		Ui.corner(bar, BAR.Y / 2)
		local fill = Ui.make("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Ui.GREEN,
		}, bar)
		Ui.corner(fill, BAR.Y / 2)
		local count = Ui.text(frame, {
			Position = UDim2.fromOffset(WORDS_LEFT + BAR.X + 10, 72),
			Size = UDim2.fromOffset(120, 32),
			TextSize = 20,
			TextColor3 = Ui.PARCHMENT,
		})

		-- A pip a tier, in the top right corner, lit in its metal once reached.
		local pips: { Frame } = {}
		local tiers = #achievement.tiers
		for index = 1, tiers do
			local pip = Ui.make("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -16 - (tiers - index) * (PIP + PIP_GAP), 0, 14),
				Size = UDim2.fromOffset(PIP, PIP),
				BackgroundColor3 = Ui.PANEL,
			}, frame)
			Ui.corner(pip, PIP / 2)
			Ui.stroke(pip, METALS[math.min(index, #METALS)], 2)
			table.insert(pips, pip)
		end
		local reward = Ui.text(frame, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 36),
			Size = UDim2.fromOffset(250, 26),
			TextSize = 19,
			TextColor3 = Ui.GOLD,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		local claim = Ui.button(frame, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -10),
			Size = UDim2.fromOffset(CLAIM.X, CLAIM.Y),
			BackgroundColor3 = Ui.GREEN,
			TextSize = 22,
			Text = Strings.get("AchievementClaim"),
			Visible = false,
		})
		claim.Activated:Connect(function()
			Remotes.ClaimAchievement:FireServer(achievement.id)
		end)
		local done = Ui.text(frame, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -16, 1, -10),
			Size = UDim2.fromOffset(CLAIM.X, CLAIM.Y),
			TextSize = 24,
			TextColor3 = Ui.GOLD,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = Strings.get("AchievementDone"),
			Visible = false,
		})
		rows[achievement.id] = {
			frame = frame,
			edge = edge,
			ring = ring,
			shade = shade,
			name = name,
			what = what,
			fill = fill,
			count = count,
			pips = pips,
			reward = reward,
			claim = claim,
			done = done,
		}
	end

	-- The rows' order (owner, 2026-10-19: "let fully done achievements move down in Awards:
	-- the higher the tier done, the lower it stands when the window is refreshed"): a reward
	-- waiting to be claimed first, so that its Claim is not lost at the foot (my call); then
	-- those still going, the fewest tiers reached first; the finished ones last, the most tiers
	-- lowest; the config's order among equals. Set only while the window is shut, so that rows
	-- never jump under the pointer: it comes into force when the window is opened again.
	local function arrange(state: Net.Snapshot)
		for order, achievement in Progress.list do
			local tiers = #achievement.tiers
			local reached = math.min(tierIn(state.achievements, achievement.id), tiers)
			local claimed = math.min(tierIn(state.claimed, achievement.id), reached)
			local group = if reached > claimed then 0 elseif reached < tiers then 1 else 2
			rows[achievement.id].frame.LayoutOrder = group * 100000 + reached * 1000 + order
		end
	end

	local function draw()
		local state: Net.Snapshot? = Store.get()
		if not state then
			return
		end
		if not window.isOpen() then
			arrange(state)
		end
		local progress = state.progress or {}
		local reachedAll, tiersAll, waiting = 0, 0, false
		for _, achievement in Progress.list do
			local row = rows[achievement.id]
			local tiers = #achievement.tiers
			local reached = math.min(tierIn(state.achievements, achievement.id), tiers)
			local claimed = math.min(tierIn(state.claimed, achievement.id), reached)
			local value = progress[achievement.stat] or 0
			reachedAll += reached
			tiersAll += tiers
			local finished = reached >= tiers
			local unclaimed = reached > claimed
			waiting = waiting or unclaimed

			local metal = if reached > 0 then METALS[math.min(reached, #METALS)] else Ui.EDGE
			row.ring.Color = metal
			row.shade.Visible = reached == 0
			row.edge.Color = if unclaimed then Ui.GREEN elseif finished then Ui.GOLD else Ui.EDGE
			row.name.TextColor3 = if finished then Ui.GOLD else Ui.PARCHMENT
			local name = Strings.get(`Ach_{achievement.id}`)
			row.name.Text = if tiers > 1 and reached > 0
				then `{name}  {NUMERALS[math.min(reached, #NUMERALS)]}`
				else name

			-- What the next tier asks, or the last one's once all are reached.
			local coming = achievement.tiers[math.min(reached + 1, tiers)]
			row.what.Text =
				Strings.get(`AchWhat_{achievement.id}`, goalWords(achievement.stat, coming.goal))
			row.fill.Size =
				UDim2.fromScale(if finished then 1 else math.clamp(value / coming.goal, 0, 1), 1)
			row.fill.BackgroundColor3 = if finished then Ui.GOLD else Ui.GREEN
			row.count.Text = if achievement.stat == "zone"
				then Strings.get("AchievementProgress", tostring(value), tostring(coming.goal))
				else Strings.get(
					"AchievementProgress",
					Format.short(math.min(value, coming.goal)),
					Format.short(coming.goal)
				)
			for index, pip in row.pips do
				pip.BackgroundColor3 = if index <= reached
					then METALS[math.min(index, #METALS)]
					else Ui.PANEL
			end

			-- What waits to be claimed, else what the next tier will pay.
			if unclaimed then
				row.reward.Text = rewardWords(Progress.reward(achievement, claimed, reached))
			elseif not finished then
				row.reward.Text = rewardWords(Progress.reward(achievement, reached, reached + 1))
			else
				row.reward.Text = ""
			end
			row.reward.TextColor3 = if unclaimed then Ui.GREEN else Ui.MUTED
			row.claim.Visible = unclaimed
			row.done.Visible = finished and not unclaimed
		end
		total.Text = Strings.get("AchievementsCount", tostring(reachedAll), tostring(tiersAll))
		claimAll.Visible = waiting
		achievementsWaiting = waiting
		marks()
	end
	Store.onChange(draw)

	-- A tier reached: a card of parchment slides out of the tile, toward the middle of the
	-- screen, and back again. The layer stands under the windows (Hud 10, windows 30).
	local layer = Ui.screen("AchievementNotes", 12)
	local clip = Ui.make("Frame", {
		Size = UDim2.fromOffset(NOTE.X, NOTE.Y),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Visible = false,
	}, layer)
	local card = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.PARCHMENT,
	}, clip)
	Ui.corner(card, 10)
	local cardEdge = Ui.stroke(card, Ui.SEAL, 3)
	local cardIcon = Ui.make("Frame", {
		Position = UDim2.fromOffset(12, (NOTE.Y - 64) / 2),
		Size = UDim2.fromOffset(64, 64),
		BackgroundTransparency = 1,
	}, card)
	local cardHead = Ui.text(card, {
		Position = UDim2.fromOffset(88, 8),
		Size = UDim2.fromOffset(NOTE.X - 100, 22),
		TextSize = 18,
		TextColor3 = Ui.SEAL,
	})
	local cardName = Ui.text(card, {
		Position = UDim2.fromOffset(88, 30),
		Size = UDim2.fromOffset(NOTE.X - 100, 30),
		TextSize = 24,
		TextColor3 = Ui.INK,
	})
	Ui.text(card, {
		Position = UDim2.fromOffset(88, 60),
		Size = UDim2.fromOffset(NOTE.X - 100, 24),
		TextSize = 18,
		TextColor3 = Ui.INK,
		Text = Strings.get("AchievementWaiting"),
	})

	local queue: { { id: string, tier: number } } = {}
	local function show(id: string, tier: number)
		local achievement = Progress.byId[id]
		if not achievement then
			return
		end
		for _, child in cardIcon:GetChildren() do
			child:Destroy()
		end
		Icons.achievement(cardIcon, id)
		cardEdge.Color = METALS[math.max(math.min(tier, #METALS), 1)]
		local head = Strings.get("AchievementEarned")
		cardHead.Text = if #achievement.tiers > 1
			then `{head}  ·  {NUMERALS[math.min(tier, #NUMERALS)]}`
			else head
		cardName.Text = Strings.get(`Ach_{id}`)

		-- Beside the tile, on the side the screen's middle is.
		local scale = Ui.scale()
		local at = tile.AbsolutePosition / scale
		local size = tile.AbsoluteSize / scale
		local room = Ui.room()
		local rightward = at.X + size.X / 2 < room.X / 2
		local x = if rightward then at.X + size.X + NOTE_GAP else at.X - NOTE_GAP - NOTE.X
		local y = math.clamp(at.Y + size.Y / 2 - NOTE.Y / 2, 8, math.max(room.Y - NOTE.Y - 8, 8))
		clip.Position = UDim2.fromOffset(x, y)
		local hidden = UDim2.fromOffset(if rightward then -NOTE.X - 8 else NOTE.X + 8, 0)
		card.Position = hidden
		clip.Visible = true
		Audio.play("pass")
		TweenService:Create(
			card,
			TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.fromOffset(0, 0) }
		):Play()
		task.wait(0.42 + NOTE_SECONDS)
		local away = TweenService:Create(
			card,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = hidden }
		)
		away:Play()
		away.Completed:Wait()
		clip.Visible = false
	end
	task.spawn(function()
		while true do
			if #queue > 0 and not Ui.windowOpen() then
				local note = table.remove(queue, 1)
				if note then
					show(note.id, note.tier)
				end
			else
				task.wait(0.25)
			end
		end
	end)

	Remotes.Achievement.OnClientEvent:Connect(function(id: string, tier: number)
		if Progress.byId[id] and typeof(tier) == "number" then
			table.insert(queue, { id = id, tier = tier })
		end
	end)
end

return AchievementsPanel
