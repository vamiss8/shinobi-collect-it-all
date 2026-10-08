--!strict
-- The always-visible UI, split by purpose: Chakra and the throw power in the bottom-left
-- corner with Ryo stacked right above them, window buttons on the right edge, and short
-- messages written on a scroll at the top.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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

-- The scroll messages are written on: the parchment, its words, and the two things that take
-- a message's color, the outline and the seal.
type Scroll = { frame: Frame, words: TextLabel, edge: UIStroke, seal: Frame }

local scroll: Scroll? = nil
local messageToken = 0
local sideColumn: Frame? = nil
local leftColumn: Frame? = nil

-- Shows a message on the scroll at the top of the screen for a few seconds. A newer one
-- replaces it. The words are always ink on parchment; `color` goes to the seal and the outline.
function Hud.toast(text: string, color: Color3?)
	local shown = scroll
	if not shown then
		return
	end
	messageToken += 1
	local token = messageToken
	shown.words.Text = text
	shown.edge.Color = color or Ui.EDGE
	shown.seal.BackgroundColor3 = color or Ui.SEAL
	shown.frame.Visible = true
	task.delay(MESSAGE_SECONDS, function()
		if messageToken == token then
			shown.frame.Visible = false
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
	local tile = Ui.button(column, {
		Size = UDim2.fromOffset(112, 116),
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

local function enemyName(zoneId: string): string
	local zone = Catalog.zoneById[zoneId]
	return if zone then zone.enemy.name else zoneId
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

	local words = Ui.text(paper.frame, {
		Position = UDim2.fromOffset(82, 8),
		Size = UDim2.new(1, -110, 1, -16),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 44 }, words)

	return { frame = paper.frame, words = words, edge = paper.edge, seal = paper.seal }
end

function Hud.start()
	local screen = Ui.screen("Hud", 10)

	-- Chakra and the throw power, bottom-left. Touch screens have the movement stick there, so
	-- on those the stack sits halfway up the left edge instead. `chakraBottom` is where the
	-- Chakra readout's lower edge is, as a share of the screen's height plus an offset.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local chakraBottom = if touch then UDim.new(0.5, CHAKRA_HEIGHT - 10) else UDim.new(1, -12)
	local chakraPlaque, chakraAmount, chakraDetail = readout(screen, Icons.chakra, Ui.BLUE, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(UDim.new(0, 12), chakraBottom),
		Size = UDim2.fromOffset(READOUT_WIDTH, CHAKRA_HEIGHT),
	})
	local slider = ThrowPower.attach(chakraPlaque)

	-- Ryo, right above Chakra. When the throw power slider opens over the Chakra readout, Ryo
	-- moves up to sit above the slider.
	local ryoPlaque, ryoAmount, ryoDetail = readout(screen, Icons.coin, Ui.GOLD, {
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.fromOffset(READOUT_WIDTH, RYO_HEIGHT),
	})
	ryoDetail.TextColor3 = Ui.GREEN
	local function stack()
		local lift = CHAKRA_HEIGHT + READOUT_GAP
		if slider.Visible then
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

	-- Window buttons, on the right edge.
	local column = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(112, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, screen)
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
	}, column)
	sideColumn = column
	-- And a column on the left edge, for Rebirth, which the games of this kind keep there. It
	-- stands at the middle of the edge, over the readouts; on a touch screen the readouts are
	-- there themselves, so it stands above them.
	local left = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, if touch then 0 else 0.5),
		Position = UDim2.new(0, 12, if touch then 0.12 else 0.5, 0),
		Size = UDim2.fromOffset(112, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, screen)
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 12),
	}, left)
	leftColumn = left

	scroll = buildScroll(screen)

	Store.onChange(function(state)
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
		local title = Catalog.unitTitle(run.character, run.mutation, 1)
		if not run.escaped then
			Hud.toast(Strings.get("RunCaught", enemyName(run.zone), title, run.reward), Ui.RED)
		elseif run.isNew then
			Hud.toast(Strings.get("RunEscapedNew", title, run.reward), Hud.rankColor(run.character))
		else
			Hud.toast(Strings.get("RunEscaped", title), Hud.rankColor(run.character))
		end
	end)
end

return Hud
