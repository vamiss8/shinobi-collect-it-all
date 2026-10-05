--!strict
-- Opens the market's shop windows. Using a stall's prompt opens that stall's window; walking
-- away closes it. The windows themselves live in Stores/ and only send intents ("buy", "sell"):
-- the server checks prices and that the player really is at the stall.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ChakraStore = require("./Stores/ChakraStore")
local Net = require(ReplicatedStorage.Shared.Net)
local SellStall = require("./Stores/SellStall")
local SpeedStore = require("./Stores/SpeedStore")
local Ui = require("./Ui")

local Shops = {}

-- A window closes once the player is this far from its stall, studs. Keep it below the range
-- the server accepts requests from (World/Market).
local CLOSE_DISTANCE = 16

function Shops.start()
	-- Keyed by the value of the stall prompt's shop attribute.
	local windows: { [string]: Ui.Window } = {
		chakra = ChakraStore.build(),
		speed = SpeedStore.build(),
		sell = SellStall.build(),
	}

	-- The window that was opened from a stall, and that stall's counter.
	local openWindow: Ui.Window? = nil
	local counter: BasePart? = nil

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local kind = prompt:GetAttribute(Net.SHOP_ATTRIBUTE)
		local window = if typeof(kind) == "string" then windows[kind] else nil
		local parent = prompt.Parent
		if window and parent and parent:IsA("BasePart") then
			openWindow = window
			counter = parent
			window.open()
		end
	end)

	RunService.Heartbeat:Connect(function()
		local window, at = openWindow, counter
		if not window or not at then
			return
		end
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local away = not root
			or not root:IsA("BasePart")
			or (root.Position - at.Position).Magnitude > CLOSE_DISTANCE
		if away then
			window.close()
		end
		if away or not window.isOpen() then
			openWindow = nil
			counter = nil
		end
	end)
end

return Shops
