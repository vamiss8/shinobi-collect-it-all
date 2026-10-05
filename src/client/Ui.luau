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

-- A ScreenGui that survives respawns.
function Ui.screen(name: string, order: number): ScreenGui
	return Ui.make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = order,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
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
-- closes the others. It shrinks to fit small screens.
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
	local function fit()
		local camera = Workspace.CurrentCamera
		if camera then
			local view = camera.ViewportSize
			scale.Scale = math.min(1, (view.X - 24) / size.X, (view.Y - 24) / size.Y)
		end
	end
	fit()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

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
