--!strict
-- What a player's rebirths are worth and what the next one asks (Config/Rebirths).
--
-- A rebirth is offered once the player's Chakra reaches what it asks. Taking it starts them
-- over, Chakra, shinobi, Ryo and run speed (`apply` has exactly what), and what it pays is for
-- good and grows with every rebirth.

local Legends = require("../Config/Legends")
local Rebirths = require("../Config/Rebirths")

local Rebirth = {}

-- The shinobi a rebirth leaves alone: the legendary ones, by character id.
local KEPT: { [string]: boolean } = {}
for _, legend in Legends do
	KEPT[legend.id] = true
end

-- What a player who has done no rebirth is called, and the color it is written in.
Rebirth.FIRST_TITLE = "Academy Student"
Rebirth.FIRST_COLOR = "#BDBDBD"
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

-- The color the rank of a player who has done `count` rebirths is written in, hex.
function Rebirth.color(count: number?): string
	local last = Rebirths[Rebirth.done(count)]
	return if last then last.color else Rebirth.FIRST_COLOR
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

-- The fields of a save a rebirth touches.
export type Save = {
	rebirths: number,
	chakra: number,
	ryo: number,
	speedLevel: number,
	runAt: number,
	units: { [string]: any },
	pads: { [string]: string },
}

-- Does a rebirth on a save, in place: one more is counted, and the player starts over. Gone
-- are their Chakra, every shinobi they threw for (on a pad or not), their Ryo and their run
-- speed. (Ryo goes with the rest: kept, it would buy the run speed straight back, and the way
-- to rebirth would be to sell the dojo first.) Left alone are their kunai, the pads and floors
-- they have bought, their Bingo Book, their potions and their count of throws, and the
-- legendary shinobi (Config/Legends), which stay on their pads at the levels bought for them:
-- they were paid for in Robux, and the first rebirths come within minutes. Whoever calls this
-- has checked that the rebirth may be done.
function Rebirth.apply(save: Save)
	save.rebirths = Rebirth.done(save.rebirths) + 1
	save.chakra = Rebirth.START_CHAKRA
	save.ryo = 0
	save.speedLevel = 0
	save.runAt = -1
	for unitId, unit in save.units do
		if not KEPT[unit.character] then
			save.units[unitId] = nil
		end
	end
	for pad, unitId in save.pads do
		if not save.units[unitId] then
			save.pads[pad] = nil
		end
	end
end

return Rebirth
