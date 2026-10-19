--!strict
-- The inventory window: every shinobi the player owns that is not standing on a pad. Clicking
-- one makes the character carry it, which is what pads and the Mission Desk act on; clicking
-- the carried one again, or "Put away", frees the hands.
--
-- Twins are merged here too (owner, 2026-10-19: "merge right in the inventory, and have it
-- glow there"): while the inventory offers a merge (Store.merges), its tile glows violet, the
-- window opens with a scroll at its head saying so, and Show turns to the page of merges
-- (client MergeView).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Hud = require("./Hud")
local Icons = require("./Icons")
local MergeView = require("./MergeView")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Ui = require("./Ui")
local UnitCard = require("./UnitCard")

local InventoryPanel = {}

local VIOLET = MergeView.VIOLET
-- The scroll at the head of the inventory while a merge waits, layout pixels high.
local BANNER = 78

function InventoryPanel.start()
	local window = Ui.window("Inventory", Vector2.new(770, 600), true)
	window.title.Text = Strings.get("InventoryTitle")

	local opener, counter =
		Hud.sideButton(Strings.get("InventoryButton"), Ui.GOLD, Icons.scroll, false, "inventory")
	opener.LayoutOrder = 1

	-- While a shinobi is carried, a strip above the bar of slots names it and puts it away in
	-- one click or key press, without opening the window. The bar's own tip covers it while a
	-- slot is hovered.
	local carried = Ui.panel(Ui.screen("Carried", 11), {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -86),
		Size = UDim2.fromOffset(520, 44),
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	Ui.stroke(carried, Ui.GOLD, 2)
	local carriedName = Ui.text(carried, {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -206, 1, 0),
		Font = Ui.BRUSH,
		TextSize = 22,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local stow = Ui.button(carried, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(180, 32),
		BackgroundColor3 = Ui.GRAY,
		TextSize = 19,
		Text = if UserInputService.KeyboardEnabled
			then Strings.get("CarriedPutAwayKey")
			else Strings.get("InventoryPutAway"),
	})
	local function putCarriedAway()
		Remotes.Hold:FireServer(nil)
	end
	stow.Activated:Connect(putCarriedAway)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and carried.Visible and input.KeyCode == Enum.KeyCode.G then
			putCarriedAway()
		end
	end)

	-- Two pages: the inventory, and the merges it offers.
	local listPage = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, window.body)
	local mergePage = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, window.body)

	-- The scroll that says a merge waits: parchment in a violet edge, a violet seal that
	-- breathes, and Show.
	local banner = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, BANNER),
		BackgroundColor3 = Ui.PARCHMENT,
		BorderSizePixel = 0,
		Visible = false,
	}, listPage)
	Ui.corner(banner, 10)
	Ui.stroke(banner, VIOLET, 3)
	local bannerScale: UIScale = Ui.make("UIScale", {}, banner)
	local seal = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 42, 0.5, 0),
		Size = UDim2.fromOffset(54, 54),
		BackgroundColor3 = VIOLET,
		BorderSizePixel = 0,
	}, banner)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, seal)
	Ui.stroke(seal, Ui.INK, 2)
	Ui.text(seal, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 34,
		TextColor3 = Ui.PARCHMENT,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "!",
	})
	local sealScale: UIScale = Ui.make("UIScale", {}, seal)
	TweenService:Create(
		sealScale,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.12 }
	):Play()
	Ui.text(banner, {
		Position = UDim2.fromOffset(82, 8),
		Size = UDim2.new(1, -82 - 184, 0, 36),
		TextSize = 28,
		TextColor3 = Ui.INK,
		Text = Strings.get("MergeBannerTitle"),
	})
	local bannerLine = Ui.text(banner, {
		Position = UDim2.fromOffset(82, 44),
		Size = UDim2.new(1, -82 - 184, 0, 26),
		TextSize = 21,
		TextColor3 = Ui.INK,
		TextTransparency = 0.15,
	})
	local show = Ui.button(banner, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(160, 52),
		BackgroundColor3 = VIOLET,
		TextSize = 26,
		Text = Strings.get("MergeShow"),
	})

	local head = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 1,
	}, listPage)
	local hint = Ui.text(head, {
		Size = UDim2.new(1, -200, 0, 42),
		TextSize = 19,
		TextColor3 = Ui.MUTED,
		TextWrapped = true,
		Text = Strings.get("InventoryHint"),
	})
	local putAway = Ui.button(head, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(180, 40),
		BackgroundColor3 = Ui.GRAY,
		TextSize = 20,
		Text = Strings.get("InventoryPutAway"),
		Visible = false,
	})
	putAway.Activated:Connect(function()
		Remotes.Hold:FireServer(nil)
	end)

	local list = Ui.scroll(listPage, {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 1, -52),
	})

	-- The inventory's page, with the scroll at its head while a merge waits. `fresh` when the
	-- window has just been opened: then the scroll springs up.
	local function showList(fresh: boolean)
		mergePage.Visible = false
		listPage.Visible = true
		local merges = #Store.merges()
		banner.Visible = merges > 0
		bannerLine.Text = Strings.get("MergeBannerLine", merges)
		local top = if merges > 0 then BANNER + 10 else 0
		head.Position = UDim2.fromOffset(0, top)
		list.Position = UDim2.fromOffset(0, top + 52)
		list.Size = UDim2.new(1, 0, 1, -(top + 52))
		if fresh and merges > 0 then
			bannerScale.Scale = 0.7
			TweenService:Create(
				bannerScale,
				TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
	end
	local merges = MergeView.build(mergePage, function()
		showList(false)
	end)
	local function showMerges()
		listPage.Visible = false
		mergePage.Visible = true
		merges.draw(true)
	end
	show.Activated:Connect(showMerges)

	opener.Activated:Connect(function()
		window.toggle()
		if window.isOpen() then
			showList(true)
		end
	end)

	-- The tile glows violet while a merge waits: a ring round it breathing, and its own edge
	-- turning from gold to violet and back.
	local tileEdge = opener:FindFirstChildOfClass("UIStroke")
	local halo = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 12, 1, 12),
		BackgroundTransparency = 1,
		Visible = false,
	}, opener)
	Ui.corner(halo, 14)
	local haloEdge = Ui.stroke(halo, VIOLET, 4)
	RunService.RenderStepped:Connect(function()
		if not halo.Visible then
			return
		end
		local wave = (math.sin(os.clock() * 4) + 1) / 2
		haloEdge.Transparency = 0.1 + 0.6 * (1 - wave)
		local grow = 10 + 8 * wave
		halo.Size = UDim2.new(1, grow, 1, grow)
		if tileEdge then
			tileEdge.Color = Ui.GOLD:Lerp(VIOLET, 0.35 + 0.65 * wave)
		end
	end)
	local function glow()
		local on = #Store.merges() > 0
		halo.Visible = on
		if tileEdge and not on then
			tileEdge.Color = Ui.GOLD
		end
	end
	Ui.make("UIGridLayout", {
		CellSize = UDim2.fromOffset(UnitCard.SIZE.X, UnitCard.SIZE.Y),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)
	Ui.padding(list, 3)

	local cards: { TextButton } = {}
	local shownHeld: string? = nil

	-- Rebuilds the grid: the carried unit first, then the rest from richest to poorest.
	local function redraw()
		local inventory: Net.Inventory = Store.inventory()
		local state = Store.get()
		local held = if state then state.held else nil
		shownHeld = held

		for _, card in cards do
			card:Destroy()
		end
		cards = {}

		local ids: { string } = {}
		for unitId in inventory do
			table.insert(ids, unitId)
		end
		table.sort(ids, function(a, b)
			if (a == held) ~= (b == held) then
				return a == held
			end
			local incomeA = Economy.unitIncome(inventory[a])
			local incomeB = Economy.unitIncome(inventory[b])
			if incomeA ~= incomeB then
				return incomeA > incomeB
			end
			return a < b
		end)

		-- A unit with a twin is marked as ready to merge, and says where the twin is.
		local twins = Store.twins()
		local paired = Store.paired()
		for order, unitId in ids do
			local ready = if paired[unitId]
				then Strings.get("MergeReadyPair")
				elseif twins[unitId] then Strings.get("MergeReadyWhy")
				else nil
			local card = UnitCard.build(list, inventory[unitId], true, nil, ready)
			card.LayoutOrder = order
			-- The carried one gets a thick gold outline in place of its rank-colored one.
			local outline = card:FindFirstChildOfClass("UIStroke")
			if unitId == held and outline then
				outline.Color = Ui.GOLD
				outline.Thickness = 4
			end
			card.Activated:Connect(function()
				-- Carrying is how a shinobi gets to a pad, so the window gets out of the way.
				if unitId == held then
					Remotes.Hold:FireServer(nil)
				else
					Remotes.Hold:FireServer(unitId)
					window.close()
				end
			end)
			table.insert(cards, card)
		end

		hint.Text = if #ids == 0
			then Strings.get("InventoryEmpty")
			else Strings.get("InventoryHint")
		putAway.Visible = held ~= nil
		counter.Text = tostring(#ids)
		counter.Visible = #ids > 0

		local heldUnit = if held then inventory[held] else nil
		carried.Visible = heldUnit ~= nil
		if heldUnit then
			local title = Strings.title(
				heldUnit.character,
				heldUnit.mutation,
				heldUnit.level,
				heldUnit.upgrade
			)
			carriedName.Text = Strings.get("CarriedName", title)
		end
	end

	Store.onInventory(function()
		redraw()
		glow()
		if mergePage.Visible then
			merges.draw(false)
		else
			showList(false)
		end
	end)
	Store.onChange(function(state)
		if state.held ~= shownHeld then
			redraw()
		end
	end)
end

return InventoryPanel
