--!strict
-- Rebirth, on the player's side: a tile on the left edge of the screen, where the games this
-- one is kin to keep theirs, and the window it opens. The window says who the player becomes,
-- how far their Chakra is towards it, what it pays for good and what it costs, and has the one
-- button that does it. The server decides whether it may be done (Services/Rebirth); a rebirth
-- that went through is celebrated on the same scroll a new speed stage is (client StageFlash).
--
-- In the style of the game: the rebirth to come is named on a scroll, its number on the seal;
-- the rest is the windows' own dark board with what changes in gold.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = require("./Hud")
local Icons = require("./Icons")
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Remotes = require("./Remotes")
local StageFlash = require("./StageFlash")
local Store = require("./Store")
local Strings = require("./Strings")
local Ui = require("./Ui")

local RebirthPanel = {}

-- How long the button stays armed after its first press, seconds: a rebirth cannot be undone,
-- so it is pressed twice.
local ARMED_SECONDS = 4
-- What a rebirth pays, in the order of its cards: the caption, the color of the numbers, and
-- the multiplier `count` rebirths give.
local PAYS: { { caption: string, color: Color3, of: (count: number) -> number } } = {
	{ caption = "RebirthRyo", color = Ui.GOLD, of = Rebirth.ryo },
	{ caption = "RebirthPower", color = Ui.BLUE, of = Rebirth.chakra },
	{ caption = "RebirthLuck", color = Ui.GREEN, of = Rebirth.mutationLuck },
}
local CARD_HEIGHT = 108
local GAP = 12

function RebirthPanel.start()
	local window = Ui.window("Rebirth", Vector2.new(780, 560))
	window.title.Text = Strings.get("RebirthTitle")
	local body = window.body

	local tile, counter = Hud.sideButton(Strings.get("RebirthButton"), Ui.GOLD, Icons.rebirth, true)
	tile.Activated:Connect(window.toggle)
	local tileEdge = tile:FindFirstChildOfClass("UIStroke")

	-- Who the player becomes: a scroll, the rebirth's number on its seal.
	local scroll = Ui.parchment(body, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(1, -40, 0, 100),
	}, 64)
	local number = Ui.text(scroll.seal, {
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		TextColor3 = Ui.PARCHMENT,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.padding(scroll.seal, 10)
	local title = Ui.text(scroll.frame, {
		Position = UDim2.fromOffset(108, 6),
		Size = UDim2.new(1, -136, 0, 54),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 46 }, title)
	local step = Ui.text(scroll.frame, {
		Position = UDim2.fromOffset(108, 62),
		Size = UDim2.new(1, -136, 0, 30),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 23 }, step)

	-- How far the player's Chakra is towards it.
	local track = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 134),
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Ui.PANEL,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, body)
	Ui.corner(track, 8)
	Ui.stroke(track, Ui.EDGE, 2)
	local fill = Ui.make("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Ui.BLUE,
		BorderSizePixel = 0,
	}, track)
	local progress = Ui.text(track, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		ZIndex = 2,
	})

	-- What it pays: a card for each multiplier, what it is now and what it becomes.
	local changes: { TextLabel } = {}
	local cardsTop = 134 + 46 + GAP
	for index, pay in PAYS do
		local card = Ui.panel(body, {
			Position = UDim2.new(
				(index - 1) / #PAYS,
				if index == 1 then 0 else GAP / 2,
				0,
				cardsTop
			),
			Size = UDim2.new(
				1 / #PAYS,
				-GAP / 2 - (if index == 2 then GAP / 2 else 0),
				0,
				CARD_HEIGHT
			),
			BackgroundColor3 = Ui.CARD,
			BackgroundTransparency = 0,
		})
		Ui.stroke(card, pay.color, 2)
		Ui.text(card, {
			Position = UDim2.fromOffset(0, 12),
			Size = UDim2.new(1, 0, 0, 28),
			TextSize = 22,
			TextColor3 = Ui.PARCHMENT,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = Strings.get(pay.caption),
		})
		changes[index] = Ui.text(card, {
			Position = UDim2.fromOffset(8, 46),
			Size = UDim2.new(1, -16, 0, 48),
			TextScaled = true,
			TextColor3 = pay.color,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		Ui.make("UITextSizeConstraint", { MaxTextSize = 34 }, changes[index])
	end

	-- What it costs, and what it leaves alone.
	local noteTop = cardsTop + CARD_HEIGHT + GAP
	Ui.text(body, {
		Position = UDim2.fromOffset(0, noteTop),
		Size = UDim2.new(1, 0, 0, 54),
		TextSize = 20,
		TextColor3 = Ui.MUTED,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("RebirthNote"),
	})

	local button = Ui.button(body, {
		Position = UDim2.fromOffset(0, noteTop + 54 + GAP),
		Size = UDim2.new(1, 0, 0, 68),
		TextSize = 32,
	})
	-- Counts the arming of the button, so an old timer cannot disarm a newer press.
	local armed = 0
	local isArmed = false

	local function draw()
		local state = Store.get()
		if not state then
			return
		end
		local done = Rebirth.done(state.rebirths)
		local following = Rebirth.next(done)
		local ready = Rebirth.ready(state.chakra, done)

		-- The tile: how many are done, and a mark and a gold edge when the next can be.
		counter.Visible = ready or done > 0
		counter.Text = if ready then "!" else tostring(done)
		if tileEdge then
			tileEdge.Color = if ready then Ui.GOLD else Ui.EDGE
		end

		for index, pay in PAYS do
			changes[index].Text = if following
				then Strings.get("RebirthChange", pay.of(done), pay.of(done + 1))
				else Strings.get("RebirthHolds", pay.of(done))
		end
		fill.Size = UDim2.fromScale(Rebirth.progress(state.chakra, done), 1)
		fill.BackgroundColor3 = if ready then Ui.GREEN else Ui.BLUE

		if not following then
			number.Text = tostring(done)
			title.Text = string.upper(Rebirth.title(done))
			step.Text = Strings.get("RebirthAllDone")
			progress.Text = Strings.get("HudChakra", state.chakra)
			button.Text = Strings.get("RebirthNoMore")
			button.BackgroundColor3 = Ui.GRAY
			button.AutoButtonColor = false
			return
		end
		number.Text = tostring(done + 1)
		title.Text = string.upper(following.title)
		step.Text = Strings.get("RebirthStep", done + 1, Rebirth.count(), Rebirth.title(done))
		progress.Text = Strings.get(
			"RebirthProgress",
			math.min(state.chakra, following.chakra),
			following.chakra
		)
		button.Text = if not ready
			then Strings.get("RebirthNeed", following.chakra - state.chakra)
			elseif isArmed then Strings.get("RebirthSure")
			else Strings.get("RebirthDo")
		button.BackgroundColor3 = if ready then Ui.SEAL else Ui.GRAY
		button.AutoButtonColor = ready
	end

	button.Activated:Connect(function()
		local state = Store.get()
		if not state or not Rebirth.ready(state.chakra, state.rebirths) then
			return
		end
		if isArmed then
			isArmed = false
			Remotes.Rebirth:FireServer()
		else
			isArmed = true
			armed += 1
			local mine = armed
			task.delay(ARMED_SECONDS, function()
				if armed == mine and isArmed then
					isArmed = false
					draw()
				end
			end)
		end
		draw()
	end)

	-- A rebirth that went through: the count went up since the last snapshot.
	local known: number? = nil
	Store.onChange(function(state)
		local done = Rebirth.done(state.rebirths)
		if known ~= nil and done > known then
			isArmed = false
			StageFlash.show(
				Ui.GOLD,
				tostring(done),
				string.upper(Rebirth.title(done)),
				Strings.get(
					"RebirthDone",
					Rebirth.ryo(done),
					Rebirth.chakra(done),
					Rebirth.mutationLuck(done)
				)
			)
			window.close()
		end
		known = done
		draw()
	end)
end

return RebirthPanel
