--!strict
-- The notice board's window (owner, 2026-10-18: "a FAQ and a changelog, on the notice board
-- and in the settings, with the chances"): four pages under tabs, the questions asked often
-- and their answers, what has changed in the game (Config/Changelog), every chance the game
-- rolls, worked out from the config itself (Logic/Roll, Config/Events, Tuning), the player's
-- own mutation luck among them, and Iruka's tips (owner, 2026-10-19: "add Iruka's tips
-- somewhere, a list with names, so that all of them can be looked through again"): every tip
-- of Config/Guide under its name, those he has said in full and the rest named only, to be
-- told in their time. It opens from the prompt on the notice board on the
-- plaza (tagged Net.INFO_TAG on the server, World/Plaza) and from the settings' row "Help".
--
-- Words are cut into lines once (Ui.lines) and not left to wrap: a window is scaled as it
-- pops open, and wrapped text is fitted anew at every step of it (see Ui.note).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Changelog = require(ReplicatedStorage.Shared.Config.Changelog)
local Events = require(ReplicatedStorage.Shared.Config.Events)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Guide = require("./Guide")
local GuideConfig = require(ReplicatedStorage.Shared.Config.Guide)
local Net = require(ReplicatedStorage.Shared.Net)
local Portrait = require("./Portrait")
local Roll = require(ReplicatedStorage.Shared.Logic.Roll)
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local InfoPanel = {}

local SIZE = Vector2.new(960, 720)
local TAB = Vector2.new(216, 54)
local TAB_GAP = 14
local PAGE_TOP = 70
-- A card's width and the room its words have, layout pixels.
local CARD = 900
local ROOM = CARD - 48
local HEAD_SIZE = 24
local BODY_SIZE = 20
-- How many questions there are: FaqQ1 and FaqA1 to FaqQn and FaqAn in the packs. The last,
-- which sends a player with a question to the community server, is asked only once there is
-- one (Tuning.Social).
local QUESTIONS = 22

-- Iruka's face at the head of his tips, layout pixels. And his tips (owner, 2026-10-19: "his
-- face on every tip, as it first comes before the player, and the tips opened by their names,
-- a list that drops down"): a bar a tip with its name, and under it, when pressed, his scroll
-- unrolling as it does in the game (client Guide), his face in its red frame and his words.
local FACE = 112
local TIP_BAR = 58
local TIP_FACE = 104
local TIP_SIZE = 24
local TIP_SCROLL = CARD - 40

-- A page: "faq", "news", "chances" or "tips".
export type Page = string
local PAGES: { Page } = { "faq", "news", "chances", "tips" }
local PAGE_WORDS: { [Page]: string } = {
	faq = "InfoFaq",
	news = "InfoNews",
	chances = "InfoChances",
	tips = "InfoTips",
}

local opener: ((page: Page) -> ())? = nil

-- What matters is written in color (Ui.paint): the FAQ marks its words in the language
-- packs, and the chances mark what they work out, a mutation in its own color.
local MARKS = Ui.MARKS
-- The ink of what is not open yet.
local FADED = Color3.fromRGB(112, 100, 88)

-- A mutation's color made dark enough for parchment; a pale one (Six Paths' white) is gold.
local function inked(color: Color3): Color3
	local hue, saturation, value = color:ToHSV()
	if saturation < 0.15 then
		return Color3.fromRGB(150, 104, 16)
	end
	return Color3.fromHSV(hue, math.max(saturation, 0.6), math.min(value, 0.62))
end

-- Marks words to be written in a color.
local function mark(color: Color3, words: string): string
	return "{#" .. color:ToHex() .. "|" .. words .. "}"
end

-- A chance as a share of a hundred, to as many places as it needs to say something.
local function percent(p: number): string
	if p >= 0.1 then
		return string.format("%.1f%%", p * 100)
	elseif p >= 0.01 then
		return string.format("%.2f%%", p * 100)
	end
	return string.format("%.3f%%", p * 100)
end

-- A card of parchment on a page: a heading in its color and lines of ink under it; `faded`,
-- grayed, for what is not open yet.
local function card(
	page: ScrollingFrame,
	order: number,
	head: string,
	headColor: Color3,
	body: { string },
	faded: boolean?
)
	local sheet = Ui.make("Frame", {
		Size = UDim2.fromOffset(CARD, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Ui.PARCHMENT,
		BackgroundTransparency = if faded then 0.45 else 0,
		LayoutOrder = order,
	}, page)
	Ui.corner(sheet, 10)
	Ui.stroke(sheet, Ui.EDGE, 2)
	Ui.make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}, sheet)
	Ui.make("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 24),
		PaddingRight = UDim.new(0, 24),
	}, sheet)
	Ui.text(sheet, {
		Size = UDim2.fromOffset(ROOM, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = HEAD_SIZE,
		TextColor3 = headColor,
		LayoutOrder = 1,
		Text = Ui.lines(head, HEAD_SIZE, ROOM),
	})
	for index, words in body do
		Ui.text(sheet, {
			Size = UDim2.fromOffset(ROOM, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = BODY_SIZE,
			TextColor3 = if faded then FADED else Ui.INK,
			RichText = true,
			LayoutOrder = 1 + index,
			Text = Ui.paint(words, BODY_SIZE, ROOM),
		})
	end
end

local function clear(page: ScrollingFrame)
	for _, child in page:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function questions(page: ScrollingFrame)
	local asked = if Tuning.Social.server then QUESTIONS else QUESTIONS - 1
	for index = 1, asked do
		card(page, index, Strings.get(`FaqQ{index}`), Ui.SEAL, { Strings.get(`FaqA{index}`) })
	end
end

local function news(page: ScrollingFrame)
	for index, entry in Changelog do
		card(page, index, entry.date, Ui.SEAL, { Strings.get(`Change_{entry.key}`) })
	end
end

-- Every chance, worked out now: the player's mutation luck is the snapshot's.
local function chances(page: ScrollingFrame)
	local lines: { string } = {}
	local plain = Roll.withLuck(Roll.mutationTable(nil), 1)
	for place = #plain, 1, -1 do
		local mutation = Catalog.mutationById[plain[place].id]
		if mutation then
			table.insert(
				lines,
				Strings.get(
					"ChancesMutationLine",
					mark(inked(Color3.fromHex(mutation.color)), Strings.name(mutation.name)),
					mark(MARKS.g, tostring(mutation.multiplier)),
					mark(MARKS.r, percent(plain[place].weight))
				)
			)
		end
	end
	for _, event in Events.list do
		local mutation = Catalog.mutationById[event.mutation]
		for _, entry in Roll.withLuck(Roll.mutationTable(event.id), 1) do
			if mutation and entry.id == mutation.id then
				table.insert(
					lines,
					Strings.get(
						"ChancesEventLine",
						mark(inked(Color3.fromHex(mutation.color)), Strings.name(mutation.name)),
						mark(MARKS.b, Strings.name(event.name)),
						mark(MARKS.g, tostring(mutation.multiplier)),
						mark(MARKS.r, percent(entry.weight))
					)
				)
			end
		end
	end
	local state = Store.get()
	local luck = if state then state.multipliers.mutationLuck else 1
	table.insert(lines, Strings.get("ChancesLuckNote", mark(MARKS.g, Format.short(luck))))
	card(page, 1, Strings.get("ChancesMutations"), Ui.SEAL, lines)

	local zones = Tuning.Zones
	card(page, 2, Strings.get("ChancesRanks"), Ui.SEAL, {
		Strings.get(
			"ChancesRankLine",
			mark(MARKS.r, percent(zones.nextRankAtStart)),
			mark(MARKS.r, percent(zones.nextRankAtEnd))
		),
	})

	local lucky: { string } = {}
	local milestones = Tuning.Luck.milestones
	for index = #milestones, 1, -1 do
		local milestone = milestones[index]
		table.insert(
			lucky,
			Strings.get(
				"ChancesLuckyLine",
				mark(MARKS.b, tostring(milestone.every)),
				mark(MARKS.g, tostring(milestone.luck))
			)
		)
	end
	card(page, 3, Strings.get("ChancesLucky"), Ui.SEAL, lucky)

	local total = Events.quiet
	for _, event in Events.list do
		total += event.weight
	end
	local coming: { string } = {}
	for _, event in Events.list do
		local every = Events.slotMinutes * total / event.weight
		table.insert(
			coming,
			Strings.get(
				"ChancesEventsLine",
				mark(MARKS.b, Strings.name(event.name)),
				mark(MARKS.g, string.format("%.0f", every)),
				mark(MARKS.g, tostring(event.minutes))
			)
		)
	end
	card(page, 4, Strings.get("ChancesEvents"), Ui.SEAL, coming)
end

-- Iruka's face in a red frame, as on his card (client Guide), with `properties` of its place.
local function irukaFace(parent: Instance, properties: { [string]: any }): Frame
	local frame: Frame = Ui.make("Frame", {
		BackgroundColor3 = Ui.SEAL,
		BorderSizePixel = 0,
	}, parent)
	for key, value in properties do
		(frame :: any)[key] = value
	end
	Ui.corner(frame, 12)
	local window: Frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundColor3 = Ui.PANEL,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, frame)
	Ui.corner(window, 9)
	if not Portrait.show(window, "iruka", false, true) then
		Ui.text(window, {
			Size = UDim2.fromScale(1, 1),
			TextScaled = true,
			TextColor3 = Ui.PARCHMENT,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "I",
		})
	end
	return frame
end

-- What a tip opens to: Iruka's scroll, his face and his words, as he said them in the game;
-- for a tip not heard yet, the scroll grayed and saying it is still to come. Made when the tip
-- is first opened (each face is a copy of a model), at `order` in the page's list.
local function tipScroll(page: ScrollingFrame, order: number, heard: boolean, words: string)
	local left = if heard then 30 + TIP_FACE + 22 else 36
	local room = TIP_SCROLL - left - 36
	local painted = Ui.paint(words, TIP_SIZE, room)
	local lines = #string.split(painted, "\n")
	local tall =
		math.max(if heard then TIP_FACE + 36 else 0, 40 + lines * math.ceil(TIP_SIZE * 1.3))
	local holder: Frame = Ui.make("Frame", {
		Size = UDim2.fromOffset(CARD, tall + 26),
		BackgroundTransparency = 1,
		LayoutOrder = order,
	}, page)
	local paper = Ui.parchment(holder, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(TIP_SCROLL, tall),
		Visible = false,
	}, 0)
	paper.seal.Visible = false
	paper.edge.Color = if heard then Ui.SEAL else Ui.EDGE
	if heard then
		irukaFace(paper.page, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 30, 0.5, 0),
			Size = UDim2.fromOffset(TIP_FACE, TIP_FACE),
		})
	end
	Ui.text(paper.page, {
		Position = UDim2.fromOffset(left, 0),
		Size = UDim2.new(0, room, 1, 0),
		TextSize = TIP_SIZE,
		TextColor3 = if heard then Ui.INK else FADED,
		RichText = true,
		Text = painted,
	})
	return holder, paper
end

-- Iruka's tips: his face and a word at the head, then every tip in the order they would most
-- likely come, a bar with its name each (one still to come grayed); a press on a bar unrolls
-- his scroll under it, another rolls it away.
local function tips(page: ScrollingFrame)
	local heard = 0
	for _, tip in GuideConfig.tips do
		if Guide.heard(tip.id) then
			heard += 1
		end
	end
	local head = Ui.make("Frame", {
		Size = UDim2.fromOffset(CARD, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Ui.PARCHMENT,
		LayoutOrder = 0,
	}, page)
	Ui.corner(head, 10)
	Ui.stroke(head, Ui.SEAL, 3)
	Ui.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 20),
	}, head)
	Ui.make("UIPadding", {
		PaddingTop = UDim.new(0, 14),
		PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 20),
	}, head)
	irukaFace(head, { Size = UDim2.fromOffset(FACE, FACE), LayoutOrder = 1 })
	local room = CARD - 40 - FACE - 20
	Ui.text(head, {
		Size = UDim2.fromOffset(room, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextSize = 22,
		TextColor3 = Ui.INK,
		RichText = true,
		LayoutOrder = 2,
		Text = Ui.paint(Strings.get("TipsIntro", heard, #GuideConfig.tips), 22, room),
	})

	for index, tip in GuideConfig.tips do
		local known = Guide.heard(tip.id)
		local bar = Ui.button(page, {
			Size = UDim2.fromOffset(CARD, TIP_BAR),
			BackgroundColor3 = if known then Ui.PARCHMENT else Ui.CARD,
			LayoutOrder = index * 2,
			Text = "",
		})
		Ui.stroke(bar, if known then Ui.SEAL else Ui.EDGE, 2)
		Ui.text(bar, {
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -90, 1, 0),
			TextSize = 26,
			TextColor3 = if known then Ui.INK else Ui.MUTED,
			Text = Strings.get(`TipName_{tip.id}`),
		})
		local arrow = Ui.text(bar, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -20, 0.5, 0),
			Size = UDim2.fromOffset(40, 40),
			TextSize = 24,
			TextColor3 = if known then Ui.SEAL else Ui.MUTED,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "▼",
		})
		local opened = false
		local holder: Frame? = nil
		local scroll: Ui.Parchment? = nil
		bar.Activated:Connect(function()
			opened = not opened
			arrow.Text = if opened then "▲" else "▼"
			if opened and not holder then
				holder, scroll = tipScroll(
					page,
					index * 2 + 1,
					known,
					if known
						then Strings.get(Strings.pick(`Tip_{tip.id}`, Ui.touch()))
						else Strings.get("TipsLocked")
				)
			end
			local frame, paper = holder, scroll
			if frame and paper then
				frame.Visible = opened
				if opened then
					paper.frame.Visible = false
					Ui.unroll(paper)
				end
			end
		end)
	end
end

-- Opens the window on a page: the questions if none is said.
function InfoPanel.open(page: Page?)
	local open = opener
	if open then
		open(page or "faq")
	end
end

function InfoPanel.start()
	local window = Ui.window("Info", SIZE, true)
	window.title.Text = Strings.get("InfoTitle")
	local body = window.body

	local pages: { [Page]: ScrollingFrame } = {}
	local tabs: { [Page]: TextButton } = {}
	local built: { [Page]: boolean } = {}
	local function show(page: Page)
		for name, frame in pages do
			frame.Visible = name == page
			local tab = tabs[name]
			tab.BackgroundColor3 = if name == page then Ui.GOLD else Ui.CARD
			tab.TextColor3 = if name == page then Ui.INK else Ui.PARCHMENT
		end
		-- Built when first shown (cutting words into lines asks Roblox to measure them); the
		-- chances and the tips anew every time, the player's luck and what Iruka has said
		-- being of the moment.
		local frame = pages[page]
		if page == "chances" then
			clear(frame)
			chances(frame)
		elseif page == "tips" then
			-- Anew every time too: a tip may have been said since.
			clear(frame)
			tips(frame)
		elseif not built[page] then
			built[page] = true
			if page == "faq" then
				questions(frame)
			else
				news(frame)
			end
		end
	end
	local left = (SIZE.X - 32 - #PAGES * TAB.X - (#PAGES - 1) * TAB_GAP) / 2
	for index, page in PAGES do
		local frame = Ui.scroll(body, {
			Position = UDim2.fromOffset(0, PAGE_TOP),
			Size = UDim2.new(1, 0, 1, -PAGE_TOP),
			ScrollBarThickness = 8,
			Visible = false,
		})
		Ui.make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}, frame)
		Ui.padding(frame, 4)
		pages[page] = frame
		local tab = Ui.button(body, {
			Position = UDim2.fromOffset(left + (index - 1) * (TAB.X + TAB_GAP), 0),
			Size = UDim2.fromOffset(TAB.X, TAB.Y),
			BackgroundColor3 = Ui.CARD,
			TextSize = 26,
			Text = Strings.get(PAGE_WORDS[page]),
		})
		tab.Activated:Connect(function()
			task.spawn(show, page)
		end)
		tabs[page] = tab
	end

	opener = function(page: Page)
		window.open()
		task.spawn(show, page)
	end

	-- The notice board's prompt (World/Plaza): the window opens on its questions.
	local function hook(item: Instance)
		if item:IsA("ProximityPrompt") then
			item.Triggered:Connect(function()
				InfoPanel.open("faq")
			end)
		end
	end
	for _, item in CollectionService:GetTagged(Net.INFO_TAG) do
		hook(item)
	end
	CollectionService:GetInstanceAddedSignal(Net.INFO_TAG):Connect(hook)
end

return InfoPanel
