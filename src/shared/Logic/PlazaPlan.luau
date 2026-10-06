--!strict
-- Where everything stands on the square behind the start of the lane, where players appear: a
-- paved plaza with a fountain in its middle, the market's three stalls round the fountain, and
-- the six dojos along its two long sides, three a side, facing each other across it. The
-- numbers are kept here, apart from the parts built from them (World/Plots, World/Plaza,
-- World/Market, ZoneArt/home), so that the specs can check the layout without Roblox.
--
-- In the Hub's coordinates: `along` is distance down the lane, so everything here is at a
-- negative along; `side` is across the lane, negative to the left of someone looking down it.

local DojoPlan = require("./DojoPlan")

local PlazaPlan = {}

PlazaPlan.DOJOS = 6
PlazaPlan.PER_SIDE = PlazaPlan.DOJOS / 2
-- From the plaza's middle line to the fronts of the dojos. The lane is 30 to a side: the
-- plaza is more than twice as wide as the street it replaced.
PlazaPlan.HALF_WIDTH = 64
PlazaPlan.FRONT_GAP = 14 -- from the lane's start back to the first pair of dojos
PlazaPlan.GAP = 10 -- between one dojo and the next
PlazaPlan.BACK_GAP = 14 -- behind the last pair
-- From one dojo's middle to the next one's on the same side.
PlazaPlan.PITCH = DojoPlan.WIDTH + PlazaPlan.GAP
-- How far back the plaza goes from the lane's start.
PlazaPlan.DEPTH = PlazaPlan.FRONT_GAP
	+ PlazaPlan.PER_SIDE * DojoPlan.WIDTH
	+ (PlazaPlan.PER_SIDE - 1) * PlazaPlan.GAP
	+ PlazaPlan.BACK_GAP
-- From the middle line to the backs of the dojos: the fence of the yard runs there.
PlazaPlan.YARD_HALF = PlazaPlan.HALF_WIDTH + DojoPlan.DEPTH

export type Spot = {
	along: number,
	side: number,
}

-- Where the middle of a dojo's front edge is, and which side of the plaza it stands on: `side`
-- is -1 or 1 here. Odd dojos stand on the left, even ones on the right, in pairs that face
-- each other; the first pair is the nearest to the lane.
function PlazaPlan.dojo(index: number): Spot
	local pair = math.ceil(index / 2)
	return {
		along = -(PlazaPlan.FRONT_GAP + DojoPlan.HALF_WIDTH + (pair - 1) * PlazaPlan.PITCH),
		side = if index % 2 == 1 then -1 else 1,
	}
end

-- Where the owner of a dojo appears: on the plaza, a few steps out from the entrance under the
-- first landing.
PlazaPlan.SPAWN_OUT = 5
function PlazaPlan.spawn(index: number): Spot
	local dojo = PlazaPlan.dojo(index)
	local from, to = DojoPlan.entrance(DojoPlan.landings[1])
	-- A dojo's own x runs away from the lane (see Logic/DojoPlan).
	return {
		along = dojo.along - (from + to) / 2,
		side = dojo.side * (PlazaPlan.HALF_WIDTH - PlazaPlan.SPAWN_OUT),
	}
end

-- The fountain, in the very middle of the plaza: the rim of its basin is this far from its
-- middle.
PlazaPlan.FOUNTAIN = { along = -PlazaPlan.DEPTH / 2, side = 0 } :: Spot
PlazaPlan.FOUNTAIN_RADIUS = 18

-- The market's stalls stand round the fountain, a third of a turn apart, this far from its
-- middle: the Chakra Store on the side of the lane, the other two behind. A stall's roof
-- reaches STALL_HALF from its middle.
PlazaPlan.STALL_RING = 36
PlazaPlan.STALL_HALF = 5.5
local function stall(turn: number): Spot
	local angle = math.rad(turn)
	return {
		along = PlazaPlan.FOUNTAIN.along + PlazaPlan.STALL_RING * math.cos(angle),
		side = PlazaPlan.STALL_RING * math.sin(angle),
	}
end
PlazaPlan.stalls = {
	chakra = stall(0),
	speed = stall(-120),
	sell = stall(120),
} :: { [string]: Spot }

return PlazaPlan
