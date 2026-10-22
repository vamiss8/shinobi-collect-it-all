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
-- The Chakra asked for goes up tenfold a rebirth to the sixth, as in every game of this kind:
-- the first comes minutes into the game. Ryo goes x2, x3, x4, a tenth is added to mutation luck
-- each time, and Chakra a quarter.
--
-- FROM THE SEVENTH ON THE STEPS ARE SHORTER: 500M, 1.5B, 4B, 10B (owner, 2026-10-18: the
-- testers had reached the end of the game, 200 to 400 million Chakra with the seventh asking a
-- billion, and "the game slows down very much there and is no longer interesting"). They were
-- 1B, 10B, 100B and 1T, and paid x7, x30, x150 and x500 Chakra a rep, a jump that stood in for
-- kunai there are not on steps of ten. On steps of three that jump would bring the last three
-- within three and a half hours of one another, so the late ranks pay x4, x8, x14 and x25: each
-- climb then takes a little longer than the one before. By `lune run sim 220` the average
-- player is reborn the seventh time at 13 h 22 min (16 h 28 min before) and the tenth at 38 h
-- 37 min (202 h); the skilled one the tenth at 36 h 49 min (122 h). A throw goes no farther
-- than the lane's end, 2.8B (the last zone's threshold times Tuning.Kick.lastZoneSpan): the
-- last two ranks ask for Chakra past it, which only training can still use.
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
	-- The Roblox badge given to whoever reaches this rank (Services/Rebirth), 0 while it is
	-- not made. The community server's bot (Bloxlink) gives the rank's role by it (owner,
	-- 2026-10-21: roles by rebirths). Its picture is assets/icons/rank_<n>.png.
	badge: number,
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
		badge = 2110248816055154,
	},
	{
		chakra = 1e4,
		title = "Chunin",
		color = "#4FC3F7",
		ryo = 3,
		power = 1.5,
		mutationLuck = 1.2,
		startSpeed = 2,
		badge = 1681354550256701,
	},
	{
		chakra = 1e5,
		title = "Special Jonin",
		color = "#7986CB",
		ryo = 4,
		power = 1.75,
		mutationLuck = 1.3,
		startSpeed = 4,
		badge = 798646705511775,
	},
	{
		chakra = 1e6,
		title = "Jonin",
		color = "#BA68C8",
		ryo = 5,
		power = 2,
		mutationLuck = 1.4,
		startSpeed = 8,
		badge = 3303083990581159,
	},
	{
		chakra = 1e7,
		title = "ANBU",
		color = "#F06292",
		ryo = 6,
		power = 2.25,
		mutationLuck = 1.5,
		startSpeed = 12,
		badge = 970437408606454,
	},
	{
		chakra = 1e8,
		title = "ANBU Captain",
		color = "#FFCA28",
		ryo = 7,
		power = 2.5,
		mutationLuck = 1.6,
		startSpeed = 16,
		badge = 0,
	},
	{
		chakra = 5e8,
		title = "Sannin",
		color = "#FF7043",
		ryo = 8,
		power = 4,
		mutationLuck = 1.7,
		startSpeed = 20,
		badge = 0,
	},
	{
		chakra = 1.5e9,
		title = "Kage",
		color = "#FF5252",
		ryo = 9,
		power = 8,
		mutationLuck = 1.8,
		startSpeed = 24,
		badge = 0,
	},
	{
		chakra = 4e9,
		title = "Sage",
		color = "#FFD54F",
		ryo = 10,
		power = 14,
		mutationLuck = 1.9,
		startSpeed = 28,
		badge = 0,
	},
	{
		chakra = 1e10,
		title = "Sage of Six Paths",
		color = "#FFF8E1",
		ryo = 11,
		power = 25,
		mutationLuck = 2,
		startSpeed = 32,
		badge = 0,
	},
}

return Rebirths
