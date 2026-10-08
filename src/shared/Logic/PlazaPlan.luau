--!strict
-- Where everything stands on the square behind the start of the lane, where players appear: a
-- paved plaza with a fountain in its middle, the market round the fountain (a shop on the
-- lane's side of it, two stalls behind), and the six dojos along its two long sides, three a
-- side, facing each other across it. The
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

-- The market's three shops stand round the fountain, a third of a turn apart, their open
-- fronts to it: Tenten's Ninja Tools (the shop "tenten", which sells kunai) on the side of the
-- lane, the Mission Desk (the shop "sell") and the Youth Training Ground (the shop "speed")
-- behind. The first two are houses (World/ShopHouse), the third an open yard on as much ground
-- (World/TrainingGround). A shop's spot is the middle of its front, SHOP_RING from the
-- fountain's middle; from the line of its front it reaches SHOP.half to either side, SHOP.front
-- out towards the fountain (a porch, eaves) and SHOP.back away from it.
PlazaPlan.SHOP_RING = 34.5
PlazaPlan.SHOP = { half = 11.8, front = 3, back = 14 }
local function round(turn: number): Spot
	local angle = math.rad(turn)
	return {
		along = PlazaPlan.FOUNTAIN.along + PlazaPlan.SHOP_RING * math.cos(angle),
		side = PlazaPlan.FOUNTAIN.side + PlazaPlan.SHOP_RING * math.sin(angle),
	}
end
PlazaPlan.shops = {
	tenten = round(0),
	sell = round(120),
	speed = round(-120),
} :: { [string]: Spot }

-- The legendary shinobi (Config/Legends) stand on show on pedestals of their own, on the middle
-- path between the back of Tenten's shop and the lane and looking at the lane: whoever comes
-- home from a throw walks towards them. One pedestal each, in the order of the config, in a
-- row across the path: the dearest, the last, in its middle, the others out to either side.
-- A pedestal's foot is PEDESTAL across.
PlazaPlan.PEDESTAL = 7
PlazaPlan.pedestals = {
	{ along = -59, side = -19 },
	{ along = -59, side = 19 },
	{ along = -59, side = 0 },
} :: { Spot }

-- Which way a shop looks out of its front, as a step along and a step across: at the fountain.
function PlazaPlan.facing(shop: Spot): Spot
	local along = PlazaPlan.FOUNTAIN.along - shop.along
	local side = PlazaPlan.FOUNTAIN.side - shop.side
	local length = math.sqrt(along * along + side * side)
	return { along = along / length, side = side / length }
end

-- The four corners of the ground a shop covers, in order round it.
function PlazaPlan.shopCorners(shop: Spot): { Spot }
	local out = PlazaPlan.facing(shop)
	local across = { along = -out.side, side = out.along }
	local size = PlazaPlan.SHOP
	local corners = {}
	for _, corner in
		{
			{ size.front, -size.half },
			{ size.front, size.half },
			{ -size.back, size.half },
			{ -size.back, -size.half },
		}
	do
		local depth, reach = corner[1], corner[2]
		table.insert(corners, {
			along = shop.along + out.along * depth + across.along * reach,
			side = shop.side + out.side * depth + across.side * reach,
		})
	end
	return corners
end

-- Whether a line square to `axis` keeps the two pieces of ground on either side of it.
local function separates(axis: Spot, a: { Spot }, b: { Spot }): boolean
	local function span(corners: { Spot }): (number, number)
		local low, high = math.huge, -math.huge
		for _, corner in corners do
			local d = corner.along * axis.along + corner.side * axis.side
			low, high = math.min(low, d), math.max(high, d)
		end
		return low, high
	end
	local aLow, aHigh = span(a)
	local bLow, bHigh = span(b)
	return aHigh < bLow or bHigh < aLow
end

-- How far a point is from the edge from `p` to `q`.
local function fromEdge(point: Spot, p: Spot, q: Spot): number
	local dx, dz = q.along - p.along, q.side - p.side
	local length = dx * dx + dz * dz
	local t = if length > 0
		then math.clamp(((point.along - p.along) * dx + (point.side - p.side) * dz) / length, 0, 1)
		else 0
	local x, z = p.along + dx * t - point.along, p.side + dz * t - point.side
	return math.sqrt(x * x + z * z)
end

-- How far apart two pieces of ground are, each given by its corners in order round it (and
-- neither of them hollow), studs: 0 when they touch or overlap.
function PlazaPlan.apart(a: { Spot }, b: { Spot }): number
	local overlap = true
	for _, corners in { a, b } do
		for i, p in corners do
			local q = corners[i % #corners + 1]
			if separates({ along = q.side - p.side, side = p.along - q.along }, a, b) then
				overlap = false
			end
		end
	end
	if overlap then
		return 0
	end
	local nearest = math.huge
	for _, pair in { { a, b }, { b, a } } do
		local points, edges = pair[1], pair[2]
		for _, point in points do
			for i, p in edges do
				nearest = math.min(nearest, fromEdge(point, p, edges[i % #edges + 1]))
			end
		end
	end
	return nearest
end

return PlazaPlan
