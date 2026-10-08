--!strict
-- Opens the market's shop windows. Using a counter's prompt opens that shop's window; walking
-- away closes it. The windows themselves live in Stores/ and only send intents ("buy", "sell"):
-- the server checks prices and that the player really is at the counter.
--
-- A shop's keeper speaks to whoever comes up to the counter, before the shop is opened: a
-- scroll over the counter (client Speech) says what the shop is for and, under it, something
-- of the keeper's own. It is said once for each time the player comes up, stays a few seconds
-- and goes when the shop is opened: a window covers the middle of the screen, and words said
-- at the opening were said behind it.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local SellStall = require("./Stores/SellStall")
local Speech = require("./Speech")
local SpeedStore = require("./Stores/SpeedStore")
local Strings = require("./Strings")
local TentenShop = require("./Stores/TentenShop")
local Ui = require("./Ui")

local Shops = {}

-- A window closes once the player is this far from its counter, studs. Keep it below the range
-- the server accepts requests from (World/Market).
local CLOSE_DISTANCE = 16
-- A keeper speaks to a player who comes this near the counter, and is ready to speak again once
-- they have gone this far off, studs. What is said stays up this long, seconds.
local SPEAK_WITHIN = 22
local SPEAK_AGAIN = 34
local SPEAK_SECONDS = 8
-- How high over the middle of a counter the middle of the keeper's words hangs, studs: the
-- scroll's foot is then just over the keeper's head (a keeper's crown is 4.6 over the middle
-- of the counter, the scroll is 7.2 tall), and the scroll itself before the shop's eaves.
local SPEECH_LIFT = 8.6
-- How often a player's distance to the counters is looked at, seconds.
local CHECK_SECONDS = 0.2
-- How long to wait for the server's market to appear, seconds.
local WAIT = 60

-- What a shop's keeper says, by shop, as keys of client/Strings: what the shop is for, the
-- seal's mark, and the lines one of which goes under it. The first line says what the shop's
-- goods are good for, and is the one said the first time; after that any of them.
local TALK: { [string]: { pitch: string, mark: string, lines: { string } } } = {
	tenten = {
		pitch = "PitchTenten",
		mark = "T",
		lines = { "TentenHello1", "TentenHello2", "TentenHello3", "TentenHello4" },
	},
	sell = {
		pitch = "PitchSell",
		mark = "S",
		lines = { "MissionHello1", "MissionHello2", "MissionHello3", "MissionHello4" },
	},
	speed = {
		pitch = "PitchSpeed",
		mark = "D",
		lines = { "DuyHello1", "DuyHello2", "DuyHello3", "DuyHello4" },
	},
}

-- A shop's counter, with what its keeper says over it.
type Keeper = {
	kind: string,
	counter: BasePart,
	scroll: Speech.Scroll,
	spoken: boolean, -- since the player last came up
	times: number, -- the keeper has spoken to this player
	said: number, -- counts what was said, so that an old timer does not hide newer words
}

local rng = Random.new()

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

	local keepers: { Keeper } = {}

	-- Takes a counter's prompt for what it is: a shop whose keeper has something to say.
	local function adopt(item: Instance)
		local kind = if item:IsA("ProximityPrompt")
			then item:GetAttribute(Net.SHOP_ATTRIBUTE)
			else nil
		local at = item.Parent
		local talk = if typeof(kind) == "string" then TALK[kind] else nil
		if talk and at and at:IsA("BasePart") then
			table.insert(keepers, {
				kind = kind :: string,
				counter = at,
				scroll = Speech.build(at, SPEECH_LIFT, talk.mark),
				spoken = false,
				times = 0,
				said = 0,
			})
		end
	end
	-- The server builds the market at startup, but this script may run first.
	task.spawn(function()
		local market = Workspace:WaitForChild(Net.MARKET_FOLDER, WAIT)
		if market then
			market.DescendantAdded:Connect(adopt)
			for _, item in market:GetDescendants() do
				adopt(item)
			end
		end
	end)

	local function hush()
		for _, keeper in keepers do
			keeper.said += 1
			keeper.scroll.hide()
		end
	end

	local function speak(keeper: Keeper)
		local talk = TALK[keeper.kind]
		keeper.times += 1
		keeper.said += 1
		local mine = keeper.said
		local key = if keeper.times == 1
			then talk.lines[1]
			else talk.lines[rng:NextInteger(1, #talk.lines)]
		keeper.scroll.say(Strings.get(talk.pitch), Strings.get(key))
		task.delay(SPEAK_SECONDS, function()
			if keeper.said == mine then
				keeper.scroll.hide()
			end
		end)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local kind = prompt:GetAttribute(Net.SHOP_ATTRIBUTE)
		local window = if typeof(kind) == "string" then windows[kind] else nil
		local parent = prompt.Parent
		if window and parent and parent:IsA("BasePart") then
			openWindow = window
			counter = parent
			window.open()
			hush()
		end
	end)

	local sinceCheck = 0
	RunService.Heartbeat:Connect(function(dt)
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local position = if root and root:IsA("BasePart") then root.Position else nil

		local window, at = openWindow, counter
		if window and at then
			local away = not position or (position - at.Position).Magnitude > CLOSE_DISTANCE
			if away then
				window.close()
			end
			if away or not window.isOpen() then
				openWindow = nil
				counter = nil
			end
		end

		sinceCheck += dt
		if sinceCheck < CHECK_SECONDS then
			return
		end
		sinceCheck = 0
		for _, keeper in keepers do
			local far = if position
				then (position - keeper.counter.Position).Magnitude
				else math.huge
			if far > SPEAK_AGAIN then
				keeper.spoken = false
			elseif far <= SPEAK_WITHIN and not keeper.spoken and not openWindow then
				keeper.spoken = true
				speak(keeper)
			end
		end
	end)
end

return Shops
