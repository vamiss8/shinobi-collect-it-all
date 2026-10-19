--!strict
-- The daily reward's page (Config/Daily, Logic/Daily, Services/Daily): the week's seven days
-- down a list that scrolls, a row each with what it gives, those claimed stamped, today's in
-- gold; a Claim button, or how long until the next one. A row a day and large words, not
-- seven narrow cards (owner, 2026-10-19, a screenshot: "the text is very small, nothing can be
-- seen; better let the menu scroll and the text be larger"). It opens by itself once a day when a reward waits (not
-- during the base tutorial: after it). IT IS A PAGE OF THE AWARDS WINDOW (client
-- AchievementsPanel), beside the achievements, with no tile of its own (owner, 2026-10-19:
-- "take daily into awards, two sub-menus, achievements and daily; with a '!', show at the top
-- in which of them something waits"). MY LOOK, told to the owner.
--
-- The rows are the week the reward due falls in: what each day gives grows with the weeks in
-- a row (Logic/Daily.reward), and a day that brings a streak's bonus says so in its head. The
-- foot says how much the weeks in a row add.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local DailyLogic = require(ReplicatedStorage.Shared.Logic.Daily)
local Days = require(ReplicatedStorage.Shared.Config.Daily)
local Guide = require("./Guide")
local GuideConfig = require(ReplicatedStorage.Shared.Config.Guide)
local Icons = require("./Icons")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Ui = require("./Ui")

local DailyPanel = {}

type Config = Days.Day

local HINT_SIZE = 22
local LIST_TOP = 72
local FOOT = 86
local ROW = Vector2.new(860, 124)
local ROW_GAP = 12
local ICON = 100
local WORDS_LEFT = 148
local STAMP = Vector2.new(190, 48)

-- The developer product that sells a potion, whose picture is the potion's.
local function productOf(potionId: string): Catalog.Product?
	for _, product in Catalog.products do
		if product.kind == "potion" and product.potion == potionId then
			return product
		end
	end
	return nil
end

-- What a claim gives, in words, a piece each.
local function given(reward: DailyLogic.Reward): { string }
	local lines: { string } = {}
	if reward.herbs > 0 then
		table.insert(lines, Strings.get("DailyHerbs", tostring(reward.herbs)))
	end
	if reward.ryoMinutes > 0 then
		table.insert(lines, Strings.get("DailyRyo", tostring(reward.ryoMinutes)))
	end
	local potion = if reward.potion then Catalog.potionById[reward.potion] else nil
	if potion then
		table.insert(lines, Strings.name(potion.name))
	end
	for _, id in reward.premium do
		local premium = Catalog.potionById[id]
		if premium then
			table.insert(lines, Strings.get("DailyPremium", Strings.name(premium.name)))
		end
	end
	return lines
end

-- The picture of a day: its potion, else Ryo, else Herbs.
local function picture(holder: Instance, day: Config)
	local potionId = day.premium or day.potion
	local product = if potionId then productOf(potionId) else nil
	if product then
		Icons.goods(holder, product.key)
	elseif day.ryoMinutes then
		Icons.coin(holder)
	else
		Icons.herb(holder)
	end
end

type Card = { frame: Frame, edge: UIStroke, stamp: TextLabel, head: TextLabel, gift: TextLabel }

-- The page as the Awards window works it: whether a reward waits, and the list scrolled to
-- today's row.
export type Page = {
	ready: () -> boolean,
	toToday: () -> (),
}

-- Builds the page into `body`, `wide` layout pixels across. `shown` says whether the page is
-- in sight (the wait is counted down while it is); `changed` is called whenever whether a
-- reward waits may have changed (the "!" marks); `due` once a visit, when a reward waits and
-- the base tutorial is behind the player: the Awards window opens on this page.
function DailyPanel.build(
	body: Frame,
	wide: number,
	shown: () -> boolean,
	changed: () -> (),
	due: () -> ()
): Page
	Ui.text(body, {
		Size = UDim2.new(1, 0, 0, LIST_TOP - 8),
		TextSize = HINT_SIZE,
		TextColor3 = Ui.MUTED,
		Text = Ui.lines(Strings.get("DailyHint"), HINT_SIZE, wide - 30),
	})

	-- The week, a row a day, in a list that scrolls.
	local list = Ui.scroll(body, {
		Position = UDim2.fromOffset(0, LIST_TOP),
		Size = UDim2.new(1, 0, 1, -LIST_TOP - FOOT),
		ScrollBarThickness = 8,
	})
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, ROW_GAP),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}, list)
	Ui.padding(list, 4)
	local cards: { Card } = {}
	for index, day in Days.days do
		local frame = Ui.make("Frame", {
			Size = UDim2.fromOffset(ROW.X, ROW.Y),
			BackgroundColor3 = Ui.CARD,
			LayoutOrder = index,
		}, list)
		Ui.corner(frame, 12)
		local edge = Ui.stroke(frame, Ui.EDGE, 2)
		local holder = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 22, 0.5, 0),
			Size = UDim2.fromOffset(ICON, ICON),
			BackgroundTransparency = 1,
		}, frame)
		picture(holder, day)
		local head = Ui.text(frame, {
			Position = UDim2.fromOffset(WORDS_LEFT, 14),
			Size = UDim2.fromOffset(ROW.X - WORDS_LEFT - STAMP.X - 40, 40),
			TextSize = 34,
			TextColor3 = Ui.PARCHMENT,
			Text = Strings.get("DailyDay", tostring(index)),
		})
		local gift = Ui.text(frame, {
			Position = UDim2.fromOffset(WORDS_LEFT, 62),
			Size = UDim2.fromOffset(ROW.X - WORDS_LEFT - STAMP.X - 40, 48),
			TextSize = 27,
			TextColor3 = Ui.GOLD,
			Text = table.concat(given(DailyLogic.reward(index)), "  ·  "),
		})
		local stamp = Ui.text(frame, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -22, 0.5, 0),
			Size = UDim2.fromOffset(STAMP.X, STAMP.Y),
			BackgroundColor3 = Ui.GREEN,
			BackgroundTransparency = 0,
			TextSize = 24,
			TextColor3 = Ui.PARCHMENT,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = Strings.get("DailyStamp"),
			Visible = false,
		})
		Ui.corner(stamp, 10)
		table.insert(cards, { frame = frame, edge = edge, stamp = stamp, head = head, gift = gift })
	end

	-- The foot: the days in a row on the left, Claim or the wait on the right.
	local streak = Ui.text(body, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -10),
		Size = UDim2.new(0.45, 0, 0, 56),
		TextSize = 28,
		TextColor3 = Ui.PARCHMENT,
	})
	local claim = Ui.button(body, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(300, 62),
		BackgroundColor3 = Ui.GREEN,
		TextSize = 30,
		Text = Strings.get("DailyClaim"),
	})
	claim.Activated:Connect(function()
		Remotes.Daily:FireServer()
	end)
	local waitLabel = Ui.text(body, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -10),
		Size = UDim2.fromOffset(480, 62),
		TextSize = 27,
		TextColor3 = Ui.MUTED,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	-- When the snapshot said what, so that the wait can be counted down.
	local heard = os.clock()
	local daily: { ready: boolean, day: number, streak: number, count: number, wait: number }? = nil

	local function draw()
		local known = daily
		if not known then
			return
		end
		-- The week the reward due falls in, and how much the weeks in a row before it add.
		local count = math.max(known.count or known.streak, 1)
		local weekStart = (count - 1) // #Days.days * #Days.days
		for index, card in cards do
			local reward = DailyLogic.reward(weekStart + index)
			card.gift.Text = table.concat(given(reward), "  ·  ")
			card.head.Text = if reward.bonus
				then Strings.get("DailyDayBonus", tostring(index))
				else Strings.get("DailyDay", tostring(index))
			local today = index == known.day
			-- Claimed this week: the days before today's, and today's once it is claimed.
			local claimed = index < known.day or (today and not known.ready)
			card.stamp.Visible = claimed
			card.edge.Color = if today then Ui.GOLD else Ui.EDGE
			card.edge.Thickness = if today then 4 else 2
			card.frame.BackgroundTransparency = if claimed and not today then 0.4 else 0
			card.head.TextColor3 = if today then Ui.GOLD else Ui.PARCHMENT
			card.gift.TextTransparency = if claimed and not today then 0.35 else 0
		end
		local grown = DailyLogic.multiplier(count)
		streak.Text = if grown > 1
			then Strings.get(
				"DailyStreakBonus",
				tostring(math.max(known.streak, 0)),
				tostring(math.floor((grown - 1) * 100 + 0.5))
			)
			else Strings.get("DailyStreak", tostring(math.max(known.streak, 0)))
		claim.Visible = known.ready
		waitLabel.Visible = not known.ready
		if not known.ready then
			local remaining = math.max(known.wait - (os.clock() - heard), 0)
			waitLabel.Text = Strings.get("DailyNext", Strings.duration(remaining))
		end
	end

	-- The list scrolled so that today's row is in sight.
	local function toToday()
		local known = daily
		if known then
			list.CanvasPosition = Vector2.new(0, math.max(known.day - 2, 0) * (ROW.Y + ROW_GAP))
		end
	end
	local opened = false
	Store.onChange(function(snapshot: Net.Snapshot)
		daily = snapshot.daily
		heard = os.clock()
		draw()
		changed()
		-- Once a visit, when a reward waits and the base tutorial is behind the player.
		if
			not opened
			and snapshot.daily.ready
			and snapshot.guide >= GuideConfig.DONE
			and not Guide.running()
			and not Ui.windowOpen()
		then
			opened = true
			due()
			toToday()
			Guide.tip("daily")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if shown() then
				draw()
			end
		end
	end)

	return {
		ready = function(): boolean
			local known = daily
			return known ~= nil and known.ready
		end,
		toToday = toToday,
	}
end

return DailyPanel
