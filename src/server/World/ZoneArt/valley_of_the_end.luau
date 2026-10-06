--!strict
-- Valley of the End: a canyon in the rain at sunset. The river runs along both sides of the
-- lane between wet cliffs; at the far end two stone giants face each other across it, hands
-- raised in a seal, and waterfalls come down the head of the canyon behind them. Past the
-- canyon's rim the mountains go on, row behind row.
--
-- The giants are stacks of blocks: a robed figure with a wild mane and one with long straight
-- hair. They are meant to be read as "two ancient rivals", not as anyone's portrait.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require("./Kit")
local Particles = require(ReplicatedStorage.Shared.View.Particles)

-- The spray at the foot of a waterfall.
local SPRAY: Particles.Layer = {
	texture = Particles.SMOKE,
	rate = 6,
	life = { 2, 3.5 },
	speed = { 2, 5 },
	spread = 50,
	size = { 6, 14 },
	lift = 0.5,
	spin = 20,
	glow = 0.2,
	fade = 0.8,
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
	local wood = Enum.Material.Wood

	Kit.ground(scene)

	-- The gate: two weathered pillars with a rope of paper tags between them.
	Kit.gateway(scene, function()
		for _, side in { -1, 1 } do
			Kit.box(scene, Vector3.new(6, 24, 6), at(0, 0, side * 36), c.rock, slate, 6)
			Kit.box(scene, Vector3.new(7.4, 2, 7.4), at(0, 24, side * 36), c.rockDark, slate, 6)
		end
		Kit.rod(scene, at(0, 22.5, -36), at(0, 22.5, 36), 0.9, c.mist, Enum.Material.Fabric, true)
		for i = -2, 2 do
			Kit.box(
				scene,
				Vector3.new(0.2, 2.4, 1.6),
				at(0, 19.8, i * 11),
				c.foam,
				Enum.Material.Fabric
			)
		end
	end)

	-- The river, either side of the lane, with streaks of foam and rocks standing in it.
	for _, side in { -1, 1 } do
		local water = Kit.box(
			scene,
			Vector3.new(length, 0.3, 29),
			at(length / 2, -0.1, side * 47.5),
			c.water,
			Enum.Material.Glass
		)
		water.Transparency = 0.25
		water.Reflectance = 0.2
		water.CastShadow = false
		for i = 0, 6 do
			Kit.box(
				scene,
				Vector3.new(pick(8, 16), 0.06, 0.6),
				at(10 + i * 26 + pick(-6, 6), 0.2, side * pick(36, 60)),
				c.foam
			)
		end
		for i = 0, 11 do
			Kit.rock(
				scene,
				at(6 + i * 15 + pick(-4, 4), 0, side * pick(36, 60)),
				Vector3.new(pick(4, 9), pick(3, 6), pick(4, 8)),
				if i % 3 == 0 then c.moss else c.rockDark
			)
		end
		for i = 0, 7 do
			Kit.rock(
				scene,
				at(8 + i * 22 + pick(-5, 5), 0, side * pick(34.5, 36)),
				Vector3.new(2.4, pick(1.4, 2.6), 2.4),
				c.rock
			)
		end
	end

	-- The canyon's walls: a near row of cliffs, each with a ledge and a capstone, and a taller
	-- row behind it.
	for _, side in { -1, 1 } do
		-- The near row stops short of the giants, who stand where its last cliffs would be.
		for i = 0, 6 do
			local x = 6 + i * 18 + pick(-3, 3)
			local z = side * pick(74, 84)
			local width, height = pick(22, 30), pick(58, 96)
			local turn = pick(-14, 14)
			Kit.box(
				scene,
				Vector3.new(width, height, 26),
				at(x, -2, z),
				if i % 2 == 0 then c.rock else c.rockWarm,
				slate,
				turn
			)
			Kit.box(
				scene,
				Vector3.new(width * 0.7, 4, 14),
				at(x + pick(-3, 3), height * pick(0.25, 0.45), z - side * 16),
				c.rockDark,
				slate,
				turn
			)
			Kit.rock(scene, at(x, height - 3, z), Vector3.new(width * 0.6, 8, 18), c.rockDark)
			-- A second, narrower shelf higher up, and a boulder fallen to the cliff's foot.
			Kit.box(
				scene,
				Vector3.new(width * 0.5, 3, 10),
				at(x + pick(-4, 4), height * pick(0.55, 0.75), z - side * 15),
				c.rock,
				slate,
				turn
			)
			Kit.rock(
				scene,
				at(x + pick(-8, 8), 0, z - side * pick(15, 19)),
				Vector3.new(pick(6, 11), pick(4, 8), pick(6, 10)),
				c.rockWarm
			)
		end
		for i = 0, 6 do
			local x = 14 + i * 26 + pick(-4, 4)
			local z = side * pick(108, 132)
			local width, height = pick(28, 38), pick(96, 136)
			Kit.box(
				scene,
				Vector3.new(width, height, 30),
				at(x, -2, z),
				c.rockDark,
				slate,
				pick(-10, 10)
			)
			Kit.rock(scene, at(x, height - 4, z), Vector3.new(width * 0.5, 10, 20), c.rock)
		end
	end

	-- Crooked pines on the ledges, dead trees by the water, moss on the stones.
	for i = 0, 7 do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(10 + i * 13, pick(18, 34), side * pick(60, 66))
		local top = base + Vector3.new(pick(-3, 3), pick(10, 14), -side * pick(2, 5))
		Kit.rod(scene, base, top, 1.2, c.bark, wood, true)
		Kit.ball(scene, pick(6, 8), top, c.needle, Enum.Material.Grass)
		Kit.ball(
			scene,
			pick(4, 6),
			top + Vector3.new(pick(-3, 3), -3, pick(-3, 3)),
			c.needle,
			Enum.Material.Grass
		)
	end
	for i = 0, 7 do
		local side = if i % 2 == 0 then 1 else -1
		local base = at(20 + i * 20, 0, side * pick(62, 68))
		local top = base + Vector3.new(pick(-2, 2), pick(12, 18), pick(-2, 2))
		Kit.rod(scene, base, top, 1, c.bark, wood, true)
		Kit.rod(
			scene,
			base + (top - base) * 0.6,
			top + Vector3.new(pick(3, 6), -2, pick(-4, 4)),
			0.5,
			c.bark,
			wood,
			true
		)
	end
	for i = 0, 9 do
		local side = if i % 2 == 0 then -1 else 1
		Kit.rock(
			scene,
			at(pick(6, length - 6), 0, side * pick(62, 70)),
			Vector3.new(pick(6, 12), pick(1.5, 3), pick(6, 10)),
			c.moss
		)
	end

	-- Tufts of wet grass between the stones.
	for i = 1, 12 do
		local side = if i % 2 == 0 then -1 else 1
		Kit.ball(
			scene,
			pick(2, 3.5),
			at(pick(6, length - 40), 0.3, side * pick(62, 69)),
			c.moss,
			Enum.Material.Grass
		)
	end

	-- The two giants, facing each other across the lane with their hands raised.
	local function giant(side: number, maned: boolean)
		local face = -side -- towards the lane
		local x, z = length - 34, side * 68
		local function piece(
			size: Vector3,
			up: number,
			forward: number,
			sideways: number,
			color: Color3
		)
			return Kit.box(scene, size, at(x + sideways, up, z + face * forward), color, slate)
		end
		piece(Vector3.new(28, 10, 26), 0, 0, 0, c.rockDark)
		-- Steps down from the plinth to the river, and boulders either side of it.
		for step = 1, 3 do
			piece(Vector3.new(22 - step * 3, 10 - step * 2.8, 4), 0, 11 + step * 4, 0, c.rock)
		end
		for _, flank in { -19, 19 } do
			Kit.rock(
				scene,
				at(x + flank, 0, z + face * pick(2, 8)),
				Vector3.new(pick(8, 12), pick(8, 14), pick(8, 12)),
				c.rockWarm
			)
			Kit.rock(
				scene,
				at(x + flank * 1.3, 0, z - face * pick(4, 10)),
				Vector3.new(pick(10, 14), pick(16, 26), pick(10, 14)),
				c.rock
			)
		end
		for _, leg in { -5.5, 5.5 } do
			piece(Vector3.new(8, 30, 9), 10, 0, leg, c.statue)
		end
		piece(Vector3.new(20, 24, 3), 12, 5.5, 0, c.statueDark) -- the robe over the legs
		piece(Vector3.new(19, 8, 11), 40, 0, 0, c.statueDark)
		piece(Vector3.new(21, 24, 12), 48, 0, 0, c.statue)
		for _, shoulder in { -13, 13 } do
			piece(Vector3.new(7, 8, 10), 64, 0, shoulder, c.statueDark)
			-- An arm: down to the elbow, then forward and in to the hands.
			local top = at(x + shoulder, 66, z)
			local elbow = at(x + shoulder * 0.95, 52, z + face * 7)
			local hand = at(x + shoulder * 0.2, 58, z + face * 15)
			Kit.rod(scene, top, elbow, 6, c.statue, slate)
			Kit.rod(scene, elbow, hand, 5, c.statue, slate)
		end
		piece(Vector3.new(7, 7, 6), 55, 15, 0, c.statueDark) -- the hands, joined in a seal
		piece(Vector3.new(7, 4, 7), 72, 0, 0, c.statueDark)
		piece(Vector3.new(11, 13, 11), 76, 0, 0, c.statue)
		piece(Vector3.new(9, 2, 1), 83, 5.6, 0, c.statueDark) -- the brow
		if maned then
			-- A wild mane: spikes fanning out behind the head and down the back.
			for spike = -2, 2 do
				local from = at(x + spike * 3, 86, z - face * 3)
				local to = at(x + spike * 9, 78 - math.abs(spike) * 6, z - face * 14)
				Kit.rod(scene, from, to, 4.5, c.statueDark, slate)
			end
		else
			-- Long straight hair down the back, and a band across the forehead.
			piece(Vector3.new(12, 30, 3), 58, -6.5, 0, c.statueDark)
			piece(Vector3.new(4, 20, 2.4), 62, 4, 7, c.statueDark)
			piece(Vector3.new(4, 20, 2.4), 62, 4, -7, c.statueDark)
			piece(Vector3.new(11.6, 2, 11.6), 85, 0, 0, c.rockDark)
		end
	end
	giant(-1, true)
	giant(1, false)

	-- The head of the canyon: the walls close in behind the giants and the falls come down.
	for _, side in { -1, 1 } do
		local x = length - 8
		Kit.box(scene, Vector3.new(20, 110, 44), at(x, -2, side * 58), c.rockDark, slate)
		Kit.rock(scene, at(x - 6, 104, side * 56), Vector3.new(16, 10, 30), c.rock)
		local sheet = Kit.box(
			scene,
			Vector3.new(1.4, 100, 18),
			at(x - 10.6, 0, side * 52),
			c.fall,
			Enum.Material.Glass
		)
		sheet.Transparency = 0.25
		sheet.CastShadow = false
		local core = Kit.box(
			scene,
			Vector3.new(1, 100, 9),
			at(x - 11.2, 0, side * 52),
			c.foam,
			Enum.Material.Neon
		)
		core.Transparency = 0.45
		core.CastShadow = false
		for i = 0, 2 do
			local foam = Kit.ball(scene, pick(6, 9), at(x - 13, 1, side * (46 + i * 6)), c.foam)
			foam.Transparency = 0.3
			if i == 1 then
				Kit.emit(foam, SPRAY, c.mist)
			end
		end
	end
	-- Thinner falls down the canyon's sides.
	for i = 0, 2 do
		local side = if i % 2 == 0 then -1 else 1
		local x = 36 + i * 44
		local fall = Kit.box(
			scene,
			Vector3.new(6, 62, 0.8),
			at(x, 0, side * 61.5),
			c.fall,
			Enum.Material.Glass
		)
		fall.Transparency = 0.3
		fall.CastShadow = false
		local foam = Kit.ball(scene, 6, at(x, 0.5, side * 58), c.foam)
		foam.Transparency = 0.3
	end

	-- Mist lying in the bottom of the canyon.
	for i = 0, 3 do
		local side = if i % 2 == 0 then -1 else 1
		local bank = Kit.box(
			scene,
			Vector3.new(pick(50, 70), pick(5, 8), 22),
			at(30 + i * 40, 2, side * pick(48, 56)),
			c.mist
		)
		bank.Transparency = 0.9
		bank.CastShadow = false
	end

	-- The zone's sign: a slab of dark slate set in rough stone, moss on its top and a rope of
	-- paper tags under it.
	Kit.signage(scene, function(sign)
		local a, half = sign.along, sign.width / 2
		Kit.border(scene, sign, 1.2, c.rockDark, slate)
		for _, side in { -1, 1 } do
			Kit.rock(
				scene,
				at(a, sign.top + 0.6, side * (half - 1)),
				Vector3.new(2.6, 2.2, 5),
				c.rock
			)
			Kit.ball(scene, 2.2, at(a, sign.top + 1.6, side * 7), c.moss, Enum.Material.Grass)
			Kit.box(scene, Vector3.new(2, 1.6, 3), at(a, sign.foot - 2.8, side * 14), c.rock, slate)
		end
		Kit.rod(
			scene,
			at(a - 0.7, sign.foot - 1.7, -half),
			at(a - 0.7, sign.foot - 1.7, half),
			0.5,
			c.mist,
			Enum.Material.Fabric,
			true
		)
		for i = -1, 1 do
			Kit.box(
				scene,
				Vector3.new(0.15, 1.4, 1),
				at(a - 0.7, sign.foot - 3.3, i * 9 + 4.5),
				c.foam,
				Enum.Material.Fabric
			)
		end
	end)

	-- Past the canyon's rim the mountains go on: great crags near at hand, and behind them
	-- heights that are only shapes in the rain.
	for _, side in { -1, 1 } do
		for i = 0, 4 do
			Kit.backdrop(
				Kit.box(
					scene,
					Vector3.new(pick(46, 64), pick(170, 240), pick(50, 70)),
					at(12 + i * 39 + pick(-8, 8), -2, side * pick(196, 262)),
					if i % 2 == 0 then c.rockDark else c.rock,
					slate,
					pick(-14, 14)
				)
			)
		end
		for i = 0, 2 do
			Kit.mound(
				scene,
				at(24 + i * 66 + pick(-8, 8), 0, side * pick(500, 580)),
				pick(190, 220),
				pick(230, 290),
				c.rockDark,
				slate
			)
		end
	end

	-- The canyon's mouth. Where the zone begins rock closes in on the gate from both sides, a
	-- fall coming down its inner face into the river, and crags stand on beyond the cliffs: from
	-- inside the canyon nothing of the arena behind is seen.
	for _, side in { -1, 1 } do
		local height = pick(58, 72)
		Kit.box(
			scene,
			Vector3.new(16, height, 30),
			at(6, -2, side * 54),
			c.rockDark,
			slate,
			side * 5
		)
		Kit.rock(scene, at(6, height - 5, side * 54), Vector3.new(13, 9, 22), c.rock)
		local sheet = Kit.box(
			scene,
			Vector3.new(0.8, height - 6, 9),
			at(14.6, 0, side * 52),
			c.fall,
			Enum.Material.Glass
		)
		sheet.Transparency = 0.3
		sheet.CastShadow = false
		local foam = Kit.ball(scene, 6, at(16, 0.5, side * 52), c.foam)
		foam.Transparency = 0.3
		for i, out in { 84, 118, 152, 186, 220, 254 } do
			Kit.backdrop(
				Kit.box(
					scene,
					Vector3.new(pick(30, 40), pick(84, 120) + i * 8, 38),
					at(pick(8, 14), -2, side * out),
					if i % 2 == 0 then c.rock else c.rockDark,
					slate,
					pick(-10, 10)
				)
			)
		end
	end
end
