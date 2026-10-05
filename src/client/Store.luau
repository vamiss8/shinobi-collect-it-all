--!strict
-- Holds the latest data from the server and tells the UI when it changes: the state snapshot,
-- the inventory and the Bingo Book.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")

local Store = {}

type StateListener = (state: Net.Snapshot) -> ()
type InventoryListener = (inventory: Net.Inventory) -> ()
type IndexListener = (found: Net.Found) -> ()

local state: Net.Snapshot? = nil
local inventory: Net.Inventory = {}
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

	Remotes.Inventory.OnClientEvent:Connect(function(list: Net.Inventory)
		inventory = list
		for _, fn in inventoryListeners do
			fn(list)
		end
	end)

	Remotes.Index.OnClientEvent:Connect(function(book: Net.Found)
		found = book
		for _, fn in indexListeners do
			fn(book)
		end
	end)
end

return Store
