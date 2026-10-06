--!strict
-- Plays the game as a scripted player and prints when each zone opens up, so the numbers in
-- Config can be tuned in minutes rather than in hours of play.
--   lune run sim        every profile, 40 hours of play
--   lune run sim 10     stop after 10 hours
--
-- The game's own math is used throughout (Logic/*), so the result follows the config. What is
-- modelled here is the player: how well they press, how they split their time and what they
-- buy (see PROFILES and `shop`). Only time spent playing counts: offline income, meditation,
-- game passes and potions are left out, and all of them make a real player faster than this.

local process = require("@lune/process")

local Catalog = require("../src/shared/Config/Catalog")
local Chase = require("../src/shared/Logic/Chase")
local DojoPlan = require("../src/shared/Logic/DojoPlan")
local Economy = require("../src/shared/Logic/Economy")
local Format = require("../src/shared/Logic/Format")
local Kick = require("../src/shared/Logic/Kick")
local Roll = require("../src/shared/Logic/Roll")
local T = require("../tests/harness")
local Tuning = require("../src/shared/Config/Tuning")

type Unit = Economy.Unit

type Profile = {
	name: string,
	ring: { number }, -- share of ring presses that are Perfect, Great and Good; the rest miss
	bar: { number }, -- the same for throws
	bubbles: number, -- share of the bonus bubbles they pop
	trainPerThrow: number, -- seconds on the ring between two throws
}

local PROFILES: { Profile } = {
	{
		name = "average",
		ring = { 0.25, 0.40, 0.25 },
		bar = { 0.25, 0.45, 0.20 },
		bubbles = 0.7,
		trainPerThrow = 30,
	},
	{
		name = "skilled",
		ring = { 0.60, 0.30, 0.10 },
		bar = { 0.60, 0.30, 0.10 },
		bubbles = 0.95,
		trainPerThrow = 30,
	},
}

-- Runs per profile; the middle one is reported, so one lucky mutation does not set the pace.
local SEEDS = 5

-- Time that goes on things the config does not describe, seconds.
local RING_OVERHEAD = 0.25 -- from a press to watching the next ring
local WALK_TO_STRIP = 6
local AIMING = 1.2 -- on the power bar
local DOJO = 8 -- carrying the catch to a pad and walking back
local MIN_LANDING = Tuning.Kick.stripDepth + 8 -- as in Services/Kicking

type Mark = { time: number, kunai: number, speed: number, income: number, chakra: number }

type Player = {
	time: number,
	chakra: number,
	kunai: number,
	speedLevel: number,
	padsBought: number,
	ryo: number,
	spins: number,
	streak: number,
	pads: { Unit },
	caught: number,
	reached: { [number]: number }, -- zone number -> when its threshold was first met
	caughtFirst: { [number]: Mark }, -- zone number -> the first shinobi brought home from it
	kunaiAt: { [number]: number }, -- kunai number -> when it was bought
	padAt: { [number]: number }, -- pads bought so far -> when the last of them was bought
	spent: { [string]: number }, -- what the Ryo went on
}

-- Reps of Chakra a second on the ring.
local function ringRate(profile: Profile): number
	local t = Tuning.Training
	local perPress = 0
	for i, grade in t.ringGrades do
		perPress += (profile.ring[i] or 0) * grade.reps
	end
	local wait = (t.ringPeriodMin + t.ringPeriodMax) / 2 * (t.ringTargetMin + t.ringTargetMax) / 2
	return perPress / (wait + RING_OVERHEAD)
end

-- What the bonus bubbles multiply training by, on average.
local function bubbleBoost(profile: Profile): number
	local t = Tuning.Training
	local weight, sum = 0, 0
	for _, bubble in t.bubbles do
		weight += bubble.weight
		sum += bubble.weight * bubble.multiplier
	end
	local cycle = t.bubbleSeconds + (t.bubbleEveryMin + t.bubbleEveryMax) / 2
	local uptime = math.min(t.boostSeconds / cycle, 1) * profile.bubbles
	return 1 + uptime * (sum / weight - 1)
end

-- Where on the bar a press of each grade lands: the middle of the grade's window.
local function barPosition(profile: Profile, r: number): number
	local grades = Tuning.Kick.grades
	local top = 1
	for i, grade in grades do
		local share = profile.bar[i] or 1
		if r < share or i == #grades then
			return (grade.from + top) / 2
		end
		r -= share
		top = grade.from
	end
	return 0
end

local function income(player: Player): number
	local total = 0
	for _, unit in player.pads do
		total += Economy.unitIncome(unit)
	end
	return total
end

local function pass(player: Player, seconds: number)
	player.ryo += income(player) * seconds
	player.time += seconds
end

-- The most Chakra worth throwing: all of it, unless the enemy out there would catch the
-- player. Then as much as still lands a throw from the top of the bar where they can get
-- away; a lower press only lands nearer.
local function aim(player: Player): number
	local speed = Economy.walkSpeed(player.speedLevel)
	-- A charged Sage throw carries farther; a careful player allows for it.
	local sage = if player.streak >= Tuning.Kick.sageStreak then Tuning.Kick.sageMultiplier else 1
	local function safe(power: number): boolean
		return Chase.escapesFrom(speed, Kick.distance(power * sage))
	end
	if safe(player.chakra) then
		return player.chakra
	end
	-- The enemy only gets faster down the lane, so the safe stretch has one far edge.
	local low, high = math.log(Catalog.zones[1].chakra), math.log(player.chakra)
	for _ = 1, 40 do
		local middle = (low + high) / 2
		if safe(math.exp(middle)) then
			low = middle
		else
			high = middle
		end
	end
	return math.exp(low)
end

-- Puts a new catch to use: merged into its twin, onto a free pad, or in place of the weakest
-- unit; whatever is left over is sold.
local function keep(player: Player, unit: Unit)
	local merged = true
	while merged do
		merged = false
		for i, other in player.pads do
			if Economy.canMerge(unit, other) then
				unit = Economy.merged(other, unit)
				table.remove(player.pads, i)
				merged = true
				break
			end
		end
	end

	if #player.pads < Tuning.Dojo.startPads + player.padsBought then
		table.insert(player.pads, unit)
		return
	end
	local weakest = 1
	for i, other in player.pads do
		if Economy.baseIncome(other) < Economy.baseIncome(player.pads[weakest]) then
			weakest = i
		end
	end
	if Economy.baseIncome(unit) > Economy.baseIncome(player.pads[weakest]) then
		player.ryo += Economy.sellPrice(player.pads[weakest])
		player.pads[weakest] = unit
	else
		player.ryo += Economy.sellPrice(unit)
	end
end

local function throw(player: Player, profile: Profile, rng: () -> number)
	local result = Kick.resolve(aim(player), barPosition(profile, rng()), player.streak)
	player.streak = result.streak
	player.spins += 1

	local distance = math.max(result.distance, MIN_LANDING)
	local drop = Roll.drop(result.distance, Roll.spinLuck(player.spins), 1, nil, rng)
	local zone = Catalog.zoneById[drop.zone]
	local unit: Unit = { character = drop.character, mutation = drop.mutation, level = 1 }

	local chase = Tuning.Chase
	local runSpeed = Economy.walkSpeed(player.speedLevel)
	local enemySpeed = Chase.enemySpeed(zone, distance)
	local staged = math.clamp(distance / 250, 0.8, 3.5)
		+ chase.rollSeconds
		+ chase.holdSeconds
		+ chase.introSeconds

	if Chase.escapes(runSpeed, enemySpeed, distance) then
		pass(player, WALK_TO_STRIP + AIMING + staged + distance / runSpeed + DOJO)
		keep(player, unit)
		local number = Catalog.zoneOrder[zone.id]
		if not player.caughtFirst[number] then
			player.caughtFirst[number] = {
				time = player.time,
				kunai = player.kunai,
				speed = player.speedLevel,
				income = income(player),
				chakra = player.chakra,
			}
		end
	else
		local headStart = chase.enemyGap - chase.catchRadius + enemySpeed * chase.enemyDelay
		pass(player, WALK_TO_STRIP + AIMING + staged + headStart / (enemySpeed - runSpeed))
		player.ryo += math.floor(Economy.unitIncome(unit) * chase.consolationSeconds)
		player.caught += 1
	end
end

-- Spends Ryo the way a sensible player would. They save for one thing at a time: run speed
-- when the enemy keeps them out of a zone their Chakra already reaches, otherwise the next
-- kunai. On the way they take any upgrade or pad that pays for itself before the thing they
-- are saving for is due.
local function shop(player: Player)
	local maxSpeed = Tuning.Speed.maxLevel
	while true do
		local perSecond = income(player)
		local nextKunai = Catalog.kunai[player.kunai + 1]
		local heldBack = Catalog.zoneFor(aim(player)) ~= Catalog.zoneFor(player.chakra)

		local goal: string? = nil
		local goalPrice = 0
		if player.speedLevel < maxSpeed and (heldBack or not nextKunai) then
			goal, goalPrice = "speed", Economy.speedPrice(player.speedLevel)
		elseif nextKunai then
			goal, goalPrice = "kunai", nextKunai.price
		end

		if goal and player.ryo >= goalPrice then
			player.ryo -= goalPrice
			player.spent[goal] += goalPrice
			if goal == "speed" then
				player.speedLevel += 1
			else
				player.kunai += 1
				player.kunaiAt[player.kunai] = player.time
			end
			continue
		end

		local due = if goal and perSecond > 0
			then (goalPrice - player.ryo) / perSecond
			else math.huge
		local bestPayback = due
		local bestPrice = 0
		local bestPad: number? = nil -- index of the unit to upgrade; 0 stands for a new pad

		for i, unit in player.pads do
			local price = Economy.upgradePrice(unit)
			if price and price <= player.ryo then
				local gain = Economy.unitIncome(Economy.upgraded(unit)) - Economy.unitIncome(unit)
				if price / gain < bestPayback then
					bestPayback, bestPrice, bestPad = price / gain, price, i
				end
			end
		end
		if player.padsBought < Tuning.Dojo.buyablePads and #player.pads > 0 then
			-- A new pad ends up earning about what the others do.
			local price = Economy.padPrice(player.padsBought)
			local gain = perSecond / #player.pads
			if price <= player.ryo and gain > 0 and price / gain < bestPayback then
				bestPayback, bestPrice, bestPad = price / gain, price, 0
			end
		end

		if not bestPad then
			return
		end
		player.ryo -= bestPrice
		player.spent[if bestPad == 0 then "pads" else "upgrades"] += bestPrice
		if bestPad == 0 then
			player.padsBought += 1
			player.padAt[player.padsBought] = player.time
		else
			player.pads[bestPad] = Economy.upgraded(player.pads[bestPad])
		end
	end
end

local function play(profile: Profile, seed: number, hours: number): Player
	local rng = T.rng(seed)
	local rate = ringRate(profile) * bubbleBoost(profile)
	local player: Player = {
		time = 0,
		chakra = 1,
		kunai = 1,
		speedLevel = 0,
		padsBought = 0,
		ryo = 0,
		spins = 0,
		streak = 0,
		pads = {},
		caught = 0,
		reached = { [1] = 0 },
		caughtFirst = {},
		kunaiAt = { [1] = 0 },
		padAt = {},
		spent = { kunai = 0, speed = 0, pads = 0, upgrades = 0 },
	}

	-- A new player throws first: the strip is the first thing they walk into.
	while player.time < hours * 3600 do
		throw(player, profile, rng)
		shop(player)
		player.chakra += rate * Economy.chakraPerRep(player.kunai) * profile.trainPerThrow
		pass(player, profile.trainPerThrow)
		for number, zone in Catalog.zones do
			if not player.reached[number] and player.chakra >= zone.chakra then
				player.reached[number] = player.time
			end
		end
		shop(player)
	end
	return player
end

local function clock(seconds: number?): string
	if not seconds then
		return "-"
	end
	local s = math.floor(seconds + 0.5)
	if s < 60 then
		return `{s}s`
	elseif s < 3600 then
		return `{s // 60}m {string.format("%02d", s % 60)}s`
	end
	return `{s // 3600}h {string.format("%02d", s % 3600 // 60)}m`
end

local function pad(text: string, width: number): string
	return text .. string.rep(" ", math.max(width - #text, 0))
end

local function row(cells: { string }, widths: { number }): string
	local out = {}
	for i, cell in cells do
		table.insert(out, pad(cell, widths[i]))
	end
	return table.concat(out, "  ")
end

-- The lowest speed level that gets a runner home from `distance` studs.
local function levelFor(distance: number): string
	for level = 0, Tuning.Speed.maxLevel do
		if Chase.escapesFrom(Economy.walkSpeed(level), distance) then
			return tostring(level)
		end
	end
	return "none"
end

local function printZones()
	local widths = { 2, 20, 9, 11, 12 }
	print("ZONES")
	print(row({ "#", "zone", "Chakra", "enemy", "speed level" }, widths))
	for number, zone in Catalog.zones do
		local finish = Catalog.zoneEnd(zone) - 0.01
		print(row({
			tostring(number),
			zone.name,
			Format.short(zone.chakra),
			`{Format.short(zone.enemy.speed)}-{Format.short(Chase.farSpeed(zone))}`,
			`{levelFor(zone.startsAt)}-{levelFor(finish)}`,
		}, widths))
	end
	print("")
end

-- Pad numbers worth reporting: the first one bought on each floor and the last one sold for Ryo.
local function padMilestones(): { number }
	local start = Tuning.Dojo.startPads
	local list = { start + 1 }
	for floor = 2, DojoPlan.FLOORS do
		local first = (floor - 1) * DojoPlan.PADS_PER_FLOOR + 1
		if first > start + 1 and first <= start + Tuning.Dojo.buyablePads then
			table.insert(list, first)
		end
	end
	table.insert(list, start + Tuning.Dojo.buyablePads)
	return list
end

local function printPrices()
	local kunai, speed, pads = {}, {}, {}
	for _, item in Catalog.kunai do
		table.insert(kunai, Format.short(item.price))
	end
	local speedTotal = 0
	for level = 0, Tuning.Speed.maxLevel - 1 do
		speedTotal += Economy.speedPrice(level)
		if level % 4 == 0 or level == Tuning.Speed.maxLevel - 1 then
			table.insert(speed, `L{level + 1} {Format.short(Economy.speedPrice(level))}`)
		end
	end
	-- The first pad for sale on each floor, and the last one.
	for _, index in padMilestones() do
		local bought = index - Tuning.Dojo.startPads - 1
		table.insert(pads, `#{index} {Format.short(Economy.padPrice(bought))}`)
	end
	print("PRICES")
	print(`kunai: {table.concat(kunai, ", ")}`)
	print(`speed: {table.concat(speed, ", ")}  (all levels: {Format.short(speedTotal)})`)
	print(`pads:  {table.concat(pads, ", ")}`)
	print("")
end

local function printProfile(profile: Profile, hours: number)
	local runs: { Player } = {}
	for seed = 1, SEEDS do
		table.insert(runs, play(profile, seed * 977, hours))
	end

	-- The run whose last zone opened at the middle time stands for the profile.
	local function progress(player: Player): number
		local zones, last = 0, 0
		for _, mark in player.caughtFirst do
			zones += 1
			last = math.max(last, mark.time)
		end
		return zones * 1e9 - last
	end
	table.sort(runs, function(a, b)
		return progress(a) > progress(b)
	end)
	local player = runs[(SEEDS + 1) // 2]

	print(
		`PROFILE {profile.name}: {string.format("%.2f", ringRate(profile))} reps a second on the ring,`
			.. ` x{string.format("%.2f", bubbleBoost(profile))} from bubbles,`
			.. ` {profile.trainPerThrow} s of training per throw`
	)
	local widths = { 2, 20, 11, 11, 6, 6, 10 }
	print(row({ "#", "zone", "Chakra met", "first home", "kunai", "speed", "income/s" }, widths))
	for number, zone in Catalog.zones do
		local mark = player.caughtFirst[number]
		print(row({
			tostring(number),
			zone.name,
			clock(player.reached[number]),
			clock(if mark then mark.time else nil),
			if mark then tostring(mark.kunai) else "-",
			if mark then tostring(mark.speed) else "-",
			if mark then Format.short(mark.income) else "-",
		}, widths))
	end

	local bought = {}
	for number = 2, #Catalog.kunai do
		table.insert(bought, clock(player.kunaiAt[number]))
	end
	print(`kunai bought at: {table.concat(bought, ", ")}`)
	local pads = {}
	for _, index in padMilestones() do
		table.insert(pads, `#{index} {clock(player.padAt[index - Tuning.Dojo.startPads])}`)
	end
	print(`pads bought at: {table.concat(pads, ", ")}`)
	local total = 0
	for _, amount in player.spent do
		total += amount
	end
	local shares = {}
	for _, kind in { "kunai", "speed", "pads", "upgrades" } do
		local share = if total > 0 then player.spent[kind] / total * 100 else 0
		table.insert(shares, `{kind} {string.format("%.0f", share)}%`)
	end
	print(`Ryo went on: {table.concat(shares, ", ")}`)
	print(
		`after {hours} h: {Format.short(player.chakra)} Chakra, {Format.short(income(player))} Ryo/s,`
			.. ` speed level {player.speedLevel}, {player.spins} throws, {player.caught} lost to enemies`
	)
	print("")
end

local hours = tonumber(process.args[1]) or 40
printZones()
printPrices()
for _, profile in PROFILES do
	printProfile(profile, hours)
end
