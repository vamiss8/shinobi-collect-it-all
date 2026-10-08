--!strict
-- Sends each player what their client needs to draw: a snapshot of their state and notifications.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require("../Data")
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Remotes = require("../Remotes")
local Session = require("../Session")
local Stats = require("./Stats")

local State = {}

-- What every player sees of every other in Roblox's list of players, by its own rule: values
-- in a folder named "leaderstats" under the Player, a column each, in this order.
local BOARD = "leaderstats"
local BOARD_REBIRTHS = "Rebirths"
local BOARD_INCOME = "Ryo/s"

-- One column of the list of players for this player, made if it is not there yet.
local function column(player: Player, name: string): IntValue
	local found = player:FindFirstChild(BOARD)
	local board: Instance = found or Instance.new("Folder")
	if not found then
		board.Name = BOARD
		board.Parent = player
	end
	local value = board:FindFirstChild(name)
	if value and value:IsA("IntValue") then
		return value
	end
	local made = Instance.new("IntValue")
	made.Name = name
	made.Parent = board
	return made
end

-- Puts the player's rebirths and what their dojo earns a second on the list of players.
local function post(player: Player, rebirths: number, income: number)
	column(player, BOARD_REBIRTHS).Value = rebirths
	column(player, BOARD_INCOME).Value = math.floor(income)
end

-- Sends the player a fresh snapshot. Call after anything in their save changes.
function State.push(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	post(player, Rebirth.done(data.rebirths), Stats.income(data))
	local session = Session.of(player)
	local snapshot: Net.Snapshot = {
		ryo = data.ryo,
		income = Stats.income(data),
		chakra = data.chakra,
		kunai = data.kunai,
		speedLevel = data.speedLevel,
		runLevel = Economy.runLevel(data.speedLevel, data.runAt),
		rebirths = data.rebirths,
		padsBought = data.padsBought,
		spins = data.spins,
		streak = data.streak,
		held = session.held,
		multipliers = Stats.multipliers(data),
		training = session.training,
		trainBoost = Session.boost(player),
		throwChakra = session.throwChakra,
	}
	Remotes.State:FireClient(player, snapshot)
end

-- Sends the player their Bingo Book. Call after a new find.
function State.pushIndex(player: Player)
	local data = Data.get(player)
	if data then
		Remotes.Index:FireClient(player, data.found)
	end
end

-- Shows a message on the player's screen. `key` names a template in client/Strings.
function State.notify(player: Player, key: string, ...: any)
	Remotes.Notify:FireClient(player, key, ...)
end

function State.start()
	Data.onLoaded(function(player)
		State.push(player)
		State.pushIndex(player)
	end)
end

return State
