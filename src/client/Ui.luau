--!strict
-- Helpers for building the UI from code.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Audio = require("./Audio")

local Ui = {}

-- One typeface for everything: the brush script. `FONT` is what labels and buttons get when
-- they name no font; it used to be a plain bold face for small text, and the owner asked for
-- the brush everywhere. Text drawn by Roblox itself (prompts, the hotbar) keeps its own.
Ui.BRUSH = Enum.Font.PermanentMarker
Ui.FONT = Ui.BRUSH
-- Ink and paper: warm near-black panels, wood-brown edges, parchment for titles.
Ui.PANEL = Color3.fromRGB(28, 22, 20)
Ui.CARD = Color3.fromRGB(48, 38, 33)
Ui.EDGE = Color3.fromRGB(124, 88, 64)
Ui.PARCHMENT = Color3.fromRGB(236, 220, 188)
Ui.INK = Color3.fromRGB(58, 40, 30)
Ui.SEAL = Color3.fromRGB(198, 40, 40)
Ui.WHITE = Color3.new(1, 1, 1)
Ui.MUTED = Color3.fromRGB(190, 178, 162)
Ui.GOLD = Color3.fromRGB(255, 202, 40)
Ui.BLUE = Color3.fromRGB(79, 195, 247)
Ui.GREEN = Color3.fromRGB(76, 175, 80)
Ui.GRAY = Color3.fromRGB(97, 97, 97)
Ui.RED = Color3.fromRGB(239, 83, 80)

-- Creates an instance, sets its properties and parents it last, which is the cheapest order.
function Ui.make(className: string, properties: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className :: any) :: any
	for name, value in properties do
		instance[name] = value
	end
	instance.Parent = parent
	return instance
end

-- The interface is laid out for a screen this many pixels tall and at least this wide, and
-- drawn larger on a bigger one, so that on a 1440p or 4K monitor it keeps its share of the
-- screen instead of shrinking into the corners. On a computer it is never drawn smaller than
-- laid out.
local DESIGN_HEIGHT = 900
local DESIGN_WIDTH = 1500
local MAX_SCALE = 2.6
-- A touch screen is drawn as one this tall and wide, and so smaller than laid out on a phone.
-- Drawn at its full size there (a phone is some 390 pixels tall as Roblox counts them), the
-- interface was two and a half screens high and lay on itself (the owner's tester, 2026-10-16,
-- on a phone); this gives a phone about 0.6, so that 24 pixels of writing come out as 15. Its
-- own corners are laid out apart too (client Hud): Roblox's stick and jump button are there.
local TOUCH_HEIGHT = 640
local TOUCH_WIDTH = 1100
local TOUCH_SMALLEST = 0.5

local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(DESIGN_WIDTH, DESIGN_HEIGHT)
end

-- Whether this is a touch screen with no keyboard: a phone or a tablet. Its interface is drawn
-- to a scale of its own and some of it stands elsewhere, out of the way of Roblox's stick in
-- the lower left corner and its jump button in the lower right.
function Ui.touch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- How many times larger than laid out the interface is drawn on this screen.
function Ui.scale(): number
	local view = viewport()
	if Ui.touch() then
		local fit = math.min(view.Y / TOUCH_HEIGHT, view.X / TOUCH_WIDTH)
		return math.clamp(fit, TOUCH_SMALLEST, MAX_SCALE)
	end
	return math.clamp(math.min(view.Y / DESIGN_HEIGHT, view.X / DESIGN_WIDTH), 1, MAX_SCALE)
end

-- The size of the screen as the layers see it: in layout units, before they are scaled up. A
-- layer begins under Roblox's own bar across the top, so it is that much shorter than the
-- window. (Reckoned without the bar, whatever was placed by this measure sat a bar's height
-- too low: the tiles that make way for the throw power slider ended up on the Ryo readout.)
function Ui.room(): Vector2
	local bar = GuiService:GetGuiInset()
	return (viewport() - bar) / Ui.scale()
end

local resizeListeners: { () -> () } = {}

-- Calls `fn` now, and again whenever the screen changes size.
function Ui.onResize(fn: () -> ())
	table.insert(resizeListeners, fn)
	fn()
end

do
	local function resized()
		for _, fn in resizeListeners do
			fn()
		end
	end
	local watching: RBXScriptConnection? = nil
	local function watch()
		if watching then
			watching:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		watching = if camera
			then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resized)
			else nil
		resized()
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watch)
	watch()
end

-- A layer of the interface that survives respawns. What comes back is the frame everything on
-- the layer goes into, and it is what scales the layer (see Ui.scale): it is made that many
-- times smaller than the screen and then drawn that many times larger. Its children lay
-- themselves out on a design-size screen and come out scaled as a whole, offsets from the
-- screen's edges included.
-- Marks a ScreenGui as one of the game's own layers. Roblox puts interfaces of its own into
-- PlayerGui too (the proximity prompts' "ProximityPrompts", a phone's TouchGui), which are
-- not to be touched (client Fonts).
Ui.LAYER = "ShinobiLayer"

function Ui.screen(name: string, order: number): Frame
	local gui = Ui.make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = order,
	})
	gui:SetAttribute(Ui.LAYER, true)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local root: Frame = Ui.make("Frame", {
		Name = "Layer",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, gui)
	local scale: UIScale = Ui.make("UIScale", {}, root)
	Ui.onResize(function()
		local factor = Ui.scale()
		scale.Scale = factor
		root.Size = UDim2.fromScale(1 / factor, 1 / factor)
	end)
	return root
end

function Ui.corner(parent: Instance, radius: number)
	Ui.make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

-- An outline around a frame or button.
function Ui.stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	return Ui.make("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function Ui.padding(parent: Instance, pixels: number)
	local inset = UDim.new(0, pixels)
	Ui.make("UIPadding", {
		PaddingTop = inset,
		PaddingBottom = inset,
		PaddingLeft = inset,
		PaddingRight = inset,
	}, parent)
end

function Ui.panel(parent: Instance, properties: { [string]: any }): Frame
	local frame = Ui.make("Frame", {
		BackgroundColor3 = Ui.PANEL,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, parent)
	for name, value in properties do
		frame[name] = value
	end
	Ui.corner(frame, 10)
	return frame
end

function Ui.text(parent: Instance, properties: { [string]: any }): TextLabel
	local label = Ui.make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Ui.FONT,
		TextColor3 = Ui.WHITE,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, parent)
	for name, value in properties do
		label[name] = value
	end
	return label
end

-- What a window is for, said at its top: a slip of parchment in a red outline with a round red
-- seal, the words in ink. `properties` place the slip, `wide` is how wide it is, layout pixels.
-- (It was pale small text on the dark window, which the owner could hardly read.)
--
-- THE WORDS ARE CUT INTO LINES HERE AND NOT LEFT TO WRAP. A window is scaled as it pops open
-- and text is drawn at whole sizes, so wrapped text is fitted anew at every step of the pop:
-- a word went to the next line and came back, and the owner saw the text at the top of every
-- shop "a little larger for a moment, then as it was" (2026-10-13). Lines that are cut once
-- stay as they are, whatever the scale.
Ui.NOTE_HEIGHT = 68
local NOTE_LINES = 2
local NOTE_SIZES = { 22, 21, 20, 19, 18 }
local NOTE_LEFT = 64
local NOTE_RIGHT = 14
-- Lines are cut a little short of the slip, so that a size rounded up still fits.
local NOTE_FILL = 0.96

-- The face words are measured in when they are cut into lines: the brush, unless client Fonts
-- writes this player's words in another (Ui.measureWith).
local measureFace: Font? = nil

-- How wide a line of words is at `size`, layout pixels.
local function width(text: string, size: number): number
	local face = measureFace
	if face then
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = face
		params.Size = size
		params.Width = 1e5
		local ok, bounds = pcall(function()
			return TextService:GetTextBoundsAsync(params)
		end)
		if ok then
			return bounds.X
		end
	end
	return TextService:GetTextSize(text, size, Ui.FONT, Vector2.new(1e5, 1e5)).X
end

-- Measures words in that face from now on, or in the brush for nil (client Fonts).
function Ui.measureWith(face: Font?)
	measureFace = face
end

local function cut(text: string, size: number, room: number): { string }
	local lines: { string } = {}
	local line = ""
	for word in string.gmatch(text, "%S+") do
		local longer = if line == "" then word else line .. " " .. word
		local wide = width(longer, size)
		if line ~= "" and wide > room then
			table.insert(lines, line)
			line = word
		else
			line = longer
		end
	end
	if line ~= "" then
		table.insert(lines, line)
	end
	return lines
end

function Ui.note(parent: Instance, properties: { [string]: any }, wide: number, text: string): Frame
	local sheet = Ui.make("Frame", {
		Size = UDim2.fromOffset(wide, Ui.NOTE_HEIGHT),
		BackgroundColor3 = Ui.PARCHMENT,
		BorderSizePixel = 0,
	}, parent)
	for name, value in properties do
		sheet[name] = value
	end
	Ui.corner(sheet, 8)
	Ui.stroke(sheet, Ui.SEAL, 2)
	local seal = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Ui.SEAL,
		BorderSizePixel = 0,
	}, sheet)
	Ui.corner(seal, 20)
	Ui.text(seal, {
		Size = UDim2.fromScale(1, 1),
		TextSize = 28,
		TextColor3 = Ui.PARCHMENT,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "!",
	})

	-- The largest writing at which the words take no more lines than the slip has.
	local room = (wide - NOTE_LEFT - NOTE_RIGHT) * NOTE_FILL
	local size = NOTE_SIZES[#NOTE_SIZES]
	local lines = cut(text, size, room)
	for _, try in NOTE_SIZES do
		local cutAt = cut(text, try, room)
		if #cutAt <= NOTE_LINES then
			size, lines = try, cutAt
			break
		end
	end
	Ui.text(sheet, {
		Position = UDim2.fromOffset(NOTE_LEFT, 0),
		Size = UDim2.new(1, -NOTE_LEFT - NOTE_RIGHT, 1, 0),
		TextSize = size,
		TextColor3 = Ui.INK,
		Text = table.concat(lines, "\n"),
	})
	return sheet
end

-- Words cut into lines that fit `room` layout pixels at `size`, joined by line breaks: text
-- in a window is cut once and not left to wrap (see Ui.note).
function Ui.lines(text: string, size: number, room: number): string
	return table.concat(cut(text, size, room * NOTE_FILL), "\n")
end

-- Parts of the interface the guide points at (client Guide, Config/Guide `point`), by name:
-- whoever builds one names it here.
local targets: { [string]: GuiObject } = {}

function Ui.target(name: string, object: GuiObject)
	targets[name] = object
end

function Ui.targetOf(name: string): GuiObject?
	return targets[name]
end

-- WHAT MATTERS IS WRITTEN IN COLOR (owner, 2026-10-18: "in How to play and Chances let the main
-- things stand out in other colors"). The words mark it themselves, `{r|...}` and the like
-- (the FAQ and Iruka's words in the language packs), and the chances mark what they work out: red for what to
-- do and what matters, blue for where it is in the game, green for how much, gold for Chakra,
-- Ryo and Herbs, and a mutation in its own color. All are dark enough to read on parchment.
Ui.MARKS = {
	r = Color3.fromRGB(176, 32, 32),
	b = Color3.fromRGB(28, 88, 160),
	g = Color3.fromRGB(36, 118, 48),
	y = Color3.fromRGB(168, 108, 0),
} :: { [string]: Color3 }

-- A piece of a word and the color it is written in; a word is the pieces between two spaces.
type Piece = { text: string, color: Color3? }

local function escape(text: string): string
	return (string.gsub(text, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

-- Words with marks in them cut into lines at `size` to fit `room`, as rich text: the marks are
-- left out of what is measured, and their words colored once the lines are cut.
function Ui.paint(text: string, size: number, room: number): string
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
			local color: Color3? = Ui.MARKS[key]
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

-- How a button answers the pointer: it swells a little under it, dips when pressed and springs
-- back when let go. A button that a list or a grid lays out would pull its neighbors along as
-- it dipped, so it is given a place of its own in the list and dips inside that.
local HOVERED = 1.03
local PRESSED = 0.93
local BLINK = 0.72

-- Whether a list or a grid lays the button out.
local function laidOut(button: GuiObject): boolean
	local holder = button.Parent
	return holder ~= nil and holder:FindFirstChildWhichIsA("UIGridStyleLayout") ~= nil
end

-- Makes a button answer the pointer. Only one that would do something answers: a button says
-- that it would by lighting up under the pointer (AutoButtonColor), which whoever owns it
-- switches off for one that is spent.
local function enliven(button: TextButton)
	-- In a list or a grid, a cell takes the button's place and the button fills the cell. The
	-- cell goes where the button is told to go, shows and hides with it, and goes when it
	-- goes, so that whoever made the button need not know of it.
	if laidOut(button) then
		local cell: Frame = Ui.make("Frame", {
			Name = "Cell",
			Size = button.Size,
			LayoutOrder = button.LayoutOrder,
			Visible = button.Visible,
			BackgroundTransparency = 1,
		}, button.Parent)
		button.AnchorPoint = Vector2.zero
		button.Position = UDim2.new()
		button.Size = UDim2.fromScale(1, 1)
		button.Parent = cell
		button:GetPropertyChangedSignal("LayoutOrder"):Connect(function()
			cell.LayoutOrder = button.LayoutOrder
		end)
		button:GetPropertyChangedSignal("Visible"):Connect(function()
			cell.Visible = button.Visible
		end)
		button.Destroying:Connect(function()
			task.defer(function()
				cell:Destroy()
			end)
		end)
	end
	-- It dips about its own middle, wherever it was hung from: hung from a corner, it would
	-- shrink into that corner.
	if not laidOut(button) then
		local anchor, size = button.AnchorPoint, button.Size
		local dx, dy = 0.5 - anchor.X, 0.5 - anchor.Y
		button.Position += UDim2.new(
			size.X.Scale * dx,
			size.X.Offset * dx,
			size.Y.Scale * dy,
			size.Y.Offset * dy
		)
		button.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	local scale: UIScale = Ui.make("UIScale", { Name = "Press" }, button)
	local function to(size: number, seconds: number, style: Enum.EasingStyle)
		TweenService
			:Create(
				scale,
				TweenInfo.new(seconds, style, Enum.EasingDirection.Out),
				{ Scale = size }
			)
			:Play()
	end
	-- The blink: a pale sheet over the button that fades at once. Made when first needed.
	local sheet: Frame? = nil
	local function blink()
		local frame: Frame = sheet
			or Ui.make("Frame", {
				Name = "Blink",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Ui.WHITE,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 9,
			}, button)
		if not sheet then
			Ui.corner(frame, 8)
			sheet = frame
		end
		frame.BackgroundTransparency = BLINK
		TweenService:Create(frame, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	end

	local over = false
	button.MouseEnter:Connect(function()
		over = true
		if button.AutoButtonColor and not laidOut(button) then
			to(HOVERED, 0.12, Enum.EasingStyle.Quad)
		end
	end)
	button.MouseLeave:Connect(function()
		over = false
		to(1, 0.16, Enum.EasingStyle.Quad)
	end)
	button.MouseButton1Down:Connect(function()
		if not button.AutoButtonColor then
			return
		elseif laidOut(button) then
			blink()
		else
			to(PRESSED, 0.07, Enum.EasingStyle.Quad)
		end
	end)
	button.MouseButton1Up:Connect(function()
		local rest = if over and button.AutoButtonColor and not laidOut(button) then HOVERED else 1
		to(rest, 0.26, Enum.EasingStyle.Back)
	end)
end

-- A button of Ui.button pressed some other way than by the pointer (a key, a gamepad): it
-- dips and springs back as under a click, and the press is heard, if it does something (owner,
-- 2026-10-19: "let keys 1 and 2 act as if pressed with the mouse: the animation, the sound").
function Ui.pressed(button: GuiButton)
	if not button.AutoButtonColor then
		return
	end
	local scale = button:FindFirstChild("Press")
	if scale and scale:IsA("UIScale") then
		TweenService:Create(
			scale,
			TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = PRESSED }
		):Play()
		task.delay(0.09, function()
			TweenService:Create(
				scale,
				TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end)
	end
	Audio.play("click")
end

-- Has a button spring up from small, `after` seconds from now: for a page of them that has
-- just been turned to. (It plays on the same scale a press does.)
function Ui.popIn(button: GuiObject, after: number)
	local scale = button:FindFirstChild("Press")
	if not scale or not scale:IsA("UIScale") then
		return
	end
	scale.Scale = 0.6
	task.delay(after, function()
		if scale.Parent then
			TweenService:Create(
				scale,
				TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end
	end)
end

function Ui.button(parent: Instance, properties: { [string]: any }): TextButton
	local button = Ui.make("TextButton", {
		BackgroundColor3 = Ui.GREEN,
		BorderSizePixel = 0,
		Font = Ui.FONT,
		TextColor3 = Ui.WHITE,
		TextSize = 18,
		AutoButtonColor = true,
		Text = "",
	}, parent)
	for name, value in properties do
		button[name] = value
	end
	Ui.corner(button, 8)
	enliven(button)
	-- A press of a button that does something is heard (Config/Sounds "click"); a spent one,
	-- whose colors do not answer the pointer, is not.
	button.Activated:Connect(function()
		if button.AutoButtonColor then
			Audio.play("click")
		end
	end)
	return button
end

-- A vertically scrolling area that grows with its content.
function Ui.scroll(parent: Instance, properties: { [string]: any }): ScrollingFrame
	local frame = Ui.make("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, parent)
	for name, value in properties do
		frame[name] = value
	end
	return frame
end

-- The rollers of a scroll and the lighter knobs on their ends.
local ROLLER = Color3.fromRGB(93, 64, 55)
local ROLLER_END = Color3.fromRGB(141, 98, 72)

-- A scroll to write on: parchment between two wooden rollers, with a round seal on its left.
-- Every message of the game is written on one, in ink (Ui.INK). A message's color goes to the
-- scroll's outline (`edge`) and to its seal, never to the words.
--
-- `frame` is where the scroll is: its place, its size, whether it is there at all. `page` is
-- what the words go on. Between them is the sheet, which is as wide as the scroll is unrolled
-- and hides the rest of the page: a scroll can be rolled out from its middle and rolled up
-- again (Ui.unroll, Ui.rollUp, Ui.rewrite), its rollers going with the sheet's two ends while
-- the words stay where they are written. One that is never rolled simply stands open.
-- A `small` scroll is for a single line in a narrow gap: its rollers are slimmer and stand
-- only 4 past the sheet, not 11, and its seal sits nearer the left end.
export type Parchment = {
	frame: Frame,
	page: Frame,
	edge: UIStroke,
	seal: Frame,
	sheet: Frame,
	rollers: { Frame },
	opened: NumberValue, -- how far it is unrolled, ROLLED..1
	turn: number, -- counts its rollings, so that an old one does not finish a newer one's work
}

-- How far open a rolled-up scroll is, as a share of its width: its two rollers side by side.
local ROLLED = 0.05
-- How long a scroll takes to unroll and to roll up, seconds: slow enough to be watched, quick
-- enough not to be waited for. And how long it takes to shut for a change of words.
local UNROLL_SECONDS = 0.44
local ROLL_UP_SECONDS = 0.34
local SHUT_SECONDS = 0.2

-- Lays a scroll out as one unrolled this far.
local function spread(paper: Parchment, open: number)
	local wide = math.clamp(open, ROLLED, 1)
	paper.sheet.Size = UDim2.fromScale(wide, 1)
	-- The page keeps the size of the whole scroll whatever the sheet's.
	paper.page.Size = UDim2.fromScale(1 / wide, 1)
	paper.rollers[1].Position = UDim2.fromScale(0.5 - wide / 2, 0.5)
	paper.rollers[2].Position = UDim2.fromScale(0.5 + wide / 2, 0.5)
end

-- Rolls a scroll to `open` in `seconds`, and then does `after`, unless it was rolled again
-- meanwhile.
local function roll(
	paper: Parchment,
	open: number,
	seconds: number,
	direction: Enum.EasingDirection,
	after: (() -> ())?
)
	paper.turn += 1
	local mine = paper.turn
	TweenService:Create(
		paper.opened,
		TweenInfo.new(seconds, Enum.EasingStyle.Quart, direction),
		{ Value = open }
	):Play()
	if after then
		task.delay(seconds, function()
			if paper.turn == mine then
				after()
			end
		end)
	end
end

-- Brings a scroll up: it appears rolled, its rollers together, and unrolls from its middle.
function Ui.unroll(paper: Parchment)
	if not paper.frame.Visible then
		paper.opened.Value = ROLLED
		paper.frame.Visible = true
	end
	roll(paper, 1, UNROLL_SECONDS, Enum.EasingDirection.Out)
end

-- Takes a scroll away: it rolls up to its middle and is gone.
function Ui.rollUp(paper: Parchment)
	if not paper.frame.Visible then
		return
	end
	roll(paper, ROLLED, ROLL_UP_SECONDS, Enum.EasingDirection.In, function()
		paper.frame.Visible = false
	end)
end

-- Has a scroll say something new: `write` puts the words on it. One that is up shuts first,
-- so that the words change out of sight, and opens again; one that is away just unrolls.
function Ui.rewrite(paper: Parchment, write: () -> ())
	if not paper.frame.Visible then
		write()
		Ui.unroll(paper)
		return
	end
	roll(paper, ROLLED, SHUT_SECONDS, Enum.EasingDirection.In, function()
		write()
		roll(paper, 1, UNROLL_SECONDS, Enum.EasingDirection.Out)
	end)
end

function Ui.parchment(
	parent: Instance,
	properties: { [string]: any },
	sealSize: number,
	small: boolean?
): Parchment
	local frame = Ui.make("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, parent)
	for name, value in properties do
		frame[name] = value
	end
	local sheet = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.PARCHMENT,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, frame)
	Ui.corner(sheet, 4)
	local edge = Ui.stroke(sheet, Ui.EDGE, if small then 2 else 3)
	local page = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, sheet)

	-- The rollers stand a little taller than the parchment, with a lighter knob on each end.
	local rollers: { Frame } = {}
	for _, side in { 0, 1 } do
		local roller = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(side, 0.5),
			Size = if small then UDim2.new(0, 14, 1, 8) else UDim2.new(0, 24, 1, 22),
			BackgroundColor3 = ROLLER,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, frame)
		Ui.corner(roller, if small then 7 else 12)
		table.insert(rollers, roller)
		for _, tip in { 0, 1 } do
			local knob = Ui.make("Frame", {
				AnchorPoint = Vector2.new(0.5, tip),
				Position = UDim2.fromScale(0.5, tip),
				Size = if small then UDim2.fromOffset(9, 4) else UDim2.fromOffset(14, 9),
				BackgroundColor3 = ROLLER_END,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, roller)
			Ui.corner(knob, if small then 2 else 4)
		end
	end

	local seal = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, if small then 16 else 28, 0.5, 0),
		Size = UDim2.fromOffset(sealSize, sealSize),
		BackgroundColor3 = Ui.SEAL,
		BorderSizePixel = 0,
	}, page)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, seal)
	Ui.stroke(seal, Ui.INK, 2)

	local opened: NumberValue = Ui.make("NumberValue", { Name = "Opened", Value = 1 }, frame)
	local paper: Parchment = {
		frame = frame,
		page = page,
		edge = edge,
		seal = seal,
		sheet = sheet,
		rollers = rollers,
		opened = opened,
		turn = 0,
	}
	opened.Changed:Connect(function(open: number)
		spread(paper, open)
	end)
	return paper
end

-- A round badge with a letter in it, standing in for an icon.
function Ui.badge(parent: Instance, letter: string, color: Color3, size: number): TextLabel
	local badge = Ui.text(parent, {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BackgroundTransparency = 0,
		TextColor3 = Ui.PANEL,
		TextSize = math.floor(size * 0.55),
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = letter,
	})
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, badge)
	return badge
end

export type Window = {
	frame: Frame,
	body: Frame, -- where the window's content goes
	title: TextLabel,
	open: () -> (),
	close: () -> (),
	toggle: () -> (),
	isOpen: () -> boolean,
}

local windows: { Window } = {}
local windowsByName: { [string]: Window } = {}

-- A window by the name it was made with (client Guide waits on one being opened and shut).
function Ui.windowNamed(name: string): Window?
	return windowsByName[name]
end
-- What takes each window off the screen at once, for when another opens over it.
local hiders: { [Window]: () -> () } = {}
local openedListeners: { () -> () } = {}

-- A window pops up from a little under its size, springing a little past it, and shrinks a
-- little as it goes: how far under, and how long each takes, seconds. Everything in a window
-- is scaled through the pop, so TEXT IN A WINDOW IS NOT LEFT TO WRAP where it can be helped
-- (see Ui.note).
local POP_FROM = 0.86
local POP_SECONDS = 0.24
local SHUT_TO = 0.92
local SHUT_WINDOW_SECONDS = 0.11
-- A WINDOW IS DRAWN OUT OF SIGHT BEFORE IT POPS. Text is drawn anew a frame after the scale it
-- is under has changed: a window that was hidden at its full size and shown at 0.86 of it had,
-- for its first frame, a small frame with its words still full size, which the owner saw in
-- every shop as text "larger for an instant than it is" (2026-10-13; cutting the hint's lines
-- and taking the spring out had not cured it). So a hidden window waits at the size its pop
-- begins from, and when opened is shown for these frames far below the screen, where its text
-- is drawn at that size, and only then put in its place to pop.
local OUT_OF_SIGHT = UDim2.fromScale(0.5, 4)
local IN_PLACE = UDim2.fromScale(0.5, 0.5)
local FRAMES_OUT_OF_SIGHT = 2

-- Has `fn` called whenever a window is opened: for what has to make way for one.
function Ui.onWindowOpened(fn: () -> ())
	table.insert(openedListeners, fn)
end

-- Whether any window is open: the player is reading one, and is not to have the world taken
-- from behind it.
function Ui.windowOpen(): boolean
	for _, window in windows do
		if window.isOpen() then
			return true
		end
	end
	return false
end

-- ON A PHONE A WINDOW IS DRAWN LARGER THAN IT FITS, AND SCROLLS (owner, 2026-10-19: "let us
-- start on the phone"). Fitted whole to a phone's screen, a window was drawn at less than half
-- its size, and its words could not be read. On a touch screen it is drawn at least
-- TOUCH_LOOK times its layout size on the screen (as wide as the screen lets it), and as tall
-- as the screen is; what does not fit under that scrolls. A window `flexible` in its height
-- (its lists are laid by the body's height: the inventory, the Bingo Book, the notice board,
-- Awards, the shop, the Mission Desk) is laid out in the height there is, no less than
-- SHORTEST, so that its list is shorter and the window itself does not scroll.
local TOUCH_LOOK = 0.75
local SHORTEST = 300
-- The title bar over a window's body, and the margin under it, layout pixels.
local BODY_TOP = 52
local BODY_FOOT = 14

-- A centered window with a title bar and a close button, hidden until opened. Opening one
-- closes the others. It grows with its layer (see Ui.screen) and shrinks again if it would not
-- fit the screen; on a phone, see TOUCH_LOOK.
function Ui.window(name: string, size: Vector2, flexible: boolean?): Window
	local screen = Ui.screen(name, 30)
	local frame = Ui.panel(screen, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 0.04,
		Visible = false,
	})
	Ui.stroke(frame, Ui.EDGE, 2)

	-- `fit` is how large the window is drawn to fit the screen; popping open and shutting
	-- play on top of it.
	local scale: UIScale = Ui.make("UIScale", {}, frame)
	local fit = 1
	-- The body stands in a frame that scrolls: on a phone a window may be taller than the
	-- screen (see TOUCH_LOOK); elsewhere the body fits it exactly and nothing scrolls.
	local inner = size.Y - BODY_TOP - BODY_FOOT
	local scroller: ScrollingFrame = Ui.make("ScrollingFrame", {
		Position = UDim2.fromOffset(16, BODY_TOP),
		Size = UDim2.new(1, -32, 1, -(BODY_TOP + BODY_FOOT)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = Ui.EDGE,
		CanvasSize = UDim2.new(1, 0, 0, inner),
		ScrollingEnabled = false,
	}, frame)
	Ui.onResize(function()
		local room = Ui.room()
		local tall = size.Y
		if Ui.touch() then
			fit = math.min(math.max(1, TOUCH_LOOK / Ui.scale()), (room.X - 16) / size.X)
			tall = math.min(size.Y, (room.Y - 16) / fit)
		else
			fit = math.min(1, (room.X - 24) / size.X, (room.Y - 24) / size.Y)
		end
		frame.Size = UDim2.fromOffset(size.X, tall)
		local seen = tall - BODY_TOP - BODY_FOOT
		local laid = if flexible then math.max(seen, math.min(SHORTEST, inner)) else inner
		local scrolls = laid > seen + 0.5
		scroller.CanvasSize = UDim2.new(1, 0, 0, laid)
		scroller.ScrollingEnabled = scrolls
		scroller.ScrollBarThickness = if scrolls then 6 else 0
		scale.Scale = if frame.Visible then fit else fit * POP_FROM
	end)
	-- Whether the window is open, as whoever asks should hear it: one that is shutting is
	-- still on the screen and already closed. `turn` counts openings and closings, so that
	-- a shutting window that was opened again is not taken away.
	local open = false
	local turn = 0

	local title = Ui.text(frame, {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -70, 0, 32),
		Font = Ui.BRUSH,
		TextSize = 26,
		TextColor3 = Ui.PARCHMENT,
	})
	-- A red brush stroke under the title.
	Ui.make("Frame", {
		Position = UDim2.fromOffset(16, 42),
		Size = UDim2.new(1, -80, 0, 3),
		BackgroundColor3 = Ui.SEAL,
		BorderSizePixel = 0,
	}, frame)
	-- Larger under a finger.
	local cross = if Ui.touch() then 42 else 32
	local closeButton = Ui.button(frame, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, if Ui.touch() then 4 else 10),
		Size = UDim2.fromOffset(cross, cross),
		BackgroundColor3 = Color3.fromRGB(198, 40, 40),
		TextSize = if Ui.touch() then 24 else 18,
		Text = "X",
	})
	-- The body is as tall as the canvas it stands on (see `scroller`).
	local body = Ui.make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, scroller)

	local window: Window
	window = {
		frame = frame,
		body = body,
		title = title,
		open = function()
			for _, other in windows do
				if other ~= window then
					hiders[other]()
				end
			end
			turn += 1
			if not open then
				open = true
				Audio.play("window")
				local mine = turn
				local function pop()
					frame.Position = IN_PLACE
					TweenService
						:Create(
							scale,
							TweenInfo.new(
								POP_SECONDS,
								Enum.EasingStyle.Back,
								Enum.EasingDirection.Out
							),
							{ Scale = fit }
						)
						:Play()
				end
				if frame.Visible then
					-- Opened again while it was shutting: it is on the screen, and pops from
					-- where it has got to.
					pop()
				else
					scale.Scale = fit * POP_FROM
					frame.Position = OUT_OF_SIGHT
					frame.Visible = true
					task.spawn(function()
						for _ = 1, FRAMES_OUT_OF_SIGHT do
							RunService.RenderStepped:Wait()
						end
						if turn == mine and open then
							pop()
						end
					end)
				end
			end
			for _, fn in openedListeners do
				fn()
			end
		end,
		close = function()
			if not open then
				return
			end
			open = false
			turn += 1
			local mine = turn
			TweenService:Create(
				scale,
				TweenInfo.new(SHUT_WINDOW_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Scale = fit * SHUT_TO }
			):Play()
			task.delay(SHUT_WINDOW_SECONDS, function()
				if turn == mine then
					frame.Visible = false
					frame.Position = IN_PLACE
					scale.Scale = fit * POP_FROM
				end
			end)
		end,
		toggle = function()
			if open then
				window.close()
			else
				window.open()
			end
		end,
		isOpen = function()
			return open
		end,
	}
	hiders[window] = function()
		open = false
		turn += 1
		frame.Visible = false
		frame.Position = IN_PLACE
		scale.Scale = fit * POP_FROM
	end
	closeButton.Activated:Connect(window.close)
	table.insert(windows, window)
	windowsByName[name] = window
	return window
end

-- A TIP: a slip of parchment with ink that comes up beside a thing while the pointer is on it,
-- as the bar of slots' tips do (owner, 2026-10-18: "hints on hover, as with Meditate and Chakra
-- Control, on Herbs, Ryo and Chakra too, and on the player's buttons"). `describe` is asked each
-- time it comes up, since what a thing says can change. A thing inside another that has a tip
-- of its own (the Herbs' chip in the Ryo readout) covers the outer one while the pointer is on
-- it. It stands over the thing, or under it near the top of the screen, and opens from the
-- thing's side nearer the screen's edge. The pointer only: a touch screen has none.
local TIP_WIDEST = 440
type Tipped = { target: GuiObject, describe: () -> string }
local tipLabel: TextLabel? = nil
local tipped: { Tipped } = {}

-- Whether a thing is on the screen: it and every frame it stands in shown, its layer on.
local function shown(target: GuiObject): boolean
	local at: Instance? = target
	while at do
		if at:IsA("LayerCollector") then
			return (at :: LayerCollector).Enabled
		elseif at:IsA("GuiObject") and not (at :: GuiObject).Visible then
			return false
		end
		at = at.Parent
	end
	return false
end

local function placeTip()
	local label = tipLabel
	if not label then
		return
	end
	local top = tipped[#tipped]
	if not top then
		label.Visible = false
		return
	end
	local scale = Ui.scale()
	local at = top.target.AbsolutePosition / scale
	local size = top.target.AbsoluteSize / scale
	local above = at.Y > 80
	local fromLeft = at.X + size.X / 2 < Ui.room().X / 2
	label.AnchorPoint = Vector2.new(if fromLeft then 0 else 1, if above then 1 else 0)
	label.Position = UDim2.fromOffset(
		if fromLeft then at.X else at.X + size.X,
		if above then at.Y - 8 else at.Y + size.Y + 8
	)
	label.Text = top.describe()
	label.Visible = true
end

function Ui.tip(target: GuiObject, describe: () -> string)
	if not tipLabel then
		local layer = Ui.screen("Tips", 60)
		local label = Ui.text(layer, {
			Size = UDim2.new(),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Ui.PARCHMENT,
			BackgroundTransparency = 0,
			TextColor3 = Ui.INK,
			TextSize = 20,
			TextWrapped = true,
			Visible = false,
		})
		Ui.make("UISizeConstraint", { MaxSize = Vector2.new(TIP_WIDEST, math.huge) }, label)
		Ui.corner(label, 6)
		Ui.stroke(label, Ui.EDGE, 2)
		Ui.make("UIPadding", {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}, label)
		tipLabel = label
		-- A tip goes when its thing leaves the screen under the pointer (a window shut).
		RunService.Heartbeat:Connect(function()
			if label.Visible then
				local top = tipped[#tipped]
				if top and not shown(top.target) then
					table.remove(tipped)
					placeTip()
				end
			end
		end)
	end
	local entry: Tipped = { target = target, describe = describe }
	local function drop()
		local index = table.find(tipped, entry)
		if index then
			table.remove(tipped, index)
		end
	end
	target.MouseEnter:Connect(function()
		drop()
		table.insert(tipped, entry)
		placeTip()
	end)
	target.MouseLeave:Connect(function()
		drop()
		placeTip()
	end)
end

-- Writes the tip under the pointer anew, for a thing whose words changed while it is pointed at
-- (a switch just pressed).
function Ui.retip()
	if tipLabel and tipLabel.Visible then
		placeTip()
	end
end

return Ui
