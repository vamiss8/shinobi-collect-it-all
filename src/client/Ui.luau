--!strict
-- Helpers for building the UI from code.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

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
-- screen instead of shrinking into the corners. It is never drawn smaller than laid out: a
-- phone is short, and its layout is already as tight as it gets.
local DESIGN_HEIGHT = 900
local DESIGN_WIDTH = 1500
local MAX_SCALE = 2.6

local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(DESIGN_WIDTH, DESIGN_HEIGHT)
end

-- How many times larger than laid out the interface is drawn on this screen.
function Ui.scale(): number
	local view = viewport()
	return math.clamp(math.min(view.Y / DESIGN_HEIGHT, view.X / DESIGN_WIDTH), 1, MAX_SCALE)
end

-- The size of the screen as the layers see it: in layout units, before they are scaled up.
function Ui.room(): Vector2
	return viewport() / Ui.scale()
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
function Ui.screen(name: string, order: number): Frame
	local gui = Ui.make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = order,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
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
export type Parchment = { frame: Frame, edge: UIStroke, seal: Frame }

function Ui.parchment(parent: Instance, properties: { [string]: any }, sealSize: number): Parchment
	local frame = Ui.make("Frame", {
		BackgroundColor3 = Ui.PARCHMENT,
		BorderSizePixel = 0,
	}, parent)
	for name, value in properties do
		frame[name] = value
	end
	Ui.corner(frame, 4)
	local edge = Ui.stroke(frame, Ui.EDGE, 3)

	-- The rollers stand a little taller than the parchment, with a lighter knob on each end.
	for _, side in { 0, 1 } do
		local roller = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(side, 0.5),
			Size = UDim2.new(0, 24, 1, 22),
			BackgroundColor3 = ROLLER,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, frame)
		Ui.corner(roller, 12)
		for _, tip in { 0, 1 } do
			local knob = Ui.make("Frame", {
				AnchorPoint = Vector2.new(0.5, tip),
				Position = UDim2.fromScale(0.5, tip),
				Size = UDim2.fromOffset(14, 9),
				BackgroundColor3 = ROLLER_END,
				BorderSizePixel = 0,
				ZIndex = 3,
			}, roller)
			Ui.corner(knob, 4)
		end
	end

	local seal = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 28, 0.5, 0),
		Size = UDim2.fromOffset(sealSize, sealSize),
		BackgroundColor3 = Ui.SEAL,
		BorderSizePixel = 0,
	}, frame)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, seal)
	Ui.stroke(seal, Ui.INK, 2)
	return { frame = frame, edge = edge, seal = seal }
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

-- A centered window with a title bar and a close button, hidden until opened. Opening one
-- closes the others. It grows with its layer (see Ui.screen) and shrinks again if it would not
-- fit the screen.
function Ui.window(name: string, size: Vector2): Window
	local screen = Ui.screen(name, 30)
	local frame = Ui.panel(screen, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 0.04,
		Visible = false,
	})
	Ui.stroke(frame, Ui.EDGE, 2)

	local scale: UIScale = Ui.make("UIScale", {}, frame)
	Ui.onResize(function()
		local room = Ui.room()
		scale.Scale = math.min(1, (room.X - 24) / size.X, (room.Y - 24) / size.Y)
	end)

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
	local closeButton = Ui.button(frame, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(32, 32),
		BackgroundColor3 = Color3.fromRGB(198, 40, 40),
		Text = "X",
	})
	local body = Ui.make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 1, -66),
	}, frame)

	local window: Window
	window = {
		frame = frame,
		body = body,
		title = title,
		open = function()
			for _, other in windows do
				if other ~= window then
					other.frame.Visible = false
				end
			end
			frame.Visible = true
		end,
		close = function()
			frame.Visible = false
		end,
		toggle = function()
			if frame.Visible then
				window.close()
			else
				window.open()
			end
		end,
		isOpen = function()
			return frame.Visible
		end,
	}
	closeButton.Activated:Connect(window.close)
	table.insert(windows, window)
	return window
end

return Ui
