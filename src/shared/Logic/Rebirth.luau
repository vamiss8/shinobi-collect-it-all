--!strict
-- What a player's rebirths are worth and what the next one asks (Config/Rebirths).
--
-- A rebirth is offered once the player's Chakra reaches what it asks. Taking it puts their
-- Chakra back to a new player's and leaves everything else as it is: kunai, shinobi, Ryo, run
-- speed, the dojo, the Bingo Book. What it pays is for good, and grows with every rebirth.

local Rebirths = require("../Config/Rebirths")

local Rebirth = {}

-- What a player who has done no rebirth is called.
Rebirth.FIRST_TITLE = "Academy Student"
-- The Chakra a rebirth leaves a player with: what a new player starts with (the save's
-- template has the same), which is what a throw into the first zone asks.
Rebirth.START_CHAKRA = 1

-- How many rebirths there are to do.
function Rebirth.count(): number
	return #Rebirths
end

-- A player's count of rebirths as the game takes it: a whole number, no more than there are.
function Rebirth.done(count: number?): number
	return math.clamp(math.floor(count or 0), 0, #Rebirths)
end

-- The rebirth a player who has done `count` of them does next; nil when all are done.
function Rebirth.next(count: number?): Rebirths.Rebirth?
	return Rebirths[Rebirth.done(count) + 1]
end

-- The title of a player who has done `count` rebirths.
function Rebirth.title(count: number?): string
	local last = Rebirths[Rebirth.done(count)]
	return if last then last.title else Rebirth.FIRST_TITLE
end

-- Whether a player with this much Chakra may do their next rebirth.
function Rebirth.ready(chakra: number, count: number?): boolean
	local following = Rebirth.next(count)
	return following ~= nil and chakra >= following.chakra
end

-- How far towards the next rebirth this much Chakra is, 0..1; 1 when there is none left.
function Rebirth.progress(chakra: number, count: number?): number
	local following = Rebirth.next(count)
	return if following then math.clamp(chakra / following.chakra, 0, 1) else 1
end

-- What `count` rebirths multiply: the dojo's Ryo, the Chakra of a rep of training, and the
-- chance of a mutation. Nothing, for a player who has done none.
function Rebirth.ryo(count: number?): number
	local last = Rebirths[Rebirth.done(count)]
	return if last then last.ryo else 1
end

function Rebirth.chakra(count: number?): number
	local last = Rebirths[Rebirth.done(count)]
	return if last then last.power else 1
end

function Rebirth.mutationLuck(count: number?): number
	local last = Rebirths[Rebirth.done(count)]
	return if last then last.mutationLuck else 1
end

return Rebirth
