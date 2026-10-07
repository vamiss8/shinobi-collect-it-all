--!strict
-- The village round the yard, behind the start of the lane. Along both sides of the yard, two
-- streets of houses and poles strung with wires; behind it, where the eye goes from the plaza,
-- an avenue lined with stone lanterns and banners that runs to the great gate in the village's
-- wall, with the round red hall on its left and a pagoda on its right, cherry trees, water
-- tanks on stilts and more houses out to the sides; and wooded mountains all round. None of
-- it can be walked to: the yard, with the plaza and the dojos in it, is fenced (World/Plots),
-- and this is what is seen over the fence.
--
-- It is here so that the world is not seen to end behind the dojos. It is not a zone: it has
-- no lane, gate or sign, and positions are the Hub's own, with the lane's start at 0 and
-- everything here at a negative `along`. Everything is placed from the yard's own size
-- (Logic/PlazaPlan), so that it moves out of the way when the yard grows.
--
-- What is worth looking at stands behind the yard, not beside it: the dojos are three floors
-- tall and hide whatever stands at their backs, which is where the hall first stood.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require("./Kit")
local PlazaPlan = require(ReplicatedStorage.Shared.Logic.PlazaPlan)

-- The yard: how far out its fence stands from the middle line, and how far back it goes.
local YARD = PlazaPlan.YARD_HALF
local DEPTH = PlazaPlan.DEPTH
-- Where the village's wall stands, studs behind the lane's start.
local BACK = DEPTH + 140
-- How far behind the lane's start the hall and the pagoda stand, either side of the avenue.
local SIGHTS = DEPTH + 78
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
	local cloth = Enum.Material.Fabric

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

	-- Behind the yard: the avenue from the great gate, a stone lantern either side of it every
	-- few steps and a red banner on a pole between one pair and the next.
	local avenue = BACK - DEPTH - 12
	Kit.backdrop(
		Kit.box(
			scene,
			Vector3.new(avenue, 0.2, 18),
			at(-(BACK + DEPTH) / 2, -0.25, 0),
			c.path,
			slate
		)
	)
	for i = 0, 3 do
		local x = -(DEPTH + 20) - i * 28
		for _, side in { -1, 1 } do
			local base = at(x, 0, side * 13)
			Kit.box(scene, Vector3.new(3, 0.8, 3), base, c.cliffShade, slate)
			Kit.pillar(scene, 3.4, 1.3, base + Vector3.new(0, 0.8, 0), c.stone, slate)
			Kit.lantern(
				Kit.box(
					scene,
					Vector3.new(1.6, 1.6, 1.6),
					base + Vector3.new(0, 4.7, 0),
					c.lantern,
					Enum.Material.Neon
				)
			)
			Kit.box(
				scene,
				Vector3.new(3.4, 0.6, 3.4),
				base + Vector3.new(0, 6.3, 0),
				c.cliffShade,
				slate
			)
			if i < 3 then
				local pole = at(x - 14, 0, side * 14.5)
				Kit.pillar(scene, 17, 0.5, pole, c.trim, wood)
				Kit.box(
					scene,
					Vector3.new(0.2, 9.4, 3),
					pole + Vector3.new(0, 7, side * 1.8),
					c.band,
					cloth
				)
				Kit.box(
					scene,
					Vector3.new(0.25, 2, 2),
					pole + Vector3.new(0, 12.6, side * 1.8),
					c.cloth,
					cloth
				)
			end
		end
	end

	-- The round red hall, left of the avenue with its face to the yard: three drums, each
	-- under a dark eave, a dome on the last, a pale plate with a red mark, and a low wing to
	-- either side.
	local hall = at(-SIGHTS, 0, -86)
	Kit.pillar(scene, 24, 46, hall, c.hall)
	Kit.pillar(scene, 1.6, 50, hall + Vector3.new(0, 24, 0), c.roofDark, slate)
	Kit.pillar(scene, 12, 32, hall + Vector3.new(0, 25.6, 0), c.hall)
	Kit.pillar(scene, 1.4, 36, hall + Vector3.new(0, 37.6, 0), c.roofDark, slate)
	Kit.pillar(scene, 7, 18, hall + Vector3.new(0, 39, 0), c.hall)
	Kit.ball(scene, 18, hall + Vector3.new(0, 46, 0), c.roofDark, slate)
	Kit.rod(
		scene,
		hall + Vector3.new(22.6, 14, 0),
		hall + Vector3.new(23.6, 14, 0),
		12,
		c.cloth,
		nil,
		true
	)
	Kit.rod(
		scene,
		hall + Vector3.new(23.4, 14, 0),
		hall + Vector3.new(23.9, 14, 0),
		6,
		c.band,
		nil,
		true
	)
	for _, wing in { -34, 34 } do
		Kit.box(scene, Vector3.new(16, 13, 22), hall + Vector3.new(6, 0, wing), c.wallShade)
		Kit.roof(
			scene,
			hall + Vector3.new(6, 13 + 10 * math.tan(math.rad(PITCH)) - 0.1, wing),
			24,
			10,
			PITCH,
			c.roof,
			slate,
			true
		)
	end

	-- The pagoda, right of the avenue: five storeys, each narrower than the one below and
	-- each under a dark roof that steps out wide, on a plinth of stone, a gilded spire on top.
	local pagoda = at(-SIGHTS, 0, 86)
	Kit.box(scene, Vector3.new(34, 2, 34), pagoda, c.stone, slate)
	local level = 2
	for storey = 0, 4 do
		local width = 26 - storey * 4
		Kit.box(
			scene,
			Vector3.new(width, 9, width),
			pagoda + Vector3.new(0, level, 0),
			if storey % 2 == 0 then c.hall else c.wall
		)
		Kit.box(
			scene,
			Vector3.new(width + 9, 1.2, width + 9),
			pagoda + Vector3.new(0, level + 9, 0),
			c.roofDark,
			slate
		)
		Kit.box(
			scene,
			Vector3.new(width + 4, 0.8, width + 4),
			pagoda + Vector3.new(0, level + 10.2, 0),
			c.roofDark,
			slate
		)
		level += 11
	end
	Kit.pillar(scene, 12, 1.2, pagoda + Vector3.new(0, level, 0), c.trim, wood)
	for ring = 1, 3 do
		Kit.pillar(
			scene,
			0.5,
			3.6 - ring * 0.7,
			pagoda + Vector3.new(0, level + ring * 2.8, 0),
			c.flower
		)
	end
	Kit.ball(scene, 2.6, pagoda + Vector3.new(0, level + 12.8, 0), c.flower)

	-- More houses out to the sides of the avenue, behind the hall and the pagoda, their doors
	-- to it; cherry trees round both and along the avenue; a water tank on stilts on each side.
	for _, side in { -1, 1 } do
		for _, spot in { { 26, 160 }, { 62, 196 }, { 100, 160 }, { 100, 236 }, { 44, 250 } } do
			house(
				-(DEPTH + spot[1]) + pick(-3, 3),
				side * (spot[2] + pick(-4, 4)),
				-side,
				spot[2] > 200
			)
		end
		for _, spot in { { 26, 44 }, { 112, 44 }, { 30, 118 }, { 106, 126 } } do
			Kit.tree(
				scene,
				at(-(DEPTH + spot[1]), 0, side * spot[2]),
				8,
				1.6,
				11,
				c.bark,
				c.blossom,
				3
			)
		end
		local tank = at(-(DEPTH + 72), 0, side * 150)
		for _, dx in { -2, 2 } do
			for _, dz in { -2, 2 } do
				Kit.box(
					scene,
					Vector3.new(0.5, 13, 0.5),
					tank + Vector3.new(dx, 0, dz),
					c.trim,
					wood
				)
			end
		end
		Kit.pillar(scene, 7, 7, tank + Vector3.new(0, 13, 0), c.tank)
		Kit.pillar(scene, 0.6, 7.8, tank + Vector3.new(0, 20, 0), c.roofDark)
	end

	-- Trees between the houses and beyond them, and out behind the yard.
	for i = 1, 26 do
		local side = if i % 2 == 0 then -1 else 1
		local x = -pick(4, BACK - 22)
		local out = if x < -(DEPTH + 12) then pick(270, 330) else YARD + pick(84, 126)
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

	-- The village's wall closes the back, capped in green, and in it the great gate: two red
	-- posts, a beam and a roof over them, and the two green doors standing open along the
	-- avenue, each with its red mark.
	--
	-- A post is thicker than the wall it stands in, and the beam thicker than the posts. The
	-- posts were as thick as the wall at first and ran a stud into it: a strip of red and a
	-- strip of wall in one plane, which flickered from the plaza as the camera moved.
	for _, side in { -1, 1 } do
		Kit.box(scene, Vector3.new(12, 40, 330), at(-BACK, 0, side * 205), c.rampart, concrete)
		Kit.box(scene, Vector3.new(15, 3, 332), at(-BACK, 40, side * 205), c.rampartCap, slate)
		Kit.box(scene, Vector3.new(13, 50, 10), at(-BACK, 0, side * 36), c.gateRed, wood)
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
		-- A wing of the wall turning forward at each end, until the mountains take it.
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

	-- Wooded mountains all round, a nearer row and a higher one behind it: on both sides and
	-- behind the wall. They are plain rounded heights and nothing stands on them. (On the left
	-- there was a row of square rocks under trees at first, a cliff carried on from the one
	-- with the faces: the rocks ran into one another and the trees on them read as nothing in
	-- particular, and the owner asked for mountains instead.)
	local function mountain(x: number, z: number, far: boolean)
		if far then
			Kit.mound(scene, at(x, 0, z), pick(205, 240), pick(135, 175), c.hillFar, grass)
		else
			Kit.mound(scene, at(x, 0, z), pick(118, 142), pick(70, 110), c.hill, grass)
		end
	end
	for i = 0, 3 do
		mountain(-44 - i * 92 + pick(-10, 10), YARD + pick(235, 260), false)
		mountain(-34 - i * 100 + pick(-10, 10), -(YARD + pick(225, 250)), false)
	end
	for i = 0, 2 do
		mountain(-90 - i * 160, YARD + pick(440, 490), true)
		mountain(-70 - i * 160, -(YARD + pick(420, 480)), true)
	end
	for i = -2, 2 do
		mountain(-BACK - pick(160, 190), i * 150 + pick(-20, 20), false)
		mountain(-BACK - pick(400, 460), i * 240, true)
	end
	mountain(-BACK - 110, 470, true)
	mountain(-BACK - 110, -480, true)
end
