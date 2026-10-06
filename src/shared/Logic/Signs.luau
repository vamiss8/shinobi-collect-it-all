--!strict
-- A zone's sign: where it hangs over the lane, how large its board is and what is written on
-- it. The Hub puts up the board and the writing; the zone's scenery (World/ZoneArt) builds a
-- frame round it in the zone's own style. Both go by the numbers here.

local Catalog = require("../Config/Catalog")
local Chase = require("./Chase")
local Format = require("./Format")
local Roll = require("./Roll")

local Signs = {}

Signs.WIDTH = 40 -- across the lane, studs
Signs.THICKNESS = 0.5
-- How tall what is written stands, studs: the zone's name, and each line under it.
Signs.NAME = 4.2
Signs.LINE = 2.3
-- Bare board above the name and below the last line.
Signs.MARGIN = 0.7

-- The underside of a sign, studs above the lane. A sign stands on the gate its zone raises
-- where it begins, and the gate's beams stay below this. The first zone's is no different: it
-- stands over the back edge of the throwing strip, where the lane starts. (It first hung low
-- and without a board a little way past the strip, so as not to stand in a thrower's view;
-- the owner wanted it a board like the rest, where its zone begins.)
Signs.FOOT = 27

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
	local height = 2 * Signs.MARGIN + Signs.NAME + #Signs.details(zone) * Signs.LINE
	return {
		along = zone.startsAt + 0.5,
		foot = Signs.FOOT,
		top = Signs.FOOT + height,
		width = Signs.WIDTH,
		height = height,
	}
end

return Signs
