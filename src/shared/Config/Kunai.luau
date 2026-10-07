--!strict
-- Kunai sold at Tenten's Ninja Tools, bought in order. The best one owned is the one thrown: it
-- sets how the throw looks (color, glow, trail) and how much Chakra one rep of training gives
-- (a meditation tick pays a share of a rep, a ring press several). There are two for every
-- zone after the first: every second one triples the Chakra, the one between is halfway there.
-- Prices grow about six times a step, thirty-five a zone: that is how fast a dojo's income
-- grows from one zone to the next (see `lune run sim`), so the kunai that triples the Chakra
-- for zone N comes into reach about when zone N does.
-- Never reorder: saves store the index of the best owned kunai.

export type Kunai = {
	id: string,
	name: string,
	price: number,
	chakraPerRep: number,
	color: string, -- the blade, hex
	trail: string, -- the trail behind it in flight, hex
	glow: boolean, -- neon blade
}

local function kunai(
	id: string,
	name: string,
	price: number,
	chakraPerRep: number,
	color: string,
	trail: string,
	glow: boolean
): Kunai
	return {
		id = id,
		name = name,
		price = price,
		chakraPerRep = chakraPerRep,
		color = color,
		trail = trail,
		glow = glow,
	}
end

local Kunai: { Kunai } = {
	kunai("training", "Training Kunai", 0, 1, "#8D6E63", "#BCAAA4", false),
	kunai("iron", "Iron Kunai", 40, 2, "#78909C", "#CFD8DC", false),
	kunai("steel", "Steel Kunai", 250, 3, "#B0BEC5", "#ECEFF1", false),
	kunai("wire", "Wire Kunai", 1_500, 5, "#90A4AE", "#FFFFFF", false),
	kunai("explosive_tag", "Explosive Tag Kunai", 9_000, 9, "#FF7043", "#FFAB91", true),
	kunai("poison", "Poison Kunai", 50_000, 16, "#7B1FA2", "#CE93D8", true),
	kunai("chakra_blade", "Chakra Blade", 300_000, 27, "#4FC3F7", "#81D4FA", true),
	kunai("earth", "Earth Release Kunai", 1_800_000, 47, "#A1887F", "#D7CCC8", true),
	kunai("water", "Water Release Kunai", 10_000_000, 81, "#2979FF", "#82B1FF", true),
	kunai("wind", "Wind Release Kunai", 60_000_000, 140, "#A5D6A7", "#E8F5E9", true),
	kunai("fire", "Fire Release Kunai", 350_000_000, 243, "#FF3D00", "#FFEA00", true),
	kunai("lightning", "Lightning Release Kunai", 2_000_000_000, 420, "#7C4DFF", "#B388FF", true),
	kunai("wood", "Wood Release Kunai", 12_000_000_000, 729, "#558B2F", "#AED581", true),
	kunai("magnet", "Magnet Release Kunai", 75_000_000_000, 1_260, "#546E7A", "#FFD54F", true),
	kunai("scorch", "Scorch Release Kunai", 450_000_000_000, 2_187, "#FF6D00", "#FFF59D", true),
	kunai("dust", "Dust Release Kunai", 2_700_000_000_000, 3_800, "#E0F7FA", "#FFFFFF", true),
	kunai(
		"black_flame",
		"Black Flame Kunai",
		16_000_000_000_000,
		6_561,
		"#1B1B1B",
		"#D500F9",
		true
	),
	kunai(
		"thunder_god",
		"Flying Thunder God Kunai",
		95_000_000_000_000,
		11_400,
		"#FFEB3B",
		"#FFFFFF",
		true
	),
	kunai(
		"truth_seeking",
		"Truth-Seeking Kunai",
		550_000_000_000_000,
		19_683,
		"#212121",
		"#FFD54F",
		true
	),
}

return Kunai
