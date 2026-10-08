--!strict
-- Lookup indexes over the static config, built once when first required.

local Characters = require("./Characters")
local Keepers = require("./Keepers")
local KunaiList = require("./Kunai")
local Legends = require("./Legends")
local Mutations = require("./Mutations")
local Potions = require("./Potions")
local Products = require("./Products")
local Ranks = require("./Ranks")
local Replaced = require("./Replaced")
local Tuning = require("./Tuning")
local Zones = require("./Zones")

export type Character = Characters.Character
export type Keeper = Keepers.Keeper
export type Kunai = KunaiList.Kunai
export type Legend = Legends.Legend
export type Mutation = Mutations.Mutation
export type Potion = Potions.Potion
export type Rank = Ranks.Rank
export type Zone = Zones.Zone

local Catalog = {}

-- Mutation id of a unit without a mutation.
Catalog.NONE = "none"

Catalog.ranks = Ranks
Catalog.characters = Characters
Catalog.mutations = Mutations
Catalog.zones = Zones
Catalog.kunai = KunaiList
Catalog.potions = Potions
-- The market's shopkeepers, who are not shinobi to collect.
Catalog.keepers = Keepers
-- Characters that left the roster -> who took their place (see Logic/Roster).
Catalog.replaced = Replaced
-- The legendary shinobi, bought for Robux. They are not of the roster (`characters`): no zone
-- drops them and the Bingo Book has no place for them. But whatever asks who a unit is finds
-- one in `characterById` like any other shinobi, under a rank of its own.
Catalog.legends = Legends
Catalog.legendRank = { id = "Legend", name = "Legendary", color = "#FFAB00" } :: Rank

Catalog.rankOrder = {} :: { [string]: number }
-- Every rank by its id: the ranks the zones drop, and the legendary one.
Catalog.rankById = { [Catalog.legendRank.id] = Catalog.legendRank } :: { [string]: Rank }
Catalog.legendById = {} :: { [string]: Legend }
Catalog.characterById = {} :: { [string]: Character }
Catalog.charactersByRank = {} :: { [string]: { Character } }
Catalog.mutationById = {} :: { [string]: Mutation }
Catalog.potionById = {} :: { [string]: Potion }
Catalog.zoneById = {} :: { [string]: Zone }
Catalog.zoneOrder = {} :: { [string]: number }
Catalog.keeperById = {} :: { [string]: Keeper }

for _, keeper in Keepers do
	Catalog.keeperById[keeper.id] = keeper
end

for i, rank in Ranks do
	Catalog.rankOrder[rank.id] = i
	Catalog.rankById[rank.id] = rank
	Catalog.charactersByRank[rank.id] = {}
end

for _, character in Characters do
	Catalog.characterById[character.id] = character
	local list = Catalog.charactersByRank[character.rank]
	if list then
		table.insert(list, character)
	end
end

for _, legend in Legends do
	Catalog.legendById[legend.id] = legend
	Catalog.characterById[legend.id] = {
		id = legend.id,
		name = legend.name,
		rank = Catalog.legendRank.id,
		income = legend.income,
	}
end

for _, mutation in Mutations do
	Catalog.mutationById[mutation.id] = mutation
end

for i, zone in Zones do
	Catalog.zoneById[zone.id] = zone
	Catalog.zoneOrder[zone.id] = i
end

for _, potion in Potions do
	Catalog.potionById[potion.id] = potion
end

-- The rank of a character, of the roster or legendary; nil for an id nobody has.
function Catalog.rankOf(characterId: string): Rank?
	local character = Catalog.characterById[characterId]
	return if character then Catalog.rankById[character.rank] else nil
end

-- Whether the character is one of the legendary shinobi.
function Catalog.isLegend(characterId: string): boolean
	return Catalog.legendById[characterId] ~= nil
end

-- The id of the game pass that sells a legendary shinobi; 0 for one whose pass is not made
-- yet, and for anyone else.
function Catalog.legendPass(characterId: string): number
	local legend = Catalog.legendById[characterId]
	for _, pass in Products.GamePasses do
		if legend and pass.key == legend.pass then
			return pass.assetId
		end
	end
	return 0
end

-- The zone a scroll landing at `distance` studs falls into.
function Catalog.zoneAt(distance: number): Zone
	local found = Zones[1]
	for _, zone in Zones do
		if distance >= zone.startsAt then
			found = zone
		end
	end
	return found
end

-- The zone that follows `zone` down the lane; nil for the last one.
function Catalog.zoneAfter(zone: Zone): Zone?
	local order = Catalog.zoneOrder[zone.id]
	return if order then Zones[order + 1] else nil
end

-- Where a zone ends: the start of the next one, or the end of the lane for the last.
function Catalog.zoneEnd(zone: Zone): number
	local following = Catalog.zoneAfter(zone)
	return if following then following.startsAt else Tuning.Kick.trackLength
end

-- How deep into `zone` a point `distance` studs down the lane is: 0 at its start, 1 at its end.
function Catalog.zoneProgress(zone: Zone, distance: number): number
	local finish = Catalog.zoneEnd(zone)
	return math.clamp((distance - zone.startsAt) / (finish - zone.startsAt), 0, 1)
end

-- The farthest zone a throw of this much power reaches.
function Catalog.zoneFor(power: number): Zone
	local found = Zones[1]
	for _, zone in Zones do
		if power >= zone.chakra then
			found = zone
		end
	end
	return found
end

-- The power that carries a throw to a zone's far end: the next zone's threshold, or for the
-- last zone a set multiple of its own.
function Catalog.zoneCeiling(zone: Zone): number
	local following = Catalog.zoneAfter(zone)
	return if following then following.chakra else zone.chakra * Tuning.Kick.lastZoneSpan
end

-- The rank one step above `rankId` that has characters to drop, if there is one.
function Catalog.nextRank(rankId: string): string?
	local order = Catalog.rankOrder[rankId]
	local nextRank = if order then Ranks[order + 1] else nil
	if nextRank and #Catalog.charactersByRank[nextRank.id] > 0 then
		return nextRank.id
	end
	return nil
end

function Catalog.mutationMultiplier(mutationId: string): number
	local mutation = Catalog.mutationById[mutationId]
	return if mutation then mutation.multiplier else 1
end

-- One star per merge, e.g. "★★" for a unit merged twice (merge level 3).
function Catalog.stars(level: number): string
	return string.rep("★", math.max(level - 1, 0))
end

-- One-line name of a unit for the hotbar and messages, e.g. "Kakashi [Ice] ★★ Lvl 3".
-- `level` is the merge level (1 = never merged), `upgrades` how many upgrades were bought.
function Catalog.unitTitle(
	characterId: string,
	mutationId: string,
	level: number,
	upgrades: number?
): string
	local character = Catalog.characterById[characterId]
	local text = if character then character.name else characterId
	local mutation = Catalog.mutationById[mutationId]
	if mutation then
		text ..= ` [{mutation.name}]`
	end
	if level > 1 then
		text ..= ` {Catalog.stars(level)}`
	end
	if upgrades and upgrades > 0 then
		text ..= ` Lvl {upgrades + 1}`
	end
	return text
end

-- Returns a list of problems with the config; empty means it is consistent.
function Catalog.validate(): { string }
	local problems = {}
	local function check(ok: boolean, message: string)
		if not ok then
			table.insert(problems, message)
		end
	end

	local seen: { [string]: boolean } = {}
	for _, c in Characters do
		check(not seen[c.id], `duplicate character id {c.id}`)
		seen[c.id] = true
		check(Catalog.rankOrder[c.rank] ~= nil, `character {c.id} has unknown rank {c.rank}`)
		check(c.income > 0, `character {c.id} has no income`)
	end
	for old, new in Replaced do
		check(not seen[old], `character {old} is listed as replaced but is still on the roster`)
		check(seen[new] or Replaced[new] ~= nil, `{old} is replaced by unknown character {new}`)
	end

	local passes: { [string]: boolean } = {}
	for _, pass in Products.GamePasses do
		passes[pass.key] = true
	end
	for _, legend in Legends do
		check(not seen[legend.id], `legendary shinobi {legend.id} is also on the roster`)
		check(Replaced[legend.id] == nil, `legendary shinobi {legend.id} is listed as replaced`)
		check(legend.income > 0, `legendary shinobi {legend.id} has no income`)
		check(passes[legend.pass] == true, `legendary shinobi {legend.id} has no game pass`)
	end

	for _, m in Mutations do
		check(m.id ~= Catalog.NONE, `mutation id "{Catalog.NONE}" is reserved`)
		check(m.chance >= 1, `mutation {m.id} has chance below 1 in 1`)
		check(m.multiplier > 1, `mutation {m.id} does not boost income`)
	end

	check(#Zones > 0, "no zones")
	check(Zones[1] ~= nil and Zones[1].startsAt == 0, "first zone must start at 0")
	-- A new save starts with 1 Chakra, and the distance math takes a logarithm of the threshold.
	check(
		Zones[1] ~= nil and Zones[1].chakra > 0 and Zones[1].chakra <= 1,
		"first zone must be reachable with 1 Chakra"
	)
	check(Tuning.Kick.lastZoneSpan > 1, "the last zone needs room past its threshold")
	for i, zone in Zones do
		if i > 1 then
			check(zone.startsAt > Zones[i - 1].startsAt, `zone {zone.id} is out of order`)
			check(
				zone.chakra > Zones[i - 1].chakra,
				`zone {zone.id} does not need more Chakra than the one before`
			)
		end
		local pool = Catalog.charactersByRank[zone.rank]
		check(pool ~= nil, `zone {zone.id} drops unknown rank {zone.rank}`)
		check(pool == nil or #pool > 0, `zone {zone.id} drops rank {zone.rank} with no characters`)
		if i > 1 then
			local order = Catalog.rankOrder[zone.rank] or 0
			local previous = Catalog.rankOrder[Zones[i - 1].rank] or 0
			check(
				order > previous,
				`zone {zone.id} does not drop a higher rank than the one before`
			)
		end
		check(zone.enemy.speed > 0, `zone {zone.id} has an enemy that cannot move`)
		if i > 1 then
			check(
				zone.enemy.speed >= Zones[i - 1].enemy.speed,
				`zone {zone.id} has a slower enemy than the one before`
			)
		end
	end

	for i, k in KunaiList do
		if i > 1 then
			check(
				k.price > KunaiList[i - 1].price,
				`kunai {k.id} is not pricier than the previous one`
			)
			check(
				k.chakraPerRep > KunaiList[i - 1].chakraPerRep,
				`kunai {k.id} is not stronger than the previous one`
			)
		end
	end

	return problems
end

return Catalog
