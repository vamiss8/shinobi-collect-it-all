--!strict
-- Player saves. ProfileStore keeps one session per player across all servers (session locking),
-- autosaves, and saves on leave. Without DataStore access (an unpublished place in Studio) it
-- falls back to an in-memory store, so progress then lasts only until the test session ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Index = require(ReplicatedStorage.Shared.Logic.Index)
local ProfileStore = require("./Vendor/ProfileStore")

local Data = {}

-- The saved shape. Only add fields (with a default in TEMPLATE); old saves get them on load.
-- Maps are keyed by strings because saves are stored as JSON.
export type Data = {
	ryo: number,
	chakra: number,
	kunai: number, -- index into Config/Kunai of the best owned kunai
	speedLevel: number,
	padsBought: number,
	spins: number, -- throws made; drives the luck milestones
	streak: number, -- Perfects in a row
	nextUnit: number, -- counter for unit ids
	units: { [string]: Economy.Unit }, -- every owned unit by id; those not on a pad are inventory
	pads: { [string]: string }, -- pad index -> unit id standing on it
	found: Index.Found,
	potions: { [string]: number }, -- potion id -> expiry, unix seconds
	lastSeen: number, -- unix seconds; 0 for a brand new save
}

local TEMPLATE: Data = {
	ryo = 0,
	chakra = 1,
	kunai = 1,
	speedLevel = 0,
	padsBought = 0,
	spins = 0,
	streak = 0,
	nextUnit = 1,
	units = {},
	pads = {},
	found = {},
	potions = {},
	lastSeen = 0,
}

type Callback = (player: Player, data: Data) -> ()

-- The DataStore the saves live in. Closed playtests write to a store of their own, so the real
-- release starts everyone from nothing: it switches the name to "PlayerData". Raising the
-- number wipes the testers' progress, which is also the way out when a change to the config
-- (a removed character, a reordered kunai) leaves old saves meaningless.
local STORE = "Playtest1"

local store = ProfileStore.New(STORE, TEMPLATE)
-- Typed loosely: ProfileStore's own Profile<T> type does not survive strict checking against T.
local profiles: { [Player]: any } = {}
local loadedCallbacks: { Callback } = {}
local leavingCallbacks: { Callback } = {}

function Data.get(player: Player): Data?
	local profile = profiles[player]
	return if profile then profile.Data :: Data else nil
end

-- Runs after a player's save is loaded, in registration order.
function Data.onLoaded(fn: Callback)
	table.insert(loadedCallbacks, fn)
end

-- Runs right before a player's save is released, in reverse registration order (like `defer`),
-- so a service can still use whatever the services started before it set up.
function Data.onLeaving(fn: Callback)
	table.insert(leavingCallbacks, fn)
end

-- Stores a new unit and returns its id.
function Data.addUnit(data: Data, unit: Economy.Unit): string
	local id = `u{data.nextUnit}`
	data.nextUnit += 1
	data.units[id] = unit
	return id
end

local function load(player: Player)
	local profile: any = store:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		player:Kick("Could not load your save. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Your save was opened on another server. Please rejoin.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
	for _, fn in loadedCallbacks do
		fn(player, profile.Data)
	end
end

local function release(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for i = #leavingCallbacks, 1, -1 do
		leavingCallbacks[i](player, profile.Data)
	end
	profiles[player] = nil
	profile:EndSession()
end

-- Call last, after every service has registered its callbacks.
function Data.start()
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

return Data
