--!strict
-- The wire protocol: RemoteEvent names and the payloads that travel over them.
-- The server creates the events under ReplicatedStorage.Remotes at startup.

local Boosts = require("./Logic/Boosts")
local Economy = require("./Logic/Economy")
local Focus = require("./Logic/Focus")
local Index = require("./Logic/Index")

local Net = {}

Net.FOLDER = "Remotes"

Net.Events = {
	State = "State", -- server -> client: Snapshot
	Inventory = "Inventory", -- server -> client: Inventory
	Index = "Index", -- server -> client: Index.Found, the Bingo Book
	Hold = "Hold", -- client -> server: id of the unit to carry, or nil to put it away
	ThrowChakra = "ThrowChakra", -- client -> server: Chakra to throw with, 0 for all of it
	KickStart = "KickStart", -- server -> client: bar period in seconds
	KickPress = "KickPress", -- client -> server: seconds the client watched the bar
	KickResult = "KickResult", -- server -> client: KickResult, or nil if the bar was cancelled
	Flight = "Flight", -- server -> all clients: Flight
	Reveal = "Reveal", -- server -> thrower: Reveal
	RunStart = "RunStart", -- server -> client: RunStart
	RunEnd = "RunEnd", -- server -> client: RunEnd
	Bubble = "Bubble", -- server -> client: Bubble
	BubblePop = "BubblePop", -- client -> server: bubble id
	Ring = "Ring", -- server -> client: RingRound, the first ring after equipping the tool
	RingPress = "RingPress", -- client -> server: seconds the client watched the ring
	RingResult = "RingResult", -- server -> client: RingResult; its `next` ring starts on receipt
	Buy = "Buy", -- client -> server: "kunai" | "speed"
	Upgrade = "Upgrade", -- client -> server: the console button (a Part) the player pressed
	Sell = "Sell", -- client -> server: list of unit ids to sell out of the inventory
	Notify = "Notify", -- server -> client: a key from client/Strings plus format arguments
	Offline = "Offline", -- server -> client: Offline, once, when a returning player's save loads
	Collect = "Collect", -- client -> server: take the offline income the Offline message offered
}

-- Attribute on a stall's ProximityPrompt naming the shop window it opens on the client.
Net.SHOP_ATTRIBUTE = "Shop"
-- The folder in Workspace holding the shared part of the world, and its attribute with the
-- world position where the lane starts.
Net.HUB_FOLDER = "Hub"
Net.ORIGIN_ATTRIBUTE = "Origin"
-- Name of the part by the throwing strip that each client hangs its own luck board on.
Net.LUCK_BOARD = "LuckBoard"
-- Attributes on a button of an upgrade console, a Part at the foot of a pad: which button it
-- is ("one" | "ten" | "max"), and whether pressing it would buy anything right now. The client
-- finds the button under the pointer by these; the server decides what a press does.
Net.UPGRADE_ATTRIBUTE = "Upgrade"
Net.ACTIVE_ATTRIBUTE = "Active"
-- How close a player has to stand to press a console button, studs.
Net.PRESS_DISTANCE = 16
-- Folder in ReplicatedStorage with real models that replace the placeholder figures: a Model
-- named after a character id (Config/Characters), or "enemy_" plus a zone id (Config/Zones).
Net.MODELS_FOLDER = "Models"

-- The numbers the HUD and the store windows are drawn from. Sent on every change and once a
-- second with the income tick.
export type Snapshot = {
	ryo: number,
	income: number, -- Ryo per second with all multipliers applied
	chakra: number,
	kunai: number, -- index into Config/Kunai of the best owned kunai
	speedLevel: number,
	padsBought: number,
	spins: number,
	streak: number,
	held: string?, -- id of the unit being carried; look it up in the Inventory
	multipliers: Boosts.Multipliers,
	training: string?, -- "meditate" | "focus" while training
	trainBoost: number, -- multiplier from a popped bubble, 1 if none
	throwChakra: number, -- Chakra the player chose to throw with, 0 for all of it
}

-- Every owned unit that is not standing on a pad, by id. Sent whenever it changes.
export type Inventory = { [string]: Economy.Unit }

export type Found = Index.Found

export type KickResult = {
	grade: string,
	power: number, -- the share of the Chakra the press put into the throw, 0..1
	distance: number,
	sage: boolean,
	zone: string,
	luck: number, -- milestone luck of this throw, 1 if none
}

-- A kunai in the air. Every client draws it.
export type Flight = {
	thrower: number, -- UserId
	kunai: number, -- index into Config/Kunai: how it looks
	from: Vector3,
	to: Vector3,
	duration: number, -- seconds in the air
	height: number, -- peak of the arc above the straight line, studs
	linger: number, -- seconds the kunai stays where it landed
}

-- What the thrower's client needs to stage the reveal: the roulette where the kunai landed,
-- then a look at the enemy. Sent together with the Flight; all times are in seconds.
export type Reveal = {
	character: string,
	mutation: string,
	zone: string,
	at: Vector3, -- where the kunai lands
	enemyAt: Vector3, -- where the enemy will appear
	flight: number,
	roll: number,
	hold: number,
	intro: number,
}

-- The player has been teleported to the kunai and the zone's enemy is after them.
export type RunStart = {
	character: string,
	mutation: string,
	zone: string,
}

export type RunEnd = {
	escaped: boolean,
	character: string,
	mutation: string,
	zone: string,
	isNew: boolean, -- first time this character + mutation pair was found
	reward: number, -- Ryo: discovery reward on an escape, consolation when caught
}

-- What the dojo earned while the player was away. The Ryo wait to be collected: the server
-- pays them out on Collect, or by itself when the player leaves without collecting.
export type Offline = {
	earned: number, -- Ryo
	away: number, -- seconds since the player was last seen
}

export type Bubble = {
	id: number,
	multiplier: number,
	seconds: number, -- how long it stays on screen
}

-- One chakra-control ring: how fast it closes and where the target sits.
export type RingRound = Focus.Round

-- How a chakra-control press was graded and what it paid, and the ring that follows.
export type RingResult = {
	grade: string,
	gain: number, -- Chakra earned
	next: RingRound,
}

return Net
