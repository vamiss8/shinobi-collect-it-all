--!strict
-- Characters that have left the roster, and who took each one's place. A save made before the
-- change still names the old ones; when it loads they are turned into their replacements
-- (Logic/Roster), so nobody's shinobi or Bingo Book entries are lost.
-- An id on the left must never come back as a character.

local Replaced: { [string]: string } = {
	-- 2026-10-06: these six chase the player as zone enemies, so they stopped being drops.
	mizuki = "ebisu",
	zabuza = "tazuna",
	sasuke_curse_mark = "kimimaro",
	itachi = "zetsu", -- was Kabuto, who left in turn
	pain = "hinata_shippuden",
	obito = "shisui",
	-- 2026-10-18: Kabuto keeps the potion cart on the plaza (Config/Keepers), and one Kabuto
	-- is enough: Zetsu drops in his place.
	kabuto = "zetsu",
}

return Replaced
