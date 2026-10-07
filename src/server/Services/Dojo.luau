--!strict
-- The dojo: placing, taking, swapping, merging and upgrading units on pads, unlocking new pads,
-- and the income that placed units earn.
--
-- A unit is either on a pad (data.pads) or in the inventory (see Inventory). The unit a pad acts
-- on is the one the player is carrying. Upgrades are bought on the console at the foot of the
-- pad: three buttons for one level, ten levels, and as many as the Ryo pays for. A button is
-- yellow when pressing it would buy something and gray when it would not.
--
-- Pads are bought one at a time, in order, as in Kick an Uma: the next one glows, with its
-- price floating over it in green when the player can pay it and in red when not. The game
-- pass's pads come last and say so. The dojo grows with them: when a floor's pads are all
-- bought, the next floor goes up (Logic/DojoPlan.floorsFor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require("../Data")
local DojoPlan = require(ReplicatedStorage.Shared.Logic.DojoPlan)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Inventory = require("./Inventory")
local Net = require(ReplicatedStorage.Shared.Net)
local Plots = require("../World/Plots")
local Remotes = require("../Remotes")
local Session = require("../Session")
local State = require("./State")
local Stats = require("./Stats")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Dojo = {}

local PAD_LOCKED = Color3.fromRGB(70, 70, 70)
local PAD_FOR_SALE = Color3.fromRGB(66, 165, 245)
local PAD_PASS = Color3.fromRGB(171, 71, 188)
local PAD_EMPTY = Color3.fromRGB(102, 187, 106)
local PAD_TAKEN = Color3.fromRGB(255, 213, 79)

local CAN_PAY = Color3.fromRGB(129, 230, 135)
local CANNOT_PAY = Color3.fromRGB(255, 112, 102)
local PASS_TEXT = Color3.fromRGB(225, 170, 255)

-- A console button that would buy something: a gilt slab round bright parchment, ink for what
-- it does, red for what it costs, a red seal. One that would not: all of it gone gray.
local BUTTON_ON = Color3.fromRGB(255, 200, 48)
local BUTTON_OFF = Color3.fromRGB(105, 102, 98)
local PAPER_ON = Color3.fromRGB(236, 220, 188)
local PAPER_OFF = Color3.fromRGB(178, 170, 156)
local INK = Color3.fromRGB(40, 30, 24)
local PRICE = Color3.fromRGB(150, 40, 30)
local SEAL = Color3.fromRGB(183, 40, 32)
local FADED = Color3.fromRGB(112, 104, 96)
-- A press is accepted from a little farther than the client lets one through, so a player who
-- is walking away as they click is not turned down.
local PRESS_SLACK = 4
-- A player back after less than this is paid for the time away at once, without a
-- welcome-back window: someone who rejoins to pick up an update has nothing to read. Seconds.
local WELCOME_AFTER = 60
-- Levels the two fixed buttons buy; the third buys what the Ryo allows.
local LEVELS = { one = 1, ten = 10 }

-- What a console button stands for, by its part: the client reports a press by naming the part.
type Press = { plot: Plots.Plot, pad: Plots.Pad, part: Part, levels: number? }
local presses: { [Instance]: Press } = {}

-- Shows one console button, bright and pressable or gray and dead: `title` is what it does,
-- `detail` what it costs or how much it buys, `mark` what the wide button's seal is stamped
-- with.
local function drawButton(
	button: Plots.Button,
	title: string,
	detail: string,
	enabled: boolean,
	mark: string?
)
	button.part.Transparency = 0
	button.part.Color = if enabled then BUTTON_ON else BUTTON_OFF
	button.part:SetAttribute(Net.ACTIVE_ATTRIBUTE, enabled)
	button.gui.Enabled = true
	button.paper.BackgroundColor3 = if enabled then PAPER_ON else PAPER_OFF
	button.title.Text = title
	button.title.TextColor3 = if enabled then INK else FADED
	button.detail.Text = detail
	button.detail.TextColor3 = if enabled then PRICE else FADED
	if button.seal and button.mark then
		button.seal.BackgroundColor3 = if enabled then SEAL else FADED
		button.mark.Text = mark or ""
	end
end

-- Redraws a pad's upgrade console. It is there for every unlocked pad of an owned dojo, gray
-- while the pad is empty, and gone otherwise. Setting a property to the value it already has
-- costs nothing, so this is also run for every pad whenever the owner's Ryo changes.
local function drawConsole(pad: Plots.Pad, data: Data.Data?, isOpen: boolean)
	local buttons = pad.buttons
	local hidden = if data and isOpen then 0 else 1
	for _, piece in pad.trim do
		piece.Transparency = hidden
	end
	if not data or not isOpen then
		pad.console.Transparency = 1
		for _, button in { buttons.one, buttons.ten, buttons.max } do
			button.part.Transparency = 1
			button.part:SetAttribute(Net.ACTIVE_ATTRIBUTE, false)
			button.gui.Enabled = false
		end
		return
	end
	pad.console.Transparency = 0

	local unitId = data.pads[tostring(pad.index)]
	local unit = if unitId then data.units[unitId] else nil
	if not unit then
		drawButton(buttons.one, "LEVEL UP", "", false, "+1")
		drawButton(buttons.ten, "+10 Lvl", "", false)
		drawButton(buttons.max, "MAX", "", false)
		return
	end

	local onePrice, oneLevels = Economy.upgradesPrice(unit, LEVELS.one)
	local tenPrice, tenLevels = Economy.upgradesPrice(unit, LEVELS.ten)
	if oneLevels == 0 or onePrice <= 0 then
		drawButton(buttons.one, "TOP LEVEL", "", false, "MAX")
		drawButton(buttons.ten, "+10 Lvl", "", false)
		drawButton(buttons.max, "MAX", "", false)
		return
	end
	local affordable = Economy.affordableUpgrades(unit, data.ryo)
	drawButton(buttons.one, "LEVEL UP", `{Format.short(onePrice)} Ryo`, data.ryo >= onePrice, "+1")
	-- The small buttons say the price without the word: there is room for larger figures so.
	drawButton(buttons.ten, `+{tenLevels} Lvl`, Format.short(tenPrice), data.ryo >= tenPrice)
	drawButton(
		buttons.max,
		"MAX",
		if affordable > 0 then `+{affordable} Lvl` else "",
		affordable > 0
	)
end

-- Whether the pad is the next one the player can buy: the first locked one, while there are
-- pads left to buy for Ryo.
local function isForSale(pad: Plots.Pad, data: Data.Data): boolean
	return pad.index == Stats.unlockedPads(data) + 1 and data.padsBought < Tuning.Dojo.buyablePads
end

-- Colors the price over the pad for sale by whether the player can pay it right now.
local function drawPrice(pad: Plots.Pad, data: Data.Data)
	local price = Economy.padPrice(data.padsBought)
	pad.tag.Text = `UNLOCK\n{Format.short(price)} Ryo`
	pad.tag.TextColor3 = if data.ryo >= price then CAN_PAY else CANNOT_PAY
end

-- Redraws one pad from the save; without a save the pad goes back to its locked look.
local function drawPad(plot: Plots.Plot, pad: Plots.Pad, data: Data.Data?)
	if pad.figure then
		pad.figure:Destroy()
		pad.figure = nil
	end

	local unlocked = if data then Stats.unlockedPads(data) else 0
	local isOpen = pad.index <= unlocked
	-- The first locked pad can be bought by walking up to it.
	local forSale = data ~= nil and isForSale(pad, data)
	-- The game pass's pads come after all those sold for Ryo.
	local d = Tuning.Dojo
	local forPass = data ~= nil and not isOpen and pad.index > d.startPads + d.buyablePads
	local unitId = if data then data.pads[tostring(pad.index)] else nil
	local unit = if data and unitId then data.units[unitId] else nil

	pad.prompt.Enabled = isOpen or forSale
	pad.part.Transparency = if isOpen or forSale then 0 elseif forPass then 0.35 else 0.6
	pad.part.Material = if forSale then Enum.Material.Neon else Enum.Material.SmoothPlastic
	pad.part.Color = if forSale
		then PAD_FOR_SALE
		elseif forPass then PAD_PASS
		elseif not isOpen then PAD_LOCKED
		elseif unit then PAD_TAKEN
		else PAD_EMPTY

	-- Only the first of the pass's pads carries the sign, so the floor is not covered in them.
	pad.tagGui.Enabled = forSale or (forPass and pad.index == d.startPads + d.buyablePads + 1)
	if data and forSale then
		drawPrice(pad, data)
	elseif forPass then
		pad.tag.Text = `GAME PASS\n+{d.gamePassPads} PADS`
		pad.tag.TextColor3 = PASS_TEXT
	end

	drawConsole(pad, data, isOpen)

	if data and forSale then
		pad.prompt.ActionText = "Unlock"
		pad.prompt.ObjectText = `{Format.short(Economy.padPrice(data.padsBought))} Ryo`
	elseif unit then
		local figure = Figure.build(unit)
		figure:PivotTo(pad.stand)
		figure.Parent = plot.folder
		pad.figure = figure
		pad.prompt.ActionText = "Take / Swap"
		pad.prompt.ObjectText = Figure.title(unit)
	else
		pad.prompt.ActionText = "Place"
		pad.prompt.ObjectText = "Empty pad"
	end
end

-- How many floors the dojo stands with for this save.
local function floorsOf(data: Data.Data): number
	return DojoPlan.floorsFor(Stats.unlockedPads(data))
end

local function drawPads(player: Player)
	local plot = Plots.of(player)
	if plot then
		local data = Data.get(player)
		Plots.setFloors(plot, if data then floorsOf(data) else 1)
		for _, pad in plot.pads do
			drawPad(plot, pad, data)
		end
	end
end

local function unlockPad(player: Player, data: Data.Data)
	local price = Economy.padPrice(data.padsBought)
	if data.ryo < price then
		State.notify(player, "NotEnoughRyo")
		return
	end
	local floors = floorsOf(data)
	data.ryo -= price
	data.padsBought += 1
	drawPads(player)
	if floorsOf(data) > floors then
		State.notify(player, "FloorBuilt", floorsOf(data))
	end
	State.push(player)
end

local function usePad(player: Player, plot: Plots.Plot, pad: Plots.Pad)
	local data = Data.get(player)
	if not data then
		return
	end
	if plot.owner ~= player then
		State.notify(player, "NotYourDojo")
		return
	end

	local unlocked = Stats.unlockedPads(data)
	if pad.index == unlocked + 1 and data.padsBought < Tuning.Dojo.buyablePads then
		unlockPad(player, data)
		return
	elseif pad.index > unlocked then
		return
	end

	local key = tostring(pad.index)
	local onPad = data.pads[key]
	local held = Inventory.held(player)

	if not onPad and not held then
		State.notify(player, "NothingHeld")
		return
	elseif not onPad and held then
		-- Place the held unit.
		data.pads[key] = held
		Inventory.hold(player, nil)
	elseif onPad and not held then
		-- Take the unit off the pad. It goes into the inventory, not into the player's hands,
		-- so clearing several pads is one press each.
		data.pads[key] = nil
	elseif onPad and held then
		local heldUnit, padUnit = data.units[held], data.units[onPad]
		if Economy.canMerge(heldUnit, padUnit) then
			local merged = Economy.merged(padUnit, heldUnit)
			data.units[onPad] = merged
			data.units[held] = nil
			Inventory.hold(player, nil)
			State.notify(player, "Merged", Figure.title(merged))
		else
			-- Swap: the held unit goes on the pad, the pad's unit into the inventory.
			data.pads[key] = held
			Inventory.hold(player, nil)
		end
	end

	drawPad(plot, pad, data)
	Inventory.sync(player)
	State.push(player)
end

-- Redraws every console of the player's dojo, and the price of the pad for sale: what they
-- can afford has changed.
local function drawConsoles(player: Player, data: Data.Data)
	local plot = Plots.of(player)
	if plot then
		local unlocked = Stats.unlockedPads(data)
		for _, pad in plot.pads do
			drawConsole(pad, data, pad.index <= unlocked)
		end
		local nextPad = plot.pads[unlocked + 1]
		if nextPad and isForSale(nextPad, data) then
			drawPrice(nextPad, data)
		end
	end
end

-- Levels up the unit standing on a pad for Ryo: by `levels`, or with none given by as many
-- levels as the player's Ryo pays for.
local function upgradePad(player: Player, plot: Plots.Plot, pad: Plots.Pad, levels: number?)
	local data = Data.get(player)
	if not data then
		return
	end
	if plot.owner ~= player then
		State.notify(player, "NotYourDojo")
		return
	end
	local unitId = data.pads[tostring(pad.index)]
	local unit = if unitId then data.units[unitId] else nil
	if not unitId or not unit then
		return
	end

	local price, bought
	if levels then
		price, bought = Economy.upgradesPrice(unit, levels)
	else
		bought, price = Economy.affordableUpgrades(unit, data.ryo)
	end
	if bought <= 0 or price <= 0 then
		return
	end
	if data.ryo < price then
		State.notify(player, "NotEnoughRyo")
		return
	end

	data.ryo -= price
	local upgraded = Economy.upgraded(unit, bought)
	data.units[unitId] = upgraded
	-- The shinobi stays where it stands and only its tag is rewritten: built anew, as the
	-- whole pad used to be on every level, it was gone for a moment each time.
	local figure = pad.figure
	if figure then
		Figure.retag(figure, upgraded)
		pad.prompt.ObjectText = Figure.title(upgraded)
	else
		drawPad(plot, pad, data)
	end
	drawConsoles(player, data)
	local payload: Net.Upgraded = {
		figure = pad.figure,
		levels = bought,
		income = Economy.unitIncome(upgraded),
	}
	Remotes.Upgraded:FireAllClients(payload)
	State.push(player)
end

-- A client says its player pressed a console button and names the part. The press counts only
-- from someone standing at that console; whose dojo it is, is checked by upgradePad.
local function pressButton(player: Player, part: unknown)
	local press = if typeof(part) == "Instance" then presses[part] else nil
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not press or not root or not root:IsA("BasePart") then
		return
	end
	local away = (root.Position - press.part.Position).Magnitude
	if away <= Net.PRESS_DISTANCE + PRESS_SLACK then
		upgradePad(player, press.plot, press.pad, press.levels)
	end
end

-- Pays out the offline income that waits in the welcome-back window, if any is left.
local function collectOffline(player: Player, data: Data.Data)
	local session = Session.of(player)
	if session.offline > 0 then
		data.ryo += session.offline
		session.offline = 0
	end
end

-- Drops pad references to units that no longer exist, so one bad save cannot break the dojo,
-- and takes units off pads the player does not have (after a change to Tuning.Dojo): they go
-- back to the inventory.
local function repair(data: Data.Data)
	local unlocked = Stats.unlockedPads(data)
	for key, unitId in data.pads do
		local index = tonumber(key)
		if not data.units[unitId] or not index or index > unlocked then
			data.pads[key] = nil
		end
	end
end

function Dojo.start()
	Plots.forEach(function(plot)
		for _, pad in plot.pads do
			pad.prompt.Triggered:Connect(function(player)
				usePad(player, plot, pad)
			end)
			local buttons = pad.buttons
			presses[buttons.one.part] =
				{ plot = plot, pad = pad, part = buttons.one.part, levels = LEVELS.one }
			presses[buttons.ten.part] =
				{ plot = plot, pad = pad, part = buttons.ten.part, levels = LEVELS.ten }
			presses[buttons.max.part] = { plot = plot, pad = pad, part = buttons.max.part }
		end
	end)
	Remotes.Upgrade.OnServerEvent:Connect(pressButton)
	Remotes.Collect.OnServerEvent:Connect(function(player)
		local data = Data.get(player)
		if data then
			collectOffline(player, data)
			drawConsoles(player, data)
			State.push(player)
		end
	end)

	Data.onLoaded(function(player, data)
		repair(data)

		if data.lastSeen > 0 then
			local away = os.time() - data.lastSeen
			local earned = Economy.offlineEarnings(Stats.income(data), away)
			if earned >= 1 and away >= WELCOME_AFTER then
				-- The Ryo wait for the player to collect them in the welcome-back window,
				-- so that the purse visibly grows when they do.
				Session.of(player).offline = earned
				local offline: Net.Offline = { earned = earned, away = away }
				Remotes.Offline:FireClient(player, offline)
			else
				data.ryo += earned
			end
		end
		data.lastSeen = os.time()

		drawPads(player)
	end)

	Data.onLeaving(function(player, data)
		-- Income nobody collected is not lost. The session is still there: Training, which
		-- clears it, registered its leave hook earlier and so runs after this one.
		collectOffline(player, data)
		local plot = Plots.of(player)
		if plot then
			for _, pad in plot.pads do
				drawPad(plot, pad, nil)
			end
		end
	end)

	-- Income tick, once a second for everyone.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = Data.get(player)
				if data then
					data.ryo += Stats.income(data)
					data.lastSeen = os.time()
					drawConsoles(player, data)
					State.push(player)
				end
			end
		end
	end)
end

return Dojo
