--!strict
-- The window that greets a returning player: how long they were away and what the dojo earned
-- in that time. It opens in the middle of the screen once the save has loaded and stays until
-- it is dismissed; as a toast the same news was gone before it could be read.
--
-- The Ryo are paid out when the window closes, whichever way it is closed, so the player sees
-- their purse grow; the server also pays them out by itself if the player leaves first. Beside
-- the Collect button the same Ryo are offered a second time for Robux (Config/Products
-- "DoubleOffline"): bought, the server pays them once more (Services/Purchases), whether the
-- window is still open or not, and the window, if it is, shows what comes in all.
--
-- THIS IS THE ONE LISTENER OF Remotes.Offline, and has to stay the only one. The server sends
-- the message the moment the save loads, and the client starts its modules only after that
-- (client Language waits for the saved language), so the message comes before anyone listens.
-- Roblox keeps such a message until a handler connects and delivers it to that handler: when
-- client Guide connected its own handler first, the window never opened (my reading, which
-- fits what the testers saw and is not seen in Studio), the
-- Ryo were paid only as the player left, and testers saw them on their next visit (owner,
-- 2026-10-23). Whoever else wants to know of a return asks WelcomeBack.onReturn.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local WelcomeBack = {}

-- Who wants to know that the player came back to income waiting (client Guide's tip), and
-- whether they have this visit: one who asks later is told at once.
local told: { () -> () } = {}
local returned = false

function WelcomeBack.onReturn(callback: () -> ())
	table.insert(told, callback)
	if returned then
		task.spawn(callback)
	end
end

function WelcomeBack.start()
	local window = Ui.window("WelcomeBack", Vector2.new(540, 380))
	window.title.Text = Strings.get("OfflineTitle")
	local body = window.body

	local away = Ui.text(body, {
		Size = UDim2.new(1, 0, 0, 32),
		TextSize = 24,
		TextColor3 = Ui.PARCHMENT,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.text(body, {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("OfflineEarnedLabel"),
	})
	local earned = Ui.text(body, {
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 72),
		TextScaled = true,
		TextColor3 = Ui.GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 62 }, earned)
	-- The rule behind the number, so the amount does not look arbitrary.
	Ui.text(body, {
		Position = UDim2.fromOffset(0, 154),
		Size = UDim2.new(1, 0, 0, 60),
		TextSize = 20,
		TextColor3 = Ui.PARCHMENT,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get(
			"OfflineNote",
			Tuning.Dojo.offlineRate * 100,
			Strings.duration(Tuning.Dojo.offlineCapHours * 3600)
		),
	})
	-- The offer to have them twice stands beside Collect once it is on sale.
	local double = Catalog.productByKey.DoubleOffline
	local selling = double ~= nil and double.assetId > 0
	local collect = Ui.button(body, {
		AnchorPoint = if selling then Vector2.new(1, 1) else Vector2.new(0.5, 1),
		Position = if selling then UDim2.new(0.5, -8, 1, 0) else UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(if selling then 224 else 260, 60),
		TextSize = 30,
		Text = Strings.get("OfflineCollect"),
	})
	collect.Activated:Connect(window.close)
	local twice: TextButton? = nil
	if double and selling then
		local offer = Ui.button(body, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0.5, 8, 1, 0),
			Size = UDim2.fromOffset(244, 60),
			BackgroundColor3 = Ui.GOLD,
			TextColor3 = Ui.INK,
			TextSize = 28,
			Text = Strings.get("OfflineDouble", "..."),
		})
		offer.Activated:Connect(function()
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, double.assetId)
		end)
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(double.assetId, Enum.InfoType.Product)
			end)
			local robux = if ok and typeof(info) == "table" then info.PriceInRobux else nil
			if typeof(robux) == "number" then
				offer.Text = Strings.get("OfflineDouble", tostring(robux))
			end
		end)
		twice = offer
	end

	-- True from the offer until the window closes. Closing it is what collects, be it by the
	-- button, the X, Enter, or another window opening over it.
	local waiting = false
	Remotes.Offline.OnClientEvent:Connect(function(offline: Net.Offline)
		if offline.doubled then
			-- Bought twice over: what comes in all. A window already closed stays so; the
			-- message on the scroll says it.
			earned.Text = Strings.get("OfflineEarned", offline.earned)
			if twice then
				twice.Visible = false
			end
			return
		end
		away.Text = Strings.get("OfflineAway", Strings.duration(offline.away))
		earned.Text = Strings.get("OfflineEarned", offline.earned)
		if twice then
			twice.Visible = true
		end
		waiting = true
		window.open()
		if not returned then
			returned = true
			for _, callback in told do
				task.spawn(callback)
			end
		end
	end)
	window.frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if waiting and not window.frame.Visible then
			waiting = false
			Remotes.Collect:FireServer()
		end
	end)

	-- Enter collects as well: under Shift Lock the mouse is not free to reach the button.
	UserInputService.InputBegan:Connect(function(input, processed)
		local isEnter = input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.KeypadEnter
		if isEnter and not processed and window.isOpen() then
			window.close()
		end
	end)
end

return WelcomeBack
