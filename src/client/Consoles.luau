--!strict
-- Presses the upgrade consoles in the dojo. Their buttons are plain parts marked with
-- attributes (see World/Plots on the server): a click, a tap or the gamepad's right trigger on
-- one asks the server to buy the upgrade it stands for.
--
-- The pointer is cast into the world by hand rather than with a ClickDetector, because a
-- ClickDetector swaps the mouse cursor for a large hand while it is hovered. Here the cursor
-- never changes, with Shift Lock on or off; the button under the pointer gets an outline.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Ui = require("./Ui")

local Consoles = {}

-- How far the pointer reaches into the world, studs. The camera can be zoomed well out.
local REACH = 300

-- The console button the ray from the camera lands on, if it would buy something and the
-- player stands close enough to press it.
local function buttonUnder(ray: Ray): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not character or not root or not root:IsA("BasePart") then
		return nil
	end

	-- The player's own body, and the shinobi they carry, must not shield a button.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * REACH, params)
	local part = if hit then hit.Instance else nil
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
		Remotes.Upgrade:FireServer(button)
	end
end

function Consoles.start()
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
