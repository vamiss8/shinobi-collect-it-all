--!strict
-- Opens the market's shop windows. Using a counter's prompt opens that shop's window, and a shop
-- with a keeper greets the player with a chat bubble over the keeper; walking away closes the
-- window. The windows themselves live in Stores/ and only send intents ("buy", "sell"): the
-- server checks prices and that the player really is at the counter.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Net = require(ReplicatedStorage.Shared.Net)
local SellStall = require("./Stores/SellStall")
local SpeedStore = require("./Stores/SpeedStore")
local Strings = require("./Strings")
local TentenShop = require("./Stores/TentenShop")
local Ui = require("./Ui")

local Shops = {}

-- A window closes once the player is this far from its counter, studs. Keep it below the range
-- the server accepts requests from (World/Market).
local CLOSE_DISTANCE = 16

-- What a shop's keeper may say when the shop is opened, by shop: keys of client/Strings.
local GREETINGS: { [string]: { string } } = {
	tenten = { "TentenHello1", "TentenHello2", "TentenHello3", "TentenHello4" },
	sell = { "MissionHello1", "MissionHello2", "MissionHello3", "MissionHello4" },
	speed = { "DuyHello1", "DuyHello2", "DuyHello3", "DuyHello4" },
}

local rng = Random.new()

-- A chat bubble over the keeper of the shop whose counter is `counter`, if it has one. Only
-- this player sees it.
local function greet(kind: string, counter: BasePart)
	local lines = GREETINGS[kind]
	local shop = counter.Parent
	local keeper = if shop then shop:FindFirstChild(Net.KEEPER) else nil
	local head = if keeper then keeper:FindFirstChild(Figure.TAG_ANCHOR) else nil
	if not lines or not head then
		return
	end
	local line = Strings.get(lines[rng:NextInteger(1, #lines)])
	-- Fails where bubble chat is off; the greeting is only a nicety.
	pcall(function()
		TextChatService:DisplayBubble(head, line)
	end)
end

function Shops.start()
	-- Keyed by the value of the counter prompt's shop attribute.
	local windows: { [string]: Ui.Window } = {
		tenten = TentenShop.build(),
		speed = SpeedStore.build(),
		sell = SellStall.build(),
	}

	-- The window that was opened from a counter, and that counter.
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
			greet(kind :: string, parent)
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
