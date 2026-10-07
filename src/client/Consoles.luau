--!strict
-- Presses the upgrade consoles in the dojo. Their buttons are plain parts marked with
-- attributes (see World/Plots on the server): a click, a tap or the gamepad's right trigger on
-- one asks the server to buy the upgrade it stands for.
--
-- The pointer is cast into the world by hand rather than with a ClickDetector, because a
-- ClickDetector swaps the mouse cursor for a large hand while it is hovered. Here the cursor
-- never changes, with Shift Lock on or off; the button under the pointer gets an outline.
--
-- A pressed button dips into its board. And when the server says a shinobi has been levelled
-- up (anybody's, in any dojo), it is shown here: the shinobi swells for a moment, sparks rise
-- round it and the levels it gained float up over its head with what it earns now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Particles = require(ReplicatedStorage.Shared.View.Particles)
local Remotes = require("./Remotes")
local Strings = require("./Strings")
local Ui = require("./Ui")

local Consoles = {}

-- How far the pointer reaches into the world, studs. The camera can be zoomed well out.
local REACH = 300
-- How many invisible walls a ray may pass through on its way to a button.
local SEE_THROUGH = 6
-- How far a pressed button dips into its board, studs.
local DIP = 0.12
-- A levelled-up shinobi swells by this share for this long. The words start this high over
-- its feet, in front of it, and rise this far while they fade: its tag is over its head, and
-- over the tag is the ceiling.
local SWELL = 0.14
local SWELL_SECONDS = 0.32
local WORDS_FROM = 2.4
local WORDS_RISE = 3
local WORDS_SECONDS = 1.2

-- Sparks that rise round a shinobi that has been levelled up.
local SPARKS: Particles.Layer = {
	texture = Particles.SPARKLE,
	rate = 0,
	life = { 0.5, 0.9 },
	speed = { 5, 9 },
	spread = 35,
	size = { 0.7, 0.1 },
	lift = 3,
	spin = 160,
	glow = 0.8,
	fade = 0.05,
}

-- Where each button rests, remembered at its first press: a press that comes in the middle of
-- the last one's dip must not take the dip for the button's place.
local rests: { [BasePart]: CFrame } = {}
-- The size each swelling shinobi really is, for the same reason.
local sizes: { [Model]: number } = {}

-- Dips a button into its board and lets it spring back. Only this player sees it.
local function dip(button: BasePart)
	local rest = rests[button] or button.CFrame
	rests[button] = rest
	-- A button's face looks along its front; into the board is the other way.
	local pressed = TweenService:Create(
		button,
		TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = rest * CFrame.new(0, 0, DIP) }
	)
	pressed.Completed:Once(function()
		TweenService:Create(
			button,
			TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = rest }
		):Play()
	end)
	pressed:Play()
end

-- Shows that a shinobi on a pad has been levelled up.
local function celebrate(upgrade: Net.Upgraded)
	local figure = upgrade.figure
	if not figure or not figure:IsDescendantOf(Workspace) then
		return
	end
	local feet = figure:GetPivot().Position

	-- It swells and settles back to the size it was.
	local size = sizes[figure] or figure:GetScale()
	sizes[figure] = size
	local startedAt = os.clock()
	local swelling: RBXScriptConnection
	swelling = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - startedAt) / SWELL_SECONDS
		if t < 1 and figure.Parent then
			figure:ScaleTo(size * (1 + SWELL * math.sin(math.pi * t)))
		else
			swelling:Disconnect()
			if figure.Parent then
				figure:ScaleTo(size)
			end
			sizes[figure] = nil
		end
	end)

	-- Sparks from an unseen piece at its feet, and before it the words, rising.
	local source = Instance.new("Part")
	source.Anchored = true
	source.CanCollide = false
	source.CanQuery = false
	source.CanTouch = false
	source.Transparency = 1
	source.Size = Vector3.new(3.2, 0.2, 3.2)
	source.Position = feet + Vector3.new(0, 0.4, 0)
	source.Parent = Workspace
	local sparks = Particles.emitter(SPARKS, Ui.GOLD)
	sparks.Parent = source
	sparks:Emit(16 + 3 * math.min(upgrade.levels, 10))

	local gui: BillboardGui = Ui.make("BillboardGui", {
		Size = UDim2.fromScale(10, 3.4),
		StudsOffset = Vector3.new(0, WORDS_FROM, 0),
		MaxDistance = 140,
		LightInfluence = 0,
		-- Drawn over the shinobi it is about, not hidden inside it.
		AlwaysOnTop = true,
	}, source)
	local gained = Ui.text(gui, {
		Size = UDim2.fromScale(1, 0.6),
		TextScaled = true,
		TextColor3 = Ui.GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.2,
		Text = Strings.get("UpgradeGained", upgrade.levels),
	})
	local earns = Ui.text(gui, {
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.4),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.2,
		Text = Strings.get("UpgradeEarns", upgrade.income),
	})
	local rising = TweenInfo.new(WORDS_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local risen = Vector3.new(0, WORDS_FROM + WORDS_RISE, 0)
	TweenService:Create(gui, rising, { StudsOffset = risen }):Play()
	local fading = TweenInfo.new(
		WORDS_SECONDS * 0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In,
		0,
		false,
		WORDS_SECONDS * 0.5
	)
	for _, words in { gained, earns } do
		TweenService:Create(words, fading, { TextTransparency = 1, TextStrokeTransparency = 1 })
			:Play()
	end
	task.delay(WORDS_SECONDS + 0.2, function()
		source:Destroy()
	end)
end

-- The first part the ray hits that can be seen. Invisible walls, such as those behind the
-- dojo's railings and the ramps under its stairs, stop rays as they stop players, so the ray
-- is cast again past each one it meets.
local function firstVisible(ray: Ray, ignore: { Instance }): BasePart?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	for _ = 1, SEE_THROUGH do
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * REACH, params)
		local part = if hit then hit.Instance else nil
		if not part or not part:IsA("BasePart") then
			return nil
		elseif part.Transparency < 1 or part:GetAttribute(Net.UPGRADE_ATTRIBUTE) ~= nil then
			return part
		end
		table.insert(ignore, part)
	end
	return nil
end

-- The console button the ray from the camera lands on, if it would buy something and the
-- player stands close enough to press it.
local function buttonUnder(ray: Ray): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not character or not root or not root:IsA("BasePart") then
		return nil
	end

	-- The player's own body, and the shinobi they carry, must not shield a button.
	local part = firstVisible(ray, { character })
	if
		not part
		or part:GetAttribute(Net.UPGRADE_ATTRIBUTE) == nil
		or part:GetAttribute(Net.ACTIVE_ATTRIBUTE) ~= true
		or (part.Position - root.Position).Magnitude > Net.PRESS_DISTANCE
	then
		return nil
	end
	return part
end

-- The ray through a point of the viewport, or nil while there is no camera.
local function rayThrough(point: Vector2): Ray?
	local camera = Workspace.CurrentCamera
	return if camera then camera:ViewportPointToRay(point.X, point.Y) else nil
end

local function press(ray: Ray?)
	local button = if ray then buttonUnder(ray) else nil
	if button then
		dip(button)
		Remotes.Upgrade:FireServer(button)
	end
end

function Consoles.start()
	Remotes.Upgraded.OnClientEvent:Connect(celebrate)

	-- With a mouse, the button under the pointer is outlined: the cursor itself gives no hint.
	-- Under Shift Lock the pointer is the crosshair in the middle of the screen.
	if UserInputService.MouseEnabled then
		local outline = Instance.new("SelectionBox")
		outline.LineThickness = 0.05
		outline.Color3 = Ui.WHITE
		outline.Parent = Workspace
		RunService.RenderStepped:Connect(function()
			local ray = rayThrough(UserInputService:GetMouseLocation())
			outline.Adornee = if ray then buttonUnder(ray) else nil
		end)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		-- A click that landed on a window or a HUD button is not a press on the world.
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			press(rayThrough(UserInputService:GetMouseLocation()))
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			-- A gamepad has no pointer: it presses what the middle of the screen looks at.
			local camera = Workspace.CurrentCamera
			if camera then
				press(rayThrough(camera.ViewportSize / 2))
			end
		end
	end)

	-- A tap, as opposed to a drag that turns the camera or moves the thumbstick.
	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if not processed then
			press(rayThrough(position))
		end
	end)
end

return Consoles
