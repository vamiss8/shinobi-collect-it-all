--!strict
-- Hidden Sand: the desert village in the heat of the day. Round houses of sandstone under
-- domes crowd both sides of the lane, with the village head's great dome on the left, market
-- awnings by the road, wind-carved pillars of rock, dunes rolling away behind and the cliffs
-- that ring the village closing the view. Past the cliffs the desert rolls on, long dunes and
-- table rocks standing out of the haze.

local Kit = require("./Kit")

return function(scene: Kit.Scene)
	local c = scene.colors
	local length = scene.length
	local function at(along: number, up: number, side: number): Vector3
		return Kit.at(scene, along, up, side)
	end
	local function pick(low: number, high: number): number
		return Kit.pick(scene, low, high)
	end
	local sandstone = Enum.Material.Sandstone
	local wood = Enum.Material.Wood
	local cloth = Enum.Material.Fabric

	Kit.ground(scene)

	-- The gate: two sandstone pylons, a rope between them and a cloth with the village's band.
	Kit.gateway(scene, function()
		for _, side in { -1, 1 } do
			Kit.box(scene, Vector3.new(9, 22, 9), at(0, 0, side * 38), c.cliff, sandstone)
			Kit.box(scene, Vector3.new(7, 6, 7), at(0, 22, side * 38), c.strata, sandstone)
		end
		Kit.rod(scene, at(0, 25, -38), at(0, 25, 38), 0.8, c.wood, wood, true)
		Kit.box(scene, Vector3.new(0.3, 4.6, 22), at(0, 19.6, 0), c.cloth, cloth)
		Kit.box(scene, Vector3.new(0.5, 1, 22.3), at(0, 21.4, 0), c.plate, cloth)
	end)

	-- A round house: a drum of sandstone under a dome, a door and a window looking at the lane,
	-- a vent on top.
	local function house(along: number, side: number, out: number, width: number, height: number)
		local base = at(along, 0, side * out)
		local face = -side * (width / 2 - 0.2)
		Kit.pillar(scene, height, width, base, c.clay, sandstone)
		Kit.ball(scene, width, base + Vector3.new(0, height, 0), c.clay, sandstone)
		Kit.box(scene, Vector3.new(2.6, 4.6, 0.8), base + Vector3.new(0, 0, face), c.door, wood)
		Kit.box(
			scene,
			Vector3.new(2.2, 2.4, 0.8),
			base + Vector3.new(0, height * 0.62, face),
			c.door
		)
		Kit.pillar(
			scene,
			2,
			1.6,
			base + Vector3.new(0, height + width / 2 - 0.4, 0),
			c.clayDark,
			sandstone
		)
	end
	for i = 0, 11 do
		local width = pick(10, 16)
		local along = 10 + i * 16.5 + pick(-3, 3)
		-- Near the village head's building the houses keep to the road, in front of it.
		local out = if math.abs(along - 112) < 30 then pick(46, 62) else pick(46, 128)
		house(along, -1, out, width, pick(8, 18))
	end
	for i = 0, 7 do
		local width = pick(10, 15)
		house(14 + i * 24 + pick(-4, 4), 1, pick(46, 116), width, pick(8, 16))
	end

	-- The village head's building: the largest dome, with a smaller one on its crown and a pale
	-- round plate on the wall that faces the lane.
	local hall = at(112, 0, -96)
	Kit.pillar(scene, 30, 36, hall, c.clay, sandstone)
	Kit.ball(scene, 36, hall + Vector3.new(0, 30, 0), c.clay, sandstone)
	Kit.pillar(scene, 8, 16, hall + Vector3.new(0, 46, 0), c.clayDark, sandstone)
	Kit.ball(scene, 16, hall + Vector3.new(0, 54, 0), c.clay, sandstone)
	Kit.rod(
		scene,
		hall + Vector3.new(0, 20, 17.6),
		hall + Vector3.new(0, 20, 18.6),
		9,
		c.plate,
		nil,
		true
	)
	Kit.box(scene, Vector3.new(5, 8, 1), hall + Vector3.new(0, 0, 17.8), c.door, wood)
	for _, corner in { { -15, 12 }, { 15, 12 }, { -15, -12 }, { 15, -12 } } do
		Kit.box(
			scene,
			Vector3.new(5, 22, 5),
			hall + Vector3.new(corner[1], 0, corner[2]),
			c.clayDark,
			sandstone
		)
	end

	-- Low walls of mud brick between the houses nearest the road.
	for i = 0, 9 do
		local side = if i % 2 == 0 then -1 else 1
		Kit.box(
			scene,
			Vector3.new(pick(10, 16), pick(2.5, 4), 1.4),
			at(16 + i * 18, 0, side * pick(40, 44)),
			c.clayDark,
			sandstone,
			pick(-8, 8)
		)
	end

	-- Market stalls by the road: four poles, a cloth roof sloping to the lane, a counter, pots.
	for i = 0, 5 do
		local side = if i % 2 == 0 then 1 else -1
		local x = 24 + i * 30
		for _, dx in { -4, 4 } do
			Kit.box(scene, Vector3.new(0.5, 6.5, 0.5), at(x + dx, 0, side * 36.5), c.wood, wood)
			Kit.box(scene, Vector3.new(0.5, 8, 0.5), at(x + dx, 0, side * 43), c.wood, wood)
		end
		Kit.block(
			scene,
			Vector3.new(10, 0.3, 8),
			CFrame.new(at(x, 7.4, side * 39.8)) * CFrame.Angles(math.rad(side * 13), 0, 0),
			if i % 3 == 0 then c.clothAlt else c.cloth,
			cloth
		)
		Kit.box(
			scene,
			Vector3.new(8, 2.6, 2),
			at(x, 0, side * 41),
			c.wood,
			Enum.Material.WoodPlanks
		)
		for pot = 0, 2 do
			Kit.pillar(
				scene,
				pick(1.6, 2.8),
				pick(1.4, 2.2),
				at(x - 3 + pot * 3, 0, side * 37.6),
				c.pot,
				sandstone
			)
		end
	end

	-- Pillars of rock the wind has carved: three stones stacked, the middle one the narrowest.
	for i = 0, 13 do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(pick(6, length - 6), 0, side * pick(120, 176))
		local width = pick(8, 14)
		Kit.rock(scene, base, Vector3.new(width, pick(10, 16), width), c.rock, sandstone)
		Kit.rock(
			scene,
			base + Vector3.new(0, 11, 0),
			Vector3.new(width * 0.6, pick(8, 12), width * 0.6),
			c.strata,
			sandstone
		)
		Kit.rock(
			scene,
			base + Vector3.new(0, 20, 0),
			Vector3.new(width * 0.95, pick(5, 8), width * 0.95),
			c.rock,
			sandstone
		)
	end
	-- And one arch of it, on the right.
	Kit.box(scene, Vector3.new(8, 26, 10), at(150, 0, 132), c.rock, sandstone, 10)
	Kit.box(scene, Vector3.new(8, 24, 10), at(178, 0, 138), c.rock, sandstone, -6)
	Kit.box(scene, Vector3.new(40, 7, 11), at(164, 24, 135), c.strata, sandstone, 12)

	-- Dunes: only the crowns of great buried spheres show above the sand.
	for i = 0, 13 do
		local side = if i % 2 == 0 then -1 else 1
		local diameter = pick(70, 130)
		local crest = pick(5, 12)
		Kit.ball(
			scene,
			diameter,
			at(pick(0, length), crest - diameter / 2, side * pick(96, 180)),
			c.dune,
			Enum.Material.Sand
		)
	end

	-- The cliffs that ring the village, banded with darker rock.
	for _, side in { -1, 1 } do
		for i = 0, 7 do
			local x = 12 + i * 25
			local height = pick(64, 100)
			Kit.box(
				scene,
				Vector3.new(30, height, 26),
				at(x, -2, side * pick(172, 184)),
				c.cliff,
				sandstone,
				pick(-8, 8)
			)
			Kit.box(
				scene,
				Vector3.new(31, 5, 27),
				at(x, height * pick(0.3, 0.7), side * 178),
				c.strata,
				sandstone
			)
		end
	end

	-- Streamers on poles, and dry scrub.
	for i = 0, 7 do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(12 + i * 25, 0, side * pick(48, 60))
		Kit.pillar(scene, 12, 0.4, base, c.wood, wood)
		Kit.box(
			scene,
			Vector3.new(5, 1.2, 0.15),
			base + Vector3.new(2.6, 10.6, 0),
			if i % 2 == 0 then c.cloth else c.clothAlt,
			cloth
		)
	end
	for i = 1, 14 do
		local side = if i % 2 == 0 then -1 else 1
		Kit.ball(
			scene,
			pick(1.5, 3),
			at(pick(4, length - 4), 0.4, side * pick(36, 110)),
			c.scrub,
			Enum.Material.Grass
		)
	end

	-- The zone's sign: a tablet of dark clay banded like the cliffs, three small domes on its
	-- top and strips of cloth hanging under it.
	Kit.signage(scene, function(sign)
		local a, half = sign.along, sign.width / 2
		Kit.border(scene, sign, 1, c.strata, sandstone)
		Kit.ball(scene, 4.6, at(a, sign.top + 1.9, 0), c.clay, sandstone)
		for _, side in { -1, 1 } do
			Kit.ball(scene, 3.2, at(a, sign.top + 1, side * (half - 1)), c.clay, sandstone)
			Kit.box(
				scene,
				Vector3.new(1.6, 1.8, 2.4),
				at(a, sign.foot - 2.8, side * 14),
				c.cliff,
				sandstone
			)
		end
		for i = -2, 2 do
			Kit.box(
				scene,
				Vector3.new(0.15, 1.6 + (i % 2) * 0.6, 1.4),
				at(a - 0.6, sign.foot - 3 - (i % 2) * 0.6, i * 7.5),
				if i % 2 == 0 then c.cloth else c.clothAlt,
				cloth
			)
		end
	end)

	-- Past the cliffs the desert rolls on: long dunes, and table rocks standing out of the haze.
	-- On the left the dunes keep clear of where the place's own spawn pad lies (80 studs along,
	-- 300 out): a player is there for a moment before being sent to a dojo.
	local dunes = {
		{ 10, -440, 120 },
		{ 75, -520, 125 },
		{ 140, -440, 120 },
		{ 200, -350, 115 },
		{ 16, 330, 130 },
		{ 74, 400, 150 },
		{ 136, 335, 135 },
		{ 196, 410, 150 },
	}
	for _, dune in dunes do
		Kit.mound(scene, at(dune[1], 0, dune[2]), dune[3], pick(28, 52), c.dune, Enum.Material.Sand)
	end
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			local width, height, depth = pick(70, 110), pick(110, 170), pick(60, 90)
			local base = at(32 + i * 68 + pick(-10, 10), -2, side * pick(470, 560))
			local turn = pick(-12, 12)
			Kit.backdrop(
				Kit.box(scene, Vector3.new(width, height, depth), base, c.cliff, sandstone, turn)
			)
			Kit.backdrop(
				Kit.box(
					scene,
					Vector3.new(width + 2, 9, depth + 2),
					base + Vector3.new(0, height * pick(0.35, 0.7), 0),
					c.strata,
					sandstone,
					turn
				)
			)
		end
	end

	-- The cliffs that ring the village close across its front too, lower the farther out, and
	-- the gate stands in the cleft they leave: the way into the village is through the rock.
	for _, side in { -1, 1 } do
		for i = 0, 7 do
			local height = pick(64, 98) - i * 3
			local z = side * (57 + i * 27)
			Kit.box(
				scene,
				Vector3.new(22, height, 29),
				at(10, -2, z),
				c.cliff,
				sandstone,
				pick(-6, 6)
			)
			Kit.box(
				scene,
				Vector3.new(23, 5, 30),
				at(10, height * pick(0.3, 0.7), z),
				c.strata,
				sandstone
			)
		end
	end
end
