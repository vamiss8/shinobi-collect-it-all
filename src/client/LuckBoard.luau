--!strict
-- The luck board on the signpost by the throwing strip: how many throws until the next lucky
-- one. It is drawn locally, on a part the server placed, because the count is the player's own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Roll = require(ReplicatedStorage.Shared.Logic.Roll)
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local LuckBoard = {}

-- "Every 10th x2  |  20th x5  |  100th x10", from the most frequent milestone up.
local function legend(): string
	local parts = {}
	for i = #Tuning.Luck.milestones, 1, -1 do
		local milestone = Tuning.Luck.milestones[i]
		table.insert(parts, Strings.get("LuckMilestone", milestone.every, milestone.luck))
	end
	return table.concat(parts, "  |  ")
end

function LuckBoard.start()
	-- The server builds the world at startup, but this script may run first.
	task.spawn(function()
		local hub = Workspace:WaitForChild(Net.HUB_FOLDER, 60)
		local anchor = if hub then hub:WaitForChild(Net.LUCK_BOARD, 60) else nil
		if not anchor then
			return
		end

		local gui = Ui.make("BillboardGui", {
			Size = UDim2.fromScale(17, 8),
			MaxDistance = 220,
			LightInfluence = 0,
		}, anchor)
		local board = Ui.panel(gui, {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 0.15,
		})
		Ui.stroke(board, Ui.GOLD, 3)

		local function line(y: number, height: number, color: Color3): TextLabel
			return Ui.text(board, {
				Position = UDim2.fromScale(0.04, y),
				Size = UDim2.fromScale(0.92, height),
				TextColor3 = color,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
		end
		local heading = line(0.04, 0.18, Ui.GOLD)
		heading.Font = Ui.BRUSH
		heading.Text = Strings.get("LuckTitle")
		-- What the luck is luck with: the next rank up, and since 2026-10-09 mutations too,
		-- an event's own among them, which is what a lucky throw is kept for.
		line(0.225, 0.1, Ui.MUTED).Text = Strings.get("LuckWhat")
		local throw = line(0.345, 0.17, Ui.WHITE)
		local countdown = line(0.53, 0.25, Ui.WHITE)
		line(0.81, 0.13, Ui.MUTED).Text = legend()

		Store.onChange(function(state)
			local throwsLeft, luck = Roll.nextMilestone(state.spins)
			throw.Text = Strings.get("LuckThrow", state.spins + 1)
			if throwsLeft == 1 then
				countdown.Text = Strings.get("LuckNow", luck)
				countdown.TextColor3 = Ui.GOLD
			else
				countdown.Text = Strings.get("LuckSoon", luck, throwsLeft)
				countdown.TextColor3 = Ui.WHITE
			end
		end)
	end)
end

return LuckBoard
