--!strict
local Catalog = require("../src/shared/Config/Catalog")
local Chase = require("../src/shared/Logic/Chase")
local Economy = require("../src/shared/Logic/Economy")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

local EPS = 1e-9

-- Plays a chase out step by step, the way the server does: the runner heads home from
-- `distance` studs, the enemy starts a gap behind and a moment later.
local function playedOut(runSpeed: number, enemySpeed: number, distance: number): boolean
	local chase = Tuning.Chase
	local dt = 1 / 240
	local runner, enemy, clock = distance, distance + chase.enemyGap, 0
	while runner > 0 do
		clock += dt
		runner -= runSpeed * dt
		if clock >= chase.enemyDelay then
			enemy -= enemySpeed * dt
			if runner > 0 and enemy - runner <= chase.catchRadius then
				return false
			end
		end
	end
	return true
end

-- The lowest speed level that gets a runner home from `distance` studs, or nil if none does.
local function levelFor(distance: number): number?
	for level = 0, Tuning.Speed.maxLevel do
		if Chase.escapesFrom(Economy.walkSpeed(level), distance) then
			return level
		end
	end
	return nil
end

return {
	["an enemy runs at its zone's speed on the near edge"] = function()
		for _, zone in Catalog.zones do
			T.near(Chase.enemySpeed(zone, zone.startsAt), zone.enemy.speed, EPS, zone.id)
		end
	end,

	["an enemy matches the next zone's by the far end, so borders hide no safe spot"] = function()
		for i = 1, #Catalog.zones - 1 do
			local zone, following = Catalog.zones[i], Catalog.zones[i + 1]
			T.near(Chase.farSpeed(zone), following.enemy.speed, EPS, zone.id)
			T.near(Chase.enemySpeed(zone, following.startsAt), following.enemy.speed, EPS, zone.id)
		end
	end,

	["the last zone's enemy gains its bonus by the end of the lane"] = function()
		local last = Catalog.zones[#Catalog.zones]
		local expected = last.enemy.speed * (1 + Tuning.Chase.farSpeedBonus)
		T.near(Chase.enemySpeed(last, Tuning.Kick.trackLength), expected, EPS)
		T.ok(Chase.farSpeed(last) > last.enemy.speed, "the far end must be the harder one")
	end,

	["a runner as fast as the enemy always gets home"] = function()
		T.ok(Chase.escapes(30, 30, 1700), "equal speeds, deep in the lane")
		T.ok(Chase.escapes(30, 25, 1700), "a faster runner")
	end,

	["a short run forgives a slower runner, a long one does not"] = function()
		T.ok(Chase.escapes(16, 20, 50), "the head start covers a short run")
		T.ok(not Chase.escapes(16, 20, 1000), "the enemy has time to close the gap")
	end,

	["the formula agrees with a chase played out step by step"] = function()
		for _, case in { { 22, 100 }, { 29, 520 }, { 41, 1120 }, { 56, 1800 } } do
			local enemySpeed, distance = case[1], case[2]
			local needed = Chase.speedNeeded(enemySpeed, distance)
			T.ok(needed < enemySpeed, "a head start always helps")
			T.eq(playedOut(needed * 1.01, enemySpeed, distance), true, `just enough at {distance}`)
			T.eq(playedOut(needed * 0.99, enemySpeed, distance), false, `just short at {distance}`)
			T.eq(Chase.escapes(needed * 1.01, enemySpeed, distance), true)
			T.eq(Chase.escapes(needed * 0.99, enemySpeed, distance), false)
		end
	end,

	["the lane only gets harder to run home from"] = function()
		local previous = -1
		for distance = 0, Tuning.Kick.trackLength, 5 do
			local zone = Catalog.zoneAt(distance)
			local needed = Chase.speedNeeded(Chase.enemySpeed(zone, distance), distance)
			T.ok(needed >= previous - EPS, `less speed is needed at {distance} than nearer home`)
			previous = needed
		end
	end,

	["a new player gets home from anywhere in the first zone"] = function()
		local first = Catalog.zones[1]
		local slowest = Economy.walkSpeed(0)
		for distance = 0, Catalog.zoneEnd(first), 5 do
			T.ok(Chase.escapesFrom(slowest, distance), `caught from {distance} studs`)
		end
	end,

	["a maxed-out player gets home from the far end of the lane"] = function()
		local top = Economy.walkSpeed(Tuning.Speed.maxLevel)
		T.ok(Chase.escapesFrom(top, Tuning.Kick.trackLength), "the last zone cannot be cleared")
	end,

	["every zone asks for more run speed than the one before"] = function()
		local previous = -1
		for i, zone in Catalog.zones do
			local level = levelFor(zone.startsAt)
			T.ok(level ~= nil, `{zone.id} cannot be entered at any speed level`)
			if i > 2 then
				T.ok(
					(level :: number) > previous,
					`{zone.id} needs no more speed than the zone before it`
				)
			end
			previous = level :: number
		end
	end,

	["speed prices keep growing"] = function()
		for level = 1, Tuning.Speed.maxLevel - 1 do
			T.ok(
				Economy.speedPrice(level) > Economy.speedPrice(level - 1),
				`level {level + 1} is no pricier than the one before`
			)
		end
	end,
}
