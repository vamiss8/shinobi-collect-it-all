--!strict
-- Makes interaction prompts keyboard-only on devices without a touch screen.
--
-- A prompt is normally also a clickable button. With the mouse locked to the screen center
-- (Shift Lock) that button ends up under the cursor as you walk up to it, and hovering a button
-- swaps the Shift Lock crosshair for the regular arrow. Touch devices keep the button, since
-- tapping it is how they activate a prompt. The change is local to this client.

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Prompts = {}

local function fix(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		instance.ClickablePrompt = false
	end
end

function Prompts.start()
	if UserInputService.TouchEnabled then
		return
	end
	Workspace.DescendantAdded:Connect(fix)
	for _, instance in Workspace:GetDescendants() do
		fix(instance)
	end
end

return Prompts
