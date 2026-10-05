--!strict
local Boosts = require("../src/shared/Logic/Boosts")
local T = require("./harness")

local EPS = 1e-9
local NOW = 1_000_000

local function state(
	passes: { [string]: boolean },
	potions: { [string]: number },
	bonus: number?
): Boosts.State
	return { passes = passes, potions = potions, now = NOW, indexBonus = bonus or 0 }
end

return {
	["nothing owned means x1 everywhere"] = function()
		local m = Boosts.compute(state({}, {}))
		T.eq(m.ryo, 1)
		T.eq(m.chakra, 1)
		T.eq(m.luck, 1)
		T.eq(m.mutationLuck, 1)
	end,

	["each pass doubles its own multiplier"] = function()
		local m = Boosts.compute(state({ DoubleLuck = true, DoubleMutationLuck = true }, {}))
		T.eq(m.luck, 2)
		T.eq(m.mutationLuck, 2)
		T.eq(m.ryo, 1, "untouched")
	end,

	["active potions apply and expired ones do not"] = function()
		local m = Boosts.compute(state({}, { gama_charm = NOW + 60, ichiraku_ramen = NOW - 1 }))
		T.eq(m.luck, 2)
		T.eq(m.ryo, 1)
	end,

	["pass, potion and book bonus stack multiplicatively"] = function()
		local m = Boosts.compute(state({ DoubleRyo = true }, { ichiraku_ramen = NOW + 60 }, 0.1))
		T.near(m.ryo, 1.1 * 2 * 2, EPS)
	end,

	["buying a potion extends an active one and restarts an expired one"] = function()
		T.eq(Boosts.extend(nil, NOW, 15), NOW + 900)
		T.eq(Boosts.extend(NOW + 100, NOW, 15), NOW + 1000)
		T.eq(Boosts.extend(NOW - 5, NOW, 15), NOW + 900)
	end,
}
