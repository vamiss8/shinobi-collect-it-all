--!strict
-- Hidden Rain: the village where it never stops raining. Steel towers stand close on both
-- sides, each with pipes up its corners, lit windows and a spire; pipes run along the lane on
-- trestles, lamps throw a cold light on wet ground and puddles, and at the far end, on the
-- left, rises the tallest tower of them all. Farther off the village goes on as shapes in the
-- rain.
--
-- The towers are painted concrete and plastic, not Metal or DiamondPlate: those show what they
-- reflect, and under a dull sky that was black (see the note in Config/ZoneArt). Only small
-- fittings are metal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require("./Kit")
local Particles = require(ReplicatedStorage.Shared.View.Particles)

-- Steam leaking from a vent.
local STEAM: Particles.Layer = {
	texture = Particles.SMOKE,
	rate = 4,
	life = { 2.5, 4 },
	speed = { 2, 4 },
	spread = 20,
	size = { 2, 8 },
	lift = 1,
	spin = 20,
	glow = 0.1,
	fade = 0.82,
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
	local concrete = Enum.Material.Concrete
	local paint = Enum.Material.SmoothPlastic
	local neon = Enum.Material.Neon

	for _, ground in Kit.ground(scene) do
		ground.Reflectance = 0.08
	end

	-- The gate: a steel gantry over the lane, braced towers either side, pipes along its beam,
	-- a lit plate under it and a lamp on each tower.
	Kit.gateway(scene, function()
		for _, side in { -1, 1 } do
			for _, z in { 35, 41 } do
				Kit.box(scene, Vector3.new(2, 28, 2), at(0, 0, side * z), c.steelDark, concrete)
			end
			for brace = 0, 2 do
				local low, high = 2 + brace * 8, 10 + brace * 8
				local from, to =
					if brace % 2 == 0 then 35 else 41, if brace % 2 == 0 then 41 else 35
				Kit.rod(
					scene,
					at(0, low, side * from),
					at(0, high, side * to),
					0.7,
					c.steel,
					concrete
				)
			end
			local lamp = Kit.ball(scene, 1.6, at(-1.4, 20, side * 34), c.lamp, neon)
			Kit.light(scene, lamp, c.lamp, 22, 1)
		end
		Kit.box(scene, Vector3.new(3, 3, 90), at(0, 22.6, 0), c.steel, paint)
		Kit.rod(scene, at(1.2, 26.2, -44), at(1.2, 26.2, 44), 1.2, c.pipe, concrete, true)
		Kit.rod(scene, at(-1.2, 21.9, -44), at(-1.2, 21.9, 44), 0.8, c.rust, concrete, true)
		Kit.box(scene, Vector3.new(0.3, 2, 14), at(-1.6, 18.6, 0), c.window, neon)
	end)

	-- A tower: a shaft, a narrower block set on top of it, a spire, a dark band round its
	-- middle, a pipe up one corner, and two strips of lit windows on the side facing the lane.
	local function tower(along: number, side: number, out: number): (Vector3, number)
		local width = pick(10, 18)
		local height = pick(60, 150)
		local base = at(along, 0, side * out)
		local face = -side * (width / 2 + 0.2)
		Kit.box(scene, Vector3.new(width, height, width), base, c.steel, concrete)
		local crown = pick(12, 26)
		Kit.box(
			scene,
			Vector3.new(width * 0.68, crown, width * 0.68),
			base + Vector3.new(0, height, 0),
			c.steelDark,
			concrete
		)
		Kit.rod(
			scene,
			base + Vector3.new(0, height + crown, 0),
			base + Vector3.new(0, height + crown + pick(14, 26), 0),
			0.8,
			c.pipe,
			concrete,
			true
		)
		Kit.box(
			scene,
			Vector3.new(width + 1, 3, width + 1),
			base + Vector3.new(0, height * pick(0.4, 0.6), 0),
			c.steelDark,
			paint
		)
		Kit.rod(
			scene,
			base + Vector3.new(width / 2 + 0.6, 0, face),
			base + Vector3.new(width / 2 + 0.6, height * 0.92, face),
			1.5,
			c.pipe,
			concrete,
			true
		)
		for _, dx in { -width * 0.22, width * 0.22 } do
			Kit.box(
				scene,
				Vector3.new(1.6, height * pick(0.3, 0.55), 0.4),
				base + Vector3.new(dx, height * pick(0.12, 0.3), face),
				c.window,
				neon
			)
		end
		return base, height
	end
	for _, side in { -1, 1 } do
		local previous: Vector3? = nil
		local previousHeight = 0
		for i = 0, many(11) do
			local base, height = tower(10 + i * gap(18.5) + gap(pick(-3, 3)), side, pick(48, 150))
			-- Every other pair of neighbors is joined by a pipe high up.
			if previous and i % 2 == 1 then
				local level = math.min(height, previousHeight) * 0.7
				Kit.rod(
					scene,
					previous + Vector3.new(0, level, 0),
					base + Vector3.new(0, level, 0),
					2,
					c.pipe,
					concrete,
					true
				)
			end
			previous, previousHeight = base, height
		end
	end

	-- The great tower at the end of the zone: drums stacked ever narrower, pipes climbing it,
	-- buttresses with slits of light, a ledge thrust out towards the lane.
	local great = Vector3.zero
	group(length, function()
		great = at(length - 26, 0, -90)
	end)
	local level = 0
	for _, drum in { { 40, 48 }, { 60, 36 }, { 60, 25 }, { 40, 15 } } do
		Kit.pillar(
			scene,
			drum[1],
			drum[2],
			great + Vector3.new(0, level, 0),
			if level % 80 == 0 then c.steel else c.steelDark,
			concrete
		)
		level += drum[1]
	end
	Kit.rod(
		scene,
		great + Vector3.new(0, level, 0),
		great + Vector3.new(0, level + 40, 0),
		1.6,
		c.pipe,
		concrete,
		true
	)
	for pipe = 0, 5 do
		local angle = pipe * math.pi / 3
		local foot = great + Vector3.new(math.cos(angle) * 25, 0, math.sin(angle) * 25)
		local head = great + Vector3.new(math.cos(angle) * 12, 150, math.sin(angle) * 12)
		Kit.rod(scene, foot, head, 4, if pipe % 2 == 0 then c.pipe else c.rust, concrete, true)
	end
	for buttress = 0, 3 do
		local angle = math.pi / 4 + buttress * math.pi / 2
		local out = Vector3.new(math.cos(angle) * 26, 0, math.sin(angle) * 26)
		Kit.box(scene, Vector3.new(9, 54, 9), great + out, c.face, concrete, math.deg(-angle))
		Kit.box(
			scene,
			Vector3.new(1.2, 16, 1.2),
			great + out * 1.2 + Vector3.new(0, 26, 0),
			c.window,
			neon
		)
	end
	Kit.box(scene, Vector3.new(10, 3, 20), great + Vector3.new(0, 62, 26), c.steelLight, paint)

	-- Pipes along both sides of the lane, on trestles, with a valve wheel here and there.
	for _, side in { -1, 1 } do
		Kit.rod(
			scene,
			at(4, 4.2, side * 35.4),
			at(length - 4, 4.2, side * 35.4),
			2.4,
			c.pipe,
			concrete,
			true
		)
		Kit.rod(
			scene,
			at(4, 6.6, side * 36),
			at(length - 4, 6.6, side * 36),
			1.3,
			c.rust,
			concrete,
			true
		)
		for i = 0, many(9) do
			Kit.box(
				scene,
				Vector3.new(1, 7.4, 3),
				at(12 + i * gap(21.5), 0, side * 35.8),
				c.steelDark,
				concrete
			)
		end
		for i = 0, many(2) do
			local x = 34 + i * gap(70)
			Kit.rod(
				scene,
				at(x, 5.6, side * 35.4),
				at(x, 8.4, side * 35.4),
				1,
				c.rust,
				concrete,
				true
			)
			Kit.rod(
				scene,
				at(x, 8.4, side * 35.4),
				at(x, 8.8, side * 35.4),
				3,
				c.rust,
				concrete,
				true
			)
		end
	end

	-- Lamps: a pole, an arm and a cold light.
	for i = 0, many(7) do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(22 + i * gap(25), 0, side * 39)
		Kit.pillar(scene, 13, 0.6, base, c.steelDark, concrete)
		Kit.rod(
			scene,
			base + Vector3.new(0, 12.6, 0),
			base + Vector3.new(0, 13.4, -side * 3),
			0.4,
			c.steelDark,
			concrete
		)
		local lamp = Kit.ball(scene, 1.4, base + Vector3.new(0, 13, -side * 3.2), c.lamp, neon)
		Kit.light(scene, lamp, c.lamp, 24, 1.1)
	end

	-- Sheds and machines between the towers; some leak steam.
	for i = 0, many(9) do
		local side = if i % 2 == 0 then 1 else -1
		local base = at(14 + i * gap(21), 0, side * pick(40, 46))
		local width = pick(6, 10)
		Kit.box(scene, Vector3.new(width, pick(5, 9), 6), base, c.steelLight, paint)
		Kit.rod(
			scene,
			base + Vector3.new(width / 2, 3, 0),
			base + Vector3.new(width / 2 + 4, 8, side * 3),
			1.2,
			c.pipe,
			concrete,
			true
		)
		local vent =
			Kit.pillar(scene, 2.4, 1.6, base + Vector3.new(-width / 4, 6, 0), c.rust, concrete)
		if i % 3 == 0 then
			Kit.emit(vent, STEAM, c.lamp)
		end
	end

	-- Gratings beside the lane, and puddles: on the ground, and a few thin ones on the lane.
	for i = 0, many(7) do
		local side = if i % 2 == 0 then -1 else 1
		Kit.box(
			scene,
			Vector3.new(8, 0.2, 4),
			at(18 + i * gap(26), 0, side * 38),
			c.grate,
			Enum.Material.DiamondPlate
		)
	end
	for i = 1, many(18) do
		local side = if i % 2 == 0 then -1 else 1
		local puddle = Kit.pillar(
			scene,
			0.06,
			pick(6, 14),
			at(pick(6, length - 6), 0, side * pick(40, 110)),
			c.puddle
		)
		puddle.Reflectance = 0.4
	end
	for i = 0, many(5) do
		local puddle =
			Kit.pillar(scene, 0.06, pick(5, 9), at(20 + i * gap(36), 0.02, pick(-22, 22)), c.puddle)
		puddle.Reflectance = 0.4
	end

	-- The zone's sign: a dark plate bolted into a steel frame on the gantry, a pipe run over its
	-- top and a strip of cold light down each side.
	Kit.signage(scene, function(sign)
		local a, half = sign.along, sign.width / 2
		Kit.border(scene, sign, 0.8, c.steelDark, paint)
		for _, side in { -1, 1 } do
			for _, y in { sign.foot - 0.4, sign.top + 0.4 } do
				Kit.rod(
					scene,
					at(a - 0.8, y, side * (half + 0.4)),
					at(a + 0.8, y, side * (half + 0.4)),
					0.9,
					c.steelLight,
					Enum.Material.Metal,
					true
				)
			end
			Kit.box(
				scene,
				Vector3.new(0.5, sign.height - 1.6, 0.4),
				at(a, sign.foot + 0.8, side * (half + 1.3)),
				c.lamp,
				neon
			)
			Kit.box(
				scene,
				Vector3.new(1.4, 1.2, 1.4),
				at(a, sign.foot - 2, side * 13),
				c.steelDark,
				paint
			)
		end
		Kit.rod(
			scene,
			at(a, sign.top + 1.5, -half - 2.4),
			at(a, sign.top + 1.5, half + 2.4),
			1.2,
			c.pipe,
			paint,
			true
		)
		Kit.rod(scene, at(a, sign.top + 2, 9), at(a, sign.top + 3.4, 9), 0.6, c.rust, paint, true)
		Kit.rod(scene, at(a, sign.top + 3.4, 9), at(a, sign.top + 3.7, 9), 2.2, c.rust, paint, true)
	end)

	-- Farther off the village goes on: towers too far away to be anything but their shapes.
	for _, side in { -1, 1 } do
		for i = 0, many(7) do
			local width = pick(26, 44)
			local height = pick(200, 380)
			local base = at(6 + i * gap(30) + gap(pick(-8, 8)), 0, side * pick(215, 420))
			Kit.backdrop(Kit.box(scene, Vector3.new(width, height, width), base, c.far, concrete))
			Kit.backdrop(
				Kit.box(
					scene,
					Vector3.new(width * 0.6, pick(30, 70), width * 0.6),
					base + Vector3.new(0, height, 0),
					c.farDark,
					concrete
				)
			)
		end
	end

	-- The village's wall. Where the zone begins it runs out to both sides of the gantry, steel
	-- as tall as a house with towers standing along it, a strip of lit windows on each: the
	-- mountain behind is only seen over it.
	group(0, function()
		for _, side in { -1, 1 } do
			Kit.box(scene, Vector3.new(6, 44, 226), at(5, 0, side * 157), c.steelDark, concrete)
			Kit.box(scene, Vector3.new(7, 2, 226), at(5, 44, side * 157), c.pipe, paint)
			for i = 0, 4 do
				local width = pick(20, 28)
				local height = pick(80, 160)
				local base = at(pick(12, 17), 0, side * (68 + i * 46 + pick(-6, 6)))
				Kit.box(scene, Vector3.new(width, height, width), base, c.steel, concrete)
				Kit.box(
					scene,
					Vector3.new(width * 0.68, pick(12, 24), width * 0.68),
					base + Vector3.new(0, height, 0),
					c.steelDark,
					concrete
				)
				Kit.box(
					scene,
					Vector3.new(0.4, height * pick(0.3, 0.5), 1.6),
					base + Vector3.new(width / 2 + 0.2, height * pick(0.15, 0.3), 0),
					c.window,
					neon
				)
			end
		end
	end)
end
