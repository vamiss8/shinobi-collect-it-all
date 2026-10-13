--!strict
-- The rebirths, in the order they are done: the Chakra each asks for, the rank a player holds
-- once it is done with the color it is written in, and what a player who has done it is paid
-- for good, as multipliers of the dojo's Ryo, of the Chakra of every rep of training, and of
-- the chance of a mutation.
--
-- A rebirth starts a player over: their Chakra, their shinobi, their Ryo and their run speed
-- go, and they climb the zones again, faster each time for what the rebirths pay. Their kunai,
-- the pads and floors of their dojo and their Bingo Book stay (Logic/Rebirth.apply).
--
-- A RANK STARTS WITH RUN SPEED OF ITS OWN (owner, 2026-10-13: "at certain ranks let a certain
-- speed be bought already, and let the rebirth window say so before the rebirth: starts with
-- Gate of..., speed N"). `startSpeed` is the level of run speed a rebirth leaves its player
-- with instead of none: each is the level of a stage of Config/SpeedStages, one stage a rank
-- from the second rank on, so the window can name it. It is always well short of what the
-- zone that rank was earned in asks for: a reborn player skips the nearest zones they have
-- long outgrown and still has speed to buy on the way back.
--
-- The Chakra asked for goes up tenfold a rebirth, as in every game of this kind: the first
-- comes minutes into the game and the last few are long goals. Ryo goes x2, x3, x4, a tenth
-- is added to mutation luck each time, and Chakra a quarter. The last three ask for more
-- Chakra than the lane has any use for and than the best kunai can train in a sane time, so
-- from the seventh on the Chakra paid jumps: it stands in for the kunai there are not
-- (`lune run sim` prints when each rebirth is done).
--
-- The colors run from plain to hot, and the last four ranks are lettered as well
-- (Config/Lettering `titles`): the higher the rank, the more it shows.
--
-- To add a rebirth, add a line: nothing else counts them. A player's count of rebirths is
-- stored in saves: ranks and what is paid may change, the order may not, and a rebirth may
-- not be taken out from under players who have done it.

export type Rebirth = {
	chakra: number, -- what it asks
	title: string,
	color: string, -- hex
	-- What a player who has done this rebirth (and not yet the next) has multiplied.
	ryo: number,
	power: number, -- Chakra from a rep of training
	mutationLuck: number,
	-- The level of run speed (Tuning.Speed) a player starts this rank with.
	startSpeed: number,
}

local Rebirths: { Rebirth } = {
	{
		chakra = 1e3,
		title = "Genin",
		color = "#9CCC65",
		ryo = 2,
		power = 1.25,
		mutationLuck = 1.1,
		startSpeed = 0,
	},
	{
		chakra = 1e4,
		title = "Chunin",
		color = "#4FC3F7",
		ryo = 3,
		power = 1.5,
		mutationLuck = 1.2,
		startSpeed = 2,
	},
	{
		chakra = 1e5,
		title = "Special Jonin",
		color = "#7986CB",
		ryo = 4,
		power = 1.75,
		mutationLuck = 1.3,
		startSpeed = 4,
	},
	{
		chakra = 1e6,
		title = "Jonin",
		color = "#BA68C8",
		ryo = 5,
		power = 2,
		mutationLuck = 1.4,
		startSpeed = 8,
	},
	{
		chakra = 1e7,
		title = "ANBU",
		color = "#F06292",
		ryo = 6,
		power = 2.25,
		mutationLuck = 1.5,
		startSpeed = 12,
	},
	{
		chakra = 1e8,
		title = "ANBU Captain",
		color = "#FFCA28",
		ryo = 7,
		power = 2.5,
		mutationLuck = 1.6,
		startSpeed = 16,
	},
	{
		chakra = 1e9,
		title = "Sannin",
		color = "#FF7043",
		ryo = 8,
		power = 7,
		mutationLuck = 1.7,
		startSpeed = 20,
	},
	{
		chakra = 1e10,
		title = "Kage",
		color = "#FF5252",
		ryo = 9,
		power = 30,
		mutationLuck = 1.8,
		startSpeed = 24,
	},
	{
		chakra = 1e11,
		title = "Sage",
		color = "#FFD54F",
		ryo = 10,
		power = 150,
		mutationLuck = 1.9,
		startSpeed = 28,
	},
	{
		chakra = 1e12,
		title = "Sage of Six Paths",
		color = "#FFF8E1",
		ryo = 11,
		power = 500,
		mutationLuck = 2,
		startSpeed = 32,
	},
}

return Rebirths
