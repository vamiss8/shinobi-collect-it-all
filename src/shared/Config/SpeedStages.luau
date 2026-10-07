--!strict
-- Run speed, Might Guy's way. Speed is bought in levels (Tuning.Speed); every few levels the
-- runner reaches a new stage: plain feet first, then laps, then training weights like Rock
-- Lee's, then heavier ones, then the Eight Gates, for which the weights come off and the last
-- of which is the top level. The stage is named in the window of the Youth Training Ground
-- (client Stores/SpeedStore), a new one is announced on screen (client StageFlash), its gate
-- has a lantern lit for every Gate opened (client GateLanterns), and it shows on the character
-- for everyone to see (Services/SpeedLook).
--
-- WHAT A STAGE SHOWS IS ONLY EVER PUT ON: weights strapped to the legs and wrists, and what
-- comes off a runner, dust, steam, sparks, a trail. Nothing of the player's own character is
-- changed or hidden, so it works on any avatar. No two stages show the same: every one has
-- something the one before it did not.
--
-- The stages come about four levels apart, which is what a zone asks for, so a runner fast
-- enough for the next zone has, as a rule, a new stage to show for it.

-- One thing a stage puts on the runner (Services/SpeedLook has what each looks like).
export type Wear =
	"dust" -- kicked up at the feet while running
	| "warmers" -- cloth round the shins
	| "weights" -- an iron band on each shin
	| "heavy" -- a second iron band under it
	| "wrists" -- cuffs and iron bands on the forearms
	| "steam" -- rising off the body, thicker with every Gate
	| "trail" -- a ribbon behind the runner, longer with every Gate
	| "motes" -- small lights rising round the body
	| "flame" -- licking up from the feet
	| "sparks" -- cracking off the body every way
	| "streaks" -- a ribbon from each hand
	| "fan" -- a fan of sparks thrown back while running
	| "burst" -- steam blasted out at the feet while running
	| "embers" -- drifting up high overhead

export type Stage = {
	name: string,
	level: number, -- the speed level that reaches it
	gate: number, -- 1..8 for the Eight Gates, 0 before them
	color: string, -- hex: of the cloth, or of everything that comes off the runner
	wears: { Wear },
}

local STAGES: { Stage } = {
	{ name = "Beginner", level = 0, gate = 0, color = "#BDBDBD", wears = {} },
	{ name = "Morning Laps", level = 2, gate = 0, color = "#D7CCC8", wears = { "dust" } },
	{
		name = "Training Weights",
		level = 4,
		gate = 0,
		color = "#FF8F00",
		wears = { "warmers", "weights", "dust" },
	},
	{
		name = "Heavy Weights",
		level = 8,
		gate = 0,
		color = "#F4511E",
		wears = { "warmers", "weights", "heavy", "wrists", "dust" },
	},
	-- The weights come off, and the first Gate opens: green, as far as the fifth.
	{
		name = "Gate of Opening",
		level = 12,
		gate = 1,
		color = "#76FF9A",
		wears = { "steam", "trail" },
	},
	{
		name = "Gate of Healing",
		level = 16,
		gate = 2,
		color = "#5CF08C",
		wears = { "steam", "trail", "motes" },
	},
	{
		name = "Gate of Life",
		level = 20,
		gate = 3,
		color = "#42E68A",
		wears = { "steam", "trail", "motes", "flame" },
	},
	{
		name = "Gate of Pain",
		level = 24,
		gate = 4,
		color = "#2BE39A",
		wears = { "steam", "trail", "motes", "flame", "sparks" },
	},
	{
		name = "Gate of Limit",
		level = 28,
		gate = 5,
		color = "#1DE9B6",
		wears = { "steam", "trail", "motes", "flame", "sparks", "streaks" },
	},
	-- Blue for the sixth and the seventh.
	{
		name = "Gate of View",
		level = 32,
		gate = 6,
		color = "#40C4FF",
		wears = { "steam", "trail", "motes", "flame", "sparks", "streaks", "fan" },
	},
	{
		name = "Gate of Wonder",
		level = 36,
		gate = 7,
		color = "#448AFF",
		wears = { "steam", "trail", "motes", "flame", "sparks", "streaks", "fan", "burst" },
	},
	-- And red for the last.
	{
		name = "Gate of Death",
		level = 40,
		gate = 8,
		color = "#FF1744",
		wears = {
			"steam",
			"trail",
			"motes",
			"flame",
			"sparks",
			"streaks",
			"fan",
			"burst",
			"embers",
		},
	},
}

local SpeedStages = {}

SpeedStages.list = STAGES
SpeedStages.GATES = 8

-- The stage a runner at speed `level` has reached, and its place in the list.
function SpeedStages.at(level: number): (Stage, number)
	local index = 1
	for i, stage in STAGES do
		if level >= stage.level then
			index = i
		end
	end
	return STAGES[index], index
end

-- The next stage up from speed `level`, or nil once the last Gate is open.
function SpeedStages.after(level: number): Stage?
	local _, index = SpeedStages.at(level)
	return STAGES[index + 1]
end

-- Whether a stage shows the given thing on its runner.
function SpeedStages.wears(stage: Stage, wear: Wear): boolean
	return table.find(stage.wears, wear) ~= nil
end

return SpeedStages
