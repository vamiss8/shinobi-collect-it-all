--!strict
-- The run home from where the kunai landed: how fast the zone's enemy is, and whether a runner
-- gets away from it.
--
-- The enemy appears `enemyGap` studs farther down the lane than the runner, sets off
-- `enemyDelay` seconds after them and catches them once it is within `catchRadius`. Both run
-- straight for the street, so the outcome is known the moment the run starts: the runner needs
-- `distance / runSpeed` seconds to get home, and the enemy closes the gap at the difference of
-- the two speeds. A short run forgives a slow runner, because the head start is a bigger share
-- of it; from deep in the lane a runner has to be nearly as fast as the enemy.

local Catalog = require("../Config/Catalog")
local Tuning = require("../Config/Tuning")

local Chase = {}

-- Speed of the zone's enemy at the zone's far end: as fast as the next zone's enemy, so the
-- danger never drops when a throw crosses a border. The last zone's enemy gains a set share.
function Chase.farSpeed(zone: Catalog.Zone): number
	local following = Catalog.zoneAfter(zone)
	return if following
		then following.enemy.speed
		else zone.enemy.speed * (1 + Tuning.Chase.farSpeedBonus)
end

-- Speed of the zone's enemy for a kunai that landed `distance` studs down the lane: the zone's
-- own speed on its near edge, rising in a straight line to the far end's.
function Chase.enemySpeed(zone: Catalog.Zone, distance: number): number
	local near, far = zone.enemy.speed, Chase.farSpeed(zone)
	return near + (far - near) * Catalog.zoneProgress(zone, distance)
end

-- The run speed a player has to beat to get home from `distance` studs with an enemy of
-- `enemySpeed` behind them.
function Chase.speedNeeded(enemySpeed: number, distance: number): number
	local c = Tuning.Chase
	local headStart = c.enemyGap - c.catchRadius + enemySpeed * c.enemyDelay
	return distance * enemySpeed / (distance + headStart)
end

function Chase.escapes(runSpeed: number, enemySpeed: number, distance: number): boolean
	return runSpeed > Chase.speedNeeded(enemySpeed, distance)
end

-- Whether a player with `runSpeed` gets home from that spot on the lane.
function Chase.escapesFrom(runSpeed: number, distance: number): boolean
	local zone = Catalog.zoneAt(distance)
	return Chase.escapes(runSpeed, Chase.enemySpeed(zone, distance), distance)
end

return Chase
