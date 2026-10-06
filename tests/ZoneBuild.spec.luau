--!strict
-- The rules every zone's scenery keeps, checked on the scenery itself: the builders are run
-- outside Roblox (tests/zones) and what they made is measured. The village round the dojos is
-- built the same way and held to the rules that apply to it.

local Catalog = require("../src/shared/Config/Catalog")
local Signs = require("../src/shared/Logic/Signs")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")
local Zones = require("./zones")

-- Scenery stays out of the lane: nothing nearer its middle than this, studs. The lane is 30
-- to a side and its walls stand just outside that.
local LANE_EDGE = Zones.LANE_WIDTH / 2 + 1.5
-- Unless it lies flat on the lane, like a puddle, or hangs above the kunai's path.
local FLAT = 0.15
local CLEAR = 80
-- A gate's beams cross the lane between these heights: over the tallest enemy, and no higher
-- than the foot of the zone's sign, which stands on the gate.
local GATE_FROM, GATE_TO = 18, Signs.FOOT
-- The frame of a sign stays this close to its board: no lower than this under its foot, no
-- higher than this over its top, and no farther than this up or down the lane.
local FRAME_UNDER, FRAME_OVER, FRAME_NEAR = 6, 10, 4
local BUDGET = { 300, 600 }
local LIGHTS = 12
local SHADOW_FROM = 10
-- How far past its own stretch of the lane a zone's scenery may reach, and how far its
-- backdrop may: hills do not stop at a border. Backdrop is what stands farther from the lane's
-- middle than any zone's own scenery does, so that a hill spills over only into the next zone's
-- backdrop and never in among its houses. (The cave's mountain did, as great dark domes.)
local OVERHANG = 40
local BACKDROP_OVERHANG = 220
local BACKDROP_FROM = Zones.REACH
-- What hangs this high is canopy, not ground: the forest's crowns may lean out over a border.
local CANOPY_FROM = 60
-- Where a zone begins, its own scenery closes the view on both sides of its gate, so that from
-- inside the zone the outside of the one before is not seen through the corners: something at
-- least this tall stands on the ground, no farther than this into the zone, all the way from
-- the gate out to the backdrop.
local WING_HEIGHT = 30
local WING_WITHIN = 45
local WING_FROM, WING_TO = 46, 250
-- The first zone begins at the dojos' yard, which is the same village. The sea begins at a
-- quay: a shore is open.
local UNWALLED = { academy = true, land_of_waves = true }
-- A backdrop closes the view when something this tall stands between these distances from the
-- lane's middle, all along the zone: anywhere from just outside the lane's walls, as the
-- cave's own walls do, out to where the haze takes over.
local HORIZON_HEIGHT = 45
local HORIZON_FROM, HORIZON_TO = 33, 700
-- The sea has no far shore: there the water runs out into the fog, and that is its horizon.
local OPEN = { land_of_waves = true }
-- The yard the players walk in (World/Plots), with room to spare: how far back it goes from
-- the lane's start and how far out from the middle of the street.
local YARD_DEPTH, YARD_HALF = 216, 88

local built: { [string]: Zones.Built } = {}
local function sceneBuilt(id: string): Zones.Built
	if not built[id] then
		built[id] = Zones.build(id)
	end
	return built[id]
end

-- Every scene: the zones in their order, then the village.
local function scenes(): { Zones.Built }
	local all = {}
	for _, zone in Catalog.zones do
		table.insert(all, sceneBuilt(zone.id))
	end
	table.insert(all, sceneBuilt(Zones.HOME))
	return all
end

-- Whether a part's box overlaps the lane's footprint, whatever its height.
local function overLane(low: any, high: any): boolean
	return high.X > 0
		and low.X < Tuning.Kick.trackLength
		and high.Z > -LANE_EDGE
		and low.Z < LANE_EDGE
end

-- How near the lane's middle a part comes on its own side of it; 0 if it lies across.
local function nearest(low: any, high: any): number
	if low.Z > 0 then
		return low.Z
	elseif high.Z < 0 then
		return -high.Z
	end
	return 0
end

local function where(part: any): string
	local at = part.CFrame.Position
	return string.format("%s at %.0f, %.0f, %.0f", Zones.shape(part), at.X, at.Y, at.Z)
end

-- Whether something `tall` stands over the point `x` along the lane, on the given side of it
-- and between `from` and `to` studs out.
local function closed(scenery: Zones.Built, x: number, side: number, tall: number): boolean
	for _, part in scenery.parts do
		local low, high = Zones.bounds(part)
		if high.Y >= tall and low.X <= x and high.X >= x then
			local near = if side > 0 then low.Z else -high.Z
			if near >= HORIZON_FROM and near <= HORIZON_TO then
				return true
			end
		end
	end
	return false
end

return {
	["every zone is within its budget of parts and lights"] = function()
		for _, zone in Catalog.zones do
			local scenery = sceneBuilt(zone.id)
			local count = #scenery.parts
			T.ok(
				count >= BUDGET[1] and count <= BUDGET[2],
				`{zone.id} has {count} parts, outside {BUDGET[1]}..{BUDGET[2]}`
			)
			T.ok(scenery.lights <= LIGHTS, `{zone.id} has {scenery.lights} lights`)
		end
		local village = sceneBuilt(Zones.HOME)
		T.ok(#village.parts <= BUDGET[2], `the village has {#village.parts} parts`)
		T.ok(village.lights <= LIGHTS, `the village has {village.lights} lights`)
	end,

	["scenery is only to be looked at"] = function()
		for _, scenery in scenes() do
			for _, part in scenery.parts do
				T.ok(part.Anchored, `{scenery.id}: {where(part)} is not anchored`)
				T.ok(not part.CanCollide, `{scenery.id}: {where(part)} can be collided with`)
				T.ok(not part.CanQuery, `{scenery.id}: {where(part)} can be hit by a ray`)
			end
		end
	end,

	["nothing stands in the lane or hangs low over it"] = function()
		for _, scenery in scenes() do
			for _, part in scenery.parts do
				local low, high = Zones.bounds(part)
				if not scenery.gate[part] and not scenery.frame[part] and overLane(low, high) then
					T.ok(
						high.Y <= FLAT or low.Y >= CLEAR,
						`{scenery.id}: {where(part)} is in the way, from {low.Y} to {high.Y} up`
					)
				end
			end
		end
	end,

	["a gate stands where its zone begins and crosses the lane under the zone's sign"] = function()
		for _, zone in Catalog.zones do
			local scenery = sceneBuilt(zone.id)
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
			T.ok(crossing > 0, `{zone.id} has no gate over the lane`)
		end
	end,

	["every sign has a frame that stays by its board and off its writing"] = function()
		for _, zone in Catalog.zones do
			local scenery = sceneBuilt(zone.id)
			local sign = scenery.sign :: Signs.Box
			local along = scenery.from + sign.along
			local count = 0
			for _, part in scenery.parts do
				if scenery.frame[part] then
					count += 1
					local low, high = Zones.bounds(part)
					T.ok(
						low.X >= along - FRAME_NEAR and high.X <= along + FRAME_NEAR,
						`{zone.id}: {where(part)} of the sign's frame is not by the board`
					)
					-- Its posts may stand on the ground beside the lane; over the lane it stays up.
					T.ok(
						not overLane(low, high) or low.Y >= sign.foot - FRAME_UNDER,
						`{zone.id}: {where(part)} of the sign's frame hangs to {low.Y}`
					)
					T.ok(
						high.Y <= sign.top + FRAME_OVER,
						`{zone.id}: {where(part)} of the sign's frame rises to {high.Y}`
					)
					-- Nothing of the frame in front of what is written, on either face.
					local onWriting = low.Z < sign.width * 0.46
						and high.Z > -sign.width * 0.46
						and low.Y < sign.top - Signs.MARGIN
						and high.Y > sign.foot + Signs.MARGIN
					T.ok(not onWriting, `{zone.id}: {where(part)} of the frame covers the writing`)
				end
			end
			T.ok(count >= 6, `{zone.id}: the sign's frame is {count} parts`)
		end
	end,

	["a sign is tall enough for what is written on it"] = function()
		for _, zone in Catalog.zones do
			local box = Signs.box(zone)
			local lines = #Signs.details(zone)
			T.near(
				box.height,
				2 * Signs.MARGIN + Signs.NAME + lines * Signs.LINE,
				1e-9,
				`{zone.id} height`
			)
			T.near(box.top - box.foot, box.height, 1e-9, `{zone.id} top`)
			T.near(box.along, zone.startsAt + 0.5, 1e-9, `{zone.id} stands at its start`)
			T.eq(box.foot, Signs.FOOT)
		end
	end,

	["small pieces cast no shadow"] = function()
		for _, scenery in scenes() do
			for _, part in scenery.parts do
				local size = part.Size
				if math.max(size.X, size.Y, size.Z) < SHADOW_FROM then
					T.ok(
						not part.CastShadow,
						`{scenery.id}: {where(part)} is small and casts a shadow`
					)
				end
			end
		end
	end,

	["a zone's scenery keeps to its own stretch of the lane"] = function()
		for index, zone in Catalog.zones do
			local scenery = sceneBuilt(zone.id)
			-- What lies past the end of the lane is the last zone's to build.
			local last = index == #Catalog.zones
			for _, part in scenery.parts do
				local low, high = Zones.bounds(part)
				local backdrop = nearest(low, high) >= BACKDROP_FROM or low.Y >= CANOPY_FROM
				local reach = if backdrop then BACKDROP_OVERHANG else OVERHANG
				T.ok(
					low.X >= scenery.from - reach,
					`{zone.id}: {where(part)} reaches {scenery.from - low.X} before the zone`
				)
				T.ok(
					high.X <= scenery.to + (if last then Zones.FAR else reach),
					`{zone.id}: {where(part)} reaches {high.X - scenery.to} past the zone`
				)
			end
		end
	end,

	["a zone's own scenery closes the view to both sides of its gate"] = function()
		for _, zone in Catalog.zones do
			if not UNWALLED[zone.id] then
				local scenery = sceneBuilt(zone.id)
				for z = WING_FROM, WING_TO, 6 do
					for _, side in { -1, 1 } do
						local shut = false
						for _, part in scenery.parts do
							local low, high = Zones.bounds(part)
							if
								low.Y <= 8
								and high.Y >= WING_HEIGHT
								and low.X <= scenery.from + WING_WITHIN
								and high.X >= scenery.from - 6
								and low.Z <= side * z
								and high.Z >= side * z
							then
								shut = true
								break
							end
						end
						T.ok(shut, `{zone.id}: its start is open {side * z} studs from the lane`)
					end
				end
			end
		end
	end,

	["the ground goes on to the horizon every way"] = function()
		local far = Zones.FAR - 1
		-- Whether flat ground of this scene covers the given rectangle.
		local function covered(
			scenery: Zones.Built,
			fromX: number,
			toX: number,
			fromZ: number,
			toZ: number
		): boolean
			for _, part in scenery.parts do
				local low, high = Zones.bounds(part)
				if
					high.Y <= FLAT
					and low.X <= fromX
					and high.X >= toX
					and low.Z <= fromZ
					and high.Z >= toZ
				then
					return true
				end
			end
			return false
		end
		for index, zone in Catalog.zones do
			local scenery = sceneBuilt(zone.id)
			local from, to = scenery.from, scenery.to
			T.ok(covered(scenery, from, to, 40, far), `{zone.id}: no ground out to the right`)
			T.ok(covered(scenery, from, to, -far, -40), `{zone.id}: no ground out to the left`)
			if index == #Catalog.zones then
				T.ok(covered(scenery, to, to + far, 0, far), "no ground past the lane, right")
				T.ok(covered(scenery, to, to + far, -far, 0), "no ground past the lane, left")
			end
		end
		local village = sceneBuilt(Zones.HOME)
		T.ok(covered(village, -far, 0, 0, far), "no ground behind the dojos, right")
		T.ok(covered(village, -far, 0, -far, 0), "no ground behind the dojos, left")
	end,

	["a backdrop closes the view all along every zone, and behind both ends of the world"] = function()
		for _, zone in Catalog.zones do
			if not OPEN[zone.id] then
				local scenery = sceneBuilt(zone.id)
				for x = scenery.from + 5, scenery.to - 5, 10 do
					for _, side in { -1, 1 } do
						T.ok(
							closed(scenery, x, side, HORIZON_HEIGHT),
							`{zone.id}: the view is open {x} studs along, on side {side}`
						)
					end
				end
			end
		end

		-- Past the far end of the lane, across the whole width of the view down it.
		local last = sceneBuilt(Catalog.zones[#Catalog.zones].id)
		for z = -300, 300, 20 do
			local shut = false
			for _, part in last.parts do
				local low, high = Zones.bounds(part)
				if
					high.Y >= HORIZON_HEIGHT
					and low.X >= last.to + 40
					and low.Z <= z
					and high.Z >= z
				then
					shut = true
					break
				end
			end
			T.ok(shut, `the view past the lane's end is open {z} studs across`)
		end

		-- Round the dojos: both sides, and behind.
		local village = sceneBuilt(Zones.HOME)
		for x = -345, -5, 10 do
			for _, side in { -1, 1 } do
				T.ok(
					closed(village, x, side, HORIZON_HEIGHT),
					`the village: the view is open {x} studs along, on side {side}`
				)
			end
		end
		for z = -300, 300, 20 do
			local shut = false
			for _, part in village.parts do
				local low, high = Zones.bounds(part)
				if high.Y >= 30 and high.X <= -YARD_DEPTH and low.Z <= z and high.Z >= z then
					shut = true
					break
				end
			end
			T.ok(shut, `the view behind the dojos is open {z} studs across`)
		end
	end,

	["the village stays out of the yard"] = function()
		for _, part in sceneBuilt(Zones.HOME).parts do
			local low, high = Zones.bounds(part)
			local inYard = high.X > -YARD_DEPTH
				and low.X < 6
				and high.Z > -YARD_HALF
				and low.Z < YARD_HALF
			T.ok(not inYard or high.Y <= FLAT, `{where(part)} of the village stands in the yard`)
		end
	end,

	["nothing is built over the place's own spawn pad"] = function()
		local spawn = Zones.SPAWN
		for _, scenery in scenes() do
			for _, part in scenery.parts do
				local low, high = Zones.bounds(part)
				local over = low.X < spawn.along + 12
					and high.X > spawn.along - 12
					and low.Z < spawn.side + 12
					and high.Z > spawn.side - 12
				-- A hill is round: its box has corners the hill does not reach.
				if over and Zones.shape(part) == "Ball" then
					local middle = part.CFrame.Position
					local wide = (high.X - low.X) / 2
					local dx, dz = middle.X - spawn.along, middle.Z - spawn.side
					over = math.sqrt(dx * dx + dz * dz) < wide + 12
				end
				T.ok(
					not over or high.Y <= FLAT,
					`{scenery.id}: {where(part)} stands over the spawn pad`
				)
			end
		end
	end,

	["building a zone twice gives the same zone"] = function()
		local first = sceneBuilt("hidden_sand").parts
		local second = Zones.build("hidden_sand").parts
		T.eq(#second, #first)
		for i, part in first do
			local a, b = Zones.describe(part), Zones.describe(second[i])
			for field, value in a do
				T.eq(b[field], value, `part {i}, field {field}`)
			end
		end
	end,
}
