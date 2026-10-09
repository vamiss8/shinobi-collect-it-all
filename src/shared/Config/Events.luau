--!strict
-- The events: stretches of a few minutes during which every catch has a chance of a mutation
-- that drops at no other time (Config/Mutations, by `mutation`), and the whole world shows it:
-- the sky changes, something comes down out of it, and something hangs in it.
--
-- WHEN ONE RUNS IS THE CLOCK'S DOING, not a server's (Logic/Events): time is cut into slots of
-- `slotMinutes`, and whether a slot has an event, and which, follows from the slot's number
-- alone. So every server of the game is in the same event at the same moment, and friends on
-- two servers can talk about it. `weight` is how often an event is the one that comes, against
-- the others and against `quiet`, a slot with none; the rarer the event, the better the
-- mutation it brings. An event starts with its slot and lasts `minutes`.
--
-- What an event looks like is data too, so that the three are told apart at a glance: the
-- tint of the picture (`sky`), what falls or drifts everywhere (`weather`, as a zone's:
-- Config/ZoneArt), and what is in the sky (`shows`, which the client builds: a moon, a ceiling
-- of cloud, fireworks). Colors are hex strings rather than Color3 so this loads under Lune.

local ZoneArt = require("./ZoneArt")

-- How the picture is tinted while an event runs, as a ColorCorrectionEffect has it.
export type Sky = {
	tint: string,
	brightness: number,
	contrast: number,
	saturation: number,
}

export type Event = {
	id: string, -- as Config/Mutations names it
	name: string,
	mutation: string, -- the mutation that drops while it runs
	weight: number,
	minutes: number,
	color: string, -- of its seal, its timer and the flash that announces it
	shows: "moon" | "clouds" | "fireworks",
	sky: Sky,
	weather: ZoneArt.Weather,
}

local list: { Event } = {
	-- The commonest: gold leaves coming down everywhere and fireworks over the village.
	{
		id = "leaf_festival",
		name = "Leaf Festival",
		mutation = "leaf_festival",
		weight = 40,
		minutes = 6,
		color = "#FFB300",
		shows = "fireworks",
		sky = { tint = "#FFF1CC", brightness = 0.04, contrast = 0.04, saturation = 0.18 },
		weather = {
			texture = "sparkle",
			direction = "down",
			rate = 26,
			life = { 5, 7 },
			speed = { 3, 6 },
			spread = 40,
			size = { 1.1, 0.8 },
			squash = 0,
			streaks = false,
			spin = 200,
			glow = 0.35,
			fade = 0.05,
			color = "#FFC947",
			wind = { 2, 1 },
			fall = 1.5,
			box = { 130, 4, 130 },
			shift = { 0, 34, 0 },
		},
	},
	-- Red clouds close over the sky and black feathers come down out of them.
	{
		id = "akatsuki_raid",
		name = "Akatsuki Raid",
		mutation = "akatsuki",
		weight = 22,
		minutes = 6,
		color = "#D32F2F",
		shows = "clouds",
		sky = { tint = "#D9B8B8", brightness = -0.08, contrast = 0.14, saturation = -0.3 },
		weather = {
			texture = "smoke",
			direction = "down",
			rate = 16,
			life = { 5, 7 },
			speed = { 4, 7 },
			spread = 25,
			size = { 0.9, 0.5 },
			squash = 1.4,
			streaks = false,
			spin = 140,
			glow = 0,
			fade = 0.1,
			color = "#1A1014",
			wind = { -3, 2 },
			fall = 2.5,
			box = { 130, 4, 130 },
			shift = { 0, 34, 0 },
		},
	},
	-- The rarest: a red moon in a red sky, and red light rising off the ground towards it.
	{
		id = "blood_moon",
		name = "Blood Moon",
		mutation = "tsukuyomi",
		weight = 10,
		minutes = 5,
		color = "#FF1744",
		shows = "moon",
		sky = { tint = "#FF9E9E", brightness = -0.1, contrast = 0.18, saturation = -0.1 },
		weather = {
			texture = "sparkle",
			direction = "up",
			rate = 22,
			life = { 4, 6 },
			speed = { 2, 4 },
			spread = 20,
			size = { 0.8, 0.2 },
			squash = 0,
			streaks = false,
			spin = 90,
			glow = 0.9,
			fade = 0.05,
			color = "#FF3D55",
			wind = { 0, 0 },
			fall = -0.6,
			box = { 130, 4, 130 },
			shift = { 0, -4, 0 },
		},
	},
}

return {
	list = list,
	-- A slot of the clock: one event at the most begins with each.
	slotMinutes = 20,
	-- How often a slot has no event, against the events' weights.
	quiet = 28,
}
