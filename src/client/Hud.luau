--!strict
-- The always-visible UI, split by purpose: Chakra and the throw power in the bottom-left
-- corner with Ryo stacked right above them, window buttons on the right edge, and short
-- messages written on a scroll at the top.
--
-- The window buttons stand low on the right edge, a gap over the Settings tile in its corner
-- (client SettingsPanel), so that the list of players over them has room for more lines
-- (owner, 2026-10-17: "a little lower than settings, but not right against it"). They stood at
-- the middle of the edge.
--
-- A touch screen has Roblox's stick in its lower left corner and the jump button in its lower
-- right (owner's tester, 2026-10-16: the readouts lay over the stick, which could not be
-- found). There Ryo and Chakra stand in the upper left corner, the throw power slider opening
-- under them, and every window tile, the left column's too, stands in the upper right corner,
-- two to a row and a little smaller.
--
-- Herbs, the potions' own currency, are a small chip in the Ryo readout's lower right corner,
-- beside the income, and every throw that brings some has a slip of parchment saying "+1" or
-- "+2" rise off it (owner, 2026-10-17: "its count written somewhere besides the shop, and a
-- small animation by it, +1, or +2 for a Perfect"; and "less important than Ryo, or it will
-- be cluttered": so no readout of its own).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Focus = require(ReplicatedStorage.Shared.Logic.Focus)
local Icons = require("./Icons")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local ThrowPower = require("./ThrowPower")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local Hud = {}

local MESSAGE_SECONDS = 4

-- The two readouts in the bottom-left corner: one width, Ryo on top of Chakra.
local READOUT_WIDTH = 400
local RYO_HEIGHT = 80
local CHAKRA_HEIGHT = 144
local READOUT_GAP = 10
-- On a touch screen: how far down from the top the readouts begin, how much smaller the tiles
-- are drawn, and how many stand in a row.
local TOUCH_TOP = 10
local TOUCH_TILES = 0.85
local TOUCH_ROW = 2
local TILE = Vector2.new(112, 116)
local TILE_GAP = 12
-- How far over the foot of the screen the column of window tiles on the right ends: the
-- Settings tile's margin and height (client SettingsPanel: 12 and TILE.Y), and a gap. It was
-- 28, which the owner found too small (2026-10-17: "the gap became too small").
local RIGHT_FOOT = 12 + TILE.Y + 60

-- The Herbs' chip in the Ryo readout, and the slip that rises off it when some come: how
-- far, how long.
local HERBS_TALL = 30 -- the chip's height; its width follows the count
local HERBS_ICON = 26
local HERBS_GAP = 4
local HERBS_TEXT = 20
local GAIN = Vector2.new(56, 30)
local GAIN_RISE = 40
local GAIN_SECONDS = 0.9
local GAIN_FADE = 0.35

-- Where the readouts end on a touch screen, from the top: what stands under them goes by it
-- (client EventShow's timer).
Hud.TOUCH_FOOT = TOUCH_TOP + RYO_HEIGHT + READOUT_GAP + CHAKRA_HEIGHT

-- The scroll messages are written on: the parchment and its words. A message's color goes to
-- the parchment's outline and seal.
type Scroll = { paper: Ui.Parchment, words: TextLabel }

local scroll: Scroll? = nil
local messageToken = 0
local sideColumn: Frame? = nil
local leftColumn: Frame? = nil
-- The column on the right edge as a keyboard and mouse have it, and how many tiles are in it.
local rightColumn: Frame? = nil
local rightTiles = 0

-- Shows a message on the scroll at the top of the screen for a few seconds: the scroll unrolls
-- with it and rolls up again after. A newer message takes its place, the scroll shutting for
-- a moment while the words change. The words are always ink on parchment; `color` goes to the
-- seal and the outline.
function Hud.toast(text: string, color: Color3?)
	local shown = scroll
	if not shown then
		return
	end
	messageToken += 1
	local token = messageToken
	Ui.rewrite(shown.paper, function()
		shown.words.Text = text
		shown.paper.edge.Color = color or Ui.EDGE
		shown.paper.seal.BackgroundColor3 = color or Ui.SEAL
	end)
	task.delay(MESSAGE_SECONDS, function()
		if messageToken == token then
			Ui.rollUp(shown.paper)
		end
	end)
end

-- The color of a character's rank, for coloring their name.
function Hud.rankColor(characterId: string): Color3
	local character = Catalog.characterById[characterId]
	local rank = if character then Catalog.ranks[Catalog.rankOrder[character.rank]] else nil
	return if rank then Color3.fromHex(rank.color) else Ui.WHITE
end

-- Adds a tile to the column on the right edge of the screen, or on the left one when `left`:
-- an icon with a caption under it. Windows use it as their opener. `drawIcon` fills the square
-- it is given (see Icons). Returns the tile and a small counter in its corner, hidden until it
-- is given text. Call after Hud.start().
function Hud.sideButton(
	text: string,
	color: Color3,
	drawIcon: (holder: Instance) -> (),
	left: boolean?
): (TextButton, TextLabel)
	local column = if left then leftColumn else sideColumn
	assert(column, "Hud.start() has not run yet")
	if column == rightColumn then
		rightTiles += 1
	end
	local tile = Ui.button(column, {
		Size = UDim2.fromOffset(TILE.X, TILE.Y),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.08,
	})
	Ui.stroke(tile, color, 3)

	local holder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(68, 68),
		BackgroundTransparency = 1,
	}, tile)
	drawIcon(holder)

	Ui.text(tile, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -8, 0, 28),
		TextColor3 = color,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
	})

	local counter = Ui.text(tile, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 5),
		Size = UDim2.fromOffset(36, 24),
		BackgroundColor3 = Ui.SEAL,
		BackgroundTransparency = 0,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	Ui.corner(counter, 12)
	return tile, counter
end

-- Where the column of window tiles on the right edge begins, from the top of the screen in
-- layout pixels: the list of players hangs over it (client PlayerList).
function Hud.rightTop(): number
	local count = math.max(rightTiles, 1)
	return Ui.room().Y - RIGHT_FOOT - count * TILE.Y - (count - 1) * TILE_GAP
end

local function enemyName(zoneId: string): string
	local zone = Catalog.zoneById[zoneId]
	return if zone then Strings.name(zone.enemy.name) else zoneId
end

-- A readout: an icon, a big number and a smaller line under it, on a dark plaque outlined in
-- the readout's color.
local function readout(
	parent: Instance,
	drawIcon: (holder: Instance) -> (),
	color: Color3,
	properties: { [string]: any }
): (Frame, TextLabel, TextLabel)
	local plaque = Ui.panel(parent, properties)
	plaque.BackgroundTransparency = 0.08
	Ui.stroke(plaque, color, 3)
	local holder = Ui.make("Frame", {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(62, 62),
		BackgroundTransparency = 1,
	}, plaque)
	drawIcon(holder)

	-- Both lines shrink to fit the plaque instead of running past its edge.
	local amount = Ui.text(plaque, {
		Position = UDim2.fromOffset(84, 4),
		Size = UDim2.new(1, -94, 0, 42),
		TextScaled = true,
		TextColor3 = color,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 40 }, amount)
	local detail = Ui.text(plaque, {
		Position = UDim2.fromOffset(84, 46),
		Size = UDim2.new(1, -94, 0, 28),
		TextScaled = true,
		TextColor3 = Ui.MUTED,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 24 }, detail)
	return plaque, amount, detail
end

-- Builds the message scroll: parchment between two wooden rollers, with a seal on the left
-- that takes the message's color.
local function buildScroll(parent: Instance): Scroll
	local paper = Ui.parchment(parent, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20),
		Size = UDim2.new(0.55, 0, 0, 86),
		Visible = false,
	}, 40)
	Ui.make("UISizeConstraint", {
		MinSize = Vector2.new(560, 86),
		MaxSize = Vector2.new(1150, 86),
	}, paper.frame)

	local words = Ui.text(paper.page, {
		Position = UDim2.fromOffset(82, 8),
		Size = UDim2.new(1, -110, 1, -16),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 44 }, words)

	return { paper = paper, words = words }
end

function Hud.start()
	local screen = Ui.screen("Hud", 10)

	-- Chakra and the throw power, bottom-left. Touch screens have the movement stick there, so
	-- on those the stack stands in the upper left corner instead. `chakraBottom` is where the
	-- Chakra readout's lower edge is, as a share of the screen's height plus an offset.
	local touch = Ui.touch()
	local chakraBottom = if touch then UDim.new(0, Hud.TOUCH_FOOT) else UDim.new(1, -12)
	local chakraPlaque, chakraAmount, chakraDetail = readout(screen, Icons.chakra, Ui.BLUE, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(UDim.new(0, 12), chakraBottom),
		Size = UDim2.fromOffset(READOUT_WIDTH, CHAKRA_HEIGHT),
	})
	-- On a touch screen the slider opens downwards, there being no room over the readouts.
	local slider = ThrowPower.attach(chakraPlaque, touch)

	-- Ryo, right above Chakra. When the throw power slider opens over the Chakra readout, Ryo
	-- moves up to sit above the slider.
	local ryoPlaque, ryoAmount, ryoDetail = readout(screen, Icons.coin, Ui.GOLD, {
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.fromOffset(READOUT_WIDTH, RYO_HEIGHT),
	})
	ryoDetail.TextColor3 = Ui.GREEN
	local function stack()
		local lift = CHAKRA_HEIGHT + READOUT_GAP
		if slider.Visible and not touch then
			-- The slider's own gap above the readout is the offset it is placed with.
			lift += slider.Size.Y.Offset - slider.Position.Y.Offset
		end
		ryoPlaque.Position =
			UDim2.new(UDim.new(0, 12), UDim.new(chakraBottom.Scale, chakraBottom.Offset - lift))
	end
	slider:GetPropertyChangedSignal("Visible"):Connect(stack)
	stack()

	-- Until the first snapshot arrives the readouts say why they are empty. A save usually
	-- loads at once, but it can take most of a minute when another server still holds it.
	ryoAmount.Text = Strings.get("HudLoading")
	chakraAmount.Text = Strings.get("HudLoading")

	-- Window buttons, on the right edge; on a touch screen in its upper right corner, two to a
	-- row, out of the way of the jump button, with the left column's among them.
	if touch then
		local wide = TOUCH_ROW * TILE.X + (TOUCH_ROW - 1) * TILE_GAP
		local grid = Ui.make("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, TOUCH_TOP),
			Size = UDim2.fromOffset(wide, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}, screen)
		Ui.make("UIGridLayout", {
			CellSize = UDim2.fromOffset(TILE.X, TILE.Y),
			CellPadding = UDim2.fromOffset(TILE_GAP, TILE_GAP),
			FillDirectionMaxCells = TOUCH_ROW,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		Ui.make("UIScale", { Scale = TOUCH_TILES }, grid)
		sideColumn = grid
		leftColumn = grid
	end
	local column = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -RIGHT_FOOT),
		Size = UDim2.fromOffset(TILE.X, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = not touch,
	}, screen)
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, TILE_GAP),
	}, column)
	if not touch then
		sideColumn = column
		rightColumn = column
	end
	-- And a column on the left edge, for Rebirth, which the games of this kind keep there. It
	-- stands at the middle of the edge, over the readouts. (On a touch screen its tiles are
	-- among the others, above.)
	local left = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(TILE.X, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = not touch,
	}, screen)
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, TILE_GAP),
	}, left)
	if not touch then
		leftColumn = left
	end
	-- The throw power slider opens upwards over the readouts, and Ryo moves up over it: into
	-- where this column stands. So the column makes way too, to just above Ryo, and comes
	-- back when the slider shuts. (A touch screen has no such column.)
	if not touch then
		local function makeWay()
			local goal = UDim2.new(0, 12, 0.5, 0)
			if slider.Visible then
				local tall = left.AbsoluteSize.Y / Ui.scale()
				-- From the foot of the Chakra readout up to the top of Ryo.
				local stacked = CHAKRA_HEIGHT
					+ READOUT_GAP
					+ slider.Size.Y.Offset
					- slider.Position.Y.Offset
					+ RYO_HEIGHT
				local room = Ui.room().Y
				local ryoTop = room * chakraBottom.Scale + chakraBottom.Offset - stacked
				local foot = ryoTop - READOUT_GAP
				if foot - tall < READOUT_GAP then
					-- A short window has no room over Ryo: the column stands beside the
					-- readouts instead.
					goal = UDim2.new(0, 12 + READOUT_WIDTH + READOUT_GAP, 0.5, 0)
				else
					goal = UDim2.fromOffset(12, math.min(room / 2 + tall / 2, foot) - tall / 2)
				end
			end
			TweenService:Create(
				left,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = goal }
			):Play()
		end
		slider:GetPropertyChangedSignal("Visible"):Connect(makeWay)
		-- A tile added while the slider is open, or the window resized, moves it again.
		left:GetPropertyChangedSignal("AbsoluteSize"):Connect(makeWay)
		Ui.onResize(makeWay)
	end

	scroll = buildScroll(screen)

	-- Herbs: a small chip in the Ryo readout's lower right corner, where the income line
	-- leaves room for it: a leaf and the count, in a muted green, on a sheet a little lighter
	-- than the readout. Less than Ryo on purpose, and nothing more on the screen.
	-- The chip is as wide as what it holds (owner, 2026-10-17: with 50 Herbs a fixed width
	-- left "a heap of room" and looked bad): it grows leftwards from the corner with the count,
	-- and the income line gives way to it.
	local herbsPlaque = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -6),
		Size = UDim2.fromOffset(0, HERBS_TALL),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Ui.CARD,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, ryoPlaque)
	Ui.corner(herbsPlaque, 15)
	Ui.stroke(herbsPlaque, Ui.GREEN, 1.5).Transparency = 0.35
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, HERBS_GAP),
	}, herbsPlaque)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 10),
	}, herbsPlaque)
	local herbsIcon = Ui.make("Frame", {
		Size = UDim2.fromOffset(HERBS_ICON, HERBS_ICON),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	}, herbsPlaque)
	Icons.herb(herbsIcon)
	local herbsPop: UIScale = Ui.make("UIScale", {}, herbsIcon)
	local herbsAmount = Ui.text(herbsPlaque, {
		Size = UDim2.fromOffset(0, HERBS_TALL - 4),
		AutomaticSize = Enum.AutomaticSize.X,
		TextSize = HERBS_TEXT,
		TextColor3 = Color3.fromRGB(165, 214, 167),
		LayoutOrder = 2,
	})
	-- The income line ends where the chip begins, however wide the chip has grown. The chip's
	-- width on the screen is the layer's scale times its width as laid out.
	local function giveWay()
		local wide = herbsPlaque.AbsoluteSize.X / Ui.scale()
		ryoDetail.Size = UDim2.new(1, -(94 + wide + 8), 0, 28)
	end
	herbsPlaque:GetPropertyChangedSignal("AbsoluteSize"):Connect(giveWay)
	giveWay()

	-- A slip of parchment with "+N" in ink rises off the readout and fades, and the leaf
	-- jumps: in the style of the upgrade's tag, not bare colored words.
	-- It is a child of the Ryo readout, not of the chip, whose list would lay it out: it starts
	-- over the chip's middle, wherever that is as the chip's width follows the count.
	local function gained(count: number)
		local middle = -8 - herbsPlaque.AbsoluteSize.X / Ui.scale() / 2
		local top = -6 - HERBS_TALL - 4
		local slip = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(1, middle, 1, top),
			Size = UDim2.fromOffset(GAIN.X, GAIN.Y),
			BackgroundColor3 = Ui.PARCHMENT,
			BorderSizePixel = 0,
			ZIndex = 4,
		}, ryoPlaque)
		Ui.corner(slip, 8)
		local edge = Ui.stroke(slip, Ui.GREEN, 2)
		local words = Ui.text(slip, {
			Size = UDim2.fromScale(1, 1),
			TextSize = 24,
			TextColor3 = Ui.INK,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 5,
			Text = Strings.get("HudHerbsGain", count),
		})
		local rise = TweenInfo.new(GAIN_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(slip, rise, {
			Position = UDim2.new(1, middle, 1, top - GAIN_RISE),
		}):Play()
		local fade = TweenInfo.new(GAIN_FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(GAIN_SECONDS - GAIN_FADE, function()
			TweenService:Create(slip, fade, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(words, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(edge, fade, { Transparency = 1 }):Play()
		end)
		task.delay(GAIN_SECONDS + 0.05, function()
			slip:Destroy()
		end)
		herbsPop.Scale = 1.3
		TweenService:Create(
			herbsPop,
			TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end
	-- What the readout said last, so that only a gain is greeted, and not the first snapshot.
	local shownHerbs: number? = nil

	Store.onChange(function(state)
		herbsAmount.Text = Strings.get("HudHerbs", state.herbs)
		local before = shownHerbs
		if before and state.herbs > before then
			gained(state.herbs - before)
		end
		shownHerbs = state.herbs
		ryoAmount.Text = Strings.get("HudRyo", state.ryo)
		ryoDetail.Text = Strings.get("HudIncome", state.income)

		chakraAmount.Text = Strings.get("HudChakra", state.chakra)
		local perRep = Economy.chakraPerRep(state.kunai)
			* state.multipliers.chakra
			* state.trainBoost
		local detail = if state.training == "meditate"
			then Strings.get(
				"HudMeditating",
				perRep * Tuning.Training.meditateReps / Tuning.Training.meditateInterval
			)
			elseif state.training == "focus" then Strings.get(
				"HudFocus",
				perRep * Focus.bestReps()
			)
			else Strings.get("HudIdle")
		if state.trainBoost > 1 then
			detail ..= Strings.get("HudBoost", state.trainBoost)
		end
		chakraDetail.Text = detail
		chakraDetail.TextColor3 = if state.trainBoost > 1 then Ui.GOLD else Ui.MUTED
	end)

	Remotes.Notify.OnClientEvent:Connect(function(key: string, ...: any)
		Hud.toast(Strings.get(key, ...))
	end)

	Remotes.RunEnd.OnClientEvent:Connect(function(run: Net.RunEnd)
		local title = Strings.title(run.character, run.mutation, 1)
		if not run.escaped then
			Hud.toast(Strings.get("RunCaught", enemyName(run.zone), title, run.reward), Ui.RED)
		else
			-- Home safe: what the catch is, and the Herbs it paid (Tuning.Herbs), which the
			-- chip in the Ryo readout greets at the same moment.
			local text = if run.isNew
				then Strings.get("RunEscapedNew", title, run.reward)
				else Strings.get("RunEscaped", title)
			if run.herbs > 0 then
				text ..= Strings.get("KickHerbs", run.herbs)
			end
			-- A twin of it stands on a pad, and glows there (client MergeGlow).
			if run.twin then
				text ..= Strings.get("RunMerge")
			end
			Hud.toast(text, Hud.rankColor(run.character))
		end
	end)
end

return Hud
