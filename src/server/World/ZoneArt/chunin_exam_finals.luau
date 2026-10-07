--!strict
-- Chunin Exam Finals: the arena at noon. High walls run along both sides of the lane with
-- three tiers of stands behind them and a crowd on every tier, flags along the top, banners on
-- the walls, corner towers, and on the left the covered box where the two Kage sit. The arena
-- stands in the village: its wooded hills close the view beyond the stands.

local Kit = require("./Kit")

local WALL = 36 -- where the arena's wall stands, studs from the lane's middle
local WALL_HEIGHT = 14
local TIER_DEPTH = 6
local TIER_RISE = 4
local FIRST, LAST = 8, 152 -- the stretch of the zone the stands run along
local SEAT = 6 -- distance between two spectators

return function(scene: Kit.Scene)
	local c = scene.colors
	local function at(along: number, up: number, side: number): Vector3
		return Kit.at(scene, along, up, side)
	end
	local function pick(low: number, high: number): number
		return Kit.pick(scene, low, high)
	end
	local function group(anchor: number, build: () -> ())
		Kit.group(scene, anchor, build)
	end
	local function many(count: number): number
		return Kit.many(scene, count)
	end
	local function gap(step: number): number
		return Kit.gap(scene, step)
	end
	local function far(studs: number): number
		return Kit.far(scene, studs)
	end
	local stone = Enum.Material.Concrete
	local wood = Enum.Material.Wood
	local cloth = Enum.Material.Fabric
	local crowd = { c.crowdRed, c.crowdBlue, c.crowdGold, c.crowdGreen, c.crowdWhite }
	local middle = (FIRST + LAST) / 2
	local run = LAST - FIRST

	Kit.ground(scene)

	-- The gate: two stone towers, a beam between them and the exam's banner hung from it.
	Kit.gateway(scene, function()
		for _, side in { -1, 1 } do
			Kit.box(scene, Vector3.new(8, 30, 8), at(0, 0, side * 38), c.wall, stone)
			Kit.box(scene, Vector3.new(9.4, 1.4, 9.4), at(0, 30, side * 38), c.cap, stone)
			Kit.pillar(scene, 9, 0.5, at(0, 31.4, side * 38), c.pole, wood)
			Kit.box(scene, Vector3.new(4.5, 2.6, 0.2), at(2.4, 37, side * 38), c.flag, cloth)
		end
		Kit.rod(scene, at(0, 25, -35), at(0, 25, 35), 1.8, c.wood, wood)
		Kit.box(scene, Vector3.new(0.3, 4, 24), at(0, 19.6, 0), c.banner, cloth)
		Kit.box(scene, Vector3.new(0.35, 1, 16), at(0, 21, 0), c.flag, cloth)
	end)

	for _, side in { -1, 1 } do
		-- The wall around the floor, its capstone, and the tiers stepping up behind it.
		Kit.box(
			scene,
			Vector3.new(far(run), WALL_HEIGHT, 3),
			at(middle, 0, side * WALL),
			c.wall,
			stone
		)
		Kit.box(
			scene,
			Vector3.new(far(run), 1, 4.2),
			at(middle, WALL_HEIGHT, side * WALL),
			c.cap,
			stone
		)
		for tier = 1, 3 do
			local top = WALL_HEIGHT + tier * TIER_RISE
			local out = WALL + 2.5 + (tier - 0.5) * TIER_DEPTH
			Kit.box(
				scene,
				Vector3.new(far(run), top, TIER_DEPTH),
				at(middle, 0, side * out),
				c.tier,
				stone
			)

			-- The crowd: a head in every seat, except where the Kage's box stands.
			for seat = 0, many(run // SEAT) - 1 do
				local x = FIRST + gap(SEAT) / 2 + seat * gap(SEAT)
				local boxed = side == -1 and tier <= 2 and far(math.abs(x - 80)) < 13
				if not boxed then
					Kit.ball(
						scene,
						2.4,
						at(x + pick(-1, 1), top + 1.2, side * out),
						Kit.oneOf(scene, crowd)
					)
				end
				-- The top tier is packed: a second row stands behind the first.
				if tier == 3 then
					Kit.ball(
						scene,
						2.4,
						at(x + gap(3), top + 2.4, side * (out + 2.2)),
						Kit.oneOf(scene, crowd)
					)
				end
			end
		end
		-- The back wall and the awning over the top tier.
		local back = WALL + 2.5 + 3 * TIER_DEPTH + 1
		Kit.box(scene, Vector3.new(far(run), 36, 2), at(middle, 0, side * back), c.wallShade, stone)
		Kit.block(
			scene,
			Vector3.new(far(run) + 0.6, 0.8, 11),
			CFrame.new(at(middle, 35, side * (back - 5))) * CFrame.Angles(math.rad(side * 10), 0, 0),
			c.roof,
			Enum.Material.Slate
		)

		-- Flags along the top of the back wall, and banners down the wall that faces the lane.
		for i = 0, many(7) do
			local x = FIRST + 9 + i * gap(18)
			Kit.group(scene, x, function()
				Kit.pillar(scene, 12, 0.5, at(x, 36, side * back), c.pole, wood)
				Kit.box(
					scene,
					Vector3.new(5, 3, 0.2),
					at(x + 2.6, 44, side * back),
					if i % 2 == 0 then c.flag else c.flagAlt,
					cloth
				)
			end)
		end
		for i = 0, many(5) do
			local x = FIRST + 12 + i * gap(24)
			local face = side * (WALL - 1.7)
			Kit.box(scene, Vector3.new(5, 8, 0.3), at(x, 4, face), c.banner, cloth)
			Kit.box(
				scene,
				Vector3.new(5.2, 1.2, 0.5),
				at(x, 9, face),
				if i % 2 == 0 then c.flag else c.flagAlt,
				cloth
			)
		end

		-- A tower at each end of the stands.
		for _, x in { FIRST - 2, LAST + 2 } do
			Kit.group(scene, x, function()
				Kit.box(scene, Vector3.new(10, 40, 10), at(x, 0, side * (WALL + 9)), c.wall, stone)
				Kit.box(
					scene,
					Vector3.new(11.6, 1.6, 11.6),
					at(x, 40, side * (WALL + 9)),
					c.cap,
					stone
				)
				Kit.pillar(scene, 10, 0.5, at(x, 41.6, side * (WALL + 9)), c.pole, wood)
				Kit.box(
					scene,
					Vector3.new(5, 3, 0.2),
					at(x + 2.6, 48, side * (WALL + 9)),
					c.flag,
					cloth
				)
			end)
		end
	end

	-- The Kage's box on the left: a roofed balcony over the lower tiers with two seats, and in
	-- them two figures in white robes and broad hats. They are stand-ins, not portraits.
	local floor = WALL_HEIGHT + 2 * TIER_RISE
	local boxAt = -(WALL + 2.5 + TIER_DEPTH)
	group(80, function()
		Kit.box(
			scene,
			Vector3.new(24, 1, 13),
			at(80, floor, boxAt),
			c.wood,
			Enum.Material.WoodPlanks
		)
		for _, dx in { -11, 11 } do
			for _, dz in { -5.5, 5.5 } do
				Kit.box(
					scene,
					Vector3.new(0.9, 10, 0.9),
					at(80 + dx, floor + 1, boxAt + dz),
					c.pole,
					wood
				)
			end
		end
		Kit.roof(scene, at(80, floor + 14.6, boxAt), 27, 8.5, 24, c.roof, Enum.Material.Slate)
		Kit.box(scene, Vector3.new(24, 2.4, 0.4), at(80, floor + 1, boxAt + 6.3), c.banner, cloth)
		for index, dx in { -4.5, 4.5 } do
			local x = 80 + dx
			Kit.box(scene, Vector3.new(4, 1.2, 3.4), at(x, floor + 1, boxAt - 1), c.wood, wood)
			Kit.box(scene, Vector3.new(4, 5, 0.6), at(x, floor + 2.2, boxAt - 2.8), c.wood, wood)
			Kit.box(scene, Vector3.new(2.6, 3, 2), at(x, floor + 2.2, boxAt - 0.6), c.robe, cloth)
			Kit.ball(scene, 1.9, at(x, floor + 6.2, boxAt - 0.6), c.crowdWhite)
			local hat = if index == 1 then c.hatFire else c.hatWind
			Kit.pillar(scene, 0.4, 4, at(x, floor + 7, boxAt - 0.6), c.robe, cloth)
			Kit.box(scene, Vector3.new(1.4, 1, 1.4), at(x, floor + 7.4, boxAt - 0.6), hat, cloth)
		end
	end)

	-- Pale patches where the sand of the floor is worn, lying flat on the lane.
	for i = 0, many(9) do
		Kit.pillar(
			scene,
			0.06,
			pick(8, 14),
			at(12 + i * gap(15) + gap(pick(-3, 3)), 0.02, pick(-22, 22)),
			c.patch,
			Enum.Material.Sand
		)
	end

	-- Braziers at the foot of the walls and trees looking over the back of the stands.
	for i = 0, many(4) - 1 do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(40 + (i // 2) * gap(80) - (80 - gap(80)) / 4, 0, side * (WALL - 2.4))
		Kit.pillar(scene, 3, 1.6, base, c.cap, stone)
		Kit.ball(scene, 1.6, base + Vector3.new(0, 3.6, 0), c.torch, Enum.Material.Neon)
	end
	for i = 0, many(7) do
		local side = if i % 2 == 0 then -1 else 1
		Kit.tree(
			scene,
			at(14 + i * gap(19), 0, side * pick(70, 86)),
			pick(30, 40),
			3,
			pick(16, 22),
			c.bark,
			c.leaf,
			2
		)
	end

	-- The zone's sign: a dark board framed in wood under a red valance, gold studs at its
	-- corners and a pennant at each end.
	Kit.signage(scene, function(sign)
		local a, half = sign.along, sign.width / 2
		Kit.border(scene, sign, 0.9, c.wood, wood)
		Kit.box(
			scene,
			Vector3.new(0.7, 1.3, sign.width + 3),
			at(a, sign.top + 0.9, 0),
			c.flag,
			cloth
		)
		for _, side in { -1, 1 } do
			for _, y in { sign.foot - 0.45, sign.top + 0.45 } do
				Kit.ball(scene, 1.4, at(a, y, side * (half + 0.45)), c.crowdGold)
			end
			Kit.pillar(scene, 5, 0.35, at(a, sign.top + 2.2, side * (half + 0.4)), c.pole, wood)
			Kit.box(
				scene,
				Vector3.new(0.15, 1.8, 3),
				at(a, sign.top + 5.2, side * (half + 2)),
				if side == 1 then c.flag else c.flagAlt,
				cloth
			)
			Kit.box(
				scene,
				Vector3.new(1.4, 1.4, 1.4),
				at(a, sign.foot - 2.3, side * 13),
				c.cap,
				stone
			)
		end
	end)

	-- The village's wooded hills beyond the stands: a nearer row with trees on it, a higher one
	-- behind.
	local grass = Enum.Material.Grass
	for _, side in { -1, 1 } do
		for i = 0, many(2) do
			local x = 24 + i * gap(56) + gap(pick(-8, 8))
			local out = pick(320, 345)
			local height = pick(55, 80)
			Kit.group(scene, x, function()
				-- The hill stands where the Kit lets it: clear of the place's spawn pad, which
				-- lies beside this zone. The trees stand on the hill wherever that is.
				local hill =
					Kit.mound(scene, at(x, 0, side * out), pick(105, 128), height, c.hill, grass)
				local moved = hill.CFrame.Position.Z - at(x, 0, side * out).Z
				for _ = 1, 2 do
					Kit.backdrop(
						Kit.ball(
							scene,
							pick(22, 34),
							at(
								x + pick(-45, 45),
								height * pick(0.6, 0.95),
								side * (out + pick(-25, 35))
							) + Vector3.new(0, 0, moved),
							c.leaf,
							grass
						)
					)
				end
			end)
		end
		for i = 0, many(1) do
			Kit.mound(
				scene,
				at(40 + i * gap(80) + gap(pick(-10, 10)), 0, side * pick(470, 530)),
				pick(190, 225),
				pick(120, 150),
				c.hillFar,
				grass
			)
		end
	end

	-- The arena's outer wall. Where the zone begins it runs out from the corner towers to both
	-- sides, capped, buttressed and hung with banners, a flag on every buttress: from the forest
	-- the arena is a wall with its gate in the middle.
	group(0, function()
		for _, side in { -1, 1 } do
			Kit.box(scene, Vector3.new(4, 34, 216), at(3, 0, side * 158), c.wallShade, stone)
			Kit.box(scene, Vector3.new(5.4, 1.2, 216), at(3, 34, side * 158), c.cap, stone)
			for i = 0, 4 do
				local z = side * (72 + i * 43)
				Kit.box(scene, Vector3.new(6, 38, 6), at(3, 0, z), c.wall, stone)
				Kit.pillar(scene, 9, 0.5, at(3, 38, z), c.pole, wood)
				Kit.box(
					scene,
					Vector3.new(0.2, 3, 5),
					at(3, 43.6, z + 2.7),
					if i % 2 == 0 then c.flag else c.flagAlt,
					cloth
				)
				Kit.box(
					scene,
					Vector3.new(0.3, 12, 5),
					at(0.85, 14, z + side * 21),
					c.banner,
					cloth
				)
			end
		end
	end)
end
