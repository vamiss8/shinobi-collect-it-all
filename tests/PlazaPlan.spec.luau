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

	["the stalls stand round the fountain with room to pass everywhere"] = function()
		local ids = { "chakra", "speed", "sell" }
		for _, id in ids do
			local spot = PlazaPlan.stalls[id]
			T.ok(spot ~= nil, `no place for the {id} stall`)
			T.near(distance(spot, PlazaPlan.FOUNTAIN), PlazaPlan.STALL_RING, EPS, `{id} ring`)
			T.ok(
				PlazaPlan.STALL_RING - PlazaPlan.STALL_HALF - PlazaPlan.FOUNTAIN_RADIUS >= PASSAGE,
				`room between the {id} stall and the fountain`
			)
			T.ok(
				PlazaPlan.HALF_WIDTH - math.abs(spot.side) - PlazaPlan.STALL_HALF >= 2 * PASSAGE,
				`room between the {id} stall and the dojos`
			)
		end
		for a = 1, #ids do
			for b = a + 1, #ids do
				local apart = distance(PlazaPlan.stalls[ids[a]], PlazaPlan.stalls[ids[b]])
				T.ok(
					apart - 2 * PlazaPlan.STALL_HALF >= PASSAGE,
					`{ids[a]} and {ids[b]} keep apart`
				)
			end
		end
		T.eq(PlazaPlan.stalls.chakra.side, 0, "the Chakra Store stands on the way to the lane")
		T.ok(PlazaPlan.stalls.chakra.along > PlazaPlan.FOUNTAIN.along, "on the lane's side")
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
			for id, stall in PlazaPlan.stalls do
				T.ok(
					distance(spawn, stall) >= PlazaPlan.STALL_HALF + PASSAGE,
					`spawn {index} is clear of the {id} stall`
				)
			end
		end
	end,
}
