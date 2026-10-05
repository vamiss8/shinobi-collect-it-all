--!strict
-- The window that greets a returning player: how long they were away and what the dojo earned
-- in that time. It opens in the middle of the screen once the save has loaded and stays until
-- it is dismissed; as a toast the same news was gone before it could be read.
--
-- The Ryo are already the player's when the window opens, so closing it any way loses nothing.
-- An offer to multiply them for Robux is planned next to the Collect button; the server keeps
-- the amount for it (Session.offline).

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
	local window = Ui.window("WelcomeBack", Vector2.new(440, 290))
	window.title.Text = Strings.get("OfflineTitle")
	local body = window.body

	local away = Ui.text(body, {
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 17,
		TextColor3 = Ui.MUTED,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.text(body, {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = Strings.get("OfflineEarnedLabel"),
	})
	local earned = Ui.text(body, {
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 56),
		TextScaled = true,
		TextColor3 = Ui.GOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 46 }, earned)
	-- The rule behind the number, so the amount does not look arbitrary.
	Ui.text(body, {
		Position = UDim2.fromOffset(0, 120),
		Size = UDim2.new(1, 0, 0, 36),
		TextSize = 13,
		TextColor3 = Ui.MUTED,
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
		Size = UDim2.fromOffset(200, 46),
		TextSize = 22,
		Text = Strings.get("OfflineCollect"),
	})
	collect.Activated:Connect(window.close)

	Remotes.Offline.OnClientEvent:Connect(function(offline: Net.Offline)
		away.Text = Strings.get("OfflineAway", Format.duration(offline.away))
		earned.Text = Strings.get("OfflineEarned", offline.earned)
		window.open()
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
