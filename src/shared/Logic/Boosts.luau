--!strict
-- Combines game passes, active potions, the Bingo Book bonus and what the player's rebirths
-- pay into multipliers.
-- Everything stacks multiplicatively. Kick milestone luck is applied on top at kick time.

local Catalog = require("../Config/Catalog")
local Rebirth = require("./Rebirth")

local Boosts = {}

export type Multipliers = {
	ryo: number,
	chakra: number,
	luck: number,
	mutationLuck: number,
}

export type State = {
	passes: { [string]: boolean }, -- game pass key -> owned
	potions: { [string]: number }, -- potion id -> expiry, unix seconds
	now: number,
	indexBonus: number, -- e.g. 0.1 for +10%
	rebirths: number, -- how many the player has done
}

local function apply(m: Multipliers, effect: string, factor: number)
	if effect == "ryo" then
		m.ryo *= factor
	elseif effect == "chakra" then
		m.chakra *= factor
	elseif effect == "luck" then
		m.luck *= factor
	elseif effect == "mutationLuck" then
		m.mutationLuck *= factor
	end
end

-- Game pass key -> the multiplier it doubles. Keys match Config/Products.
local PASSES: { [string]: string } = {
	DoubleRyo = "ryo",
	DoubleChakra = "chakra",
	DoubleLuck = "luck",
	DoubleMutationLuck = "mutationLuck",
}

function Boosts.compute(state: State): Multipliers
	local m: Multipliers = {
		ryo = (1 + state.indexBonus) * Rebirth.ryo(state.rebirths),
		chakra = Rebirth.chakra(state.rebirths),
		luck = 1,
		mutationLuck = Rebirth.mutationLuck(state.rebirths),
	}
	for key, effect in PASSES do
		if state.passes[key] then
			apply(m, effect, 2)
		end
	end
	for potionId, expiresAt in state.potions do
		local potion = Catalog.potionById[potionId]
		if potion and expiresAt > state.now then
			apply(m, potion.effect, potion.multiplier)
		end
	end
	return m
end

-- New expiry after buying a potion: extends an active one, starts fresh otherwise.
function Boosts.extend(expiresAt: number?, now: number, minutes: number): number
	return math.max(expiresAt or 0, now) + minutes * 60
end

return Boosts
