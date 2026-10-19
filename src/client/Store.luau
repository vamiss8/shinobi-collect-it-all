--!strict
-- Holds the latest data from the server and tells the UI when it changes: the state snapshot,
-- the inventory and the Bingo Book.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")

local Store = {}

type StateListener = (state: Net.Snapshot) -> ()
type InventoryListener = (inventory: Net.Inventory) -> ()
type IndexListener = (found: Net.Found) -> ()

local state: Net.Snapshot? = nil
local inventory: Net.Inventory = {}
local twins: Net.Twins = {}
local onPads: Net.OnPads = {}
local merges: { Economy.MergeOption } = {}
local mergeable: { [string]: boolean } = {}
local paired: { [string]: boolean } = {}
local found: Net.Found = {}

local stateListeners: { StateListener } = {}
local inventoryListeners: { InventoryListener } = {}
local indexListeners: { IndexListener } = {}

function Store.get(): Net.Snapshot?
	return state
end

-- Every owned unit that is not standing on a pad, by id.
function Store.inventory(): Net.Inventory
	return inventory
end

-- The units of the inventory whose twin stands on a pad, each with that pad's number: they
-- are ready to merge. Changes with the inventory, so read it in an onInventory listener.
function Store.twins(): Net.Twins
	return twins
end

-- The units standing on the player's pads, by pad number (a string). Changes with the
-- inventory.
function Store.onPads(): Net.OnPads
	return onPads
end

-- The merges the inventory offers (Economy.mergeOptions), the best first. Changes with the
-- inventory, so read it in an onInventory listener.
function Store.merges(): { Economy.MergeOption }
	return merges
end

-- The units of the inventory that some merge could take: with a twin in the inventory or on a
-- pad. They are marked "ready to merge" on their cards and in the bar.
function Store.mergeable(): { [string]: boolean }
	return mergeable
end

-- The units of an inventory that have a twin in it.
local function pairsUp(list: Net.Inventory): { [string]: boolean }
	local counts: { [string]: number } = {}
	local function key(unit: Economy.Unit): string
		return `{unit.character}|{unit.mutation}|{unit.level}`
	end
	for _, unit in list do
		counts[key(unit)] = (counts[key(unit)] or 0) + 1
	end
	local twinned: { [string]: boolean } = {}
	for unitId, unit in list do
		if counts[key(unit)] >= 2 then
			twinned[unitId] = true
		end
	end
	return twinned
end

-- The units of the inventory that have a twin in it, not only on a pad: a card says which.
function Store.paired(): { [string]: boolean }
	return paired
end

-- Which character + mutation pairs the player has found.
function Store.found(): Net.Found
	return found
end

-- Calls `fn` on every new snapshot, and right away if one has already arrived.
function Store.onChange(fn: StateListener)
	table.insert(stateListeners, fn)
	if state then
		fn(state)
	end
end

-- Calls `fn` whenever the inventory changes, and right away with the current one.
function Store.onInventory(fn: InventoryListener)
	table.insert(inventoryListeners, fn)
	fn(inventory)
end

-- Calls `fn` whenever the Bingo Book changes, and right away with the current one.
function Store.onIndex(fn: IndexListener)
	table.insert(indexListeners, fn)
	fn(found)
end

function Store.start()
	Remotes.State.OnClientEvent:Connect(function(snapshot: Net.Snapshot)
		state = snapshot
		for _, fn in stateListeners do
			fn(snapshot)
		end
	end)

	Remotes.Inventory.OnClientEvent:Connect(
		function(list: Net.Inventory, pairs: Net.Twins?, standing: Net.OnPads?)
			inventory = list
			twins = pairs or {}
			onPads = standing or {}
			merges = Economy.mergeOptions(inventory, onPads)
			paired = pairsUp(inventory)
			mergeable = {}
			for unitId in inventory do
				if paired[unitId] or twins[unitId] then
					mergeable[unitId] = true
				end
			end
			for _, fn in inventoryListeners do
				fn(list)
			end
		end
	)

	Remotes.Index.OnClientEvent:Connect(function(book: Net.Found)
		found = book
		for _, fn in indexListeners do
			fn(book)
		end
	end)
end

return Store
