--!strict
-- Kamui Dimension: a void with no sky. Pale cuboids of every height stand in ranks away from
-- the lane and step up into the haze, thin columns rise among them, and cubes hang in the air
-- at every height, a few with an edge of violet light. Nothing here is alive and nothing is
-- any other color. Behind the great blocks at the edge of sight stand greater ones, and the
-- floor goes on under them into the gray.
--
-- The cuboids on the ground stand square to the lane, as they do in the dimension itself; only
-- what floats is turned.

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
	local shades = { c.cube, c.cubeDark, c.cubeLight }
	local neon = Enum.Material.Neon

	Kit.ground(scene)

	-- The gate: two stacks of cubes and three long blocks laid across them.
	Kit.gateway(scene, function()
		for _, side in { -1, 1 } do
			Kit.box(scene, Vector3.new(8, 8, 8), at(0, 0, side * 37), c.cubeDark)
			Kit.box(scene, Vector3.new(7, 7, 7), at(0.6, 8, side * 37.6), c.cube)
			Kit.box(scene, Vector3.new(6, 6, 6), at(-0.4, 15, side * 36.8), c.cubeLight)
		end
		Kit.box(scene, Vector3.new(6, 5, 84), at(0, 21, 0), c.cube)
		Kit.box(scene, Vector3.new(4, 3, 40), at(1.6, 23.6, -18), c.cubeLight)
		Kit.box(scene, Vector3.new(4, 3, 34), at(-1.4, 23.8, 22), c.cubeDark)
	end)

	-- The ranks of cuboids: low by the lane, higher the farther out they stand.
	for i = 1, 170 do
		local side = if i % 2 == 0 then -1 else 1
		local out = pick(38, 186)
		local width = pick(8, 22)
		local height = pick(4, 16 + (out - 38) * 0.55)
		-- Kept off the lane's walls whatever its width.
		out = math.max(out, Kit.EDGE + width / 2 + 1)
		Kit.box(
			scene,
			Vector3.new(width, height, pick(8, 22)),
			at(pick(2, length - 2), 0, side * out),
			Kit.oneOf(scene, shades)
		)
	end

	-- Thin columns among them.
	for i = 1, 26 do
		local side = if i % 2 == 0 then -1 else 1
		local width = pick(5, 8)
		Kit.box(
			scene,
			Vector3.new(width, pick(70, 170), width),
			at(pick(4, length - 4), 0, side * pick(60, 180)),
			Kit.oneOf(scene, shades)
		)
	end

	-- Great blocks at the edge of sight.
	for i = 1, 12 do
		local side = if i % 2 == 0 then -1 else 1
		Kit.box(
			scene,
			Vector3.new(pick(40, 70), pick(100, 220), pick(30, 50)),
			at(10 + (i - 1) * 19, 0, side * pick(160, 186)),
			c.cubeDark
		)
	end

	-- What floats. Over the lane it hangs above the kunai's path; elsewhere at any height.
	local function floating(size: number, low: number)
		local z = pick(-150, 150)
		-- A turned cube reaches about its whole size from its middle.
		local overLane = math.abs(z) < Kit.EDGE + size
		local height = if overLane then pick(Kit.CLEAR + size, 135) else pick(low, 115)
		local where = CFrame.new(at(pick(4, length - 4), height, z))
			* CFrame.Angles(math.rad(pick(-25, 25)), math.rad(pick(0, 90)), math.rad(pick(-25, 25)))
		return Kit.block(
			scene,
			Vector3.new(size, size * pick(0.6, 1.4), size),
			where,
			Kit.oneOf(scene, shades)
		)
	end
	for _ = 1, 50 do
		floating(pick(6, 18), 14)
	end
	for _ = 1, 22 do
		floating(pick(2, 4), 8)
	end

	-- A line of violet light along the top edge of some of the nearer cuboids.
	for i = 1, 14 do
		local side = if i % 2 == 0 then -1 else 1
		local width = pick(10, 18)
		local height = pick(8, 20)
		local base = at(8 + (i - 1) * 16.5, 0, side * pick(46, 70))
		Kit.box(scene, Vector3.new(width, height, width), base, c.cubeLight)
		Kit.box(
			scene,
			Vector3.new(width, 0.3, 0.5),
			base + Vector3.new(0, height, -side * (width / 2 - 0.2)),
			c.edge,
			neon
		)
	end

	-- The zone's sign: a dark slab held in a loose frame of cubes, a line of violet light under
	-- it.
	Kit.signage(scene, function(sign)
		local a, half = sign.along, sign.width / 2
		for i = 0, 6 do
			local size = pick(2.2, 4)
			Kit.box(
				scene,
				Vector3.new(size, size, size),
				at(a + pick(-0.4, 0.4), sign.top - 0.3, -half + i * (sign.width / 6)),
				Kit.oneOf(scene, shades)
			)
		end
		for _, side in { -1, 1 } do
			for i = 0, 2 do
				local size = pick(2.2, 3.4)
				Kit.box(
					scene,
					Vector3.new(size, size, size),
					at(
						a + pick(-0.4, 0.4),
						sign.foot + i * (sign.height - 3) / 2,
						side * (half + size / 2 - 0.2)
					),
					Kit.oneOf(scene, shades)
				)
			end
			Kit.box(scene, Vector3.new(3, 2.6, 3), at(a, sign.foot - 2.8, side * 12), c.cubeDark)
		end
		Kit.box(
			scene,
			Vector3.new(0.5, 0.3, sign.width + 2),
			at(a, sign.foot - 0.4, 0),
			c.edge,
			neon
		)
	end)

	-- And past the great blocks stand greater ones, lost in the gray.
	for i = 1, 10 do
		local side = if i % 2 == 0 then -1 else 1
		Kit.backdrop(
			Kit.box(
				scene,
				Vector3.new(pick(60, 110), pick(220, 420), pick(60, 100)),
				at(12 + (i - 1) * 23, 0, side * pick(270, 470)),
				c.cubeDark
			)
		)
	end

	-- Where the zone begins a wall of great blocks stands across on both sides of the gate,
	-- taller the farther out: the dimension has no way out but the lane.
	for _, side in { -1, 1 } do
		for i = 0, 6 do
			Kit.box(
				scene,
				Vector3.new(pick(26, 40), 80 + i * 22 + pick(-14, 14), pick(35, 42)),
				at(pick(16, 21), 0, side * (62 + i * 33)),
				Kit.oneOf(scene, shades)
			)
		end
	end
end
