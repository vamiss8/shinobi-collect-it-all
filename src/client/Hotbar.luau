--!strict
-- The bar at the bottom of the screen, drawn by the game in place of Roblox's own backpack bar.
-- Slots 1 and 2 hold the two training tools and stand a little apart on the left, so they are
-- not taken for shinobi; slots 3 to 9 are quick slots for the shinobi in the inventory, best
-- earner first. A slot's number key, a click or a tap takes the tool out or picks the shinobi
-- up, and doing it again puts it back. Hovering a slot says what is in it.
--
-- There are only seven quick slots, so the Inventory window stays the place to see everyone.
--
-- The tools are still the Roblox Tools the server hands out (Services/Training): the server
-- learns about training from their Equipped and Unequipped events, so this bar equips and
-- unequips them and does nothing else in their place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Hud = require("./Hud")
local Icons = require("./Icons")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Ui = require("./Ui")

local Hotbar = {}

local SLOT = 68
local GAP = 6
-- The wider gap that sets the two tools apart from the shinobi.
local GROUP_GAP = 30
local QUICK_SLOTS = 7
local MARGIN = 10 -- under the bar
-- Room kept clear on either side of the bar for what sits in the bottom corners: the Chakra
-- readout on the left. The bar shrinks rather than run into it.
local CORNER_ROOM = 364
local SMALLEST = 0.55

local INK = Color3.fromRGB(58, 40, 30)

-- The training tools in slot order, by the names the server gives them.
local TOOLS: { { name: string, icon: (holder: Instance) -> () } } = {
	{ name = "Meditate", icon = Icons.meditate },
	{ name = "Chakra Control", icon = Icons.focus },
}

local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

type Slot = {
	button: TextButton,
	edge: UIStroke,
	content: Frame, -- where the icon is drawn
	stars: TextLabel, -- merge stars of the shinobi in the slot
}

local function makeSlot(parent: Instance, number: number, x: number): Slot
	local button = Ui.button(parent, {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.fromOffset(SLOT, SLOT),
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.12,
	})
	local edge = Ui.stroke(button, Ui.EDGE, 2)
	local content = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(SLOT - 12, SLOT - 12),
		BackgroundTransparency = 1,
	}, button)
	Ui.text(button, {
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.fromOffset(18, 20),
		TextSize = 17,
		TextStrokeTransparency = 0.3,
		ZIndex = 3,
		Text = tostring(number),
	})
	local stars = Ui.text(button, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 13,
		TextColor3 = Ui.GOLD,
		TextStrokeTransparency = 0.3,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})
	return { button = button, edge = edge, content = content, stars = stars }
end

-- The tool by that name and whether it is out: a tool in use sits in the character, one put
-- away in the backpack.
local function findTool(name: string): (Tool?, boolean)
	local player = Players.LocalPlayer
	local character = player.Character
	local out = if character then character:FindFirstChild(name) else nil
	if out and out:IsA("Tool") then
		return out, true
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	local stored = if backpack then backpack:FindFirstChild(name) else nil
	if stored and stored:IsA("Tool") then
		return stored, false
	end
	return nil, false
end

local function toggleTool(name: string)
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local tool, out = findTool(name)
	if not humanoid or not tool then
		return
	end
	if out then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
end

-- The ids of the shinobi that get the quick slots: the best earners, steadily ordered, so a
-- slot does not change hands every time one of them is picked up.
local function quickOrder(inventory: Net.Inventory): { string }
	local ids: { string } = {}
	for unitId in inventory do
		table.insert(ids, unitId)
	end
	table.sort(ids, function(a, b)
		local incomeA = Economy.unitIncome(inventory[a])
		local incomeB = Economy.unitIncome(inventory[b])
		if incomeA ~= incomeB then
			return incomeA > incomeB
		end
		return a < b
	end)
	return ids
end

function Hotbar.start()
	-- Roblox's own bar goes: this one takes over its keys as well. The call can fail while the
	-- core scripts are still loading, so it is tried until it takes.
	task.spawn(function()
		for _ = 1, 30 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			if ok then
				return
			end
			task.wait(0.5)
		end
	end)

	local screen = Ui.screen("Hotbar", 13)
	local width = #TOOLS * SLOT
		+ (#TOOLS - 1) * GAP
		+ GROUP_GAP
		+ QUICK_SLOTS * SLOT
		+ (QUICK_SLOTS - 1) * GAP
	local bar = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -MARGIN),
		Size = UDim2.fromOffset(width, SLOT),
		BackgroundTransparency = 1,
	}, screen)
	local fit: UIScale = Ui.make("UIScale", {}, bar)
	Ui.onResize(function()
		fit.Scale = math.clamp((Ui.room().X - 2 * CORNER_ROOM) / width, SMALLEST, 1)
	end)

	-- What a hovered slot holds, on a strip of parchment above the bar.
	local tip = Ui.text(screen, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(MARGIN + SLOT + 8)),
		Size = UDim2.fromOffset(0, 38),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Ui.PARCHMENT,
		BackgroundTransparency = 0,
		TextColor3 = INK,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	Ui.corner(tip, 6)
	Ui.stroke(tip, Ui.EDGE, 2)
	Ui.make("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
	}, tip)

	local hovered: Slot? = nil
	-- Shows the tip while the pointer is on the slot. `describe` is asked afresh every time,
	-- since what a slot holds changes.
	local function explain(slot: Slot, describe: () -> string)
		slot.button.MouseEnter:Connect(function()
			hovered = slot
			tip.Text = describe()
			tip.Visible = true
		end)
		slot.button.MouseLeave:Connect(function()
			if hovered == slot then
				hovered = nil
				tip.Visible = false
			end
		end)
	end

	-- Slots 1 and 2: the tools.
	local toolSlots: { Slot } = {}
	for index, tool in TOOLS do
		local slot = makeSlot(bar, index, (index - 1) * (SLOT + GAP))
		tool.icon(slot.content)
		slot.button.Activated:Connect(function()
			toggleTool(tool.name)
		end)
		explain(slot, function()
			local found = findTool(tool.name)
			local what = if found then found.ToolTip else ""
			return if what ~= ""
				then Strings.get("HotbarTip", string.upper(tool.name), what)
				else string.upper(tool.name)
		end)
		toolSlots[index] = slot
	end

	-- Slots 3 to 9: shinobi out of the inventory.
	local quickSlots: { Slot } = {}
	local quickUnits: { string } = {} -- unit id in each quick slot
	local quickStart = #TOOLS * SLOT + (#TOOLS - 1) * GAP + GROUP_GAP

	local function heldUnit(): string?
		local state = Store.get()
		return if state then state.held else nil
	end

	local function pickUp(index: number)
		local unitId = quickUnits[index]
		if unitId then
			Remotes.Hold:FireServer(if heldUnit() == unitId then nil else unitId)
		end
	end

	for index = 1, QUICK_SLOTS do
		local slot = makeSlot(bar, #TOOLS + index, quickStart + (index - 1) * (SLOT + GAP))
		slot.button.Activated:Connect(function()
			pickUp(index)
		end)
		explain(slot, function()
			local unit = Store.inventory()[quickUnits[index]]
			if not unit then
				return Strings.get("HotbarEmpty")
			end
			local title = Catalog.unitTitle(unit.character, unit.mutation, unit.level, unit.upgrade)
			return Strings.get(
				"HotbarTip",
				string.upper(title),
				Strings.get("CardIncome", Economy.unitIncome(unit))
			)
		end)
		quickSlots[index] = slot
	end

	-- The outline of a quick slot: gold and thick for the shinobi being carried, otherwise in
	-- the color of its mutation, or of its rank if it has none.
	local function outline(index: number)
		local slot = quickSlots[index]
		local unitId = quickUnits[index]
		local unit = if unitId then Store.inventory()[unitId] else nil
		if not unit then
			slot.edge.Color = Ui.EDGE
			slot.edge.Thickness = 2
		elseif unitId == heldUnit() then
			slot.edge.Color = Ui.GOLD
			slot.edge.Thickness = 4
		else
			local mutation = Catalog.mutationById[unit.mutation]
			slot.edge.Color = if mutation
				then Color3.fromHex(mutation.color)
				else Hud.rankColor(unit.character)
			slot.edge.Thickness = 2
		end
	end

	Store.onInventory(function(inventory)
		quickUnits = quickOrder(inventory)
		for index, slot in quickSlots do
			slot.content:ClearAllChildren()
			local unit = inventory[quickUnits[index]]
			if unit then
				Icons.shinobi(slot.content, unit.character, Hud.rankColor(unit.character))
				slot.stars.Text = Catalog.stars(unit.level)
				slot.button.BackgroundTransparency = 0.12
			else
				slot.stars.Text = ""
				slot.button.BackgroundTransparency = 0.55
			end
			outline(index)
		end
	end)

	local shownHeld: string? = nil
	Store.onChange(function(state)
		if state.held ~= shownHeld then
			shownHeld = state.held
			for index in quickSlots do
				outline(index)
			end
		end
	end)

	-- A tool that is out has a gold outline. The server puts tools away too (when the player
	-- moves, or throws), so the bar looks at where each tool is rather than at its own clicks.
	local out: { boolean } = {}
	RunService.RenderStepped:Connect(function()
		for index, tool in TOOLS do
			local _, isOut = findTool(tool.name)
			if out[index] ~= isOut then
				out[index] = isOut
				toolSlots[index].edge.Color = if isOut then Ui.GOLD else Ui.EDGE
				toolSlots[index].edge.Thickness = if isOut then 4 else 2
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local number = table.find(KEYS, input.KeyCode)
		if not number then
			return
		end
		if number <= #TOOLS then
			toggleTool(TOOLS[number].name)
		else
			pickUp(number - #TOOLS)
		end
	end)
end

return Hotbar
