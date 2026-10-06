--!strict
-- Where everything in a dojo stands. A dojo has three floors; on each, two rows of five pads
-- face each other across an aisle. A staircase climbs the front of the building in one
-- straight line, with no turns: from the street up to a landing in front of the second floor,
-- and on up to a landing in front of the third. World/Plots and World/DojoHall turn the
-- numbers here into parts; they are kept apart from them so the specs can check the layout
-- without Roblox.
--
-- Dojo-local coordinates, in studs: x runs along the street, from the end of the plot nearest
-- the throwing strip (-HALF_WIDTH) to the far end (+HALF_WIDTH); y is height above the ground
-- floor; z runs away from the street, from the plot's front edge (0) to its back edge (DEPTH).

local DojoPlan = {}

DojoPlan.FLOORS = 3
DojoPlan.PADS_PER_ROW = 5
DojoPlan.PADS_PER_FLOOR = 2 * DojoPlan.PADS_PER_ROW
DojoPlan.PAD_COUNT = DojoPlan.FLOORS * DojoPlan.PADS_PER_FLOOR

-- The plot.
DojoPlan.WIDTH = 64
DojoPlan.HALF_WIDTH = DojoPlan.WIDTH / 2
DojoPlan.DEPTH = 50

-- The building. Its front is a row of pillars; the strip between them and the street carries
-- the staircase.
DojoPlan.FRONT = 6.5 -- z of the street side of the front pillars
DojoPlan.BACK = 44.5 -- z of the outer face of the back wall
DojoPlan.WALL = 1 -- thickness of walls, pillars and the side of a pillar
DojoPlan.STOREY = 14 -- from one floor to the next
DojoPlan.SLAB = 1 -- thickness of a floor
DojoPlan.TOP = DojoPlan.FLOORS * DojoPlan.STOREY -- y of the top of the ceiling of the top floor

-- Pads. The front row stands a walkway's width behind the front pillars, the back row as far
-- in front of the back wall; their upgrade consoles reach into the aisle between them.
DojoPlan.PAD_SIZE = 7
DojoPlan.PAD_PITCH = 11 -- from the center of one pad to the next along a row
DojoPlan.FRONT_ROW = 13 -- z of the front row's centers
DojoPlan.BACK_ROW = 37 -- z of the back row's centers
DojoPlan.CONSOLE_DEPTH = 2.8 -- how far a console reaches into the aisle from its pad's edge

-- The staircase. Each flight climbs one storey in `STEPS` steps. The steps are only for show:
-- World/DojoHall lays a smooth, invisible ramp along each flight, which characters walk up
-- without snagging on a step or having to jump.
DojoPlan.STAIR_NEAR = 0.5 -- z of the strip's street side
DojoPlan.STAIR_FAR = DojoPlan.FRONT -- z of its building side: it runs against the pillars
DojoPlan.STEPS = 20
local APPROACH = 1 -- level ground at the foot of the first flight, at the end of the plot
local RUN = 23 -- length of a flight along the facade
-- Length of the landing at the head of each flight. The last one runs to the end of the plot.
local LANDINGS = { 9, 8 }

export type PadSpot = {
	floor: number,
	row: number, -- 1 by the front, 2 by the back
	column: number, -- 1 at the end nearest the throwing strip
	x: number,
	y: number, -- the level of its floor
	z: number,
	facing: number, -- +1 or -1: the way along z to the aisle, where its console stands
}

-- A flight of the staircase, climbing towards +x.
export type Flight = {
	from: number, -- x where it leaves the level below: its ramp starts here
	to: number, -- x where it reaches the level above, at the start of the next landing
	low: number, -- y of the level below
	high: number, -- y of the level above
}

-- A landing at the head of a flight, in front of the floor it leads into.
export type Landing = {
	floor: number,
	from: number,
	to: number,
	y: number,
}

-- The y of the floor surface of the given floor, 1 being the ground floor.
function DojoPlan.level(floor: number): number
	return (floor - 1) * DojoPlan.STOREY
end

-- Pads are numbered floor by floor; on each floor the front row comes first, and each row runs
-- from the end nearest the throwing strip. Pads are bought in this order, so a new player's
-- free pads are the front row of the ground floor.
function DojoPlan.pad(index: number): PadSpot
	local floor = (index - 1) // DojoPlan.PADS_PER_FLOOR + 1
	local onFloor = (index - 1) % DojoPlan.PADS_PER_FLOOR
	local row = onFloor // DojoPlan.PADS_PER_ROW + 1
	local column = onFloor % DojoPlan.PADS_PER_ROW + 1
	return {
		floor = floor,
		row = row,
		column = column,
		x = (column - (DojoPlan.PADS_PER_ROW + 1) / 2) * DojoPlan.PAD_PITCH,
		y = DojoPlan.level(floor),
		z = if row == 1 then DojoPlan.FRONT_ROW else DojoPlan.BACK_ROW,
		facing = if row == 1 then 1 else -1,
	}
end

-- How many floors a dojo stands with when `unlocked` of its pads are open: up to the floor of
-- the next pad to buy, so the next floor goes up as soon as the one below is full.
function DojoPlan.floorsFor(unlocked: number): number
	local following = math.clamp(math.floor(unlocked) + 1, 1, DojoPlan.PAD_COUNT)
	return DojoPlan.pad(following).floor
end

local flights: { Flight } = {}
local landings: { Landing } = {}
do
	local x = -DojoPlan.HALF_WIDTH + APPROACH
	for floor = 2, DojoPlan.FLOORS do
		local low = DojoPlan.level(floor - 1)
		local high = DojoPlan.level(floor)
		table.insert(flights, { from = x, to = x + RUN, low = low, high = high })
		x += RUN
		local length = LANDINGS[floor - 1]
		table.insert(landings, { floor = floor, from = x, to = x + length, y = high })
		x += length
	end
end
DojoPlan.flights = flights
DojoPlan.landings = landings

-- How high one step of a flight is, and how deep.
function DojoPlan.stepRise(flight: Flight): number
	return (flight.high - flight.low) / DojoPlan.STEPS
end

function DojoPlan.stepRun(flight: Flight): number
	return (flight.to - flight.from) / DojoPlan.STEPS
end

-- The opening in the front of a floor that its landing leads through: the gap between the two
-- pillars that stand at the landing's ends.
function DojoPlan.entrance(landing: Landing): (number, number)
	return landing.from, math.min(landing.to, DojoPlan.HALF_WIDTH - DojoPlan.WALL)
end

-- x of the pillars along the front: one at each corner and one at either side of every
-- entrance, and one more in the middle of each gap wider than `MAX_SPAN`.
local MAX_SPAN = 16
local pillars: { number } = { -DojoPlan.HALF_WIDTH + DojoPlan.WALL / 2 }
do
	local corner = DojoPlan.HALF_WIDTH - DojoPlan.WALL / 2
	local fixed: { number } = {}
	for _, landing in landings do
		local from, to = DojoPlan.entrance(landing)
		table.insert(fixed, from - DojoPlan.WALL / 2)
		table.insert(fixed, math.min(to + DojoPlan.WALL / 2, corner))
	end
	table.insert(fixed, corner)
	table.sort(fixed)
	for _, x in fixed do
		local last = pillars[#pillars]
		if x - last > MAX_SPAN then
			table.insert(pillars, (last + x) / 2)
		end
		if x > last then
			table.insert(pillars, x)
		end
	end
end
DojoPlan.pillars = pillars

return DojoPlan
