--!strict
-- Great Ninja War: the last battlefield, at night under the moon. Past the end of the lane
-- stands what it all leads to, the God Tree, its bud half open over a trunk as thick as a
-- village, and its roots have come up all over the field. Around the lane: sheaves of wooden
-- stakes standing where they struck, craters, two rocks pulled out of the sky, walls of earth
-- raised to hold the beast back, what is left of the allied camp, and fires burning down. A
-- red gate still stands where the zone begins. Broken heights ring the field and close the
-- view behind the tree.
--
-- The zone's light and the moon are not this module's and are not to change (Config/ZoneArt).
-- The scenery was rebuilt on 2026-10-06: it had been forty-odd spikes and boulders, and the
-- owner found it too plain beside the other nine zones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require("./Kit")
local Particles = require(ReplicatedStorage.Shared.View.Particles)

-- How far past the end of the lane the tree stands, studs.
local TREE_PAST = 170

-- Smoke off a fire that is burning down, and the sparks in it.
local SMOKE: Particles.Layer = {
	texture = Particles.SMOKE,
	rate = 3,
	life = { 4, 6 },
	speed = { 2, 4 },
	spread = 14,
	size = { 3, 10 },
	lift = 0.6,
	spin = 15,
	glow = 0,
	fade = 0.8,
}
local SPARKS: Particles.Layer = {
	texture = Particles.SPARKLE,
	rate = 4,
	life = { 1.5, 2.5 },
	speed = { 3, 6 },
	spread = 25,
	size = { 0.4, 0.1 },
	lift = 1.5,
	spin = 60,
	glow = 1,
	fade = 0.1,
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
	local slate = Enum.Material.Slate
	local wood = Enum.Material.Wood
	local cloth = Enum.Material.Fabric
	local neon = Enum.Material.Neon

	Kit.ground(scene)
	Kit.beyond(scene)

	-- The gate: a red torii the war has left standing, a rope of paper tags under its beams
	-- and the allied banner hung from each post.
	Kit.gateway(scene, function()
		for _, side in { -1, 1 } do
			Kit.pillar(scene, 26.2, 3.2, at(0, 0, side * 36), c.gate, wood)
			Kit.box(scene, Vector3.new(5.4, 2, 5.4), at(0, 0, side * 36), c.boulder, slate)
			Kit.rod(scene, at(0, 15, side * 37.4), at(0, 15, side * 42), 0.4, c.pole, wood)
			Kit.box(scene, Vector3.new(0.2, 8, 3), at(0, 7, side * 40.4), c.banner, cloth)
			Kit.box(scene, Vector3.new(0.25, 1.6, 2), at(0, 11.6, side * 40.4), c.tag, cloth)
		end
		Kit.box(scene, Vector3.new(3.4, 2.4, 92), at(0, 24, 0), c.gate, wood)
		Kit.box(scene, Vector3.new(4.4, 0.6, 96), at(0, 26.3, 0), c.gateDark, wood)
		Kit.box(scene, Vector3.new(2.2, 1.8, 80), at(0, 21.2, 0), c.gate, wood)
		Kit.rod(scene, at(-1.5, 20.6, -34), at(-1.5, 20.6, 34), 0.6, c.rope, cloth, true)
		for i = -3, 3 do
			Kit.box(scene, Vector3.new(0.15, 1.6, 1.1), at(-1.5, 18.7, i * 9), c.tag, cloth)
		end
	end)

	-- The zone's sign: a scorched board in a frame of the beast's own wood, splinters standing
	-- up from its top and torn banners hanging at its ends.
	Kit.signage(scene, function(sign)
		local a, half = sign.along, sign.width / 2
		Kit.border(scene, sign, 1, c.spike, wood)
		for i = 0, 5 do
			local base = at(a, sign.top + 0.8, -half + 3 + i * (sign.width - 6) / 5)
			Kit.rod(
				scene,
				base,
				base + Vector3.new(0, pick(2.4, 5), pick(-1.6, 1.6)),
				pick(0.6, 1),
				c.spike,
				wood
			)
		end
		for _, side in { -1, 1 } do
			Kit.box(
				scene,
				Vector3.new(0.15, pick(3.5, 5), 2.6),
				at(a - 2.8, sign.foot - 5.4, side * (half - 2)),
				c.banner,
				cloth
			)
			Kit.box(
				scene,
				Vector3.new(1.8, 1.2, 2.4),
				at(a, sign.foot - 2.2, side * 13),
				c.gateDark,
				wood
			)
		end
	end)

	-- What the lane leads to: the God Tree, past its far end. A trunk of four drums, roots
	-- thrown out over the ground, boughs spread under a bud that has begun to open, and in the
	-- bud, on the side that looks down the lane, a pale light.
	local tree = Vector3.zero
	group(length, function()
		tree = at(length + TREE_PAST, 0, 0)
	end)
	local crown = 0
	for index, drum in { { 90, 76 }, { 90, 62 }, { 80, 50 }, { 70, 38 } } do
		Kit.backdrop(
			Kit.pillar(
				scene,
				drum[1],
				drum[2],
				tree + Vector3.new(0, crown, 0),
				if index % 2 == 1 then c.trunk else c.trunkDark,
				wood
			)
		)
		crown += drum[1]
	end
	for root = 0, 8 do
		local angle = root * (2 * math.pi / 9) + 0.35
		local way = Vector3.new(math.cos(angle), 0, math.sin(angle))
		-- A root thrown back towards the lane stops short of it.
		local reach = if way.X < -0.4 then pick(96, 118) else pick(120, 160)
		local knee = tree + way * reach * 0.48 + Vector3.new(0, pick(24, 40), 0)
		Kit.backdrop(
			Kit.rod(
				scene,
				tree + way * 22 + Vector3.new(0, pick(50, 72), 0),
				knee,
				pick(16, 22),
				c.root,
				wood,
				true
			)
		)
		Kit.backdrop(
			Kit.rod(
				scene,
				knee,
				tree + way * reach + Vector3.new(0, -4, 0),
				pick(11, 15),
				c.root,
				wood,
				true
			)
		)
	end
	local top = tree + Vector3.new(0, crown, 0)
	local bud = top + Vector3.new(0, 76, 0)
	for bough = 0, 5 do
		local angle = bough * math.pi / 3 + 0.5
		local way = Vector3.new(math.cos(angle), 0, math.sin(angle))
		Kit.backdrop(
			Kit.rod(
				scene,
				top - Vector3.new(0, 34, 0),
				top + way * 118 + Vector3.new(0, pick(8, 36), 0),
				14,
				c.trunkDark,
				wood,
				true
			)
		)
	end
	Kit.backdrop(Kit.ball(scene, 150, bud, c.crown, Enum.Material.Grass))
	-- The petals that have come away from the bud, leaning out all round it.
	for petal = 0, 7 do
		local turned = CFrame.new(bud)
			* CFrame.Angles(0, petal * math.pi / 4, 0)
			* CFrame.new(0, -34, 92)
			* CFrame.Angles(math.rad(-38), 0, 0)
		Kit.backdrop(Kit.block(scene, Vector3.new(62, 7, 84), turned, c.petal, Enum.Material.Grass))
	end
	Kit.backdrop(Kit.ball(scene, 16, bud + Vector3.new(-72, -8, 0), c.tag))
	Kit.backdrop(Kit.ball(scene, 9, bud + Vector3.new(-77, -8, 0), c.glow, neon))

	-- Its roots have come up all over the field: each heaves out of the ground, arches and
	-- plunges back in.
	for i = 0, many(7) do
		local side = if i % 2 == 0 then -1 else 1
		local x = 16 + i * gap(26) + gap(pick(-5, 5))
		local out = pick(52, 124)
		local span = pick(26, 44)
		local rise = pick(16, 38)
		local thick = pick(5, 9)
		Kit.group(scene, x, function()
			local first = at(x + span * 0.3, rise, side * (out + pick(-8, 8)))
			local second = at(x + span * 0.7, rise * pick(0.8, 1.1), side * (out + pick(-8, 8)))
			Kit.rod(scene, at(x, -2, side * out), first, thick, c.root, wood, true)
			Kit.rod(scene, first, second, thick * 0.9, c.root, wood, true)
			Kit.rod(
				scene,
				second,
				at(x + span, -2, side * (out + pick(0, 12))),
				thick * 0.8,
				c.root,
				wood,
				true
			)
			Kit.ball(scene, thick * 1.05, first, c.root, wood)
			Kit.ball(scene, thick * 0.95, second, c.root, wood)
		end)
	end

	-- Stakes of the beast's wood, thrown like spears and standing where they struck, in sheaves.
	-- They lean every way but towards the lane.
	for i = 1, many(14) do
		local side = if i % 2 == 0 then -1 else 1
		local middle = at(pick(6, length - 6), 0, side * pick(42, 152))
		for _ = 1, 4 do
			local lean = Vector3.new(pick(-0.5, 0.5), 1, side * pick(-0.12, 0.5)).Unit
			local foot = middle + Vector3.new(pick(-3, 3), -1.5, pick(-3, 3))
			Kit.rod(scene, foot, foot + lean * pick(12, 28), pick(1.4, 2.6), c.spike, wood)
		end
	end

	-- Craters: a scorched floor ringed by slabs the blast stood on end.
	for i = 0, many(5) do
		local side = if i % 2 == 0 then 1 else -1
		local middle = at(24 + i * gap(37) + gap(pick(-6, 6)), 0, side * pick(64, 130))
		local radius = pick(12, 20)
		Kit.backdrop(Kit.pillar(scene, 0.3, radius * 2, middle, c.scorch, slate))
		for slab = 0, 6 do
			local angle = slab * (2 * math.pi / 7) + pick(-0.2, 0.2)
			local way = Vector3.new(math.cos(angle), 0, math.sin(angle))
			-- A slab lies along the line from the crater's rim up and outward.
			local tilted = CFrame.lookAt(
				middle + way * radius + Vector3.new(0, 2, 0),
				middle + way * (radius + 10) + Vector3.new(0, pick(8, 14), 0)
			)
			Kit.block(
				scene,
				Vector3.new(pick(5, 9), pick(1.6, 3), pick(7, 12)),
				tilted,
				if slab % 2 == 0 then c.boulder else c.rockWarm,
				slate
			)
		end
	end
	-- And the marks of smaller blasts, flat on the lane.
	for i = 0, many(5) do
		Kit.pillar(
			scene,
			0.06,
			pick(8, 16),
			at(18 + i * gap(38) + gap(pick(-5, 5)), 0.02, pick(-22, 22)),
			c.scorch,
			slate
		)
	end

	-- Two rocks that were pulled out of the sky lie half buried on the right, the ground thrown
	-- up round them.
	for _, meteor in { { 72, 152, 100 }, { 170, 122, 76 } } do
		local x, out, size = meteor[1], meteor[2], meteor[3]
		local middle = at(x, 0, out)
		Kit.ball(scene, size, middle + Vector3.new(0, size * 0.18, 0), c.meteor, slate)
		for slab = 0, 7 do
			local angle = slab * math.pi / 4 + pick(-0.2, 0.2)
			local way = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local tilted = CFrame.lookAt(
				middle + way * size * 0.5 + Vector3.new(0, 3, 0),
				middle + way * (size * 0.5 + 10) + Vector3.new(0, pick(12, 20), 0)
			)
			Kit.block(
				scene,
				Vector3.new(pick(10, 16), pick(3, 5), pick(14, 22)),
				tilted,
				if slab % 2 == 0 then c.rockWarm else c.boulder,
				slate
			)
		end
	end

	-- Walls of earth raised to hold the beast back, leaning now: a long line on the left, a
	-- shorter and lower one on the right.
	for i = 0, many(9) do
		local tall = pick(28, 44)
		Kit.block(
			scene,
			Vector3.new(16, tall, 6),
			CFrame.new(at(14 + i * gap(22) + gap(pick(-3, 3)), tall / 2 - 2, -pick(86, 98)))
				* CFrame.Angles(0, math.rad(pick(-8, 8)), 0)
				* CFrame.Angles(math.rad(pick(6, 14)), 0, 0),
			if i % 2 == 0 then c.rockWarm else c.boulder,
			slate
		)
	end
	for i = 0, many(7) do
		local tall = pick(16, 26)
		Kit.block(
			scene,
			Vector3.new(14, tall, 5),
			CFrame.new(at(20 + i * gap(26) + gap(pick(-4, 4)), tall / 2 - 2, pick(54, 62)))
				* CFrame.Angles(0, math.rad(pick(-8, 8)), 0)
				* CFrame.Angles(math.rad(-pick(6, 14)), 0, 0),
			if i % 2 == 0 then c.boulder else c.rockWarm,
			slate
		)
	end

	-- What is left of the allied camp, on the left by the gate: tents, a weapon rack by each.
	for i = 0, many(4) do
		local x, z = 22 + i * gap(14) + gap(pick(-2, 2)), -pick(46, 74)
		-- Every other tent stands across the lane; the door flap is in the gable end either way.
		local across = i % 2 == 0
		Kit.group(scene, x, function()
			Kit.roof(scene, at(x, 5.6, z), 10, 5, 48, c.tent, cloth, across)
			if across then
				Kit.box(scene, Vector3.new(2.2, 3.4, 0.3), at(x, 0, z + 5.05), c.flap, cloth)
			else
				Kit.box(scene, Vector3.new(0.3, 3.4, 2.2), at(x + 5.05, 0, z), c.flap, cloth)
			end
			if i % 2 == 0 then
				local rack = at(x + 2, 0, z + 9)
				for _, dx in { -2.4, 2.4 } do
					Kit.box(
						scene,
						Vector3.new(0.4, 4.4, 0.4),
						rack + Vector3.new(dx, 0, 0),
						c.pole,
						wood
					)
				end
				Kit.box(
					scene,
					Vector3.new(5.6, 0.3, 0.5),
					rack + Vector3.new(0, 4, 0),
					c.pole,
					wood
				)
				for spear = -1, 1 do
					Kit.rod(
						scene,
						rack + Vector3.new(spear * 1.6, 0, 1.6),
						rack + Vector3.new(spear * 1.6, 7.4, -0.3),
						0.25,
						c.steel
					)
				end
			end
		end)
	end
	-- Banners on poles along both sides of the lane, some of them torn short.
	for i = 0, many(7) do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(22 + i * gap(27), 0, side * pick(36.5, 39))
		local drop = pick(3.5, 7)
		Kit.pillar(scene, 15, 0.5, base, c.pole, wood)
		Kit.box(
			scene,
			Vector3.new(0.2, drop, 2.8),
			base + Vector3.new(0, 14.4 - drop, side * 1.8),
			c.banner,
			cloth
		)
		Kit.box(
			scene,
			Vector3.new(0.25, 1.4, 1.8),
			base + Vector3.new(0, 12.4, side * 1.8),
			c.tag,
			cloth
		)
	end
	-- Great four-bladed shuriken left standing in the ground.
	for i = 0, many(3) do
		local side = if i % 2 == 0 then 1 else -1
		local stuck = CFrame.new(at(40 + i * gap(48) + gap(pick(-8, 8)), 2.4, side * pick(42, 70)))
			* CFrame.Angles(math.rad(pick(-20, 20)), math.rad(pick(0, 180)), math.rad(pick(20, 50)))
		Kit.block(scene, Vector3.new(9, 1.5, 0.3), stuck, c.steel)
		Kit.block(scene, Vector3.new(1.5, 9, 0.3), stuck, c.steel)
		Kit.block(scene, Vector3.new(2.6, 2.6, 0.5), stuck, c.char)
	end

	-- Fires burning down: two charred logs and what still glows between them.
	for i = 0, many(5) do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(30 + i * gap(34), 0, side * pick(38, 46))
		Kit.rod(
			scene,
			base + Vector3.new(-2, 0.4, -0.6),
			base + Vector3.new(2, 0.9, 0.6),
			0.9,
			c.char,
			wood,
			true
		)
		Kit.rod(
			scene,
			base + Vector3.new(-0.8, 0.4, 1.8),
			base + Vector3.new(0.8, 1.1, -1.8),
			0.8,
			c.char,
			wood,
			true
		)
		local ember = Kit.ball(scene, 1.3, base + Vector3.new(0, 0.7, 0), c.ember, neon)
		Kit.emit(ember, SMOKE, c.smoke)
		Kit.emit(ember, SPARKS, c.ember)
		if i % 2 == 0 then
			Kit.light(scene, ember, c.ember, 20, 0.9)
		end
	end

	-- Boulders all over the field, and a few at the foot of the tree.
	for i = 1, many(36) do
		local side = if i % 2 == 0 then -1 else 1
		local width = pick(4, 13)
		Kit.rock(
			scene,
			at(pick(4, length - 4), 0, side * pick(38 + width * 0.8, 175)),
			Vector3.new(width, width * pick(0.6, 0.9), width * pick(0.8, 1.2)),
			if i % 3 == 0 then c.rockWarm else c.boulder
		)
	end
	group(length, function()
		for i = 1, 6 do
			local side = if i % 2 == 0 then -1 else 1
			local width = pick(12, 24)
			Kit.rock(
				scene,
				at(length + pick(20, 120), 0, side * pick(50, 160)),
				Vector3.new(width, width * pick(0.6, 0.9), width),
				c.boulder
			)
		end
	end)

	-- Trees burnt down to their trunks.
	for i = 1, many(10) do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(pick(6, length - 6), 0, side * pick(48, 165))
		local crest = base + Vector3.new(pick(-2, 2), pick(14, 24), pick(-2, 2))
		Kit.rod(scene, base, crest, pick(1.6, 2.6), c.char, wood, true)
		for _ = 1, 2 do
			local from = base + (crest - base) * pick(0.5, 0.85)
			Kit.rod(
				scene,
				from,
				from + Vector3.new(pick(-5, 5), pick(3, 7), pick(-5, 5)),
				0.7,
				c.char,
				wood,
				true
			)
		end
	end

	-- The field lies in a ring of broken heights: slabs of the earth stood on end near at hand
	-- and bare hills behind, on both sides and round behind the tree.
	for _, side in { -1, 1 } do
		for i = 0, many(5) do
			local tall = pick(120, 190)
			Kit.backdrop(
				Kit.block(
					scene,
					Vector3.new(pick(40, 60), tall, pick(40, 60)),
					CFrame.new(
						at(12 + i * gap(42) + gap(pick(-8, 8)), tall / 2 - 6, side * pick(205, 270))
					)
						* CFrame.Angles(
							math.rad(pick(-8, 8)),
							math.rad(pick(0, 90)),
							math.rad(pick(-8, 8))
						),
					if i % 2 == 0 then c.ridge else c.boulder,
					slate
				)
			)
		end
		for i = 0, many(2) do
			Kit.mound(
				scene,
				at(30 + i * gap(85) + gap(pick(-10, 10)), 0, side * pick(470, 540)),
				pick(200, 230),
				pick(150, 210),
				c.ridge,
				slate
			)
		end
		group(length, function()
			Kit.mound(scene, at(length + 270, 0, side * 400), 210, pick(150, 200), c.ridge, slate)
		end)
	end
	group(length, function()
		for i = -3, 3 do
			Kit.mound(
				scene,
				at(length + pick(480, 560), 0, i * 170 + pick(-30, 30)),
				pick(180, 230),
				pick(140, 220),
				c.ridge,
				slate
			)
		end
	end)

	-- Where the zone begins the earth itself was stood on end across the field, to both sides
	-- of the gate: great slabs, leaning now, the last of what held the beast in.
	group(0, function()
		for _, side in { -1, 1 } do
			for i = 0, 6 do
				local tall = pick(56, 104)
				Kit.block(
					scene,
					Vector3.new(10, tall, 36),
					CFrame.new(at(pick(3, 6), tall / 2 - 4, side * (62 + i * 32)))
						* CFrame.Angles(0, math.rad(pick(-6, 6)), math.rad(pick(-9, 9))),
					if i % 2 == 0 then c.ridge else c.rockWarm,
					slate
				)
			end
		end
	end)
end
