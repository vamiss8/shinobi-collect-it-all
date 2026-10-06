--!strict
local DojoPlan = require("../src/shared/Logic/DojoPlan")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

local EPS = 1e-9
local WALKWAY = 2 -- the least room to walk around a pad, studs
local AISLE = 10 -- the least room to stand between the consoles of the two rows, studs

-- Whether two ranges overlap by more than a touch.
local function overlap(a1: number, a2: number, b1: number, b2: number): boolean
	return math.min(a2, b2) - math.max(a1, b1) > EPS
end

return {
	["the dojo has a pad for every one a player can unlock"] = function()
		local d = Tuning.Dojo
		T.eq(DojoPlan.PAD_COUNT, d.startPads + d.buyablePads + d.gamePassPads)
		T.eq(DojoPlan.PAD_COUNT, 30, "three floors of two rows of five")
	end,

	["pads are numbered floor by floor, front row first"] = function()
		local first = DojoPlan.pad(1)
		T.eq(first.floor, 1)
		T.eq(first.row, 1)
		T.eq(first.column, 1)
		T.ok(first.x < 0, "pad 1 is at the end nearest the throwing strip")
		T.eq(DojoPlan.pad(5).row, 1)
		T.eq(DojoPlan.pad(5).column, 5)
		T.eq(DojoPlan.pad(6).row, 2)
		T.eq(DojoPlan.pad(6).column, 1)
		T.eq(DojoPlan.pad(11).floor, 2)
		T.eq(DojoPlan.pad(11).row, 1)
		T.eq(DojoPlan.pad(30).floor, 3)
		T.eq(DojoPlan.pad(30).column, 5)
		for index = 1, DojoPlan.PAD_COUNT do
			local spot = DojoPlan.pad(index)
			T.eq(spot.y, DojoPlan.level(spot.floor), `pad {index} stands on its floor`)
		end
	end,

	["the free pads fill the front row of the ground floor"] = function()
		for index = 1, Tuning.Dojo.startPads do
			local spot = DojoPlan.pad(index)
			T.ok(spot.floor == 1 and spot.row == 1, `pad {index} is by the entrance`)
		end
	end,

	["pads stand inside the building with room to walk around them"] = function()
		local half = DojoPlan.PAD_SIZE / 2
		for index = 1, DojoPlan.PAD_COUNT do
			local spot = DojoPlan.pad(index)
			T.ok(
				math.abs(spot.x) + half <= DojoPlan.HALF_WIDTH - DojoPlan.WALL - WALKWAY,
				`pad {index} keeps clear of the side walls`
			)
			T.ok(
				spot.z - half >= DojoPlan.FRONT + DojoPlan.WALL + WALKWAY,
				`pad {index} keeps clear of the front pillars`
			)
			T.ok(
				spot.z + half <= DojoPlan.BACK - DojoPlan.WALL - WALKWAY,
				`pad {index} keeps clear of the back wall`
			)
		end
	end,

	["no two pads overlap"] = function()
		local reach = DojoPlan.PAD_SIZE + WALKWAY
		for a = 1, DojoPlan.PAD_COUNT do
			for b = a + 1, DojoPlan.PAD_COUNT do
				local p, q = DojoPlan.pad(a), DojoPlan.pad(b)
				T.ok(
					p.floor ~= q.floor
						or math.abs(p.x - q.x) >= reach
						or math.abs(p.z - q.z) >= reach,
					`pads {a} and {b} keep apart`
				)
			end
		end
	end,

	["consoles face each other across an aisle wide enough to stand in"] = function()
		T.eq(DojoPlan.pad(1).facing, 1, "the front row looks towards the back")
		T.eq(DojoPlan.pad(6).facing, -1, "the back row looks towards the front")
		local gap = DojoPlan.BACK_ROW - DojoPlan.FRONT_ROW - DojoPlan.PAD_SIZE
		T.ok(gap - 2 * DojoPlan.CONSOLE_DEPTH >= AISLE, "room between the consoles")
	end,

	["every flight climbs one storey at a gentle slope"] = function()
		T.eq(#DojoPlan.flights, DojoPlan.FLOORS - 1)
		for i, flight in DojoPlan.flights do
			T.near(flight.high - flight.low, DojoPlan.STOREY, EPS, `flight {i} rise`)
			local slope =
				math.deg(math.atan((flight.high - flight.low) / (flight.to - flight.from)))
			T.ok(slope >= 25 and slope <= 35, `flight {i} slopes {slope} degrees`)
			T.ok(DojoPlan.stepRise(flight) <= 0.8, `flight {i} has low steps`)
			T.ok(DojoPlan.stepRun(flight) >= 1, `flight {i} has deep steps`)
		end
	end,

	["the staircase runs without a gap from the street to the top floor"] = function()
		local flights, landings = DojoPlan.flights, DojoPlan.landings
		T.ok(flights[1].from >= -DojoPlan.HALF_WIDTH, "starts on the plot")
		T.eq(flights[1].low, 0, "starts on the ground")
		for i, flight in flights do
			local landing = landings[i]
			T.near(landing.from, flight.to, EPS, `flight {i} ends at its landing`)
			T.near(landing.y, flight.high, EPS, `landing {i} is level with the flight's top`)
			T.eq(landing.floor, i + 1)
			T.near(
				landing.y,
				DojoPlan.level(landing.floor),
				EPS,
				`landing {i} is level with its floor`
			)
			local following = flights[i + 1]
			if following then
				T.near(following.from, landing.to, EPS, `flight {i + 1} leaves landing {i}`)
				T.near(following.low, landing.y, EPS)
			end
		end
		T.eq(landings[#landings].floor, DojoPlan.FLOORS, "reaches the top floor")
		T.ok(landings[#landings].to <= DojoPlan.HALF_WIDTH + EPS, "ends on the plot")
	end,

	["nothing of the staircase hangs over another part of it"] = function()
		local pieces: { { from: number, to: number } } = {}
		for _, flight in DojoPlan.flights do
			table.insert(pieces, flight)
		end
		for _, landing in DojoPlan.landings do
			table.insert(pieces, landing)
		end
		for a = 1, #pieces do
			for b = a + 1, #pieces do
				local p, q = pieces[a], pieces[b]
				T.ok(not overlap(p.from, p.to, q.from, q.to), "one piece above another")
			end
		end
	end,

	["the staircase stays out in front of the building"] = function()
		T.ok(DojoPlan.STAIR_NEAR >= 0, "on the plot")
		T.ok(DojoPlan.STAIR_FAR <= DojoPlan.FRONT + EPS, "clear of the pillars")
		T.ok(DojoPlan.STAIR_FAR - DojoPlan.STAIR_NEAR >= 5, "wide enough to pass on")
	end,

	["each landing opens onto its floor between two pillars"] = function()
		local half = DojoPlan.WALL / 2
		for i, landing in DojoPlan.landings do
			local from, to = DojoPlan.entrance(landing)
			T.ok(to - from >= 6, `entrance {i} is wide enough`)
			for _, x in DojoPlan.pillars do
				T.ok(not overlap(x - half, x + half, from, to), `a pillar stands in entrance {i}`)
			end
		end
	end,

	["the dojo grows a floor when the one below is full"] = function()
		local per = DojoPlan.PADS_PER_FLOOR
		T.eq(DojoPlan.floorsFor(0), 1)
		T.eq(DojoPlan.floorsFor(Tuning.Dojo.startPads), 1, "a new player has one floor")
		T.eq(DojoPlan.floorsFor(per - 1), 1)
		T.eq(DojoPlan.floorsFor(per), 2, "the first floor is full")
		T.eq(DojoPlan.floorsFor(2 * per - 1), 2)
		T.eq(DojoPlan.floorsFor(2 * per), 3, "the second floor is full")
		T.eq(
			DojoPlan.floorsFor(DojoPlan.PAD_COUNT),
			DojoPlan.FLOORS,
			"never more floors than built"
		)
		for unlocked = 0, DojoPlan.PAD_COUNT do
			local floors = DojoPlan.floorsFor(unlocked)
			local forSale = math.min(unlocked + 1, DojoPlan.PAD_COUNT)
			T.ok(
				DojoPlan.pad(forSale).floor <= floors,
				`the pad for sale stands with {unlocked} open`
			)
			T.ok(floors <= DojoPlan.FLOORS, "no floor above the top")
		end
	end,

	["pillars stand at both corners and never too far apart"] = function()
		local pillars = DojoPlan.pillars
		local corner = DojoPlan.HALF_WIDTH - DojoPlan.WALL / 2
		T.near(pillars[1], -corner, EPS)
		T.near(pillars[#pillars], corner, EPS)
		for i = 2, #pillars do
			local span = pillars[i] - pillars[i - 1]
			T.ok(span > DojoPlan.WALL and span <= 16, `span {i} is {span} studs`)
		end
	end,
}
