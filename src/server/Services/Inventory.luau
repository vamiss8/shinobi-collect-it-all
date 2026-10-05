--!strict
-- The shinobi inventory: every owned unit that is not standing on a pad. The client shows it
-- in its own window and asks to carry ("hold") one unit at a time; the held unit floats over
-- the player's head and is the one pads and the selling stall act on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require("../Data")
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Loadout = require("./Loadout")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("../Remotes")
local Session = require("../Session")
local State = require("./State")

local Inventory = {}

local heldFigures: { [Player]: Model } = {}

-- Which units stand on a pad, as a set of ids.
local function placed(data: Data.Data): { [string]: boolean }
	local set = {}
	for _, unitId in data.pads do
		set[unitId] = true
	end
	return set
end

-- Shows the held unit above the player's head, or removes it when nothing is held.
local function drawHeld(player: Player)
	local old = heldFigures[player]
	if old then
		old:Destroy()
		heldFigures[player] = nil
	end

	local data = Data.get(player)
	local held = if data then Session.of(player).held else nil
	local unit = if data and held then data.units[held] else nil
	local character = player.Character
	if unit and character then
		local figure = Figure.build(unit)
		Figure.attach(figure, character)
		heldFigures[player] = figure
	end
end

-- Id of the unit the player is carrying, if any.
function Inventory.held(player: Player): string?
	return Session.of(player).held
end

-- Makes the player carry the given unit, or nothing.
function Inventory.hold(player: Player, unitId: string?)
	Session.of(player).held = unitId
	drawHeld(player)
end

-- Sends the client the current inventory. Call after units are added, placed, taken or sold.
function Inventory.sync(player: Player)
	local data = Data.get(player)
	if not data then
		return
	end
	local onPad = placed(data)
	local list: Net.Inventory = {}
	for unitId, unit in data.units do
		if not onPad[unitId] then
			list[unitId] = unit
		end
	end
	Remotes.Inventory:FireClient(player, list)
end

-- Adds a brand new unit to the save and the inventory. Returns its id.
function Inventory.add(player: Player, data: Data.Data, unit: Economy.Unit): string
	local unitId = Data.addUnit(data, unit)
	Inventory.sync(player)
	return unitId
end

-- The client asks to carry a unit from the inventory, or to put the carried one away.
local function onHold(player: Player, unitId: unknown)
	local data = Data.get(player)
	if not data then
		return
	end
	if typeof(unitId) == "string" and data.units[unitId] and not placed(data)[unitId] then
		Inventory.hold(player, unitId)
	else
		Inventory.hold(player, nil)
	end
	State.push(player)
end

function Inventory.start()
	Remotes.Hold.OnServerEvent:Connect(onHold)

	Data.onLoaded(function(player)
		Inventory.sync(player)
	end)

	-- The carried figure is welded to the character, so it is gone after a respawn.
	Loadout.register(function(player)
		heldFigures[player] = nil
		Session.of(player).held = nil
		State.push(player)
	end)

	Data.onLeaving(function(player)
		heldFigures[player] = nil
	end)
end

return Inventory
