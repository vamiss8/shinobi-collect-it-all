--!strict
-- The always-visible UI, kept small and split by purpose: Ryo on the left edge, Chakra and the
-- throw power in the bottom-left corner, window buttons on the right edge, and short messages
-- ("toasts") at the top.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Focus = require(ReplicatedStorage.Shared.Logic.Focus)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local ThrowPower = require("./ThrowPower")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local Hud = {}

local TOAST_SECONDS = 3.5

local toastLabel: TextLabel? = nil
local toastToken = 0
local sideColumn: Frame? = nil

-- Shows a message at the top of the screen for a few seconds. A newer one replaces it.
function Hud.toast(text: string, color: Color3?)
	local label = toastLabel
	if not label then
		return
	end
	toastToken += 1
	local token = toastToken
	label.Text = text
	label.TextColor3 = color or Ui.WHITE
	label.Visible = true
	task.delay(TOAST_SECONDS, function()
		if toastToken == token then
			label.Visible = false
		end
	end)
end

-- The color of a character's rank, for coloring their name.
function Hud.rankColor(characterId: string): Color3
	local character = Catalog.characterById[characterId]
	local rank = if character then Catalog.ranks[Catalog.rankOrder[character.rank]] else nil
	return if rank then Color3.fromHex(rank.color) else Ui.WHITE
end

-- Adds a tile to the column on the right edge of the screen: an icon with a caption under it.
-- Windows use it as their opener. `drawIcon` fills the square it is given (see Icons). Returns
-- the tile and a small counter in its corner, hidden until it is given text. Call after
-- Hud.start().
function Hud.sideButton(
	text: string,
	color: Color3,
	drawIcon: (holder: Instance) -> ()
): (TextButton, TextLabel)
	assert(sideColumn, "Hud.start() has not run yet")
	local tile = Ui.button(sideColumn, {
		Size = UDim2.fromOffset(96, 98),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.1,
	})
	Ui.stroke(tile, color, 2)

	local holder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(56, 56),
		BackgroundTransparency = 1,
	}, tile)
	drawIcon(holder)

	Ui.text(tile, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -8, 0, 24),
		Font = Ui.BRUSH,
		TextColor3 = color,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
	})

	local counter = Ui.text(tile, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, 5),
		Size = UDim2.fromOffset(30, 20),
		BackgroundColor3 = Ui.SEAL,
		BackgroundTransparency = 0,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	Ui.corner(counter, 10)
	return tile, counter
end

local function enemyName(zoneId: string): string
	local zone = Catalog.zoneById[zoneId]
	return if zone then zone.enemy.name else zoneId
end

-- A pill-shaped readout: a round badge, a big number and a smaller line under it.
local function readout(
	parent: Instance,
	letter: string,
	color: Color3,
	properties: { [string]: any }
): (Frame, TextLabel, TextLabel)
	local pill = Ui.panel(parent, properties)
	pill.BackgroundTransparency = 0.1
	Ui.stroke(pill, color, 2)
	local badge = Ui.badge(pill, letter, color, 40)
	badge.Position = UDim2.fromOffset(10, 8)

	-- Both lines shrink to fit the pill instead of running past its edge.
	local amount = Ui.text(pill, {
		Position = UDim2.fromOffset(60, 4),
		Size = UDim2.new(1, -70, 0, 28),
		Font = Ui.BRUSH,
		TextScaled = true,
		TextColor3 = color,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 24 }, amount)
	local detail = Ui.text(pill, {
		Position = UDim2.fromOffset(60, 32),
		Size = UDim2.new(1, -70, 0, 18),
		TextScaled = true,
		TextColor3 = Ui.MUTED,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 14 }, detail)
	return pill, amount, detail
end

function Hud.start()
	local screen = Ui.screen("Hud", 10)

	-- Ryo, on the left edge.
	local _, ryoAmount, ryoDetail = readout(screen, "R", Ui.GOLD, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, -60),
		Size = UDim2.fromOffset(230, 56),
	})
	ryoDetail.TextColor3 = Ui.GREEN

	-- Chakra and the throw power, bottom-left. Touch screens have the movement stick there, so
	-- on those it sits under the Ryo readout instead.
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local chakraPill, chakraAmount, chakraDetail = readout(screen, "C", Ui.BLUE, {
		AnchorPoint = if touch then Vector2.new(0, 0.5) else Vector2.new(0, 1),
		Position = if touch then UDim2.new(0, 12, 0.5, 30) else UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(300, 98),
	})

	ThrowPower.attach(chakraPill)

	-- Until the first snapshot arrives the readouts say why they are empty. A save usually
	-- loads at once, but it can take most of a minute when another server still holds it.
	ryoAmount.Text = Strings.get("HudLoading")
	chakraAmount.Text = Strings.get("HudLoading")

	-- Window buttons, on the right edge.
	local column = Ui.make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(96, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, screen)
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, column)
	sideColumn = column

	local toast = Ui.text(screen, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0.5, 0, 0, 46),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.2,
		Font = Ui.BRUSH,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		Visible = false,
	})
	Ui.corner(toast, 10)
	Ui.padding(toast, 8)
	Ui.make("UITextSizeConstraint", { MaxTextSize = 24 }, toast)
	toastLabel = toast

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

	Remotes.RunStart.OnClientEvent:Connect(function(run: Net.RunStart)
		local title = Catalog.unitTitle(run.character, run.mutation, 1)
		Hud.toast(Strings.get("RunStart", title, enemyName(run.zone)), Hud.rankColor(run.character))
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
