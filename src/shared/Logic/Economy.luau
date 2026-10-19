--!strict
-- Income, merging, upgrading and prices.

local Catalog = require("../Config/Catalog")
local Tuning = require("../Config/Tuning")

local Economy = {}

-- One owned shinobi. It grows two ways: `level` starts at 1 and goes up by merging two alike;
-- `upgrade` counts the upgrades bought for Ryo (absent in older saves, which means none).
export type Unit = {
	character: string,
	mutation: string,
	level: number,
	upgrade: number?,
}

-- Ryo per second of a unit at its first level: character, mutation and merges, without bought
-- upgrades. This is the unit's own worth, the number to compare two units by: a level can be
-- bought for any of them.
function Economy.baseIncome(unit: Unit): number
	local character = Catalog.characterById[unit.character]
	if not character then
		return 0
	end
	return character.income
		* Catalog.mutationMultiplier(unit.mutation)
		* Tuning.Dojo.mergeMultiplier ^ (unit.level - 1)
end

-- Ryo per second of one unit, before global multipliers. Upgrades compound.
function Economy.unitIncome(unit: Unit): number
	return Economy.baseIncome(unit) * Tuning.Upgrade.incomeGrowth ^ (unit.upgrade or 0)
end

-- How many times its own height a shinobi with this many upgrades stands (Tuning.Upgrade): 1
-- with none, and never quite `tallest`.
function Economy.growth(upgrades: number?): number
	local u = Tuning.Upgrade
	local bought = math.clamp(upgrades or 0, 0, u.maxUpgrades)
	return 1 + (u.tallest - 1) * (1 - math.exp(-bought / u.growthLevels))
end

-- Price of the unit's next upgrade, or nil when it is maxed out. Prices scale with what the
-- unit earns, so upgrading a rare unit costs more and gives more.
function Economy.upgradePrice(unit: Unit): number?
	local bought = unit.upgrade or 0
	if bought >= Tuning.Upgrade.maxUpgrades then
		return nil
	end
	local u = Tuning.Upgrade
	return Economy.baseIncome(unit) * u.costSeconds * u.costGrowth ^ bought
end

-- Price of the unit's next `count` upgrades bought together, and how many of them there are:
-- fewer than asked for when the unit is near its top level.
function Economy.upgradesPrice(unit: Unit, count: number): (number, number)
	local u = Tuning.Upgrade
	local bought = unit.upgrade or 0
	local levels = math.clamp(math.floor(count), 0, math.max(u.maxUpgrades - bought, 0))
	local first = Economy.baseIncome(unit) * u.costSeconds * u.costGrowth ^ bought
	-- Each upgrade costs `costGrowth` times the one before: the sum of a geometric series.
	return first * (u.costGrowth ^ levels - 1) / (u.costGrowth - 1), levels
end

-- How many upgrades in a row `ryo` pays for, and what they cost together.
function Economy.affordableUpgrades(unit: Unit, ryo: number): (number, number)
	local u = Tuning.Upgrade
	local left = u.maxUpgrades - (unit.upgrade or 0)
	local first = Economy.upgradesPrice(unit, 1)
	if left <= 0 or first <= 0 or ryo < first then
		return 0, 0
	end
	-- The series solved for the count; rounding can leave it one off either way.
	local levels =
		math.floor(math.log(ryo * (u.costGrowth - 1) / first + 1) / math.log(u.costGrowth))
	levels = math.clamp(levels, 1, left)
	while levels > 1 and Economy.upgradesPrice(unit, levels) > ryo do
		levels -= 1
	end
	while levels < left and Economy.upgradesPrice(unit, levels + 1) <= ryo do
		levels += 1
	end
	return levels, (Economy.upgradesPrice(unit, levels))
end

-- The unit after `count` more upgrades (one if not given).
function Economy.upgraded(unit: Unit, count: number?): Unit
	return {
		character = unit.character,
		mutation = unit.mutation,
		level = unit.level,
		upgrade = (unit.upgrade or 0) + (count or 1),
	}
end

-- Two units merge when they are the same character with the same mutation at the same merge
-- level. Bought upgrades do not have to match.
function Economy.canMerge(a: Unit, b: Unit): boolean
	return a.character == b.character and a.mutation == b.mutation and a.level == b.level
end

-- The pads a unit could be merged on: every pad whose unit is its twin (Economy.canMerge), in
-- order, none if there is none. `pads` is a save's pad number (as a string) -> unit id,
-- `units` its units by id. Asked for units that are not on a pad themselves.
function Economy.twinPads(
	unit: Unit,
	units: { [string]: Unit },
	pads: { [string]: string }
): { number }
	local found: { number } = {}
	for key, unitId in pads do
		local other = units[unitId]
		local index = tonumber(key)
		if other and index and Economy.canMerge(unit, other) then
			table.insert(found, index)
		end
	end
	table.sort(found)
	return found
end

-- The unit two merged units become. It keeps the better of their bought upgrades.
function Economy.merged(a: Unit, b: Unit): Unit
	return {
		character = a.character,
		mutation = a.mutation,
		level = a.level + 1,
		upgrade = math.max(a.upgrade or 0, b.upgrade or 0),
	}
end

-- One merge to be made from the inventory (owner, 2026-10-19: "merge right in the inventory,
-- and show the choices: Madara + Madara = Madara with a star"): two of its units, `unit` and
-- `other`, or `unit` into its twin standing on `pad`. `result` is what they become; `count`
-- how many such merges there are to make (pairs of alike units in the inventory; 1 for a pad).
export type MergeOption = {
	unit: string,
	other: string?,
	pad: number?,
	result: Unit,
	count: number,
}

-- A save's units split for Economy.mergeOptions: those in the inventory by id, and those
-- standing on pads by pad number (a string, as `pads` keys them).
function Economy.sides(
	units: { [string]: Unit },
	pads: { [string]: string }
): ({ [string]: Unit }, { [string]: Unit })
	local placed: { [string]: boolean } = {}
	local onPads: { [string]: Unit } = {}
	for key, unitId in pads do
		local unit = units[unitId]
		if unit then
			placed[unitId] = true
			onPads[key] = unit
		end
	end
	local inventory: { [string]: Unit } = {}
	for unitId, unit in units do
		if not placed[unitId] then
			inventory[unitId] = unit
		end
	end
	return inventory, onPads
end

-- Every merge the inventory offers. For each kind of unit (shinobi, mutation, stars) it holds
-- two of: one merge of the most levelled with the least, which loses the fewest bought levels
-- (the merged unit keeps the better of the two). And for each pad whose unit is the twin of
-- one in the inventory: the inventory's most levelled one merged into it. The best first, by
-- what the merged unit earns; the same save always gives the same list, on the server and on
-- the client alike.
function Economy.mergeOptions(
	inventory: { [string]: Unit },
	onPads: { [string]: Unit }
): { MergeOption }
	local kinds: { [string]: { string } } = {}
	for unitId, unit in inventory do
		local key = `{unit.character}|{unit.mutation}|{unit.level}`
		local ids = kinds[key]
		if not ids then
			ids = {}
			kinds[key] = ids
		end
		table.insert(ids, unitId)
	end

	local options: { MergeOption } = {}
	for _, ids in kinds do
		table.sort(ids, function(a, b)
			local levelsA, levelsB = inventory[a].upgrade or 0, inventory[b].upgrade or 0
			if levelsA ~= levelsB then
				return levelsA > levelsB
			end
			return a < b
		end)
		local best = ids[1]
		local unit = inventory[best]
		if #ids >= 2 then
			local least = ids[#ids]
			table.insert(options, {
				unit = best,
				other = least,
				result = Economy.merged(unit, inventory[least]),
				count = #ids // 2,
			})
		end
		for key, padUnit in onPads do
			local pad = tonumber(key)
			if pad and Economy.canMerge(padUnit, unit) then
				table.insert(options, {
					unit = best,
					pad = pad,
					result = Economy.merged(padUnit, unit),
					count = 1,
				})
			end
		end
	end

	table.sort(options, function(a, b)
		local earnsA, earnsB = Economy.unitIncome(a.result), Economy.unitIncome(b.result)
		if earnsA ~= earnsB then
			return earnsA > earnsB
		end
		local padA, padB = a.pad or math.huge, b.pad or math.huge
		if padA ~= padB then
			return padA < padB
		end
		return a.unit < b.unit
	end)
	return options
end

-- Ryo paid for selling a unit.
function Economy.sellPrice(unit: Unit): number
	return math.floor(Economy.unitIncome(unit) * Tuning.Dojo.sellSeconds)
end

-- Price of the next purchase in a series that grows geometrically, after `bought` purchases.
function Economy.seriesPrice(base: number, growth: number, bought: number): number
	return math.floor(base * growth ^ bought + 0.5)
end

function Economy.padPrice(bought: number): number
	return Economy.seriesPrice(Tuning.Dojo.padBasePrice, Tuning.Dojo.padPriceGrowth, bought)
end

function Economy.maxPads(hasPadPass: boolean): number
	local d = Tuning.Dojo
	return d.startPads + d.buyablePads + (if hasPadPass then d.gamePassPads else 0)
end

function Economy.speedPrice(level: number): number
	return Economy.seriesPrice(Tuning.Speed.basePrice, Tuning.Speed.priceGrowth, level)
end

function Economy.walkSpeed(level: number): number
	return Tuning.Speed.base + Tuning.Speed.perLevel * math.clamp(level, 0, Tuning.Speed.maxLevel)
end

-- The speed level a player runs at. They may choose to run slower than they have bought, to
-- keep their feet on the plaza or to wear an earlier stage (Config/SpeedStages): `chosen` is
-- that level, or negative for "as fast as I have bought".
function Economy.runLevel(bought: number, chosen: number?): number
	if chosen and chosen >= 0 then
		return math.min(math.floor(chosen), bought)
	end
	return bought
end

-- Chakra per rep with the kunai at `kunaiIndex` (1 = the starting one).
function Economy.chakraPerRep(kunaiIndex: number): number
	local kunai = Catalog.kunai[math.clamp(kunaiIndex, 1, #Catalog.kunai)]
	return kunai.chakraPerRep
end

-- What the dojo earned while the player was away: a share of its income, for no longer than
-- the cap, so a few days off are rewarded and a month off is worth no more than that.
function Economy.offlineEarnings(perSecond: number, secondsAway: number): number
	local cap = Tuning.Dojo.offlineCapHours * 3600
	return perSecond * Tuning.Dojo.offlineRate * math.clamp(secondsAway, 0, cap)
end

return Economy
