--!strict
-- Stretches of the lane, one per rank. A throw lands in the farthest zone whose `chakra` it
-- reaches, and the deeper into that zone the closer its power is to the next zone's (see
-- Logic/Kick); `startsAt` only says where the zone lies on the lane. A zone drops its own rank,
-- with a small chance of the next rank up that grows towards its far end (see Tuning.Zones).
-- Lower ranks never drop. The zone's enemy chases the player home, faster the farther in the
-- kunai fell (see Logic/Chase). Zones must be listed in ascending `chakra`, `startsAt` and rank.
-- A zone's id also names its scenery (World/Scenery), its lighting (client Mood) and its enemy's
-- model ("enemy_<id>", see View/Figure).

export type Enemy = {
	name: string,
	speed: number, -- studs per second at the zone's start; compare with Tuning.Speed
	color: string,
}

export type Zone = {
	id: string,
	name: string,
	chakra: number, -- Chakra a throw needs to reach the zone
	startsAt: number, -- where the zone begins on the lane, studs
	color: string, -- lane color, hex
	rank: string, -- the rank this zone drops
	enemy: Enemy,
}

local Zones: { Zone } = {
	{
		id = "academy",
		name = "Academy Grounds",
		chakra = 1,
		startsAt = 0,
		color = "#8BC34A",
		rank = "D",
		enemy = { name = "Mizuki", speed = 14, color = "#B0BEC5" },
	},
	{
		id = "land_of_waves",
		name = "Land of Waves",
		chakra = 50,
		startsAt = 100,
		color = "#4FC3F7",
		rank = "C",
		enemy = { name = "Demon of the Mist", speed = 18, color = "#455A64" },
	},
	{
		id = "forest_of_death",
		name = "Forest of Death",
		chakra = 400,
		startsAt = 220,
		color = "#2E7D32",
		rank = "B",
		enemy = { name = "Giant Snake", speed = 22, color = "#6A1B9A" },
	},
	{
		id = "chunin_exam_finals",
		name = "Chunin Exam Finals",
		chakra = 3_000,
		startsAt = 360,
		color = "#E0D2A8",
		rank = "A",
		enemy = { name = "Shukaku", speed = 25, color = "#C9A66B" },
	},
	{
		id = "valley_of_the_end",
		name = "Valley of the End",
		chakra = 22_000,
		startsAt = 520,
		color = "#A1887F",
		rank = "A+",
		enemy = { name = "Cursed Sasuke", speed = 29, color = "#4527A0" },
	},
	{
		id = "hidden_sand",
		name = "Hidden Sand",
		chakra = 160_000,
		startsAt = 700,
		color = "#F2B33D",
		rank = "S",
		enemy = { name = "Sasori's Puppet", speed = 33, color = "#3E2723" },
	},
	{
		id = "akatsuki_lair",
		name = "Akatsuki Lair",
		chakra = 1_200_000,
		startsAt = 900,
		color = "#B71C1C",
		rank = "S+",
		enemy = { name = "Amaterasu", speed = 37, color = "#1C1C1C" },
	},
	{
		id = "hidden_rain",
		name = "Hidden Rain",
		chakra = 9_000_000,
		startsAt = 1120,
		color = "#546E7A",
		rank = "SS",
		enemy = { name = "Pain", speed = 41, color = "#FF6F00" },
	},
	{
		id = "kamui_dimension",
		name = "Kamui Dimension",
		chakra = 65_000_000,
		startsAt = 1340,
		color = "#4A4E8C",
		rank = "SSS",
		enemy = { name = "Obito (Masked Man)", speed = 45, color = "#283593" },
	},
	{
		id = "great_ninja_war",
		name = "Great Ninja War",
		chakra = 500_000_000,
		startsAt = 1570,
		color = "#37474F",
		rank = "SixPaths",
		enemy = { name = "Ten-Tails", speed = 49, color = "#880E4F" },
	},
}

return Zones
