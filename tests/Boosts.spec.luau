--!strict
local Boosts = require("../src/shared/Logic/Boosts")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

local EPS = 1e-9
local NOW = 1_000_000

local function state(
	passes: { [string]: boolean },
	potions: { [string]: number },
	bonus: number?,
	rebirths: number?
): Boosts.State
	return {
		passes = passes,
		potions = potions,
		now = NOW,
		indexBonus = bonus or 0,
		rebirths = rebirths or 0,
	}
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

	-- The Daimyo's VIP: more income on top of x2 Ryo, and more of it while away.
	["the VIP pass adds to income and to what is earned away, and to nothing else"] = function()
		local vip = Boosts.compute(state({ Vip = true, DoubleRyo = true }, {}))
		T.near(vip.ryo, 2 * Tuning.Shop.vipIncome, EPS)
		T.eq(vip.chakra, 1)
		T.eq(vip.luck, 1)
		T.eq(vip.mutationLuck, 1)
		T.ok(Tuning.Shop.vipIncome > 1 and Tuning.Shop.vipIncome < 2, "VIP should be under x2 Ryo")
		T.eq(Boosts.offline({ Vip = true }), Tuning.Shop.vipOffline)
		T.eq(Boosts.offline({ DoubleRyo = true }), 1)
		-- Half the dojo's income away, and no more than all of it with the pass.
		T.ok(Tuning.Dojo.offlineRate * Tuning.Shop.vipOffline <= 1, "away pays more than at home")
	end,

	["buying a potion extends an active one and restarts an expired one"] = function()
		T.eq(Boosts.extend(nil, NOW, 15), NOW + 900)
		T.eq(Boosts.extend(NOW + 100, NOW, 15), NOW + 1000)
		T.eq(Boosts.extend(NOW - 5, NOW, 15), NOW + 900)
	end,
}
