--!strict
-- The plaza behind the lane's start, checked on the plaza itself: its builder is run outside
-- Roblox (tests/zones) and what it made is measured against the layout (Logic/PlazaPlan).

local DojoPlan = require("../src/shared/Logic/DojoPlan")
local PlazaPlan = require("../src/shared/Logic/PlazaPlan")
local T = require("./harness")
local Zones = require("./zones")

-- Anything lower than this is paving or a pattern laid into it: it is walked over, not round.
local FLAT = 0.2
-- How much room a player needs clear of anything solid, studs.
local ROOM = 4
local LANE_HALF = Zones.LANE_WIDTH / 2

local folder: any = nil
local function parts(): { any }
	if not folder then
		folder = Zones.plaza()
	end
	local list = {}
	for _, item in folder:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(list, item)
		end
	end
	return list
end

local function where(part: any): string
	local at = part.CFrame.Position
	return string.format("%s at %.0f, %.0f, %.0f", part.Name, at.X, at.Y, at.Z)
end

-- Whether a part stands up out of the paving inside the given rectangle of the ground.
local function standsIn(part: any, fromX: number, toX: number, fromZ: number, toZ: number): boolean
	local low, high = Zones.bounds(part)
	return high.Y > FLAT and high.X > fromX and low.X < toX and high.Z > fromZ and low.Z < toZ
end

return {
	["the plaza builds, with a sensible number of parts and few lights"] = function()
		local count = #parts()
		T.ok(count >= 150 and count <= 450, `the plaza is {count} parts`)
		local lights = 0
		for _, item in folder:GetDescendants() do
			if item:IsA("PointLight") then
				lights += 1
			end
		end
		T.ok(lights <= 8, `the plaza has {lights} lights`)
	end,

	["everything of the plaza is anchored and stands inside the yard"] = function()
		for _, part in parts() do
			local low, high = Zones.bounds(part)
			T.ok(part.Anchored, `{where(part)} is not anchored`)
			T.ok(low.X >= -PlazaPlan.DEPTH - 0.01, `{where(part)} stands behind the yard`)
			T.ok(high.X <= 0.01, `{where(part)} stands on the lane`)
			T.ok(
				low.Z >= -PlazaPlan.YARD_HALF and high.Z <= PlazaPlan.YARD_HALF,
				`{where(part)} stands outside the yard`
			)
		end
	end,

	["the paving covers the whole plaza"] = function()
		local found = false
		for _, part in parts() do
			local low, high = Zones.bounds(part)
			if
				part.CanCollide
				and math.abs(high.Y) < 1e-6
				and low.X <= -PlazaPlan.DEPTH + 0.01
				and high.X >= -0.01
				and low.Z <= -PlazaPlan.HALF_WIDTH + 0.01
				and high.Z >= PlazaPlan.HALF_WIDTH - 0.01
			then
				found = true
			end
		end
		T.ok(found, "no solid floor from the lane's start to the back and from dojo to dojo")
	end,

	["nothing solid stands where an owner appears"] = function()
		for index = 1, PlazaPlan.DOJOS do
			local spawn = PlazaPlan.spawn(index)
			for _, part in parts() do
				local blocked = part.CanCollide
					and standsIn(
						part,
						spawn.along - ROOM,
						spawn.along + ROOM,
						spawn.side - ROOM,
						spawn.side + ROOM
					)
				T.ok(not blocked, `{where(part)} stands where the owner of dojo {index} appears`)
			end
		end
	end,

	["the stalls' places are left free"] = function()
		local reach = PlazaPlan.STALL_HALF + 1
		for id, spot in PlazaPlan.stalls do
			for _, part in parts() do
				local taken = standsIn(
					part,
					spot.along - reach,
					spot.along + reach,
					spot.side - reach,
					spot.side + reach
				)
				T.ok(not taken, `{where(part)} stands in the place of the {id} stall`)
			end
		end
	end,

	["the way from the plaza onto the lane is open"] = function()
		for _, part in parts() do
			local blocked = part.CanCollide
				and standsIn(part, -PlazaPlan.FRONT_GAP, 1, -LANE_HALF, LANE_HALF)
			T.ok(not blocked, `{where(part)} stands in the way onto the lane`)
		end
	end,

	["nothing of the plaza stands on a dojo's plot or at the foot of its stairs"] = function()
		for index = 1, PlazaPlan.DOJOS do
			local dojo = PlazaPlan.dojo(index)
			-- A dojo's stairs start at its end nearest the lane and are stepped onto from
			-- beside it: a few studs past that end have to stay clear as well.
			local fromX = dojo.along - DojoPlan.HALF_WIDTH
			local toX = dojo.along + DojoPlan.HALF_WIDTH + ROOM
			local near = PlazaPlan.HALF_WIDTH
			local far = PlazaPlan.HALF_WIDTH + DojoPlan.FRONT + ROOM
			for _, part in parts() do
				local onPlot = if dojo.side > 0
					then standsIn(part, fromX, toX, near, far)
					else standsIn(part, fromX, toX, -far, -near)
				T.ok(not onPlot, `{where(part)} stands on the plot of dojo {index}`)
			end
		end
	end,

	["the fountain's basin is walled all the way round, in the plaza's middle"] = function()
		local fountain = PlazaPlan.FOUNTAIN
		local rim = 0
		for _, part in parts() do
			if part.Name == "Rim" then
				rim += 1
				local at = part.CFrame.Position
				local out = math.sqrt((at.X - fountain.along) ^ 2 + (at.Z - fountain.side) ^ 2)
				T.ok(out < PlazaPlan.FOUNTAIN_RADIUS, `{where(part)} is outside the fountain`)
				T.ok(out > PlazaPlan.FOUNTAIN_RADIUS - 3, `{where(part)} is not at the rim`)
				T.ok(part.CanCollide, "the rim is solid")
			end
		end
		T.ok(rim >= 16, `the rim is only {rim} pieces`)
		-- Nothing else that is solid crowds the walk round it, out to where the stalls stand.
		local reach = PlazaPlan.FOUNTAIN_RADIUS
		local clear = PlazaPlan.STALL_RING - PlazaPlan.STALL_HALF
		for _, part in parts() do
			if part.CanCollide then
				local low, high = Zones.bounds(part)
				local at = part.CFrame.Position
				local out = math.sqrt((at.X - fountain.along) ^ 2 + (at.Z - fountain.side) ^ 2)
				local inWalk = high.Y > FLAT and out > reach + 1 and out < reach + 6
				T.ok(not inWalk, `{where(part)} crowds the walk round the fountain ({low.Y})`)
				T.ok(
					clear > reach + 6,
					"the walk round the fountain is narrower than it is checked"
				)
			end
		end
	end,

	["cherry trees stand in the alleys beside the dojos, well back from the plaza"] = function()
		local planters = 0
		for _, part in parts() do
			if part.Name == "Planter" then
				planters += 1
				local at = part.CFrame.Position
				T.ok(
					math.abs(at.Z) >= PlazaPlan.HALF_WIDTH + DojoPlan.FRONT + ROOM + 3,
					`{where(part)} stands at the mouth of an alley`
				)
				for index = 1, PlazaPlan.DOJOS do
					local dojo = PlazaPlan.dojo(index)
					T.ok(
						math.abs(at.X - dojo.along) >= DojoPlan.HALF_WIDTH + 1,
						`{where(part)} stands on the plot of dojo {index}`
					)
				end
			end
		end
		T.eq(planters, 2 * (PlazaPlan.PER_SIDE + 1), "a tree in every alley on both sides")
	end,
}
