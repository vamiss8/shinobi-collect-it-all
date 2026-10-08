--!strict
-- Sends each player what their client needs to draw: a snapshot of their state and notifications.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require("../Data")
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("../Remotes")
local Session = require("../Session")
local Stats = require("./Stats")

local State = {}

-- Sends the player a fresh snapshot. Call after anything in their save changes.
function State.push(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local session = Session.of(player)
	local snapshot: Net.Snapshot = {
		ryo = data.ryo,
		income = Stats.income(data),
		chakra = data.chakra,
		kunai = data.kunai,
		speedLevel = data.speedLevel,
		runLevel = Economy.runLevel(data.speedLevel, data.runAt),
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
