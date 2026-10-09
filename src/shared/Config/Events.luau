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
--
-- AN EVENT LOOKS THE SAME AT ANY HOUR (owner, 2026-10-09: "the night changes the colors of
-- the effects during events; let the beauty of an event not depend on the time of day"). The
-- village has a day and a night of five minutes each, so an event of five minutes always ran
-- through both, and its tint lay now on a sunlit plaza and now on a blue night. So an event
-- has a `light` of its own, which the village is held in for as long as it runs (client Mood):
-- the clock is turned to the event's hour when it begins and let go when it ends, the lanterns
-- with it. The festival is always an evening, the raid a gray afternoon, the moon a red night.
-- The other zones never went by the hour: they keep their own light under the tint.

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
	-- The light the village is held in while the event runs, whatever its own hour.
	light: ZoneArt.Light,
	weather: ZoneArt.Weather,
}

-- One of the village's hours with what an event changes in it.
local function lit(hour: ZoneArt.Light, changes: { [string]: any }): ZoneArt.Light
	local full: { [string]: any } = table.clone(hour :: any)
	for key, value in changes do
		full[key] = value
	end
	return full :: any
end

local list: { Event } = {
	-- The commonest: gold leaves coming down everywhere and fireworks over the village, on an
	-- evening just after sunset, with every lantern lit.
	{
		id = "leaf_festival",
		name = "Leaf Festival",
		mutation = "leaf_festival",
		weight = 44,
		minutes = 5,
		color = "#FFB300",
		shows = "fireworks",
		sky = { tint = "#FFF1CC", brightness = 0.04, contrast = 0.04, saturation = 0.18 },
		light = lit(ZoneArt.hours.sunset, {
			clock = 18.7,
			ambient = "#5A4E4A",
			outdoor = "#A08A7C",
			air = "#F2B08C",
			decay = "#B8705E",
		}),
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
	-- Red clouds close over the sky and black feathers come down out of them, on an afternoon
	-- gone gray under them.
	{
		id = "akatsuki_raid",
		name = "Akatsuki Raid",
		mutation = "akatsuki",
		weight = 20,
		minutes = 5,
		color = "#D32F2F",
		shows = "clouds",
		sky = { tint = "#D9B8B8", brightness = -0.08, contrast = 0.14, saturation = -0.3 },
		light = lit(ZoneArt.hours.noon, {
			clock = 14,
			brightness = 2.3,
			ambient = "#4C484A",
			outdoor = "#8C8686",
			air = "#B4AAAC",
			decay = "#6A585C",
			density = 0.36,
			haze = 2.2,
			glare = 0,
			tint = "#F4E8E8",
			saturation = -0.08,
			rays = 0,
		}),
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
	-- The rarest: the moon turned red in a red night, and red light rising off the ground
	-- towards it. A night's sky light is blue, and a red tint on blue is a dark violet: here it
	-- is red to begin with.
	{
		id = "crimson_moon",
		name = "Crimson Moon",
		mutation = "tsukuyomi",
		weight = 10,
		minutes = 5,
		color = "#FF1744",
		shows = "moon",
		sky = { tint = "#FF9E9E", brightness = -0.05, contrast = 0.16, saturation = -0.05 },
		light = lit(ZoneArt.hours.night, {
			clock = 0,
			brightness = 2.2,
			exposure = 0.25,
			ambient = "#74444C",
			outdoor = "#8C4C58",
			air = "#5C2632",
			decay = "#3A101C",
			density = 0.3,
			haze = 1,
			tint = "#FFDADA",
			saturation = 0.04,
			contrast = 0.06,
			bloom = 1.3,
			bloomThreshold = 1.4,
		}),
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
	-- A slot of the clock: one event at the most begins with each. With the weights above a
	-- Leaf Festival comes about every 27 minutes, an Akatsuki Raid every hour and a Crimson
	-- Moon every two (owner, 2026-10-09: "a little more often: the festival every 25 to 30
	-- minutes, the raid every hour, the moon every two"), and an event fills half its slot, so
	-- that two never run into each other.
	slotMinutes = 10,
	-- How often a slot has no event, against the events' weights.
	quiet = 46,
}
