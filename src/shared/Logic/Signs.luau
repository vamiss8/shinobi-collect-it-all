--!strict
-- A zone's sign: where it hangs over the lane, how large its board is and what is written on
-- it. The Hub puts up the board and the writing; the zone's scenery (World/ZoneArt) builds a
-- frame round it in the zone's own style. Both go by the numbers here.

local Catalog = require("../Config/Catalog")
local Chase = require("./Chase")
local Format = require("./Format")
local Roll = require("./Roll")
local Tuning = require("../Config/Tuning")

local Signs = {}

Signs.WIDTH = 40 -- across the lane, studs
Signs.THICKNESS = 0.5
-- How tall what is written stands, studs: the zone's name, and each line under it.
Signs.NAME = 4.2
Signs.LINE = 2.3
-- Bare board above the name and below the last line.
Signs.MARGIN = 0.7

-- The underside of a sign, studs above the lane. A sign stands on the gate its zone raises
-- where it begins, and the gate's beams stay below this.
Signs.FOOT = 27
-- The first zone begins at the throwing strip and has no gate: its sign hangs low, a little
-- way past the strip.
Signs.FIRST_FOOT = 9
Signs.FIRST_PAST_STRIP = 14

export type Box = {
	along: number, -- where the board stands on the lane, studs from its start
	foot: number, -- its underside and its top, studs above the lane
	top: number,
	width: number,
	height: number,
}

-- The lines under the zone's name: its rank and the Chakra a throw needs, then who chases the
-- thrower home and how fast. Rich text.
function Signs.details(zone: Catalog.Zone): { string }
	local rank = Catalog.ranks[Catalog.rankOrder[zone.rank]]
	local slowest = Format.short(zone.enemy.speed)
	local fastest = Format.short(Chase.farSpeed(zone))
	local lines = {
		`<font color="{rank.color}">{rank.name}</font>  |  {Format.short(zone.chakra)}+ Chakra`,
		`<font color="#FF8A80">{zone.enemy.name} - speed {slowest} to {fastest}</font>`,
	}
	-- The last zone rewards depth with mutation luck (see Roll.depthMutationLuck).
	local deepLuck = Roll.depthMutationLuck(zone, Catalog.zoneEnd(zone))
	if deepLuck > 1 then
		table.insert(
			lines,
			`<font color="#B39DDB">the deeper, the luckier: up to x{Format.short(deepLuck)} mutations</font>`
		)
	end
	return lines
end

function Signs.box(zone: Catalog.Zone): Box
	local first = Catalog.zoneOrder[zone.id] == 1
	local height = 2 * Signs.MARGIN + Signs.NAME + #Signs.details(zone) * Signs.LINE
	local foot = if first then Signs.FIRST_FOOT else Signs.FOOT
	return {
		along = if first
			then Tuning.Kick.stripDepth + Signs.FIRST_PAST_STRIP
			else zone.startsAt + 0.5,
		foot = foot,
		top = foot + height,
		width = Signs.WIDTH,
		height = height,
	}
end

return Signs
