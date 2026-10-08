--!strict
-- How the name of a mutation or of a rank is written when a plain color is not enough for it:
-- on the tag over a shinobi, on its card and in the Bingo Book (client/Lettering draws it and
-- keeps it moving).
--
-- THE RARER, THE MORE THE LETTERS DO (owner, 2026-10-08: "for Rinnegan and Six Paths the
-- writing is quite dull... the last stage must not be written simply in white. For Storm, a
-- little lightning on the text; for Six Paths something dark, with an aura; for Lava an orange
-- that shimmers a little; and so on. The further, the cooler"). Chakra and Kurama he said to
-- leave as they are, and the ranks below SSS keep their plain colors: a name not listed here
-- is written in the color its config gives it.
--
-- Colors are hex strings rather than Color3 so this module also loads under Lune.

-- What the letters do:
--   "sheen"  a glint of light passes over them now and again
--   "flow"   their colors run through them without a stop, like something molten
--   "storm"  they flicker white and a bolt of lightning crosses them
--   "ripple" bands of color spread out from the middle of the word, ring after ring
--   "aura"   a glint, and the letters' own shapes rise off them like flame (in the color
--            `shade`, when that is not to be the glint's)
export type Motion = "sheen" | "flow" | "storm" | "ripple" | "aura"

export type Style = {
	fill: { string }, -- the letters' colors, across the word
	edge: string, -- their outline
	flare: string, -- what passes over the letters or comes off them: glint, flash, flame
	shade: string?,
	motion: Motion,
	period: number, -- seconds for the motion to come round once
}

local Lettering = {}

local MUTATIONS: { [string]: Style } = {
	-- Ice with light running over it.
	ice = {
		fill = { "#B3E5FC", "#E1F5FE", "#81D4FA", "#E1F5FE" },
		edge = "#0B3C5D",
		flare = "#FFFFFF",
		motion = "sheen",
		period = 3.2,
	},
	-- Molten rock: reds, orange and yellow running through the word.
	lava = {
		fill = { "#DD2C00", "#FF6D00", "#FFD600", "#FF6D00" },
		edge = "#3E0A00",
		flare = "#FFF59D",
		motion = "flow",
		period = 2.6,
	},
	-- A violet sky that lightning cracks across.
	storm = {
		fill = { "#7C4DFF", "#B388FF", "#D1C4E9", "#9575FF" },
		edge = "#12063A",
		flare = "#F3E5F5",
		motion = "storm",
		period = 1.8,
	},
	-- The rings of the Rinnegan, spreading from the middle of the word.
	rinnegan = {
		fill = { "#EDE7F6", "#7E57C2", "#D1C4E9", "#5E35B1" },
		edge = "#1A0F33",
		flare = "#B39DDB",
		motion = "ripple",
		period = 2.8,
	},
	-- Pale as bone, edged in black, a glint of gold, and black flame rising off it.
	six_paths = {
		fill = { "#FFFFFF", "#B0BEC5", "#FFFFFF", "#90A4AE" },
		edge = "#000000",
		flare = "#FFD54F",
		shade = "#0E0A14",
		motion = "aura",
		period = 2.2,
	},
	-- The red moon.
	tsukuyomi = {
		fill = { "#FF1744", "#FF5252", "#FF8A80", "#E53935" },
		edge = "#2A0000",
		flare = "#FF8A80",
		motion = "ripple",
		period = 3.6,
	},
	-- Red clouds drifting on black.
	akatsuki = {
		fill = { "#E53935", "#FF5252", "#B71C1C", "#FF5252" },
		edge = "#000000",
		flare = "#FFCDD2",
		motion = "flow",
		period = 4,
	},
	-- Gold leaves in the sun.
	leaf_festival = {
		fill = { "#FFD54F", "#AED581", "#FFE082", "#FFB300" },
		edge = "#1B5E20",
		flare = "#FFFDE7",
		motion = "sheen",
		period = 3.6,
	},
}

local RANKS: { [string]: Style } = {
	-- Cyan with a glint of white passing over it.
	SSS = {
		fill = { "#00E5FF", "#84FFFF", "#00B8D4", "#18FFFF" },
		edge = "#00363F",
		flare = "#FFFFFF",
		motion = "sheen",
		period = 2.6,
	},
	-- The last rank: the Sage's gold, a glint of white, and gold flame rising off it.
	SixPaths = {
		fill = { "#FFF8E1", "#FFD54F", "#FFFFFF", "#FFB300" },
		edge = "#3E2A00",
		flare = "#FFFFFF",
		shade = "#FFD54F",
		motion = "aura",
		period = 2.6,
	},
	-- The legendary shinobi (Config/Legends): amber and gold in rings from the word's middle.
	Legend = {
		fill = { "#FFE57F", "#FFAB00", "#FFF8E1", "#FF8F00" },
		edge = "#4A1500",
		flare = "#FFFFFF",
		motion = "ripple",
		period = 3,
	},
}

-- The ranks players hold for their rebirths (Config/Rebirths), by how many rebirths the rank
-- takes. The four highest: below them a rank is its plain color.
local TITLES: { [string]: Style } = {
	-- Sannin: red with a glint.
	["7"] = {
		fill = { "#FF7043", "#FFAB91", "#FF5722", "#FF8A65" },
		edge = "#3E0A00",
		flare = "#FFFFFF",
		motion = "sheen",
		period = 2.8,
	},
	-- Kage: the fire of a village's shadow, running through the word.
	["8"] = {
		fill = { "#FF3D00", "#FF9100", "#FFEA00", "#FF9100" },
		edge = "#3E0A00",
		flare = "#FFF59D",
		motion = "flow",
		period = 2.4,
	},
	-- Sage: gold in rings going out from the middle.
	["9"] = {
		fill = { "#FFF8E1", "#FFB300", "#FFE082", "#FF8F00" },
		edge = "#3E2A00",
		flare = "#FFFFFF",
		motion = "ripple",
		period = 2.8,
	},
	-- Sage of Six Paths: bone white and gold, a glint of gold, and black flame rising off it.
	["10"] = {
		fill = { "#FFFFFF", "#FFE082", "#FFFFFF", "#CFD8DC" },
		edge = "#000000",
		flare = "#FFD54F",
		shade = "#0E0A14",
		motion = "aura",
		period = 2.2,
	},
}

Lettering.mutations = MUTATIONS
Lettering.ranks = RANKS
Lettering.titles = TITLES

local SEPARATOR = ":"

-- The key of the lettering a mutation's or a rank's name is written in, or nil when it is
-- written in its plain color. The key is what a label is marked with for the client to find.
function Lettering.key(kind: "mutation" | "rank" | "title", id: string): string?
	local styles = if kind == "mutation" then MUTATIONS elseif kind == "rank" then RANKS else TITLES
	return if styles[id] then kind .. SEPARATOR .. id else nil
end

-- The lettering a key stands for; nil for a key nobody gave out.
function Lettering.style(key: string): Style?
	local kind, id = string.match(key, "^(%a+)" .. SEPARATOR .. "(.+)$")
	if kind == "mutation" then
		return MUTATIONS[id :: string]
	elseif kind == "rank" then
		return RANKS[id :: string]
	elseif kind == "title" then
		return TITLES[id :: string]
	end
	return nil
end

return Lettering
