--!strict
-- Weighted rolls with luck: the rank a zone drops, the character, the mutation.
-- Callers pass numbers in [0, 1) from their own RNG, which keeps this deterministic in tests.

local Catalog = require("../Config/Catalog")
local Tuning = require("../Config/Tuning")

local Roll = {}

export type Entry = {
	id: string,
	weight: number,
}

export type Drop = {
	zone: string,
	rank: string,
	character: string,
	mutation: string,
}

-- Converts weights into probabilities and applies luck. A table is listed from the least
-- wanted entry to the most: every entry except the first has its chance multiplied by `luck`,
-- and the first takes whatever is left. When the boosted chances add up to more than 1 the
-- first drops out and the rest are served from the far end of the list: the most wanted keeps
-- all that its luck gave it and those before it give way, so that more luck is never spent on
-- more of the commonest thing.
function Roll.withLuck(entries: { Entry }, luck: number): { Entry }
	local total = 0
	for _, e in entries do
		total += e.weight
	end
	assert(total > 0, "roll table has no weight")

	local out: { Entry } = table.create(#entries)
	local left = 1
	for i = #entries, 2, -1 do
		local chance = math.min(entries[i].weight / total * luck, left)
		left -= chance
		out[i] = { id = entries[i].id, weight = chance }
	end
	out[1] = { id = entries[1].id, weight = math.max(left, 0) }
	return out
end

-- Picks an entry by weight.
function Roll.pick(entries: { Entry }, r: number): string
	local total = 0
	for _, e in entries do
		total += e.weight
	end
	local x = r * total
	for _, e in entries do
		if x < e.weight then
			return e.id
		end
		x -= e.weight
	end
	-- Float rounding can leave x a hair past the end; that belongs to the last real entry.
	for i = #entries, 1, -1 do
		if entries[i].weight > 0 then
			return entries[i].id
		end
	end
	error("roll table has no weight")
end

-- Chance of the next rank up for a throw that lands at `distance` inside `zone`: small at the
-- zone's start, growing in a straight line towards its far end.
function Roll.nextRankChance(zone: Catalog.Zone, distance: number): number
	local progress = Catalog.zoneProgress(zone, distance)
	local z = Tuning.Zones
	return z.nextRankAtStart + (z.nextRankAtEnd - z.nextRankAtStart) * progress
end

-- What a throw landing at `distance` inside `zone` can drop: the zone's own rank and, less
-- likely, the next rank up. Never a lower one.
function Roll.rankTable(zone: Catalog.Zone, distance: number): { Entry }
	local nextRank = Catalog.nextRank(zone.rank)
	if not nextRank then
		return { { id = zone.rank, weight = 1 } }
	end
	local chance = Roll.nextRankChance(zone, distance)
	return {
		{ id = zone.rank, weight = 1 - chance },
		{ id = nextRank, weight = chance },
	}
end

-- The last zone has no next rank to offer, so a throw deep into it pays in mutation luck
-- instead: none extra on its near edge, rising in a straight line to
-- Tuning.Zones.deepMutationLuck at the far end of the lane. Every other zone gives 1.
function Roll.depthMutationLuck(zone: Catalog.Zone, distance: number): number
	if Catalog.nextRank(zone.rank) then
		return 1
	end
	return 1 + (Tuning.Zones.deepMutationLuck - 1) * Catalog.zoneProgress(zone, distance)
end

-- Mutation chances, with "no mutation" first and then from the mutation that pays least to
-- the one that pays most, which is the order luck serves them in when there is more of it
-- than fits (Roll.withLuck). Event mutations join only while their event runs.
function Roll.mutationTable(activeEvent: string?): { Entry }
	local dropping = {}
	for _, m in Catalog.mutations do
		if m.event == nil or m.event == activeEvent then
			table.insert(dropping, m)
		end
	end
	table.sort(dropping, function(a, b)
		if a.multiplier ~= b.multiplier then
			return a.multiplier < b.multiplier
		end
		-- Of two that pay alike the rarer is the more wanted.
		if a.chance ~= b.chance then
			return a.chance < b.chance
		end
		return a.id < b.id
	end)
	local entries = { { id = Catalog.NONE, weight = 0 } }
	local sum = 0
	for _, m in dropping do
		local p = 1 / m.chance
		sum += p
		table.insert(entries, { id = m.id, weight = p })
	end
	entries[1].weight = math.max(1 - sum, 0)
	return entries
end

-- Luck bonus of the `spin`-th kick (counting from 1): every 10th, 20th, 100th and so on.
function Roll.spinLuck(spin: number): number
	if spin <= 0 then
		return 1
	end
	for _, m in Tuning.Luck.milestones do
		if spin % m.every == 0 then
			return m.luck
		end
	end
	return 1
end

-- How many kicks until the next lucky one after `spin` kicks, and the luck it will have.
function Roll.nextMilestone(spin: number): (number, number)
	local smallest = Tuning.Luck.milestones[#Tuning.Luck.milestones].every
	local left = smallest - spin % smallest
	return left, Roll.spinLuck(spin + left)
end

-- Multiplier of the next training bubble.
function Roll.bubble(r: number): number
	local entries: { Entry } = {}
	for _, bubble in Tuning.Training.bubbles do
		table.insert(entries, { id = tostring(bubble.multiplier), weight = bubble.weight })
	end
	return tonumber(Roll.pick(entries, r)) or 1
end

-- A character of the given rank, each equally likely.
function Roll.character(rankId: string, r: number): string
	local pool = Catalog.charactersByRank[rankId]
	assert(pool and #pool > 0, `no characters of rank {rankId}`)
	local i = math.min(math.floor(r * #pool) + 1, #pool)
	return pool[i].id
end

-- Everything a kunai landing at `distance` turns into. `rng` returns numbers in [0, 1). `luck`
-- multiplies the chance of the next rank up and `mutationLuck` that of every mutation; a lucky
-- throw is in both (Services/Kicking).
function Roll.drop(
	distance: number,
	luck: number,
	mutationLuck: number,
	activeEvent: string?,
	rng: () -> number
): Drop
	local zone = Catalog.zoneAt(distance)
	local rank = Roll.pick(Roll.withLuck(Roll.rankTable(zone, distance), luck), rng())
	local mutations = Roll.withLuck(
		Roll.mutationTable(activeEvent),
		mutationLuck * Roll.depthMutationLuck(zone, distance)
	)
	return {
		zone = zone.id,
		rank = rank,
		character = Roll.character(rank, rng()),
		mutation = Roll.pick(mutations, rng()),
	}
end

return Roll
