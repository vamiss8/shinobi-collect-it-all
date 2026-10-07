--!strict
-- Akatsuki Lair: a cave under the earth. Rock walls close in on both sides and a vault hangs
-- far overhead with stalactites; bowls of black flame burn along the lane and throw a warm
-- light right across it; black banners hang by the walls, red crystal grows in the cracks, and
-- at the far end two great stone hands rise out of the floor.
--
-- The vault is kept above Kit.CLEAR: a kunai flies high, and the camera with it.
--
-- From outside the cave is a mountain: crags stand across its mouth and its far end, peaks
-- rise behind them and rock is piled over its roof, so that neither neighbor sees a box
-- standing on the plain. The crags are blocks and keep to the zone's own ground. (They were
-- half-buried balls at first, and those bulged out into the desert village as great dark
-- domes.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require("./Kit")
local Particles = require(ReplicatedStorage.Shared.View.Particles)

local VAULT = 92 -- the underside of the cave's roof, studs above the lane

-- Black fire with a red edge.
local BLACK_FLAME: Particles.Layer = {
	texture = Particles.FIRE,
	rate = 14,
	life = { 0.8, 1.3 },
	speed = { 3, 5 },
	spread = 15,
	size = { 3.2, 0.6 },
	lift = 2,
	spin = 30,
	glow = 0,
	fade = 0.1,
}
local RED_EDGE: Particles.Layer = {
	texture = Particles.FIRE,
	rate = 8,
	life = { 0.6, 1 },
	speed = { 2.5, 4 },
	spread = 22,
	size = { 2.2, 0.4 },
	lift = 2,
	spin = 30,
	glow = 1,
	fade = 0.25,
}

return function(scene: Kit.Scene)
	local c = scene.colors
	local length = scene.length
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
	local slate = Enum.Material.Slate
	local cloth = Enum.Material.Fabric

	Kit.ground(scene)

	-- The mouth of the cave: boulders either side, a slab of rock across them, and a paper
	-- seal stuck to the slab.
	Kit.gateway(scene, function()
		for _, side in { -1, 1 } do
			Kit.box(scene, Vector3.new(16, 24, 14), at(0, -1, side * 41), c.rock, slate, side * 8)
			Kit.box(
				scene,
				Vector3.new(11, 12, 10),
				at(3, -1, side * 51),
				c.rockDark,
				slate,
				side * -14
			)
		end
		Kit.box(scene, Vector3.new(13, 6, 96), at(0, 20.6, 0), c.rockDark, slate)
		Kit.box(scene, Vector3.new(0.3, 3.4, 2.6), at(-6.7, 18.6, 0), c.bone, cloth)
		Kit.box(scene, Vector3.new(0.35, 1.6, 0.5), at(-6.75, 19.5, 0), c.cloud, cloth)
	end)

	-- The walls: slabs of rock standing shoulder to shoulder, boulders heaped at their feet.
	-- A slab laps over the next, and the two are of different rock, so every other one stands
	-- a little taller: two sides of unlike rock in one plane would flicker.
	local slabs = many(11)
	local span = length / slabs
	for _, side in { -1, 1 } do
		for i = 0, slabs - 1 do
			local x = span / 2 + i * span
			Kit.box(
				scene,
				Vector3.new(far(span) + 3, 98 + i % 2, 26),
				at(x, -2, side * pick(50, 55)),
				if i % 2 == 0 then c.rock else c.rockRed,
				slate,
				pick(-5, 5)
			)
			Kit.rock(
				scene,
				at(x + pick(-5, 5), 0, side * pick(41, 45)),
				Vector3.new(pick(8, 14), pick(5, 11), pick(6, 9)),
				c.rockDark
			)
		end
	end
	-- The vault overhead, every other slab of it hung half a stud higher and cut a stud wider
	-- for the same reason.
	for i = 0, slabs - 1 do
		Kit.box(
			scene,
			Vector3.new(far(span) + 2, pick(12, 18), 126 + i % 2),
			at(span / 2 + i * span, VAULT + (i % 2) * 0.5, 0),
			if i % 2 == 0 then c.rockDark else c.rock,
			slate
		)
	end

	-- Stalactites. Over the lane they are short and stay above the kunai's path; over the
	-- sides they come down long.
	for i = 1, many(36) do
		local z = pick(-46, 46)
		local reach = if math.abs(z) < Kit.EDGE + 3
			then pick(4, VAULT - Kit.CLEAR - 2)
			else pick(14, 36)
		local x = pick(4, length - 4)
		local thick = pick(2.6, 4.2)
		local top = at(x, VAULT + 1, z)
		local waist = at(x, VAULT - reach * 0.6, z)
		Kit.rod(scene, top, waist, thick, if i % 2 == 0 then c.rock else c.rockDark, slate, true)
		Kit.rod(scene, waist, at(x, VAULT - reach, z), thick * 0.45, c.rockDark, slate, true)
	end
	-- Stalagmites by the walls.
	for i = 1, many(24) do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(pick(6, length - 6), -1, side * pick(36.5, 46))
		local height = pick(6, 18)
		local thick = pick(2.4, 4)
		Kit.rod(scene, base, base + Vector3.new(0, height * 0.6, 0), thick, c.rock, slate, true)
		Kit.rod(
			scene,
			base + Vector3.new(0, height * 0.6, 0),
			base + Vector3.new(0, height, 0),
			thick * 0.45,
			c.rockDark,
			slate,
			true
		)
	end

	-- Bowls of black flame along the lane, one every 42 studs on each side. Each lights the lane from its own
	-- wall to past the middle: they stand 35 studs out, and with a reach of 26 they lit a
	-- red pool at the foot of each wall and left the lane itself in the dark.
	for i = 0, many(9) do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(18 + i * gap(21), 0, side * 35)
		Kit.pillar(scene, 4.6, 2.2, base, c.bowl, slate)
		local bowl =
			Kit.pillar(scene, 1, 4.6, base + Vector3.new(0, 4.6, 0), c.bowl, Enum.Material.Metal)
		Kit.emit(bowl, BLACK_FLAME, c.flame)
		Kit.emit(bowl, RED_EDGE, c.ember)
		Kit.light(scene, bowl, c.firelight, 48, 2.2)
	end

	-- Black banners by the walls, each with red blots like clouds.
	for i = 0, many(9) do
		local side = if i % 2 == 0 then 1 else -1
		local x = 28 + i * gap(20)
		local z = side * 34.6
		Kit.group(scene, x, function()
			Kit.box(scene, Vector3.new(7, 18, 0.4), at(x, 5, z), c.banner, cloth)
			Kit.box(scene, Vector3.new(3.8, 2.6, 0.5), at(x - 0.6, 16, z), c.cloud, cloth)
			Kit.box(scene, Vector3.new(2.8, 2, 0.5), at(x + 1, 10, z), c.cloud, cloth)
		end)
	end

	-- Red crystal growing out of the cracks at the foot of the walls.
	for i = 1, many(12) do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(pick(8, length - 8), 0, side * pick(36, 42))
		Kit.rod(
			scene,
			base,
			base + Vector3.new(pick(-1.5, 1.5), pick(3, 6), pick(-1, 1)),
			1,
			c.crystal,
			Enum.Material.Neon
		)
		Kit.rod(
			scene,
			base,
			base + Vector3.new(pick(-2, 2), pick(1.6, 3), pick(-1.5, 1.5)),
			0.7,
			c.crystal,
			Enum.Material.Neon
		)
	end

	-- The statue's hands at the far end: a wrist and palm of stone, and five fingers that
	-- stand up and curl towards the lane.
	group(length, function()
		for _, side in { -1, 1 } do
			local x = length - 26
			local z = side * 62
			local face = -side
			Kit.box(scene, Vector3.new(24, 28, 22), at(x, -2, z), c.boneDark, slate)
			Kit.box(scene, Vector3.new(30, 8, 26), at(x, 26, z), c.bone, slate)
			for finger = -2, 2 do
				local foot = at(x + finger * 6.4, 33, z + face * 4)
				local knuckle = foot + Vector3.new(0, 20 - math.abs(finger) * 3, face * 3)
				local tip = knuckle + Vector3.new(0, 10, face * 9)
				Kit.rod(scene, foot, knuckle, 5, c.bone, slate, true)
				Kit.rod(scene, knuckle, tip, 4, c.boneDark, slate, true)
			end
		end
	end)

	-- Rubble.
	for i = 1, many(20) do
		local side = if i % 2 == 0 then -1 else 1
		Kit.rock(
			scene,
			at(pick(4, length - 4), 0, side * pick(36, 44)),
			Vector3.new(pick(2, 5), pick(1.5, 3.5), pick(2, 5)),
			c.rockDark
		)
	end

	-- The zone's sign: a black banner edged in red on the slab over the cave's mouth, red
	-- clouds at its ends and crystal growing from its top.
	Kit.signage(scene, function(sign)
		local a, half = sign.along, sign.width / 2
		Kit.border(scene, sign, 0.9, c.cloud, cloth)
		for _, side in { -1, 1 } do
			local middle = (sign.foot + sign.top) / 2
			Kit.ball(scene, 3.4, at(a, middle, side * (half + 2.2)), c.cloud)
			Kit.ball(scene, 2.6, at(a, middle + 1.6, side * (half + 3.6)), c.cloud)
			Kit.ball(scene, 2.4, at(a, middle - 1.2, side * (half + 4)), c.cloud)
			Kit.box(
				scene,
				Vector3.new(2.4, 1.2, 3),
				at(a, sign.foot - 1.8, side * 13),
				c.rockDark,
				slate
			)
		end
		for i = -1, 1 do
			local base = at(a, sign.top + 0.6, i * 12 + pick(-2, 2))
			Kit.rod(
				scene,
				base,
				base + Vector3.new(0, pick(2.4, 4.2), pick(-1.2, 1.2)),
				0.9,
				c.crystal,
				Enum.Material.Neon
			)
		end
	end)

	-- From outside the cave is a mountain. A row of crags stands across at its mouth and
	-- another at its far end, stepping down away from the lane, boulders heaped at their feet;
	-- peaks rise behind them, a brow of rock hangs over the mouth and rock is piled on the roof.
	for _, along in { 24, length - 24 } do
		-- Each row belongs to its end of the cave.
		Kit.group(scene, if along < 100 then 0 else length, function()
			for _, side in { -1, 1 } do
				for i = 0, 3 do
					local z = side * (90 + i * 50)
					Kit.backdrop(
						Kit.box(
							scene,
							Vector3.new(pick(40, 52), 150 - i * 26 + pick(-12, 12), 58),
							at(along + pick(-4, 4), -2, z),
							if i % 2 == 0 then c.crag else c.cragDark,
							slate,
							pick(-7, 7)
						)
					)
					if i < 3 then
						local out = if along < 100 then -pick(22, 30) else pick(22, 30)
						Kit.rock(
							scene,
							at(along + out, 0, z + side * pick(-14, 14)),
							Vector3.new(pick(10, 18), pick(8, 14), pick(10, 18)),
							c.cragDark
						)
					end
				end
			end
		end)
	end
	for _, side in { -1, 1 } do
		for i = 0, many(2) do
			Kit.backdrop(
				Kit.box(
					scene,
					Vector3.new(pick(70, 96), pick(190, 250), pick(80, 110)),
					at(44 + i * gap(66) + gap(pick(-6, 6)), -2, side * pick(320, 390)),
					c.cragDark,
					slate,
					pick(-10, 10)
				)
			)
		end
	end
	group(0, function()
		for _, z in { -30, 0, 30 } do
			Kit.backdrop(
				Kit.box(
					scene,
					Vector3.new(pick(18, 26), pick(30, 46), pick(28, 36)),
					at(pick(3, 8), 84 + pick(0, 6), z + pick(-4, 4)),
					if z == 0 then c.cragDark else c.crag,
					slate,
					pick(-10, 10)
				)
			)
		end
	end)
	for i = 0, many(5) do
		Kit.backdrop(
			Kit.box(
				scene,
				Vector3.new(pick(48, 66), pick(26, 58), pick(96, 132)),
				at(20 + i * gap(36) + gap(pick(-5, 5)), VAULT + 12, pick(-12, 12)),
				if i % 2 == 0 then c.rock else c.rockDark,
				slate,
				pick(-12, 12)
			)
		)
	end
end
