--!strict
-- Player saves. ProfileStore keeps one session per player across all servers (session locking),
-- autosaves, and saves on leave. Test sessions in Studio never touch the real saves: they get
-- an in-memory store, so progress there lasts only until the session ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Index = require(ReplicatedStorage.Shared.Logic.Index)
local ProfileStore = require("./Vendor/ProfileStore")
local Roster = require(ReplicatedStorage.Shared.Logic.Roster)
local Saves = require(ReplicatedStorage.Shared.Logic.Saves)
local Settings = require(ReplicatedStorage.Shared.Logic.Settings)

local Data = {}

-- The saved shape. Only add fields (with a default in TEMPLATE); old saves get them on load.
-- Maps are keyed by strings because saves are stored as JSON.
export type Data = {
	version: number, -- the rules the save was written under (Logic/Saves)
	ryo: number,
	chakra: number,
	kunai: number, -- index into Config/Kunai of the best owned kunai
	speedLevel: number,
	-- The speed level the player chose to run at (Economy.runLevel); -1 for the fastest bought.
	runAt: number,
	-- Rebirths done (Logic/Rebirth): each gave up the Chakra of its day for lasting multipliers.
	rebirths: number,
	padsBought: number,
	spins: number, -- throws made; drives the luck milestones
	streak: number, -- Perfects in a row
	nextUnit: number, -- counter for unit ids
	units: { [string]: Economy.Unit }, -- every owned unit by id; those not on a pad are inventory
	pads: { [string]: string }, -- pad index -> unit id standing on it
	found: Index.Found,
	potions: { [string]: number }, -- potion id -> expiry, unix seconds
	-- Herbs, earned by throws and spent on potions at the Herb Shop (Tuning.Herbs), and the
	-- potions in the pouch, not drunk yet, by potion id (Logic/Pouch).
	herbs: number,
	stock: { [string]: number },
	-- Premium potions in the pouch, bought for Robux, which run longer (Config/Potions).
	premium: { [string]: number },
	lastSeen: number, -- unix seconds; 0 for a brand new save
	-- Game passes owned, by key (Config/Products), legends aside: kept here as well as asked of
	-- Roblox at every join, so that what they give does not wait on Roblox or fail with it.
	passes: { [string]: boolean },
	-- Products sold once (Config/Products `once`) that the player has had, by key.
	bought: { [string]: boolean },
	-- Whether the player has had the gift for joining the group (Services/GroupGift).
	groupGift: boolean,
	-- The achievements' tiers reached, by achievement id (Config/Achievements,
	-- Services/Achievements), for good, and the tiers whose reward has been claimed.
	achievements: { [string]: number },
	claimed: { [string]: number },
	-- Numbers no other field keeps, which achievements are measured by, by name
	-- (Logic/Achievements.COUNTED): catches brought home, merges, potions drunk and the like.
	counts: { [string]: number },
	-- The base tutorial's steps done (Config/Guide) and the tips Iruka has said, by id.
	guide: number,
	tips: { [string]: boolean },
	-- The daily rewards (Logic/Daily): the day of the last claim and the days in a row.
	daily: { last: number, streak: number },
	-- The promo codes the player has redeemed, by name (server/Codes, Services/Codes).
	codes: { [string]: boolean },
	-- Ids of the newest purchases granted (Services/Purchases), so none is granted twice.
	receipts: { string },
	-- The player's settings (client SettingsPanel): language, font, volumes.
	settings: Settings.Settings,
}

local TEMPLATE: Data = {
	-- Not today's number: a save from before the rules were numbered gets this one filled in
	-- on load, and is then brought up to date like any other. A new save comes to no harm.
	version = 0,
	ryo = 0,
	chakra = 1,
	kunai = 1,
	speedLevel = 0,
	runAt = -1,
	rebirths = 0,
	padsBought = 0,
	spins = 0,
	streak = 0,
	nextUnit = 1,
	units = {},
	pads = {},
	found = {},
	potions = {},
	herbs = 0,
	stock = {},
	premium = {},
	lastSeen = 0,
	passes = {},
	bought = {},
	groupGift = false,
	achievements = {},
	claimed = {},
	counts = {},
	guide = 0,
	tips = {},
	daily = { last = 0, streak = 0 },
	codes = {},
	receipts = {},
	settings = Settings.defaults(),
}

type Callback = (player: Player, data: Data) -> ()

-- The DataStore the saves live in. Closed playtests write to a store of their own, so the real
-- release starts everyone from nothing: it switches the name to "PlayerData". Raising the
-- number wipes the testers' progress, which is also the way out when a change to the config
-- (a removed character, a reordered kunai) leaves old saves meaningless.
local STORE = "Playtest1"
-- The save store's name, for the stores that go with it (Services/Leaderboards).
Data.STORE = STORE

-- A test session in Studio keeps its saves in memory. With the place published Studio can
-- reach the real DataStore, and a test run would then go for the tester's live save: it waits
-- out the live server's lock on it (the player stands at the template's spawn with an empty
-- HUD meanwhile), throws them out of the live game, and writes the test run's progress over
-- the real one. Typed loosely, like the profiles below.
local liveStore = ProfileStore.New(STORE, TEMPLATE)
local store: any = if RunService:IsStudio() then liveStore.Mock else liveStore
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

-- Counts one more (or `by` more) of a number the achievements are measured by.
function Data.count(data: Data, name: string, by: number?)
	data.counts[name] = (data.counts[name] or 0) + (by or 1)
end

-- Stores a new unit and returns its id.
function Data.addUnit(data: Data, unit: Economy.Unit): string
	local id = `u{data.nextUnit}`
	data.nextUnit += 1
	data.units[id] = unit
	return id
end

-- Saves the player's save now and waits until a save has gone out in which `kept` finds what
-- it looks for (a purchase's id, say). True once one has; false when the player has left, or
-- after `seconds`. A purchase is told to Roblox as granted only once it is safe in the
-- DataStore: a server that went down in between would otherwise lose it.
function Data.saveAndWait(player: Player, kept: (saved: any) -> boolean, seconds: number): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	local done = false
	local connection = profile.OnAfterSave:Connect(function(saved)
		if kept(saved) then
			done = true
		end
	end)
	profile:Save()
	local deadline = os.clock() + seconds
	while not done and os.clock() < deadline and profiles[player] == profile do
		task.wait(0.1)
	end
	connection:Disconnect()
	return done
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
	Saves.bring(profile.Data)
	-- Shinobi that have left the roster since this save was written become their replacements.
	Roster.migrate(profile.Data.units, profile.Data.found)
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
	if RunService:IsStudio() then
		-- ProfileStore itself reports that data "will be saved" whenever Studio has API access.
		print("[Data] Studio test session: saves are kept in memory and end with it")
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(release)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

return Data
