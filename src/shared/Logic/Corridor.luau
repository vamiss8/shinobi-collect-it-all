--!strict
-- Keeps a camera inside the lane. The lane's walls are unseen and the scenery beside it is not
-- solid, so nothing stops the game's own camera from backing out through a wall when a player
-- on the lane looks along it sideways, and from there the camera sees the scenery from inside:
-- behind an arena's wall, in a cave's rock. Pulled in along its own line of sight, the way any
-- camera is at a wall, it stays where the scenery is meant to be seen from.
--
-- Pure arithmetic; client/LaneCamera feeds it the camera.

local Corridor = {}

-- How near what it looks at the camera is brought at most, as a share of the way out to where
-- it wanted to be: it never lands on its subject.
Corridor.NEAREST = 0.06

-- How far out along the line from what the camera looks at (`focus`) to where the camera wants
-- to stand (`eye`) it may go, as a share of that line: 1 when it may stand where it wants.
-- Both are distances across the lane from its middle line, negative to the left; `limit` is
-- how far from the middle a camera may be.
function Corridor.reach(focus: number, eye: number, limit: number): number
	if math.abs(eye) <= limit then
		return 1
	end
	local edge = if eye > 0 then limit else -limit
	-- What it looks at is itself out past the limit, on the same side: as near as allowed.
	if (eye > 0 and focus >= edge) or (eye < 0 and focus <= edge) then
		return Corridor.NEAREST
	end
	return math.max((edge - focus) / (eye - focus), Corridor.NEAREST)
end

return Corridor
