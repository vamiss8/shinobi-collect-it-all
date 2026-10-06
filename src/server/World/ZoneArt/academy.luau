--!strict
-- Academy Grounds: a sunny morning in the village. The Academy stands on the left with its red
-- roof and round sign, a tree with a swing by the lane, rows of training posts and targets on
-- the right, a ramen stand at the far corner, village houses behind, and far off a cliff with
-- four great faces cut into it.
--
-- The zone has no gate of its own: it begins at the throwing strip, which is the Hub's.

local Kit = require("./Kit")

return function(scene: Kit.Scene)
	local c = scene.colors
	local function at(along: number, up: number, side: number): Vector3
		return Kit.at(scene, along, up, side)
	end
	local function pick(low: number, high: number): number
		return Kit.pick(scene, low, high)
	end

	Kit.ground(scene)

	-- The Academy, its front to the lane.
	local front = -66
	Kit.box(scene, Vector3.new(56, 20, 24), at(58, 0, front - 12), c.wall)
	Kit.box(scene, Vector3.new(57, 1, 1), at(58, 10, front + 0.3), c.trim, Enum.Material.Wood)
	Kit.roof(scene, at(58, 27.9, front - 12), 60, 15, 28, c.roof, Enum.Material.Slate)
	Kit.box(
		scene,
		Vector3.new(60, 1.2, 1.6),
		at(58, 27.6, front - 12),
		c.roofDark,
		Enum.Material.Wood
	)
	for _, floor in { 3, 13 } do
		for i = 0, 5 do
			Kit.box(scene, Vector3.new(3, 4, 0.5), at(34 + i * 9.6, floor, front + 0.2), c.window)
		end
	end
	Kit.box(scene, Vector3.new(4, 7, 0.5), at(58, 0, front + 0.2), c.door, Enum.Material.Wood)
	for _, side in { -1, 1 } do
		Kit.box(
			scene,
			Vector3.new(0.8, 8, 0.8),
			at(58 + side * 4, 0, front + 5),
			c.trim,
			Enum.Material.Wood
		)
	end
	Kit.roof(scene, at(58, 9.3, front + 2.5), 11, 3.4, 22, c.roof, Enum.Material.Slate)
	-- The round sign over the door: a red disc with a dark mark, facing the lane.
	Kit.rod(scene, at(58, 15, front + 0.2), at(58, 15, front + 0.8), 5, c.band, nil, true)
	Kit.rod(scene, at(58, 15, front + 0.7), at(58, 15, front + 1), 2.2, c.door, nil, true)
	for step = 1, 3 do
		Kit.box(
			scene,
			Vector3.new(8, 0.5, 1.2),
			at(58, (3 - step) * 0.5, front + 0.6 + step * 1.2),
			c.stone,
			Enum.Material.Slate
		)
	end
	-- Its lower wing.
	Kit.box(scene, Vector3.new(22, 13, 18), at(19, 0, front - 9), c.wallShade)
	Kit.roof(scene, at(19, 18.3, front - 9), 24, 11, 26, c.roofDark, Enum.Material.Slate)
	for _, x in { 13, 25 } do
		Kit.box(scene, Vector3.new(3, 4, 0.5), at(x, 5, front + 0.2), c.window)
	end

	-- A path of flagstones from the lane to the door, a fence along the yard, benches and two
	-- trees in blossom.
	for i = 0, 5 do
		Kit.box(
			scene,
			Vector3.new(5, 0.2, 4),
			at(58 + pick(-0.6, 0.6), 0, -36 - i * 5),
			c.path,
			Enum.Material.Slate
		)
	end
	for i = 0, 15 do
		local x = 8 + i * 6
		-- The two posts either side of the path stand taller: a gateway.
		local height = if x == 56 or x == 62 then 5 else 3
		Kit.box(scene, Vector3.new(0.6, height, 0.6), at(x, 0, -35), c.fence, Enum.Material.Wood)
	end
	for _, y in { 1.2, 2.4 } do
		Kit.box(scene, Vector3.new(45, 0.3, 0.3), at(31, y, -35), c.fence, Enum.Material.Wood)
		Kit.box(scene, Vector3.new(36, 0.3, 0.3), at(80, y, -35), c.fence, Enum.Material.Wood)
	end
	for _, x in { 40, 76 } do
		Kit.box(scene, Vector3.new(5, 0.4, 1.6), at(x, 1.4, -41), c.fence, Enum.Material.WoodPlanks)
		for _, leg in { -2, 2 } do
			Kit.box(
				scene,
				Vector3.new(0.4, 1.4, 1.4),
				at(x + leg, 0, -41),
				c.trim,
				Enum.Material.Wood
			)
		end
	end
	for _, x in { 46, 70 } do
		Kit.tree(scene, at(x, 0, -60), 8, 1.6, 9, c.bark, c.blossom, 3)
	end

	-- The tree with the swing, on the right by the strip.
	Kit.pillar(scene, 18, 3.4, at(30, 0, 48), c.bark, Enum.Material.Wood)
	Kit.ball(scene, 16, at(30, 22, 48), c.leaf, Enum.Material.Grass)
	Kit.ball(scene, 11, at(25, 19, 52), c.leafLight, Enum.Material.Grass)
	Kit.ball(scene, 11, at(35, 20, 44), c.leaf, Enum.Material.Grass)
	Kit.rod(scene, at(30, 12, 48), at(30, 13, 39), 1.2, c.bark, Enum.Material.Wood, true)
	for _, x in { 29, 31 } do
		Kit.rod(scene, at(x, 12.6, 41), at(x, 3, 41), 0.2, c.cloth)
	end
	Kit.box(scene, Vector3.new(3, 0.3, 1.2), at(30, 2.7, 41), c.trim, Enum.Material.Wood)

	-- The training field: posts with a red band, targets behind them and straw dummies.
	for row = 0, 2 do
		for column = 0, 3 do
			local base = at(46 + column * 7, 0, 40 + row * 7)
			Kit.pillar(scene, 6, 1.6, base, c.bark, Enum.Material.Wood)
			Kit.pillar(scene, 0.8, 1.8, base + Vector3.new(0, 4, 0), c.band, Enum.Material.Fabric)
		end
	end
	for i = 0, 3 do
		local x = 48 + i * 7
		Kit.pillar(scene, 4, 0.6, at(x, 0, 62), c.bark, Enum.Material.Wood)
		Kit.box(scene, Vector3.new(4, 4, 0.4), at(x, 4, 62), c.target, Enum.Material.Wood)
		Kit.rod(scene, at(x, 6, 61.75), at(x, 6, 61.55), 1.6, c.band, nil, true)

		Kit.pillar(scene, 5, 1, at(x - 2, 0, 68), c.bark, Enum.Material.Wood)
		Kit.rod(scene, at(x - 3.6, 3.6, 68), at(x - 0.4, 3.6, 68), 0.5, c.bark, Enum.Material.Wood)
		Kit.ball(scene, 1.6, at(x - 2, 5.6, 68), c.cloth, Enum.Material.Fabric)
	end

	-- The ramen stand at the far corner: a counter under a roof, curtains, stools, a lantern.
	Kit.box(scene, Vector3.new(12, 3.4, 2.4), at(86, 0, 42), c.fence, Enum.Material.WoodPlanks)
	Kit.box(scene, Vector3.new(12, 8, 0.6), at(86, 0, 47.5), c.wallShade)
	Kit.box(scene, Vector3.new(11, 0.4, 1.2), at(86, 4.6, 47), c.trim, Enum.Material.Wood)
	for _, x in { 80, 92 } do
		for _, z in { 41, 47.6 } do
			Kit.box(scene, Vector3.new(0.7, 8.6, 0.7), at(x, 0, z), c.trim, Enum.Material.Wood)
		end
	end
	Kit.roof(scene, at(86, 10.8, 44.3), 15, 5.2, 24, c.roofDark, Enum.Material.Slate)
	for i = 0, 4 do
		local cloth = if i % 2 == 0 then c.cloth else c.band
		Kit.box(
			scene,
			Vector3.new(2, 2.2, 0.15),
			at(81.2 + i * 2.4, 6.2, 41),
			cloth,
			Enum.Material.Fabric
		)
	end
	for i = 0, 3 do
		Kit.pillar(scene, 1.6, 1.2, at(81.5 + i * 3, 0, 39.6), c.trim, Enum.Material.Wood)
	end
	local lantern = Kit.ball(scene, 1.8, at(79.2, 6.4, 40.4), c.lantern, Enum.Material.Neon)
	Kit.light(scene, lantern, c.lantern, 14, 1)
	Kit.box(scene, Vector3.new(7, 2, 0.4), at(86, 11.6, 41.4), c.cloth, Enum.Material.Wood)
	Kit.box(scene, Vector3.new(5, 0.5, 0.45), at(86, 12.3, 41.38), c.band)
	Kit.pillar(scene, 1.4, 1.6, at(89, 3.4, 42), c.stone, Enum.Material.Metal)

	-- Far off on the left, the cliff over the village with four great faces cut into it, tall
	-- enough to be seen over the Academy's roof from the lane. The faces are only blocks: a
	-- brow, a nose, eyes, a mouth, each under a different crown of hair.
	for i = 0, 4 do
		Kit.box(
			scene,
			Vector3.new(30, pick(118, 140), 34),
			at(10 + i * 20, -2, -178 + pick(-4, 4)),
			c.cliff,
			Enum.Material.Slate,
			pick(-6, 6)
		)
	end
	for i = 0, 3 do
		Kit.rock(scene, at(18 + i * 22, 0, -152), Vector3.new(24, pick(30, 44), 22), c.cliffShade)
	end
	for i = 0, 3 do
		local x = 20 + i * 20
		Kit.box(scene, Vector3.new(16, 24, 5), at(x, 72, -160.5), c.cliffShade, Enum.Material.Slate)
		Kit.box(
			scene,
			Vector3.new(17, 5 + i * 1.5, 6),
			at(x, 96, -160.5),
			c.cliff,
			Enum.Material.Slate
		)
		Kit.box(scene, Vector3.new(15, 2.4, 1.6), at(x, 89, -157.4), c.cliff, Enum.Material.Slate)
		Kit.box(scene, Vector3.new(2.8, 8, 2.8), at(x, 80, -157.2), c.cliff, Enum.Material.Slate)
		Kit.box(scene, Vector3.new(6, 1, 0.6), at(x, 76, -157.7), c.trim)
		for _, eye in { -3.8, 3.8 } do
			Kit.box(scene, Vector3.new(3.4, 1.6, 0.7), at(x + eye, 86, -157.7), c.trim)
		end
		Kit.ball(scene, 16, at(x + 10, 124, -178), c.leaf, Enum.Material.Grass)
	end

	-- Village houses behind the field and beside the Academy.
	local houses = {
		{ 12, 100 },
		{ 34, 112 },
		{ 58, 98 },
		{ 80, 110 },
		{ 22, 150 },
		{ 46, 146 },
		{ 70, 152 },
		{ 92, 144 },
		{ 94, -118 },
		{ 6, -122 },
	}
	for i, house in houses do
		local x, z = house[1], house[2]
		local width, height, depth = pick(14, 18), pick(9, 12), pick(12, 14)
		-- The door looks at the lane.
		local face = if z > 0 then -1 else 1
		Kit.box(
			scene,
			Vector3.new(width, height, depth),
			at(x, 0, z),
			if i % 2 == 0 then c.wall else c.wallShade
		)
		-- The roof's foot rests on the walls: its ridge is as high over them as its slope takes it.
		local reach = depth / 2 + 2
		Kit.roof(
			scene,
			at(x, height + reach * math.tan(math.rad(26)) - 0.1, z),
			width + 3,
			reach,
			26,
			if i % 3 == 0 then c.roofDark else c.roof,
			Enum.Material.Slate
		)
		Kit.box(
			scene,
			Vector3.new(2.6, 5, 0.4),
			at(x - 3, 0, z + face * depth / 2),
			c.door,
			Enum.Material.Wood
		)
		Kit.box(scene, Vector3.new(3, 2.6, 0.4), at(x + 3, 4, z + face * depth / 2), c.window)
	end

	-- Trees, bushes along the lane and flowers.
	for _ = 1, 6 do
		Kit.tree(
			scene,
			at(pick(6, 96), 0, pick(74, 88)),
			pick(6, 9),
			1.6,
			pick(8, 11),
			c.bark,
			c.leaf,
			2
		)
	end
	for _ = 1, 4 do
		Kit.tree(
			scene,
			at(pick(2, 10), 0, -pick(40, 58)),
			pick(6, 9),
			1.6,
			pick(8, 11),
			c.bark,
			c.leafLight,
			2
		)
	end
	for _ = 1, 6 do
		Kit.tree(
			scene,
			at(pick(4, 96), 0, -pick(98, 132)),
			pick(8, 12),
			2,
			pick(10, 14),
			c.bark,
			c.leaf,
			2
		)
	end
	for i = 1, 12 do
		local side = if i % 2 == 0 then -1 else 1
		Kit.ball(
			scene,
			pick(3, 5),
			at(pick(12, 98), 0.6, side * pick(37, 39)),
			c.leafLight,
			Enum.Material.Grass
		)
	end
	for i = 1, 18 do
		Kit.ball(
			scene,
			0.8,
			at(pick(40, 76), 0.3, -pick(38, 62)),
			if i % 2 == 0 then c.flower else c.blossom
		)
	end
end
