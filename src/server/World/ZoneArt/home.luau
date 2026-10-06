--!strict
-- The village round the yard, behind the start of the lane: streets of houses on both sides of
-- the yard and along the road behind it, poles strung with wires, water tanks on stilts, the
-- round red hall under the cliff on the left, the village's wall at the back with its great
-- gate standing open, and wooded hills all round. None of it can be walked to: the yard, with
-- the plaza and the dojos in it, is fenced (World/Plots), and this is what is seen over the
-- fence.
--
-- It is here so that the world is not seen to end behind the dojos. It is not a zone: it has
-- no lane, gate or sign, and positions are the Hub's own, with the lane's start at 0 and
-- everything here at a negative `along`. Everything is placed from the yard's own size
-- (Logic/PlazaPlan), so that it moves out of the way when the yard grows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require("./Kit")
local PlazaPlan = require(ReplicatedStorage.Shared.Logic.PlazaPlan)

-- The yard: how far out its fence stands from the middle line, and how far back it goes.
local YARD = PlazaPlan.YARD_HALF
local DEPTH = PlazaPlan.DEPTH
-- Where the village's wall stands, studs behind the lane's start.
local BACK = DEPTH + 140
-- The pitch of every house's roof, degrees.
local PITCH = 26

return function(scene: Kit.Scene)
	local c = scene.colors
	local function at(along: number, up: number, side: number): Vector3
		return Kit.at(scene, along, up, side)
	end
	local function pick(low: number, high: number): number
		return Kit.pick(scene, low, high)
	end
	local grass = Enum.Material.Grass
	local slate = Enum.Material.Slate
	local wood = Enum.Material.Wood
	local concrete = Enum.Material.Concrete

	-- Grass from the lane's start back to the horizon, a hair under the Hub's own, which lies
	-- under the yard.
	for _, side in { -1, 1 } do
		local ground = Kit.block(
			scene,
			Vector3.new(Kit.FAR, 1, Kit.FAR),
			CFrame.new(at(-Kit.FAR / 2, -0.75, side * Kit.FAR / 2)),
			Color3.fromHex(scene.art.ground.color),
			Kit.material(scene.art.ground.material)
		)
		ground.CastShadow = false
	end

	-- A house: walls, a roof resting on them, a door and a window on the side that looks
	-- `face`-wards across the lane's line, and a second row of windows if it has an upper floor.
	local houses = 0
	local function house(x: number, z: number, face: number, upper: boolean)
		houses += 1
		local width, depth = pick(13, 17), pick(11, 14)
		local height = if upper then pick(15, 19) else pick(9, 12)
		local reach = depth / 2 + 2
		local front = z + face * depth / 2
		Kit.box(
			scene,
			Vector3.new(width, height, depth),
			at(x, 0, z),
			if houses % 2 == 0 then c.wall else c.wallShade
		)
		Kit.roof(
			scene,
			at(x, height + reach * math.tan(math.rad(PITCH)) - 0.1, z),
			width + 3,
			reach,
			PITCH,
			if houses % 3 == 0 then c.roofDark else c.roof,
			slate
		)
		Kit.box(scene, Vector3.new(2.6, 5, 0.4), at(x - 3, 0, front), c.door, wood)
		Kit.box(scene, Vector3.new(3, 2.6, 0.4), at(x + 3, 4, front), c.window)
		if upper then
			Kit.box(scene, Vector3.new(3, 2.6, 0.4), at(x + 3, 11, front), c.window)
		end
	end

	-- Two streets along each side of the yard, the houses' doors to it.
	for _, side in { -1, 1 } do
		for i = 0, 6 do
			house(-16 - i * 36 + pick(-4, 4), side * (YARD + pick(17, 26)), -side, i % 3 == 1)
		end
		for i = 0, 5 do
			house(-34 - i * 40 + pick(-5, 5), side * (YARD + pick(56, 74)), -side, i % 2 == 0)
		end
	end
	-- The road from the great gate to the yard, with houses along it. They stop short of the
	-- gate's doors, which stand open along the road.
	local road = BACK - DEPTH - 12
	Kit.backdrop(
		Kit.box(scene, Vector3.new(road, 0.2, 18), at(-(BACK + DEPTH) / 2, -0.25, 0), c.path, slate)
	)
	for _, side in { -1, 1 } do
		for i = 0, 2 do
			house(-(DEPTH + 26) - i * 27 + pick(-2, 2), side * pick(21, 24), -side, i % 2 == 1)
		end
	end

	-- Trees between the houses and beyond them, and behind the yard. On the left they keep off
	-- the hall.
	for i = 1, 30 do
		local side = if i % 2 == 0 then -1 else 1
		local x = -pick(4, BACK - 22)
		local out = if x < -(DEPTH + 12) then pick(40, 230) else YARD + pick(84, 126)
		if side == -1 and x > -128 and x < -56 then
			out = YARD + pick(38, 44)
		end
		Kit.tree(
			scene,
			at(x, 0, side * out),
			pick(7, 11),
			1.8,
			pick(9, 13),
			c.bark,
			if i % 3 == 0 then c.leafLight else c.leaf,
			2
		)
	end

	-- Poles along the yard's fence, a pair of wires from each to the next.
	for _, side in { -1, 1 } do
		local previous: Vector3? = nil
		for i = 0, 5 do
			local base = at(-10 - i * 48, 0, side * (YARD + 7))
			Kit.pillar(scene, 15, 0.7, base, c.trim, wood)
			Kit.box(scene, Vector3.new(0.4, 0.4, 4), base + Vector3.new(0, 13.6, 0), c.trim, wood)
			local head = base + Vector3.new(0, 14.1, 0)
			if previous then
				for _, wire in { -1.6, 1.6 } do
					local offset = Vector3.new(0, 0, wire)
					Kit.rod(scene, previous + offset, head + offset, 0.12, c.wire)
				end
			end
			previous = head
		end
	end

	-- Water tanks on stilts: one between the streets on each side, one behind the yard.
	for _, tank in { { -70, YARD + 41 }, { -176, -(YARD + 41) }, { -(DEPTH + 28), 70 } } do
		local base = at(tank[1], 0, tank[2])
		for _, dx in { -2, 2 } do
			for _, dz in { -2, 2 } do
				Kit.box(
					scene,
					Vector3.new(0.5, 13, 0.5),
					base + Vector3.new(dx, 0, dz),
					c.trim,
					wood
				)
			end
		end
		Kit.pillar(scene, 7, 7, base + Vector3.new(0, 13, 0), c.tank)
		Kit.pillar(scene, 0.6, 7.8, base + Vector3.new(0, 20, 0), c.roofDark)
	end

	-- The round red hall under the cliff, on the left: three drums, each under a dark eave, a
	-- dome on the last, a pale plate with a red mark on the side that looks at the yard, and a
	-- low wing either side.
	local hall = at(-92, 0, -(YARD + 122))
	Kit.pillar(scene, 24, 46, hall, c.hall)
	Kit.pillar(scene, 1.6, 50, hall + Vector3.new(0, 24, 0), c.roofDark, slate)
	Kit.pillar(scene, 12, 32, hall + Vector3.new(0, 25.6, 0), c.hall)
	Kit.pillar(scene, 1.4, 36, hall + Vector3.new(0, 37.6, 0), c.roofDark, slate)
	Kit.pillar(scene, 7, 18, hall + Vector3.new(0, 39, 0), c.hall)
	Kit.ball(scene, 18, hall + Vector3.new(0, 46, 0), c.roofDark, slate)
	Kit.rod(
		scene,
		hall + Vector3.new(0, 14, 22.6),
		hall + Vector3.new(0, 14, 23.6),
		12,
		c.cloth,
		nil,
		true
	)
	Kit.rod(
		scene,
		hall + Vector3.new(0, 14, 23.4),
		hall + Vector3.new(0, 14, 23.9),
		6,
		c.band,
		nil,
		true
	)
	for _, wing in { -34, 34 } do
		Kit.box(scene, Vector3.new(22, 13, 16), hall + Vector3.new(wing, 0, 6), c.wallShade)
		Kit.roof(
			scene,
			hall + Vector3.new(wing, 13 + 10 * math.tan(math.rad(PITCH)) - 0.1, 6),
			24,
			10,
			PITCH,
			c.roof,
			slate
		)
	end

	-- The cliff the faces are cut in runs on behind the hall: each rock stands under a cap of
	-- turf, and trees grow on top, set back from its edge. (The trees were bare balls of
	-- leaves sitting on the rock at first, which the owner did not like the look of.)
	for i = 0, 8 do
		local x = -18 - i * 42
		local height = pick(84, 120)
		local z = -(YARD + 178) + pick(-6, 6)
		local turn = pick(-6, 6)
		Kit.backdrop(
			Kit.box(
				scene,
				Vector3.new(46, height, 40),
				at(x, -2, z),
				if i % 2 == 0 then c.cliff else c.cliffShade,
				slate,
				turn
			)
		)
		local top = height - 2
		Kit.backdrop(
			Kit.box(scene, Vector3.new(48, 2.2, 42), at(x, top - 0.4, z), c.hill, grass, turn)
		)
		for _ = 1, 2 do
			Kit.tree(
				scene,
				at(x + pick(-15, 15), top + 1.6, z + pick(-12, 4)),
				pick(7, 10),
				1.6,
				pick(10, 14),
				c.bark,
				if i % 2 == 0 then c.leaf else c.leafLight,
				2
			)
		end
	end

	-- The village's wall closes the back, capped in green, and in it the great gate: two red
	-- posts, a beam and a roof over them, and the two green doors standing open along the road,
	-- each with its red mark.
	for _, side in { -1, 1 } do
		Kit.box(scene, Vector3.new(12, 40, 330), at(-BACK, 0, side * 205), c.rampart, concrete)
		Kit.box(scene, Vector3.new(15, 3, 332), at(-BACK, 40, side * 205), c.rampartCap, slate)
		Kit.box(scene, Vector3.new(12, 50, 10), at(-BACK, 0, side * 36), c.gateRed, wood)
		Kit.box(scene, Vector3.new(28, 36, 2), at(-BACK + 20, 0, side * 31), c.gateGreen, wood)
		Kit.rod(
			scene,
			at(-BACK + 20, 20, side * 30.2),
			at(-BACK + 20, 20, side * 29.6),
			10,
			c.gateRed,
			nil,
			true
		)
		-- A wing of the wall turning forward at each end, until the hills take it.
		Kit.box(
			scene,
			Vector3.new(152, 40, 12),
			at(-BACK + 53, 0, side * 423),
			c.rampart,
			concrete,
			-side * 45
		)
	end
	Kit.box(scene, Vector3.new(14, 7, 84), at(-BACK, 44, 0), c.gateRed, wood)
	Kit.roof(
		scene,
		at(-BACK, 51 + 11 * math.tan(math.rad(24)) - 0.1, 0),
		98,
		11,
		24,
		c.rampartCap,
		slate,
		true
	)

	-- Wooded hills all round: a nearer row with trees standing on it and a higher one behind,
	-- on the right, behind the cliff on the left, and behind the wall.
	local function hill(x: number, z: number, far: boolean)
		if far then
			Kit.mound(scene, at(x, 0, z), pick(205, 240), pick(135, 175), c.hillFar, grass)
			return
		end
		local height = pick(62, 88)
		Kit.mound(scene, at(x, 0, z), pick(112, 134), height, c.hill, grass)
		for _ = 1, 2 do
			Kit.backdrop(
				Kit.ball(
					scene,
					pick(22, 34),
					at(x + pick(-40, 40), height * pick(0.6, 0.95), z + pick(-30, 30)),
					c.leaf,
					grass
				)
			)
		end
	end
	for i = 0, 3 do
		hill(-44 - i * 92 + pick(-10, 10), YARD + pick(235, 260), false)
	end
	for i = 0, 2 do
		hill(-90 - i * 160, YARD + pick(440, 490), true)
		hill(-70 - i * 160, -(YARD + pick(420, 480)), true)
	end
	for i = -2, 2 do
		hill(-BACK - pick(160, 190), i * 150 + pick(-20, 20), false)
		hill(-BACK - pick(400, 460), i * 240, true)
	end
	hill(-BACK - 110, 470, true)
	hill(-BACK - 110, -480, true)
end
