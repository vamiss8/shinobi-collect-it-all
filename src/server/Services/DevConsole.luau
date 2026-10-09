--!strict
-- The developer console, on the server's side: for the accounts listed in server/Developers,
-- and nobody else, it changes their own save on request, so that anything in the game can be
-- looked at without playing up to it: Ryo, Chakra, rebirths, run speed, kunai, pads, any
-- shinobi with any mutation, the legendary ones.
--
-- Who may is decided here, by the account's id, on every single command: the attribute that
-- makes a developer's client build the console's window is only a convenience, and a client
-- that sends a command without being listed is not answered at all.
--
-- A command changes the save and then has the rest of the world catch up with it, as a
-- rebirth does: the dojo is drawn anew, the inventory sent, the runner given their speed and
-- its look, the rank's tag rewritten.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Data = require("../Data")
local Developers = require("../Developers")
local Dojo = require("./Dojo")
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Events = require("./Events")
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Inventory = require("./Inventory")
local Kicking = require("./Kicking")
local Legends = require("./Legends")
local Net = require(ReplicatedStorage.Shared.Net)
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Remotes = require("../Remotes")
local Session = require("../Session")
local SpeedLook = require("./SpeedLook")
local State = require("./State")
local Stats = require("./Stats")
local Titles = require("./Titles")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local DevConsole = {}

-- No amount is taken past this: numbers beyond it stop being numbers a save can hold.
local MOST = 1e60
-- Shinobi given by one command, at most.
local MOST_UNITS = 60
-- Merge levels (stars) a given shinobi may have, at most.
local MOST_STARS = 12

local function allowed(player: Player): boolean
	return table.find(Developers, player.UserId) ~= nil
end

-- A number a client sent, as a whole one within bounds; nil for anything else.
local function whole(value: unknown, least: number, most: number): number?
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(math.floor(value), least, most)
end

-- An amount of Ryo or Chakra a client sent; nil for anything that is not one.
local function amount(value: unknown): number?
	if typeof(value) ~= "number" or value ~= value or value < 0 then
		return nil
	end
	return math.min(value, MOST)
end

-- Which units stand on a pad, as a set of ids.
local function placed(data: Data.Data): { [string]: boolean }
	local set = {}
	for _, unitId in data.pads do
		set[unitId] = true
	end
	return set
end

-- Takes shinobi off pads the save no longer has.
local function fitPads(data: Data.Data)
	local unlocked = Stats.unlockedPads(data)
	for key, unitId in data.pads do
		local index = tonumber(key)
		if not data.units[unitId] or not index or index > unlocked then
			data.pads[key] = nil
		end
	end
end

-- Has the world catch up with a save that was changed under it.
local function refresh(player: Player, data: Data.Data)
	fitPads(data)
	local held = Inventory.held(player)
	if held and (not data.units[held] or placed(data)[held]) then
		Inventory.hold(player, nil)
	end
	Dojo.redraw(player)
	Inventory.sync(player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if character and humanoid then
		local level = Economy.runLevel(data.speedLevel, data.runAt)
		if humanoid.WalkSpeed > 0 then
			humanoid.WalkSpeed = Economy.walkSpeed(level)
		end
		SpeedLook.apply(character, level)
	end
	Titles.dress(player)
	State.push(player)
	State.pushIndex(player)
end

type Command = (player: Player, data: Data.Data, ...unknown) -> string?

local commands: { [string]: Command } = {}

-- "ryo" and "chakra": an amount, and whether it is added to what is there or put in its place.
function commands.ryo(_, data, value, add)
	local given = amount(value)
	if not given then
		return nil
	end
	data.ryo = math.min(if add == true then data.ryo + given else given, MOST)
	return `Ryo: {Format.short(data.ryo)}`
end

function commands.chakra(player, data, value, add)
	local given = amount(value)
	if not given then
		return nil
	end
	data.chakra = math.clamp(if add == true then data.chakra + given else given, 1, MOST)
	-- An amount chosen to throw with may be more than there now is.
	Session.of(player).throwChakra = 0
	return `Chakra: {Format.short(data.chakra)}`
end

function commands.rebirths(_, data, value)
	local count = whole(value, 0, Rebirth.count())
	if not count then
		return nil
	end
	data.rebirths = count
	return `Rebirths: {count}, {Rebirth.title(count)}`
end

function commands.speed(_, data, value)
	local level = whole(value, 0, Tuning.Speed.maxLevel)
	if not level then
		return nil
	end
	data.speedLevel = level
	data.runAt = -1
	return `Run speed: level {level}`
end

function commands.kunai(_, data, value)
	local place = whole(value, 1, #Catalog.kunai)
	if not place then
		return nil
	end
	data.kunai = place
	return `Kunai: {place}, {Catalog.kunai[place].name}`
end

function commands.pads(_, data, value)
	local bought = whole(value, 0, Tuning.Dojo.buyablePads)
	if not bought then
		return nil
	end
	data.padsBought = bought
	return `Pads: {Stats.unlockedPads(data)}`
end

-- "unit": a shinobi of the roster with a mutation ("none" for none), merged to `stars` and
-- levelled up to `level`, `count` of them, into the inventory.
function commands.unit(_, data, characterId, mutationId, stars, level, count)
	local character = if typeof(characterId) == "string"
		then Catalog.characterById[characterId]
		else nil
	local plain = mutationId == Catalog.NONE
	local mutation = if typeof(mutationId) == "string"
		then Catalog.mutationById[mutationId]
		else nil
	local merged = whole(stars, 0, MOST_STARS)
	local upgrades = whole(level, 1, Tuning.Upgrade.maxUpgrades + 1)
	local many = whole(count, 1, MOST_UNITS)
	-- The legendary shinobi are given and taken by a command of their own: there is one each.
	if not character or Catalog.isLegend(character.id) or not (plain or mutation) then
		return nil
	end
	if not merged or not upgrades or not many then
		return nil
	end
	local unit: Economy.Unit = {
		character = character.id,
		mutation = if mutation then mutation.id else Catalog.NONE,
		level = merged + 1,
		upgrade = upgrades - 1,
	}
	for _ = 1, many do
		Data.addUnit(data, table.clone(unit))
	end
	return `Given: {many} x {Catalog.unitTitle(
		unit.character,
		unit.mutation,
		unit.level,
		unit.upgrade
	)}`
end

-- "zone": one of each shinobi a zone drops, with a mutation, into the inventory.
function commands.zone(_, data, zoneNumber, mutationId)
	local number = whole(zoneNumber, 1, #Catalog.zones)
	local plain = mutationId == Catalog.NONE
	local mutation = if typeof(mutationId) == "string"
		then Catalog.mutationById[mutationId]
		else nil
	if not number or not (plain or mutation) then
		return nil
	end
	local zone = Catalog.zones[number]
	for _, character in Catalog.charactersByRank[zone.rank] do
		Data.addUnit(data, {
			character = character.id,
			mutation = if mutation then mutation.id else Catalog.NONE,
			level = 1,
			upgrade = 0,
		})
	end
	return `Given: every shinobi of {zone.name}`
end

-- "place": the inventory's best earners onto the pads that stand empty.
function commands.place(_, data)
	local onPad = placed(data)
	local spare: { string } = {}
	for unitId in data.units do
		if not onPad[unitId] then
			table.insert(spare, unitId)
		end
	end
	table.sort(spare, function(a, b)
		local earnsA, earnsB = Economy.unitIncome(data.units[a]), Economy.unitIncome(data.units[b])
		if earnsA ~= earnsB then
			return earnsA > earnsB
		end
		return a < b
	end)
	local stood = 0
	for index = 1, Stats.unlockedPads(data) do
		local key = tostring(index)
		if not data.pads[key] and spare[stood + 1] then
			stood += 1
			data.pads[key] = spare[stood]
		end
	end
	return `Placed: {stood} shinobi`
end

-- "clear": every shinobi gone but the legendary ones, as a rebirth leaves the dojo.
function commands.clear(_, data)
	for unitId, unit in data.units do
		if not Catalog.isLegend(unit.character) then
			data.units[unitId] = nil
		end
	end
	return "Shinobi cleared"
end

-- "legend": one of the legendary shinobi given, or taken away again.
function commands.legend(player, data, legendId, give)
	local legend = if typeof(legendId) == "string" then Catalog.legendById[legendId] else nil
	if not legend then
		return nil
	end
	if give == true then
		Legends.grant(player, legend.id)
		return `{legend.name}: given`
	end
	for unitId, unit in data.units do
		if unit.character == legend.id then
			data.units[unitId] = nil
		end
	end
	return `{legend.name}: taken`
end

-- "event": an event started on this server for everyone on it, or with no id the one started
-- by hand ended. The clock's own schedule goes on underneath.
function commands.event(_, _, id)
	if typeof(id) ~= "string" then
		Events.force(nil)
		return "The event started by hand is over"
	end
	return if Events.force(id) then `Event started: {id}` else nil
end

-- "reset": the save as a new player's, but for the legendary shinobi and the Bingo Book.
function commands.reset(player, data)
	commands.clear(player, data)
	data.ryo = 0
	data.chakra = Rebirth.START_CHAKRA
	data.kunai = 1
	data.speedLevel = 0
	data.runAt = -1
	data.rebirths = 0
	data.padsBought = 0
	data.spins = 0
	data.streak = 0
	Session.of(player).throwChakra = 0
	return "Save reset"
end

-- The commands that touch no save, and so can be given in the middle of a throw: an event is
-- the server's, and how one looks to a player who is throwing is a thing to be tried.
local ANY_TIME = { event = true }

local function run(player: Player, name: unknown, ...: unknown)
	if not allowed(player) then
		return
	end
	local data = Data.get(player)
	local command = if typeof(name) == "string" then commands[name] else nil
	if not data or not command then
		return
	end
	local anyTime = ANY_TIME[name :: string] == true
	-- A throw holds on to the Chakra, the speed and the catch of the save as it was.
	if Kicking.throwing(player) and not anyTime then
		Remotes.Dev:FireClient(player, "Not in the middle of a throw")
		return
	end
	local done = command(player, data, ...)
	if done and not anyTime then
		refresh(player, data)
	end
	Remotes.Dev:FireClient(player, done or "That is not something the console can do")
end

function DevConsole.start()
	local function greet(player: Player)
		if allowed(player) then
			player:SetAttribute(Net.DEVELOPER_ATTRIBUTE, true)
		end
	end
	Players.PlayerAdded:Connect(greet)
	for _, player in Players:GetPlayers() do
		greet(player)
	end
	Remotes.Dev.OnServerEvent:Connect(run)
end

return DevConsole
