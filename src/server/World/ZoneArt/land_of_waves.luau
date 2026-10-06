--!strict
-- Land of Waves: a cold morning on the water. The lane is the deck of a bridge that is still
-- being built: railings and piles along it, side spans that end in the air, scaffolds, a crane
-- and stacks of planks. Around it, in the fog, rowing boats, huts on stilts and small islands.
--
-- The water lies level with the deck, not under it: the grass under the whole world is just
-- below, and the fog hides how shallow the picture is.

local Kit = require("./Kit")

return function(scene: Kit.Scene)
	local c = scene.colors
	local function at(along: number, up: number, side: number): Vector3
		return Kit.at(scene, along, up, side)
	end
	local function pick(low: number, high: number): number
		return Kit.pick(scene, low, high)
	end
	local wood = Enum.Material.Wood
	local planks = Enum.Material.WoodPlanks

	for _, water in Kit.ground(scene) do
		water.Transparency = 0.2
		water.Reflectance = 0.15
	end

	-- The gate: two timber pylons of the bridge with beams across the lane.
	Kit.gateway(scene, function()
		for _, side in { -1, 1 } do
			for _, z in { 35, 40 } do
				Kit.pillar(scene, 28, 2.4, at(0, 0, side * z), c.pile, wood)
			end
			for _, y in { 8, 16, 24 } do
				Kit.rod(scene, at(0, y, side * 34), at(0, y, side * 41), 1.2, c.plankDark, wood)
			end
			Kit.box(
				scene,
				Vector3.new(0.3, 7, 3),
				at(0, 13, side * 33.5),
				c.cloth,
				Enum.Material.Fabric
			)
		end
		Kit.rod(scene, at(0, 25, -42), at(0, 25, 42), 2, c.pile, wood)
		Kit.rod(scene, at(0, 21, -41), at(0, 21, 41), 1.2, c.plankDark, wood)
	end)

	-- Railings and piles along both edges of the deck.
	for _, side in { -1, 1 } do
		for i = 0, 13 do
			Kit.box(
				scene,
				Vector3.new(0.8, 4, 0.8),
				at(6 + i * 8, 0, side * 33.4),
				c.plankDark,
				wood
			)
		end
		Kit.box(scene, Vector3.new(105, 0.4, 0.5), at(58, 3.4, side * 33.4), c.plank, wood)
		Kit.box(
			scene,
			Vector3.new(105, 0.25, 0.25),
			at(58, 1.8, side * 33.4),
			c.rope,
			Enum.Material.Fabric
		)
		for i = 0, 9 do
			Kit.pillar(scene, pick(2, 6), 1.6, at(8 + i * 11.5, 0, side * 36), c.pile, wood)
		end
	end

	-- Side spans that were begun and left: a stretch of deck on piles, loose planks, a stack of
	-- timber, a coil of rope, a couple of crates.
	for index, span in { { 30, 1 }, { 82, 1 }, { 46, -1 }, { 96, -1 } } do
		local x, side = span[1], span[2]
		Kit.box(scene, Vector3.new(14, 0.6, 16), at(x, 0, side * 42), c.plank, planks)
		for _, dx in { -6, 6 } do
			for _, z in { 37, 49 } do
				Kit.pillar(scene, 3, 1.4, at(x + dx, 0, side * z), c.pile, wood)
			end
		end
		Kit.block(
			scene,
			Vector3.new(1.4, 0.3, 9),
			CFrame.new(at(x - 3, 1.6, side * 51)) * CFrame.Angles(math.rad(-18), math.rad(20), 0),
			c.plank,
			planks
		)
		Kit.block(
			scene,
			Vector3.new(1.4, 0.3, 8),
			CFrame.new(at(x + 4, 1.2, side * 50)) * CFrame.Angles(math.rad(-12), math.rad(-25), 0),
			c.plankDark,
			planks
		)
		Kit.box(scene, Vector3.new(7, 1.6, 2.4), at(x + 2, 0.6, side * 38), c.plank, planks, 8)
		Kit.pillar(scene, 0.7, 2.2, at(x - 4, 0.6, side * 44), c.rope, Enum.Material.Fabric)
		Kit.box(
			scene,
			Vector3.new(2.2, 2.2, 2.2),
			at(x - 1, 0.6, side * 46),
			c.boat,
			planks,
			index * 20
		)
		Kit.box(
			scene,
			Vector3.new(1.6, 1.6, 1.6),
			at(x + 1.5, 0.6, side * 45),
			c.plankDark,
			planks,
			35
		)
	end

	-- Scaffolds: four poles, ties between them, a platform and a ladder.
	for _, scaffold in { { 58, 1 }, { 104, -1 } } do
		local x, side = scaffold[1], scaffold[2]
		local near, far = side * 36, side * 42
		for _, dx in { -3, 3 } do
			Kit.rod(scene, at(x + dx, 0, near), at(x + dx, 18, near), 0.6, c.pile, wood, true)
			Kit.rod(scene, at(x + dx, 0, far), at(x + dx, 18, far), 0.6, c.pile, wood, true)
		end
		for _, y in { 6, 12 } do
			Kit.rod(scene, at(x - 3, y, near), at(x + 3, y, near), 0.4, c.plankDark, wood)
			Kit.rod(scene, at(x - 3, y, far), at(x + 3, y, far), 0.4, c.plankDark, wood)
		end
		Kit.box(scene, Vector3.new(7, 0.4, 7), at(x, 12.2, side * 39), c.plank, planks)
		for _, dx in { -0.8, 0.8 } do
			Kit.rod(scene, at(x + dx, 0, side * 44), at(x + dx, 12.6, far), 0.3, c.plankDark, wood)
		end
		for rung = 1, 3 do
			Kit.rod(
				scene,
				at(x - 0.8, rung * 3, side * (44 - rung * 0.5)),
				at(x + 0.8, rung * 3, side * (44 - rung * 0.5)),
				0.25,
				c.plankDark,
				wood
			)
		end
	end

	-- The crane: a mast, a boom leaning out over the water, a rope and a bundle of planks.
	Kit.box(scene, Vector3.new(5, 1.2, 5), at(108, 0, 39), c.plankDark, planks)
	Kit.pillar(scene, 26, 1.6, at(108, 1.2, 39), c.pile, wood)
	Kit.rod(scene, at(108, 24, 39), at(98, 30, 54), 1, c.pile, wood, true)
	Kit.rod(scene, at(98, 30, 54), at(98, 12, 54), 0.2, c.rope)
	Kit.box(scene, Vector3.new(5, 1.4, 2), at(98, 10.6, 54), c.plank, planks, 15)

	-- Lanterns on the first railing posts: the only warm light in the fog.
	for _, side in { -1, 1 } do
		local lantern = Kit.ball(scene, 1.4, at(6, 5, side * 33.4), c.foam, Enum.Material.Neon)
		Kit.light(scene, lantern, c.foam, 16, 0.8)
	end

	-- Rowing boats lying on the water.
	for _ = 1, 7 do
		local side = if pick(0, 1) < 0.5 then -1 else 1
		local turn = pick(0, 180)
		local where = CFrame.new(at(pick(8, 112), 0.5, side * pick(54, 150)))
			* CFrame.Angles(0, math.rad(turn), 0)
		Kit.block(scene, Vector3.new(9, 1, 3), where, c.boat, planks)
		for _, z in { -1.6, 1.6 } do
			Kit.block(
				scene,
				Vector3.new(9.4, 0.5, 0.3),
				where * CFrame.new(0, 0.7, z),
				c.plankDark,
				wood
			)
		end
		Kit.block(scene, Vector3.new(0.5, 0.25, 3), where * CFrame.new(0.5, 0.6, 0), c.plank, wood)
		Kit.block(
			scene,
			Vector3.new(2.2, 1, 2.2),
			where * CFrame.new(4.6, 0.1, 0) * CFrame.Angles(0, math.rad(45), 0),
			c.boat,
			planks
		)
		Kit.block(
			scene,
			Vector3.new(7, 0.2, 0.3),
			where * CFrame.new(-0.5, 1, 2.4) * CFrame.Angles(0, math.rad(12), math.rad(-8)),
			c.rope,
			wood
		)
	end

	-- Fishermen's huts on stilts.
	local huts = { { 16, 92 }, { 58, 128 }, { 100, 98 }, { 24, -104 }, { 66, -86 }, { 102, -132 } }
	for i, hut in huts do
		local x, z = hut[1], hut[2]
		for _, dx in { -4.5, 4.5 } do
			for _, dz in { -4, 4 } do
				Kit.pillar(scene, 7, 0.9, at(x + dx, 0, z + dz), c.pile, wood)
			end
		end
		Kit.box(scene, Vector3.new(12, 0.6, 11), at(x, 6.6, z), c.plank, planks)
		Kit.box(scene, Vector3.new(9, 6, 8), at(x, 7.2, z), c.hut, planks)
		Kit.roof(scene, at(x, 16.4, z), 11, 6, 30, c.roof, Enum.Material.Slate, i % 2 == 0)
		Kit.box(
			scene,
			Vector3.new(2, 4, 0.3),
			at(x, 7.2, z - (if z > 0 then 4 else -4)),
			c.plankDark,
			wood
		)
	end

	-- Small islands of rock, each with a crooked pine.
	for _ = 1, 5 do
		local side = if pick(0, 1) < 0.5 then -1 else 1
		local x, z = pick(6, 114), side * pick(70, 165)
		Kit.rock(scene, at(x, 0, z), Vector3.new(pick(12, 20), pick(5, 9), pick(10, 16)), c.rock)
		Kit.rock(
			scene,
			at(x + 5, 0, z + 4),
			Vector3.new(pick(6, 9), pick(3, 5), pick(6, 9)),
			c.rock
		)
		Kit.rod(scene, at(x, 3, z), at(x + 2, 13, z - 1), 1.1, c.bark, wood, true)
		Kit.ball(scene, 7, at(x + 2.5, 14.5, z - 1), c.leaf, Enum.Material.Grass)
		Kit.ball(scene, 5, at(x - 0.5, 11.5, z + 1.5), c.leaf, Enum.Material.Grass)
	end

	-- Mooring poles standing about, some leaning; foam around the nearer ones.
	for i = 1, 24 do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(pick(4, 116), 0, side * pick(44, 120))
		local lean = Vector3.new(pick(-1.5, 1.5), pick(4, 12), pick(-1.5, 1.5))
		Kit.rod(scene, base, base + lean, 1.1, c.pile, wood, true)
		if i <= 16 then
			Kit.box(
				scene,
				Vector3.new(pick(3, 6), 0.06, 0.5),
				base + Vector3.new(pick(-1, 1), 0, 1.2),
				c.foam,
				nil,
				pick(0, 180)
			)
		end
	end

	-- Racks with nets hung out to dry.
	for _, rack in { { 40, 62 }, { 88, -60 }, { 14, -58 } } do
		local x, z = rack[1], rack[2]
		for _, dx in { -4, 4 } do
			Kit.pillar(scene, 6, 0.5, at(x + dx, 0, z), c.pile, wood)
		end
		local net =
			Kit.box(scene, Vector3.new(8, 4, 0.2), at(x, 1.6, z), c.rope, Enum.Material.Fabric)
		net.Transparency = 0.45
	end

	-- Banks of fog lying on the water away from the lane.
	for i = 1, 6 do
		local side = if i % 2 == 0 then -1 else 1
		local bank = Kit.box(
			scene,
			Vector3.new(pick(50, 70), pick(6, 10), pick(30, 46)),
			at(pick(10, 110), pick(1, 5), side * pick(96, 150)),
			c.mist
		)
		bank.Transparency = 0.9
		bank.CastShadow = false
	end
end
