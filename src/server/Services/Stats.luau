--!strict
-- Numbers derived from a save: multipliers, unlocked pads, income.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.Shared.Logic.Boosts)
local Data = require("../Data")
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Index = require(ReplicatedStorage.Shared.Logic.Index)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Stats = {}

function Stats.multipliers(data: Data.Data): Boosts.Multipliers
	return Boosts.compute({
		passes = data.passes,
		potions = data.potions,
		now = os.time(),
		indexBonus = Index.incomeBonus(data.found),
		rebirths = data.rebirths,
	})
end

-- The pads open: the free ones, those bought for Ryo, and the pass's four, which count from
-- the moment the pass is bought (the next pad for Ryo then comes after them).
function Stats.unlockedPads(data: Data.Data): number
	local d = Tuning.Dojo
	return d.startPads + data.padsBought + (if data.passes.ExtraPads then d.gamePassPads else 0)
end

-- Ryo per second from every unit standing on a pad, with multipliers.
function Stats.income(data: Data.Data): number
	local total = 0
	for _, unitId in data.pads do
		local unit = data.units[unitId]
		if unit then
			total += Economy.unitIncome(unit)
		end
	end
	return total * Stats.multipliers(data).ryo
end

return Stats
