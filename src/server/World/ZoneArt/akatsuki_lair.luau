--!strict
-- Akatsuki Lair: a cave under the earth. Rock walls close in on both sides and a vault hangs
-- far overhead with stalactites; bowls of black flame burn along the lane and give the only
-- light, red and dim; black banners hang by the walls, red crystal grows in the cracks, and at
-- the far end two great stone hands rise out of the floor.
--
-- The vault is kept above Kit.CLEAR: a kunai flies high, and the camera with it.

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
		Kit.box(scene, Vector3.new(13, 6, 96), at(0, 21.4, 0), c.rockDark, slate)
		Kit.box(scene, Vector3.new(0.3, 3.4, 2.6), at(-6.7, 19.4, 0), c.bone, cloth)
		Kit.box(scene, Vector3.new(0.35, 1.6, 0.5), at(-6.75, 20.3, 0), c.cloud, cloth)
	end)

	-- The walls: slabs of rock standing shoulder to shoulder, boulders heaped at their feet.
	local slabs = 11
	local span = length / slabs
	for _, side in { -1, 1 } do
		for i = 0, slabs - 1 do
			local x = span / 2 + i * span
			Kit.box(
				scene,
				Vector3.new(span + 3, 98, 26),
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
	-- The vault overhead.
	for i = 0, slabs - 1 do
		Kit.box(
			scene,
			Vector3.new(span + 2, pick(12, 18), 126),
			at(span / 2 + i * span, VAULT, 0),
			if i % 2 == 0 then c.rockDark else c.rock,
			slate
		)
	end

	-- Stalactites. Over the lane they are short and stay above the kunai's path; over the
	-- sides they come down long.
	for i = 1, 36 do
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
	for i = 1, 24 do
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

	-- Bowls of black flame along the lane, five to a side. Each lights a red pool around it.
	for i = 0, 9 do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(18 + i * 21, 0, side * 35)
		Kit.pillar(scene, 4.6, 2.2, base, c.bowl, slate)
		local bowl =
			Kit.pillar(scene, 1, 4.6, base + Vector3.new(0, 4.6, 0), c.bowl, Enum.Material.Metal)
		Kit.emit(bowl, BLACK_FLAME, c.flame)
		Kit.emit(bowl, RED_EDGE, c.ember)
		Kit.light(scene, bowl, c.ember, 26, 1.1)
	end

	-- Black banners by the walls, each with red blots like clouds.
	for i = 0, 9 do
		local side = if i % 2 == 0 then 1 else -1
		local x = 28 + i * 20
		local z = side * 34.6
		Kit.box(scene, Vector3.new(7, 18, 0.4), at(x, 5, z), c.banner, cloth)
		Kit.box(scene, Vector3.new(3.8, 2.6, 0.5), at(x - 0.6, 16, z), c.cloud, cloth)
		Kit.box(scene, Vector3.new(2.8, 2, 0.5), at(x + 1, 10, z), c.cloud, cloth)
	end

	-- Red crystal growing out of the cracks at the foot of the walls.
	for i = 1, 12 do
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

	-- Rubble.
	for i = 1, 20 do
		local side = if i % 2 == 0 then -1 else 1
		Kit.rock(
			scene,
			at(pick(4, length - 4), 0, side * pick(36, 44)),
			Vector3.new(pick(2, 5), pick(1.5, 3.5), pick(2, 5)),
			c.rockDark
		)
	end
end
