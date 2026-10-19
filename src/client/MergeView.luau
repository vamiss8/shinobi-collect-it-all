--!strict
-- The inventory window's page of merges (owner, 2026-10-19: "merge right in the inventory, and
-- have it glow there too: on opening, 'you are ready to merge', and on pressing, the choices,
-- like Madara + Madara = Madara with a star and the level"). A row of parchment for every merge
-- the inventory offers (Store.merges, Economy.mergeOptions): the two shinobi, an ink plus
-- between them, an equals sign over what the merge multiplies the income by, what they become
-- with its income, and a Merge button; at the head Back and Merge all. A press draws the two
-- into what they become, and then asks the server (Services/Dojo onMerge); the page is drawn
-- anew from the inventory it sends back.
--
-- A row offers the two least levelled of its kind (Economy.mergeOptions), and a round ⇄ on a
-- chip of the inventory picks another of the kind in its place (owner, 2026-10-19: "with
-- Minato at Lvl 1, 5 and 40 show 1 + 5 = 5, and let the player change it to 1 + 40 = 40").

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Icons = require("./Icons")
local Lettering = require("./Lettering")
local Looks = require(ReplicatedStorage.Shared.Config.Lettering)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local MergeView = {}

-- Gold for a shinobi standing on a pad: its outline, the plate under it and the words over it.
local ON_PAD = Color3.fromRGB(214, 168, 40)

-- The color of a merge, as the glow of a twin on its pad (client MergeGlow) and the notice on
-- the run home (client TwinNotice).
MergeView.VIOLET = Color3.fromRGB(178, 112, 255)
local VIOLET = MergeView.VIOLET

-- A row, layout pixels: its height, where the chips stand in it and how large they are, and
-- where each part of it begins along it.
local ROW = 142
local CHIP = Vector2.new(160, 96)
local CAPTION_TOP = 6
local CHIP_TOP = 30
local A_X = 10
local PLUS_X, PLUS_WIDE = 172, 30
local B_X = 204
local EQUALS_X, EQUALS_WIDE = 366, 50
local RESULT_X, RESULT_WIDE = 418, 172
local BUTTON_X = 600
-- How long the two shinobi take to fly into what they become, seconds.
local FLY_SECONDS = 0.28
-- The head of the page: its height and where the rows begin.
local HEAD = 46
local ROWS_TOP = 56

export type View = {
	draw: (pop: boolean) -> (),
}

type Chip = { frame: Frame, scale: UIScale }
-- What a row is made of, for the flight of its two into what they become.
type Row = { sheet: Frame, a: Chip, b: Chip, result: Chip }

-- A small card of one shinobi: its photograph, name, mutation, and its level with its stars.
-- `outline` is for what a merge makes; others are outlined in their rank's color.
local function chip(
	parent: Instance,
	unit: Economy.Unit,
	x: number,
	width: number,
	outline: Color3?,
	badged: boolean?,
	onPad: boolean?
): Chip
	local rank = Catalog.rankOf(unit.character)
	local rankColor = if rank then Color3.fromHex(rank.color) else Ui.WHITE
	local character = Catalog.characterById[unit.character]
	local mutation = Catalog.mutationById[unit.mutation]

	local frame: Frame = Ui.make("Frame", {
		Position = UDim2.fromOffset(x, CHIP_TOP),
		Size = UDim2.fromOffset(width, CHIP.Y),
		BackgroundColor3 = Ui.CARD,
		BorderSizePixel = 0,
	}, parent)
	Ui.corner(frame, 8)
	Ui.stroke(frame, outline or (if onPad then ON_PAD else rankColor), if outline then 4 else 3)
	-- One standing on a pad is drawn standing on one: a plate of gold under it (owner,
	-- 2026-10-19: "mark the one on the pad as currently on pad").
	if onPad then
		local plate = Ui.make("Frame", {
			Position = UDim2.new(0, -4, 1, 3),
			Size = UDim2.new(1, 8, 0, 8),
			BackgroundColor3 = ON_PAD,
			BorderSizePixel = 0,
		}, frame)
		Ui.corner(plate, 4)
		Ui.stroke(plate, Ui.INK, 1)
	end
	local scale: UIScale = Ui.make("UIScale", {}, frame)

	local portrait = Ui.make("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.fromOffset(54, 54),
		BackgroundColor3 = Ui.PANEL,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, frame)
	Ui.corner(portrait, 6)
	Icons.shinobi(portrait, unit.character, rankColor)

	local name = Ui.text(frame, {
		Position = UDim2.fromOffset(66, 4),
		Size = UDim2.new(1, if badged then -88 else -72, 0, 36),
		TextScaled = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = if character then Strings.name(character.name) else unit.character,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 19, MinTextSize = 12 }, name)
	if mutation then
		local words = Ui.text(frame, {
			Position = UDim2.fromOffset(66, 42),
			Size = UDim2.new(1, -72, 0, 18),
			TextSize = 16,
			TextColor3 = Color3.fromHex(mutation.color),
			Text = Strings.upper(Strings.name(mutation.name)),
		})
		Lettering.dress(words, Looks.key("mutation", mutation.id))
	end

	local level = Strings.get("CardLevel", (unit.upgrade or 0) + 1)
	if unit.level > 1 then
		level ..= " " .. Catalog.stars(unit.level)
	end
	local line = Ui.text(frame, {
		Position = UDim2.new(0, 6, 1, -30),
		Size = UDim2.new(1, -12, 0, 26),
		TextScaled = true,
		TextColor3 = if outline then Ui.GOLD else Ui.WHITE,
		Text = level,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 21 }, line)
	return { frame = frame, scale = scale }
end

-- A line of ink over a chip: where it is, or what it becomes.
local function caption(parent: Instance, x: number, width: number, text: string, color: Color3?)
	Ui.text(parent, {
		Position = UDim2.fromOffset(x + 2, CAPTION_TOP),
		Size = UDim2.fromOffset(width - 4, 22),
		TextSize = 19,
		TextColor3 = color or Ui.INK,
		Text = text,
	})
end

-- A sign of ink between the chips.
local function sign(parent: Instance, x: number, width: number, text: string)
	Ui.text(parent, {
		Position = UDim2.fromOffset(x, CHIP_TOP + 14),
		Size = UDim2.fromOffset(width, 40),
		TextSize = 40,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = text,
	})
end

-- The next of `choices` after `current`, round the end, that is neither it nor `avoid`; itself
-- when there is no other.
local function another(choices: { string }, current: string, avoid: string?): string
	local at = table.find(choices, current) or 0
	for step = 1, #choices do
		local candidate = choices[(at + step - 1) % #choices + 1]
		if candidate ~= current and candidate ~= avoid then
			return candidate
		end
	end
	return current
end

-- Builds the page in `page` (the inventory window's body, under its other page). `back` shows
-- the inventory again; it is also what happens when the last merge is made.
function MergeView.build(page: Frame, back: () -> ()): View
	local head = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 0, HEAD),
		BackgroundTransparency = 1,
	}, page)
	local backButton = Ui.button(head, {
		Size = UDim2.fromOffset(140, HEAD - 2),
		BackgroundColor3 = Ui.GRAY,
		TextSize = 22,
		Text = Strings.get("MergeBack"),
	})
	Ui.text(head, {
		Position = UDim2.fromOffset(150, 0),
		Size = UDim2.new(1, -370, 1, 0),
		TextSize = 28,
		TextColor3 = VIOLET,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("MergeTitle"),
	})
	local allButton = Ui.button(head, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(210, HEAD - 2),
		BackgroundColor3 = VIOLET,
		TextSize = 22,
		Text = Strings.get("MergeAll"),
	})

	local list = Ui.scroll(page, {
		Position = UDim2.fromOffset(0, ROWS_TOP),
		Size = UDim2.new(1, 0, 1, -ROWS_TOP),
	})
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, list)
	Ui.padding(list, 3)

	local rows: { Row } = {}
	-- A merge asked for and not answered yet: no other press until the inventory comes back.
	local waiting = false

	-- The two of a row fly into what they become, and it swells to meet them.
	local function fly(row: Row)
		local into = UDim2.fromOffset(RESULT_X + (RESULT_WIDE - CHIP.X) / 2, CHIP_TOP)
		local info = TweenInfo.new(FLY_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, part in { row.a, row.b } do
			TweenService:Create(part.frame, info, { Position = into }):Play()
			TweenService:Create(part.scale, info, { Scale = 0.25 }):Play()
		end
		TweenService:Create(
			row.result.scale,
			TweenInfo.new(FLY_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1.12 }
		):Play()
	end

	local function ask(...: any)
		waiting = true
		local asked = table.pack(...)
		task.delay(FLY_SECONDS, function()
			Remotes.Merge:FireServer(table.unpack(asked, 1, asked.n))
		end)
	end

	local function draw(pop: boolean)
		for _, row in rows do
			row.sheet:Destroy()
		end
		rows = {}
		waiting = false

		local options = Store.merges()
		if #options == 0 then
			back()
			return
		end
		local inventory = Store.inventory()
		local onPads = Store.onPads()
		for order, option in options do
			local padUnit = if option.pad then onPads[tostring(option.pad)] else nil
			-- Which of the kind are merged: those offered, the two least levelled, until the
			-- player picks others.
			local pickA: string = option.unit
			local pickB: string? = option.other
			if not inventory[pickA] or (pickB and not inventory[pickB]) then
				continue
			end
			if option.pad and not padUnit then
				continue
			end

			local sheet: Frame = Ui.make("Frame", {
				Size = UDim2.new(1, -10, 0, ROW),
				BackgroundColor3 = Ui.PARCHMENT,
				BorderSizePixel = 0,
				LayoutOrder = order,
			}, list)
			Ui.corner(sheet, 10)
			Ui.stroke(sheet, VIOLET, 2)

			caption(sheet, A_X, CHIP.X, Strings.get("MergeInInventory"))
			if option.pad then
				-- Said in gold, and over the equals sign's room as well: the words are longer.
				caption(sheet, B_X, RESULT_X - B_X - 6, Strings.get("MergeOnPad"), Ui.MARKS.y)
			else
				caption(sheet, B_X, CHIP.X, Strings.get("MergeInInventory"))
			end
			sign(sheet, PLUS_X, PLUS_WIDE, "+")
			sign(sheet, EQUALS_X, EQUALS_WIDE, "=")
			-- What a merge multiplies the income by, under the equals sign.
			Ui.text(sheet, {
				Position = UDim2.fromOffset(EQUALS_X - 6, CHIP_TOP + 58),
				Size = UDim2.fromOffset(EQUALS_WIDE + 12, 26),
				TextSize = 22,
				TextColor3 = Ui.MARKS.g,
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = Strings.get("MergeGain", Tuning.Dojo.mergeMultiplier),
			})
			caption(sheet, RESULT_X, RESULT_WIDE, Strings.get("MergeBecomes"), VIOLET)
			-- And what it will earn, at the right of the same line.
			local earns = Ui.text(sheet, {
				Position = UDim2.fromOffset(RESULT_X + 2, CAPTION_TOP),
				Size = UDim2.fromOffset(RESULT_WIDE - 4, 22),
				TextSize = 19,
				TextColor3 = Ui.MARKS.g,
				TextXAlignment = Enum.TextXAlignment.Right,
			})

			local button = Ui.button(sheet, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromOffset(BUTTON_X, CHIP_TOP + CHIP.Y / 2),
				Size = UDim2.new(1, -(BUTTON_X + 10), 0, 60),
				BackgroundColor3 = VIOLET,
				TextSize = 24,
				Text = Strings.get("MergeButton"),
			})
			-- More than one pair of the kind: how many, over the Merge button, clear of the
			-- income (owner, 2026-10-19: "x2 covers the numbers, a little right and up").
			if option.count > 1 then
				local times = Ui.text(sheet, {
					Position = UDim2.fromOffset(RESULT_X + RESULT_WIDE + 10, 8),
					Size = UDim2.fromOffset(44, 28),
					BackgroundColor3 = VIOLET,
					BackgroundTransparency = 0,
					TextSize = 18,
					TextColor3 = Ui.WHITE,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 3,
					Text = `x{option.count}`,
				})
				Ui.corner(times, 13)
				Ui.stroke(times, Ui.INK, 2)
			end

			-- How many others of the kind a chip could take in its place: all but those
			-- picked.
			local function spare(): number
				return #option.choices - (if pickB then 2 else 1)
			end
			local refill: () -> ()
			-- A round ⇄ in a chip's top right corner that picks another of the kind for it.
			local function swapper(part: Chip, isA: boolean)
				local badge = Ui.button(part.frame, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(1, -16, 0, 8),
					Size = UDim2.fromOffset(30, 30),
					BackgroundColor3 = VIOLET,
					TextSize = 20,
					ZIndex = 4,
					Text = "⇄",
				})
				local round = badge:FindFirstChildOfClass("UICorner")
				if round then
					round.CornerRadius = UDim.new(0.5, 0)
				end
				Ui.stroke(badge, Ui.INK, 2)
				Ui.tip(badge, function()
					return Strings.get("MergeSwap")
				end)
				badge.Activated:Connect(function()
					if waiting then
						return
					end
					if isA then
						pickA = another(option.choices, pickA, pickB)
					else
						local current = pickB
						if current then
							pickB = another(option.choices, current, pickA)
						end
					end
					refill()
				end)
			end
			-- The row's three chips for what is picked now.
			local function chips(): (Chip, Chip, Chip)
				local unitA = inventory[pickA]
				local pickedB = pickB
				local unitB = if pickedB then inventory[pickedB] else padUnit :: Economy.Unit
				local result = Economy.merged(unitB, unitA)
				local swappable = spare() > 0
				local a = chip(sheet, unitA, A_X, CHIP.X, nil, swappable)
				local b = chip(
					sheet,
					unitB,
					B_X,
					CHIP.X,
					nil,
					swappable and pickedB ~= nil,
					pickedB == nil
				)
				earns.Text = Strings.get("CardIncome", Economy.unitIncome(result))
				-- Made after the two, so that they fly in under it.
				local made = chip(sheet, result, RESULT_X, RESULT_WIDE, VIOLET)
				if swappable then
					swapper(a, true)
					if pickedB then
						swapper(b, false)
					end
				end
				return a, b, made
			end

			local a, b, result = chips()
			local row: Row = { sheet = sheet, a = a, b = b, result = result }
			table.insert(rows, row)
			refill = function()
				row.a.frame:Destroy()
				row.b.frame:Destroy()
				row.result.frame:Destroy()
				row.a, row.b, row.result = chips()
				-- What changed springs up.
				for _, part in { row.a, row.b, row.result } do
					part.scale.Scale = 0.85
					TweenService:Create(
						part.scale,
						TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
						{ Scale = 1 }
					):Play()
				end
			end
			button.Activated:Connect(function()
				if waiting then
					return
				end
				fly(row)
				ask(pickA, pickB or option.pad)
			end)

			-- A page opened anew comes in as a wave, row after row.
			if pop then
				for index, part in { a, b, result } do
					part.scale.Scale = 0.6
					task.delay(order * 0.05 + index * 0.04, function()
						if part.frame.Parent then
							TweenService
								:Create(
									part.scale,
									TweenInfo.new(
										0.26,
										Enum.EasingStyle.Back,
										Enum.EasingDirection.Out
									),
									{ Scale = 1 }
								)
								:Play()
						end
					end)
				end
			end
		end
		list.CanvasPosition = Vector2.zero
	end

	backButton.Activated:Connect(back)
	allButton.Activated:Connect(function()
		if waiting then
			return
		end
		for _, row in rows do
			fly(row)
		end
		ask("*")
	end)

	return { draw = draw }
end

return MergeView
