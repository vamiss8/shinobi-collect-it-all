--!strict
-- The power bar. The server says when it starts; the client animates the marker from its own
-- clock and reports how long the player watched before pressing. The server grades the press.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Hud = require("./Hud")
local Kick = require(ReplicatedStorage.Shared.Logic.Kick)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local KickBar = {}

-- Presses this soon after the bar appears are ignored, so the input that started the kick
-- cannot also end it.
local ARM_DELAY = 0.2

local GRADE_COLORS: { [string]: Color3 } = {
	Perfect = Color3.fromRGB(255, 202, 40),
	Great = Color3.fromRGB(102, 187, 106),
	Good = Color3.fromRGB(66, 165, 245),
	Miss = Color3.fromRGB(189, 189, 189),
}

local function zoneName(zoneId: string): string
	for _, zone in Catalog.zones do
		if zone.id == zoneId then
			return zone.name
		end
	end
	return zoneId
end

function KickBar.start()
	local screen = Ui.screen("KickBar", 15)
	local holder = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.new(0.6, 0, 0, 104),
		BackgroundTransparency = 1,
		Visible = false,
	}, screen)
	Ui.make("UISizeConstraint", { MaxSize = Vector2.new(560, 104) }, holder)

	Ui.text(holder, {
		Size = UDim2.new(1, 0, 0, 28),
		Font = Ui.BRUSH,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
		Text = Strings.get("KickHint"),
	})

	local bar = Ui.make("Frame", {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = Color3.fromRGB(55, 55, 62),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, holder)
	Ui.corner(bar, 8)

	-- One colored segment per grade window, from its start up to where the better one begins.
	local windowEnd = 1
	for _, grade in Tuning.Kick.grades do
		if grade.from > 0 then
			Ui.make("Frame", {
				Position = UDim2.fromScale(grade.from, 0),
				Size = UDim2.fromScale(windowEnd - grade.from, 1),
				BackgroundColor3 = GRADE_COLORS[grade.id] or Ui.GRAY,
				BorderSizePixel = 0,
			}, bar)
		end
		windowEnd = grade.from
	end

	local marker = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = Ui.WHITE,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, bar)

	-- Under the bar: the Perfect streak and what it is for.
	local streak = Ui.text(holder, {
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.4,
	})
	Store.onChange(function(state)
		local needed = Tuning.Kick.sageStreak
		local ready = state.streak >= needed
		streak.Text = if ready
			then Strings.get("KickSageReady", Tuning.Kick.sageMultiplier)
			else Strings.get("KickStreak", state.streak, needed, Tuning.Kick.sageMultiplier)
		streak.TextColor3 = if ready then Ui.GOLD else Ui.WHITE
	end)

	local active = false
	local pressed = false
	local startedAt = 0
	local period = Tuning.Kick.barPeriod

	Remotes.KickStart.OnClientEvent:Connect(function(barPeriod: number)
		period = barPeriod
		startedAt = os.clock()
		active = true
		pressed = false
		holder.Visible = true
	end)

	RunService.RenderStepped:Connect(function()
		if active and not pressed then
			local position = Kick.barPosition(os.clock() - startedAt, period)
			marker.Position = UDim2.fromScale(position, 0.5)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		-- A click that landed on a button or a window is not a throw.
		if processed then
			return
		end
		local isPress = input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.ButtonA
		if not isPress or not active or pressed then
			return
		end
		local elapsed = os.clock() - startedAt
		if elapsed < ARM_DELAY then
			return
		end
		pressed = true
		Remotes.KickPress:FireServer(elapsed)
	end)

	Remotes.KickResult.OnClientEvent:Connect(function(result: Net.KickResult?)
		active = false
		-- Leave the frozen marker on screen for a moment so the player sees where they hit.
		task.delay(0.7, function()
			if not active then
				holder.Visible = false
			end
		end)
		if not result then
			return
		end

		local text = Strings.get("KickResult", result.grade, result.distance, zoneName(result.zone))
		if result.luck > 1 then
			text = Strings.get("KickLucky", result.luck) .. text
		end
		if result.sage then
			text = Strings.get("KickSage") .. text
		end
		Hud.toast(text, GRADE_COLORS[result.grade])
	end)
end

return KickBar
