--!strict
-- Sends each player what their client needs to draw: a snapshot of their state and notifications.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Data = require("../Data")
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Remotes = require("../Remotes")
local Session = require("../Session")
local Stats = require("./Stats")

local State = {}

-- Puts what every other player sees of this one where their clients can read it: the rebirths
-- done and what the dojo earns a second, as attributes of the Player. The game's own list of
-- players is drawn from them (client PlayerList). An attribute set to the value it has is not
-- sent again.
local function post(player: Player, rebirths: number, income: number)
	player:SetAttribute(Net.PLAYER_REBIRTHS, rebirths)
	player:SetAttribute(Net.PLAYER_INCOME, income)
end

-- The legendary shinobi in a save, by id, in the order of the config.
local function legends(data: Data.Data): { string }
	local has: { [string]: boolean } = {}
	for _, unit in data.units do
		if Catalog.isLegend(unit.character) then
			has[unit.character] = true
		end
	end
	local owned = {}
	for _, legend in Catalog.legends do
		if has[legend.id] then
			table.insert(owned, legend.id)
		end
	end
	return owned
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
		legends = legends(data),
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
