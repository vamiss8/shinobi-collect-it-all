--!strict
-- The window that greets a returning player: how long they were away and what the dojo earned
-- in that time. It opens in the middle of the screen once the save has loaded and stays until
-- it is dismissed; as a toast the same news was gone before it could be read.
--
-- The Ryo are paid out when the window closes, whichever way it is closed, so the player sees
-- their purse grow; the server also pays them out by itself if the player leaves first. An
-- offer to multiply them for Robux is planned next to the Collect button: it will act on the
-- amount while it still waits on the server (Session.offline).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local WelcomeBack = {}

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
			Format.duration(Tuning.Dojo.offlineCapHours * 3600)
		),
	})
	local collect = Ui.button(body, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(260, 60),
		TextSize = 30,
		Text = Strings.get("OfflineCollect"),
	})
	collect.Activated:Connect(window.close)

	-- True from the offer until the window closes. Closing it is what collects, be it by the
	-- button, the X, Enter, or another window opening over it.
	local waiting = false
	Remotes.Offline.OnClientEvent:Connect(function(offline: Net.Offline)
		away.Text = Strings.get("OfflineAway", Format.duration(offline.away))
		earned.Text = Strings.get("OfflineEarned", offline.earned)
		waiting = true
		window.open()
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
