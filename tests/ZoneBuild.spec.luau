--!strict
-- The rules every zone's scenery keeps, checked on the scenery itself: the builders are run
-- outside Roblox (tests/zones) and what they made is measured.

local Catalog = require("../src/shared/Config/Catalog")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")
local Zones = require("./zones")
local reference = require("./fixtures/great_ninja_war")

-- The zone that is kept as it was; it predates the rules below and is held to its own
-- reference instead.
local KEPT = "great_ninja_war"

-- Scenery stays out of the lane: nothing nearer its middle than this, studs. The lane is 30
-- to a side and its walls stand just outside that.
local LANE_EDGE = Zones.LANE_WIDTH / 2 + 1.5
-- Unless it lies flat on the lane, like a puddle, or hangs above the kunai's path.
local FLAT = 0.15
local CLEAR = 80
-- A gate's beams cross the lane between these heights: over the tallest enemy, under the sign.
local GATE_FROM, GATE_TO = 18, 28.5
local BUDGET = { 300, 600 }
local LIGHTS = 12
local SHADOW_FROM = 10
-- How far past its own stretch of the lane a zone's backdrop may reach.
local OVERHANG = 80

local built: { [string]: Zones.Built } = {}
local function zoneBuilt(id: string): Zones.Built
	if not built[id] then
		built[id] = Zones.build(id)
	end
	return built[id]
end

-- Whether a part's box overlaps the lane's footprint, whatever its height.
local function overLane(low: any, high: any): boolean
	return high.X > 0
		and low.X < Tuning.Kick.trackLength
		and high.Z > -LANE_EDGE
		and low.Z < LANE_EDGE
end

local function where(part: any): string
	local at = part.CFrame.Position
	return string.format("%s at %.0f, %.0f, %.0f", part.ClassName, at.X, at.Y, at.Z)
end

return {
	["every new zone is within its budget of parts and lights"] = function()
		for _, zone in Catalog.zones do
			if zone.id ~= KEPT then
				local scenery = zoneBuilt(zone.id)
				local count = #scenery.parts
				T.ok(
					count >= BUDGET[1] and count <= BUDGET[2],
					`{zone.id} has {count} parts, outside {BUDGET[1]}..{BUDGET[2]}`
				)
				T.ok(scenery.lights <= LIGHTS, `{zone.id} has {scenery.lights} lights`)
			end
		end
	end,

	["scenery is only to be looked at"] = function()
		for _, zone in Catalog.zones do
			for _, part in zoneBuilt(zone.id).parts do
				T.ok(part.Anchored, `{zone.id}: {where(part)} is not anchored`)
				T.ok(not part.CanCollide, `{zone.id}: {where(part)} can be collided with`)
				T.ok(not part.CanQuery, `{zone.id}: {where(part)} can be hit by a ray`)
			end
		end
	end,

	["nothing stands in the lane or hangs low over it"] = function()
		for _, zone in Catalog.zones do
			if zone.id ~= KEPT then
				local scenery = zoneBuilt(zone.id)
				for _, part in scenery.parts do
					local low, high = Zones.bounds(part)
					if not scenery.gate[part] and overLane(low, high) then
						T.ok(
							high.Y <= FLAT or low.Y >= CLEAR,
							`{zone.id}: {where(part)} is in the way, from {low.Y} to {high.Y} up`
						)
					end
				end
			end
		end
	end,

	["a gate stands where its zone begins and crosses the lane at the right height"] = function()
		for index, zone in Catalog.zones do
			if zone.id ~= KEPT then
				local scenery = zoneBuilt(zone.id)
				local crossing = 0
				for _, part in scenery.parts do
					if scenery.gate[part] then
						local low, high = Zones.bounds(part)
						T.ok(
							math.abs(part.CFrame.Position.X - scenery.from) <= 8,
							`{zone.id}: {where(part)} of the gate is not at the zone's start`
						)
						if overLane(low, high) then
							crossing += 1
							T.ok(
								low.Y >= GATE_FROM and high.Y <= GATE_TO,
								`{zone.id}: {where(part)} of the gate spans {low.Y} to {high.Y} up`
							)
						end
					end
				end
				-- The first zone begins at the throwing strip and has no gate of its own.
				if index == 1 then
					T.eq(crossing, 0, "the first zone has no gate")
				else
					T.ok(crossing > 0, `{zone.id} has no gate over the lane`)
				end
			end
		end
	end,

	["small pieces cast no shadow"] = function()
		for _, zone in Catalog.zones do
			if zone.id ~= KEPT then
				for _, part in zoneBuilt(zone.id).parts do
					local size = part.Size
					if math.max(size.X, size.Y, size.Z) < SHADOW_FROM then
						T.ok(
							not part.CastShadow,
							`{zone.id}: {where(part)} is small and casts a shadow`
						)
					end
				end
			end
		end
	end,

	["a zone's scenery keeps to its own stretch of the lane"] = function()
		for _, zone in Catalog.zones do
			if zone.id ~= KEPT then
				local scenery = zoneBuilt(zone.id)
				for _, part in scenery.parts do
					local low, high = Zones.bounds(part)
					T.ok(
						low.X >= scenery.from - OVERHANG and high.X <= scenery.to + OVERHANG,
						`{zone.id}: {where(part)} reaches far outside the zone`
					)
				end
			end
		end
	end,

	["building a zone twice gives the same zone"] = function()
		local first = zoneBuilt("hidden_sand").parts
		local second = Zones.build("hidden_sand").parts
		T.eq(#second, #first)
		for i, part in first do
			local a, b = Zones.describe(part), Zones.describe(second[i])
			for field, value in a do
				T.eq(b[field], value, `part {i}, field {field}`)
			end
		end
	end,

	-- The owner's reference: Great Ninja War is not to change.
	["the last zone is built piece for piece as it always was"] = function()
		local parts = zoneBuilt(KEPT).parts
		T.eq(#parts, #reference, "the number of parts")
		for i, part in parts do
			local now, was = Zones.describe(part), reference[i]
			T.eq(#now, #was, `part {i} is described differently`)
			for field, value in now do
				if typeof(value) == "number" then
					T.near(value, was[field] :: number, 1e-4, `part {i}, field {field}`)
				else
					T.eq(value, was[field], `part {i}, field {field}`)
				end
			end
			-- The old scenery cast shadows from everything, down to the smallest stone.
			T.ok(part.CastShadow, `part {i} lost its shadow`)
		end
	end,
}
