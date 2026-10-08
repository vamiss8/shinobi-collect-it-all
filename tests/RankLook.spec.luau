--!strict
-- What a rank shows on its holder (Logic/RankLook): the orbs behind their back.
local RankLook = require("../src/shared/Logic/RankLook")
local Rebirth = require("../src/shared/Logic/Rebirth")
local T = require("./harness")

return {
	["a player who has done no rebirth has no orbs"] = function()
		T.eq(RankLook.of(0), nil)
		T.eq(RankLook.of(nil), nil)
		T.eq(RankLook.of(-2), nil)
	end,

	["the first rank has one orb, and no rank more than the Sage's nine"] = function()
		local first = RankLook.of(1) :: RankLook.Look
		T.eq(first.orbs, 1)
		for count = 1, Rebirth.count() do
			local look = RankLook.of(count) :: RankLook.Look
			T.ok(look.orbs >= 1 and look.orbs <= RankLook.MOST_ORBS, `{count}: {look.orbs} orbs`)
			T.eq(look.color, Rebirth.color(count), "the orbs are of the rank's color")
		end
	end,

	-- The owner's rule for everything a rank shows: the higher, the more.
	["a higher rank shows more: never fewer orbs, each larger, turning faster"] = function()
		for count = 2, Rebirth.count() do
			local before = RankLook.of(count - 1) :: RankLook.Look
			local look = RankLook.of(count) :: RankLook.Look
			T.ok(look.orbs >= before.orbs, `rank {count} has fewer orbs`)
			T.ok(look.size > before.size, `rank {count}'s orbs are no larger`)
			T.ok(look.spin > before.spin, `rank {count}'s wheel turns no faster`)
			T.ok(look.tail or not before.tail, `rank {count} lost its tails`)
			-- Something has to tell two ranks apart besides the color.
			local more = look.orbs > before.orbs or look.dark ~= before.dark
			T.ok(more, `rank {count} looks like the one before but for its color`)
		end
	end,

	["orbs stay small beside a character, and the highest ranks' leave tails"] = function()
		for count = 1, Rebirth.count() do
			local look = RankLook.of(count) :: RankLook.Look
			T.ok(look.size >= 0.4 and look.size <= 0.8, `rank {count}: orbs {look.size} wide`)
			T.eq(look.tail, count >= RankLook.TAILS_FROM)
		end
		local last = RankLook.of(Rebirth.count()) :: RankLook.Look
		T.ok(last.dark, "the last rank's orbs are the Sage's black ones")
		T.eq(last.orbs, RankLook.MOST_ORBS)
		T.ok(not (RankLook.of(Rebirth.count() - 1) :: RankLook.Look).dark)
	end,
}
