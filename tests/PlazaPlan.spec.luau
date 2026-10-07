--!strict
local DojoPlan = require("../src/shared/Logic/DojoPlan")
local PlazaPlan = require("../src/shared/Logic/PlazaPlan")
local T = require("./harness")

local EPS = 1e-9
-- The least room to walk between two things that stand on the plaza, studs.
local PASSAGE = 8
-- The lane is this wide to a side (World/Hub).
local LANE_HALF = 30

local function distance(a: PlazaPlan.Spot, b: PlazaPlan.Spot): number
	return math.sqrt((a.along - b.along) ^ 2 + (a.side - b.side) ^ 2)
end

return {
	["six dojos stand three a side, in pairs that face each other"] = function()
		T.eq(PlazaPlan.DOJOS, 6)
		for index = 1, PlazaPlan.DOJOS, 2 do
			local left, right = PlazaPlan.dojo(index), PlazaPlan.dojo(index + 1)
			T.eq(left.side, -1, `dojo {index} is on the left`)
			T.eq(right.side, 1, `dojo {index + 1} is on the right`)
			T.near(left.along, right.along, EPS, "a pair stands at the same place along the plaza")
		end
	end,

	["dojos keep apart and stay on the plaza's length"] = function()
		local half = DojoPlan.HALF_WIDTH
		for index = 1, PlazaPlan.DOJOS do
			local dojo = PlazaPlan.dojo(index)
			T.ok(
				dojo.along + half <= -PlazaPlan.FRONT_GAP + EPS,
				`dojo {index} leaves the front gap`
			)
			T.ok(
				dojo.along - half >= -PlazaPlan.DEPTH + PlazaPlan.BACK_GAP - EPS,
				`dojo {index} leaves the back gap`
			)
			local following = index + 2
			if following <= PlazaPlan.DOJOS then
				local gap = dojo.along - PlazaPlan.dojo(following).along - DojoPlan.WIDTH
				T.near(gap, PlazaPlan.GAP, EPS, `the gap behind dojo {index}`)
			end
		end
	end,

	["the plaza is much wider than the lane it leads to"] = function()
		T.ok(PlazaPlan.HALF_WIDTH >= 2 * LANE_HALF, "twice the lane's width or more")
		T.near(PlazaPlan.YARD_HALF, PlazaPlan.HALF_WIDTH + DojoPlan.DEPTH, EPS)
	end,

	["the fountain is in the middle, level with the middle pair of dojos"] = function()
		local fountain = PlazaPlan.FOUNTAIN
		T.near(fountain.along, -PlazaPlan.DEPTH / 2, EPS)
		T.eq(fountain.side, 0)
		T.near(PlazaPlan.dojo(3).along, fountain.along, EPS)
		T.ok(
			PlazaPlan.FOUNTAIN_RADIUS + PASSAGE <= PlazaPlan.HALF_WIDTH / 2,
			"with most of the plaza's width left to walk round it"
		)
	end,

	["the shops stand round the fountain with room to pass everywhere"] = function()
		local shops: { [string]: { PlazaPlan.Spot } } = {}
		for _, id in { "tenten", "speed", "sell" } do
			local shop = PlazaPlan.shops[id]
			T.ok(shop ~= nil, `no place for the {id} shop`)
			T.near(distance(shop, PlazaPlan.FOUNTAIN), PlazaPlan.SHOP_RING, EPS, `{id} ring`)
			local out = PlazaPlan.facing(shop)
			local toFountain = {
				along = PlazaPlan.FOUNTAIN.along - shop.along,
				side = PlazaPlan.FOUNTAIN.side - shop.side,
			}
			T.ok(
				out.along * toFountain.along + out.side * toFountain.side > 0,
				`the {id} shop faces the fountain`
			)
			shops[id] = PlazaPlan.shopCorners(shop)
		end
		T.ok(
			PlazaPlan.SHOP_RING - PlazaPlan.SHOP.front - PlazaPlan.FOUNTAIN_RADIUS >= PASSAGE,
			"room between the shops and the fountain"
		)
		for id, corners in shops do
			for _, corner in corners do
				T.ok(
					PlazaPlan.HALF_WIDTH - math.abs(corner.side) >= 2 * PASSAGE,
					`room between the {id} shop and the dojos`
				)
			end
			for other, theirs in shops do
				if other > id then
					T.ok(PlazaPlan.apart(corners, theirs) >= PASSAGE, `{id} and {other} keep apart`)
				end
			end
		end
		local tenten = PlazaPlan.shops.tenten
		T.eq(tenten.side, 0, "Tenten's shop stands on the way to the lane")
		T.ok(tenten.along > PlazaPlan.FOUNTAIN.along, "on the lane's side")
	end,

	["the measure of how far apart two pieces of ground are"] = function()
		local function square(along: number, side: number, half: number): { PlazaPlan.Spot }
			return {
				{ along = along - half, side = side - half },
				{ along = along + half, side = side - half },
				{ along = along + half, side = side + half },
				{ along = along - half, side = side + half },
			}
		end
		T.near(PlazaPlan.apart(square(0, 0, 1), square(5, 0, 1)), 3, EPS, "side by side")
		T.near(PlazaPlan.apart(square(0, 0, 1), square(4, 4, 1)), math.sqrt(8), EPS, "corners")
		T.eq(PlazaPlan.apart(square(0, 0, 1), square(1, 1, 1)), 0, "overlapping")
		T.eq(PlazaPlan.apart(square(0, 0, 3), square(0, 0, 1)), 0, "one inside the other")
		local corners = PlazaPlan.shopCorners(PlazaPlan.shops.sell)
		local width = distance(corners[1], corners[2])
		local depth = distance(corners[2], corners[3])
		T.near(width, 2 * PlazaPlan.SHOP.half, 1e-6, "a shop is as wide as the plan says")
		T.near(depth, PlazaPlan.SHOP.front + PlazaPlan.SHOP.back, 1e-6, "and as deep")
	end,

	["every owner appears on open paving in front of their own dojo"] = function()
		for index = 1, PlazaPlan.DOJOS do
			local spawn = PlazaPlan.spawn(index)
			local dojo = PlazaPlan.dojo(index)
			T.ok(math.abs(spawn.side) < PlazaPlan.HALF_WIDTH, `spawn {index} is on the plaza`)
			T.eq(spawn.side > 0, dojo.side > 0, `spawn {index} is on its dojo's side`)
			T.ok(
				math.abs(spawn.along - dojo.along) <= DojoPlan.HALF_WIDTH,
				`spawn {index} is in front of its dojo`
			)
			T.ok(
				distance(spawn, PlazaPlan.FOUNTAIN) >= PlazaPlan.FOUNTAIN_RADIUS + PASSAGE,
				`spawn {index} is clear of the fountain`
			)
			for id, shop in PlazaPlan.shops do
				local corners = PlazaPlan.shopCorners(shop)
				T.ok(
					PlazaPlan.apart({ spawn }, corners) >= PASSAGE,
					`spawn {index} is clear of the {id} shop`
				)
			end
		end
	end,
}
