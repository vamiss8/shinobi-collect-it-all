--!strict
-- The notice board's window (owner, 2026-10-18: "a FAQ and a changelog, on the notice board
-- and in the settings, with the chances"): three pages under tabs, the questions asked often
-- and their answers, what has changed in the game (Config/Changelog), and every chance the
-- game rolls, worked out from the config itself (Logic/Roll, Config/Events, Tuning), the
-- player's own mutation luck among them. It opens from the prompt on the notice board on the
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
local Net = require(ReplicatedStorage.Shared.Net)
local Roll = require(ReplicatedStorage.Shared.Logic.Roll)
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local InfoPanel = {}

local SIZE = Vector2.new(960, 720)
local TAB = Vector2.new(260, 54)
local TAB_GAP = 14
local PAGE_TOP = 70
-- A card's width and the room its words have, layout pixels.
local CARD = 900
local ROOM = CARD - 48
local HEAD_SIZE = 24
local BODY_SIZE = 20
-- How many questions there are: FaqQ1 and FaqA1 to FaqQn and FaqAn in the packs.
local QUESTIONS = 12

-- A page: "faq", "news" or "chances".
export type Page = string
local PAGES: { Page } = { "faq", "news", "chances" }
local PAGE_WORDS: { [Page]: string } = {
	faq = "InfoFaq",
	news = "InfoNews",
	chances = "InfoChances",
}

local opener: ((page: Page) -> ())? = nil

-- WHAT MATTERS IS WRITTEN IN COLOR (owner, 2026-10-18: "in How to play and Chances let the main
-- things stand out in other colors"). The words mark it themselves, `{r|...}` and the like
-- (the FAQ in the language packs), and the chances mark what they work out: red for what to
-- do and what matters, blue for where it is in the game, green for how much, gold for Chakra,
-- Ryo and Herbs, and a mutation in its own color. All are dark enough to read on parchment.
local MARKS: { [string]: Color3 } = {
	r = Color3.fromRGB(176, 32, 32),
	b = Color3.fromRGB(28, 88, 160),
	g = Color3.fromRGB(36, 118, 48),
	y = Color3.fromRGB(168, 108, 0),
}

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

-- A piece of a word and the color it is written in; a word is the pieces between two spaces.
type Piece = { text: string, color: Color3? }

local function escape(text: string): string
	return (string.gsub(text, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

-- Words with marks in them cut into lines at `size` to fit `room`, as rich text: the marks are
-- left out of what is measured, and their words colored once the lines are cut.
local function paint(text: string, size: number, room: number): string
	local pieces: { Piece } = {}
	local at = 1
	while at <= #text do
		local open = string.find(text, "{", at, true)
		if not open then
			table.insert(pieces, { text = string.sub(text, at) })
			break
		end
		if open > at then
			table.insert(pieces, { text = string.sub(text, at, open - 1) })
		end
		local key, inside, after = string.match(text, "^{([^|{}]+)|([^{}]*)}()", open)
		if key and inside and after then
			local color = MARKS[key]
			if not color and string.sub(key, 1, 1) == "#" then
				local ok, read = pcall(Color3.fromHex, key)
				color = if ok then read else nil
			end
			table.insert(pieces, { text = inside, color = color })
			at = tonumber(after) or open + 1
		else
			table.insert(pieces, { text = "{" })
			at = open + 1
		end
	end

	-- The words, each the pieces between spaces: a mark that ends inside a word ("PERFEKT}-Band")
	-- keeps the rest of the word to it.
	local words: { { Piece } } = {}
	local word: { Piece } = {}
	for _, piece in pieces do
		local index = 1
		while index <= #piece.text do
			local gapStart, gapEnd = string.find(piece.text, "%s+", index)
			if gapStart == index and gapEnd then
				if #word > 0 then
					table.insert(words, word)
					word = {}
				end
				index = gapEnd + 1
			else
				local stop = (gapStart or #piece.text + 1) - 1
				table.insert(
					word,
					{ text = string.sub(piece.text, index, stop), color = piece.color }
				)
				index = stop + 1
			end
		end
	end
	if #word > 0 then
		table.insert(words, word)
	end

	local plain: { string } = {}
	for _, each in words do
		local whole = ""
		for _, piece in each do
			whole ..= piece.text
		end
		table.insert(plain, whole)
	end
	local out: { string } = {}
	local count = 0
	for _, line in string.split(Ui.lines(table.concat(plain, " "), size, room), "\n") do
		local said: { string } = {}
		for _ in string.gmatch(line, "%S+") do
			count += 1
			local each = words[count]
			if each then
				local written = ""
				for _, piece in each do
					local color = piece.color
					written ..= if color
						then `<font color="#{color:ToHex()}">{escape(piece.text)}</font>`
						else escape(piece.text)
				end
				table.insert(said, written)
			end
		end
		table.insert(out, table.concat(said, " "))
	end
	return table.concat(out, "\n")
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

-- A card of parchment on a page: a heading in its color and lines of ink under it.
local function card(
	page: ScrollingFrame,
	order: number,
	head: string,
	headColor: Color3,
	body: { string }
)
	local sheet = Ui.make("Frame", {
		Size = UDim2.fromOffset(CARD, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Ui.PARCHMENT,
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
			TextColor3 = Ui.INK,
			RichText = true,
			LayoutOrder = 1 + index,
			Text = paint(words, BODY_SIZE, ROOM),
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
	for index = 1, QUESTIONS do
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

-- Opens the window on a page: the questions if none is said.
function InfoPanel.open(page: Page?)
	local open = opener
	if open then
		open(page or "faq")
	end
end

function InfoPanel.start()
	local window = Ui.window("Info", SIZE)
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
		-- chances anew every time, the player's luck being of the moment.
		local frame = pages[page]
		if page == "chances" then
			clear(frame)
			chances(frame)
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
