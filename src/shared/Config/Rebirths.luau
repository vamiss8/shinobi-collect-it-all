--!strict
-- The rebirths, in the order they are done: the Chakra each asks for, the title a player holds
-- once it is done, and what a player who has done it is paid for good, as multipliers of the
-- dojo's Ryo, of the Chakra of every rep of training, and of the chance of a mutation. A
-- rebirth takes the player's Chakra back to where a new player starts and nothing else
-- (Logic/Rebirth).
--
-- The Chakra asked for goes up tenfold a rebirth, as in every game of this kind: the first
-- comes minutes into the game and the last few are long goals. Ryo goes x2, x3, x4, a tenth
-- is added to mutation luck each time, and Chakra a quarter, which is what makes the way back
-- to the zone a player was throwing into short. The last three ask for more Chakra than the
-- lane has any use for and than the best kunai can train in a sane time, so from the seventh
-- on the Chakra paid jumps: it stands in for the kunai there are not (`lune run sim` prints
-- when each rebirth is done).
--
-- To add a rebirth, add a line: nothing else counts them. A player's count of rebirths is
-- stored in saves: titles and what is paid may change, the order may not, and a rebirth may
-- not be taken out from under players who have done it.

export type Rebirth = {
	chakra: number, -- what it asks
	title: string,
	-- What a player who has done this rebirth (and not yet the next) has multiplied.
	ryo: number,
	power: number, -- Chakra from a rep of training
	mutationLuck: number,
}

local Rebirths: { Rebirth } = {
	{ chakra = 1e3, title = "Genin", ryo = 2, power = 1.25, mutationLuck = 1.1 },
	{ chakra = 1e4, title = "Chunin", ryo = 3, power = 1.5, mutationLuck = 1.2 },
	{ chakra = 1e5, title = "Special Jonin", ryo = 4, power = 1.75, mutationLuck = 1.3 },
	{ chakra = 1e6, title = "Jonin", ryo = 5, power = 2, mutationLuck = 1.4 },
	{ chakra = 1e7, title = "ANBU", ryo = 6, power = 2.25, mutationLuck = 1.5 },
	{ chakra = 1e8, title = "ANBU Captain", ryo = 7, power = 2.5, mutationLuck = 1.6 },
	{ chakra = 1e9, title = "Sannin", ryo = 8, power = 7, mutationLuck = 1.7 },
	{ chakra = 1e10, title = "Kage", ryo = 9, power = 30, mutationLuck = 1.8 },
	{ chakra = 1e11, title = "Sage", ryo = 10, power = 150, mutationLuck = 1.9 },
	{ chakra = 1e12, title = "Sage of Six Paths", ryo = 11, power = 500, mutationLuck = 2 },
}

return Rebirths
