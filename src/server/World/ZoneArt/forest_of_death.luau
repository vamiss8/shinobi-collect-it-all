--!strict
-- Forest of Death: trees as thick as houses with roots taller than a player, crowns that close
-- over the lane far above it, a green dusk underneath and shafts of light coming through. The
-- zone is entered through the gate of the training ground's fence, hung with warning signs.
-- Behind the giants the forest goes on: a wall of trunks under one roof of leaves, and dark
-- wooded heights beyond it.

local Kit = require("./Kit")

-- A trunk standing this close to the lane keeps its roots from reaching into it.
local ROOT_LIMIT = Kit.EDGE + 2

return function(scene: Kit.Scene)
	local c = scene.colors
	local function at(along: number, up: number, side: number): Vector3
		return Kit.at(scene, along, up, side)
	end
	local function pick(low: number, high: number): number
		return Kit.pick(scene, low, high)
	end
	local wood = Enum.Material.Wood
	local leaves = Enum.Material.Grass
	local metal = Enum.Material.Metal

	Kit.ground(scene)

	-- The gate in the fence: two steel posts, a beam and a warning board over the lane.
	Kit.gateway(scene, function()
		for _, side in { -1, 1 } do
			Kit.box(scene, Vector3.new(2, 26, 2), at(0, 0, side * 34), c.fence, metal)
		end
		Kit.rod(scene, at(0, 25, -35), at(0, 25, 35), 1.6, c.fence, metal)
		Kit.box(scene, Vector3.new(0.4, 4, 18), at(0, 19.5, 0), c.sign, wood)
		Kit.box(scene, Vector3.new(0.5, 1, 12), at(0, 21, 0), c.signMark)
	end)
	-- The fence itself runs off into the trees either side: posts, mesh and more signs.
	for _, side in { -1, 1 } do
		for i = 1, 8 do
			local z = side * (34 + i * 8)
			Kit.box(scene, Vector3.new(0.8, 12, 0.8), at(0, 0, z), c.fence, metal)
			if i <= 7 then
				local mesh =
					Kit.box(scene, Vector3.new(0.2, 10, 8), at(0, 1, z - side * 4), c.mesh, metal)
				mesh.Transparency = 0.55
			end
			if i % 3 == 1 then
				Kit.box(scene, Vector3.new(0.3, 3, 4), at(-0.3, 6, z - side * 4), c.sign, wood)
				Kit.box(
					scene,
					Vector3.new(0.35, 0.8, 2.6),
					at(-0.32, 7.1, z - side * 4),
					c.signMark
				)
			end
		end
		Kit.box(scene, Vector3.new(0.5, 0.5, 64), at(0, 11.6, side * 66), c.fence, metal)
	end

	-- The giant trees: a trunk on a flared foot, three roots arching to the ground, two boughs
	-- and a crown of two great balls of leaves, all of it high above the lane.
	local function giant(along: number, side: number, out: number)
		local height = pick(92, 124)
		local width = pick(10, 16)
		local base = at(along, 0, side * out)
		Kit.pillar(scene, height, width, base, c.bark, wood)
		Kit.pillar(scene, 8, width * 1.45, base, c.barkDark, wood)

		for root = 1, 3 do
			local angle = pick(0, 2 * math.pi)
			local reach = pick(12, 18)
			local foot = Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)
			-- A root that would come down inside the lane's walls is turned the other way.
			if math.abs(side * out + foot.Z) < ROOT_LIMIT + 3 then
				foot = Vector3.new(foot.X, 0, side * math.abs(foot.Z))
			end
			local knee = base + Vector3.new(foot.X * 0.45, pick(7, 11), foot.Z * 0.45)
			Kit.rod(
				scene,
				base + Vector3.new(0, 5 + root, 0),
				knee,
				pick(3.5, 5),
				c.root,
				wood,
				true
			)
			Kit.rod(
				scene,
				knee,
				base + foot + Vector3.new(0, -1, 0),
				pick(3, 4),
				c.root,
				wood,
				true
			)
		end

		for bough = 1, 2 do
			local angle = pick(0, 2 * math.pi)
			-- High enough that a bough reaching over the lane stays above the kunai's path.
			local from = base + Vector3.new(0, height * pick(0.9, 0.96), 0)
			local to = from + Vector3.new(math.cos(angle) * 26, pick(10, 18), math.sin(angle) * 26)
			Kit.rod(scene, from, to, 3.2 - bough * 0.6, c.barkDark, wood, true)
		end

		local crown = pick(40, 52)
		local top = base + Vector3.new(0, math.max(height, Kit.CLEAR + crown / 2 + 6), 0)
		Kit.ball(scene, crown, top + Vector3.new(0, 6, 0), c.leaf, leaves)
		Kit.ball(
			scene,
			crown * 0.8,
			top + Vector3.new(pick(-14, 14), pick(8, 16), side * pick(4, 16)),
			c.leafDark,
			leaves
		)
	end
	for _, side in { -1, 1 } do
		for i = 0, 4 do
			giant(14 + i * 28 + pick(-4, 4), side, pick(52, 64))
		end
		for i = 0, 5 do
			giant(6 + i * 25 + pick(-5, 5), side, pick(86, 150))
		end
	end

	-- The roof of leaves over the lane itself, with gaps for the light.
	for i = 0, 11 do
		local crown = pick(44, 56)
		Kit.ball(
			scene,
			crown,
			at(8 + i * 11.5, Kit.CLEAR + crown / 2 + pick(6, 20), pick(-26, 26)),
			if i % 2 == 0 then c.leaf else c.leafDark,
			leaves
		)
	end

	-- Shafts of light slanting down through the gaps, beside the lane.
	for i = 0, 7 do
		local side = if i % 2 == 0 then -1 else 1
		local shaft = Kit.block(
			scene,
			Vector3.new(5, 96, 9),
			CFrame.new(at(12 + i * 16, 46, side * pick(40, 58)))
				* CFrame.Angles(0, 0, math.rad(pick(10, 20))),
			c.shaft,
			Enum.Material.Neon
		)
		shaft.Transparency = 0.9
		shaft.CastShadow = false
	end

	-- A giant that fell long ago, lying along the left side with two broken boughs.
	Kit.rod(scene, at(40, 4, -44), at(92, 5, -48), 8, c.barkDark, wood, true)
	Kit.rod(scene, at(60, 7, -45), at(64, 15, -52), 2, c.bark, wood, true)
	Kit.rod(scene, at(78, 8, -47), at(74, 16, -56), 1.8, c.bark, wood, true)

	-- Roots that heave out of the ground along the lane like low walls.
	for i = 0, 5 do
		local side = if i % 2 == 0 then 1 else -1
		local x = 16 + i * 22
		local z = side * pick(37, 41)
		local crest = at(x + 6, pick(7, 10), z + side * 2)
		Kit.rod(scene, at(x, -1, z), crest, 3.4, c.root, wood, true)
		Kit.rod(scene, crest, at(x + 13, -1, z + side * 3), 3, c.root, wood, true)
	end

	-- Underfoot: ferns, mossy stones, pale mushrooms that glow a little.
	for i = 1, 30 do
		local side = if i % 2 == 0 then -1 else 1
		Kit.ball(scene, pick(3, 6), at(pick(4, 136), 0.4, side * pick(36, 120)), c.fern, leaves)
	end
	for i = 1, 12 do
		local side = if i % 2 == 0 then -1 else 1
		Kit.rock(
			scene,
			at(pick(4, 136), 0, side * pick(38, 110)),
			Vector3.new(pick(4, 9), pick(2, 5), pick(4, 8)),
			if i % 3 == 0 then c.moss else c.rock
		)
	end
	for i = 1, 8 do
		local side = if i % 2 == 0 then -1 else 1
		local base = at(pick(6, 134), 0, side * pick(36, 70))
		Kit.pillar(scene, 1.6, 0.5, base, c.sign, wood)
		Kit.ball(scene, 1.8, base + Vector3.new(0, 1.8, 0), c.mushroom, Enum.Material.Neon)
	end

	-- Creepers hanging from the boughs.
	for i = 1, 14 do
		local side = if i % 2 == 0 then -1 else 1
		local top = at(pick(6, 134), pick(84, 104), side * pick(36, 80))
		Kit.rod(scene, top, top - Vector3.new(pick(-2, 2), pick(18, 32), 0), 0.5, c.vine, leaves)
	end

	-- Behind the giants the forest goes on: a wall of trunks whose crowns have grown into one
	-- roof, and dark wooded heights beyond.
	for _, side in { -1, 1 } do
		for i = 0, 6 do
			local x = 4 + i * 22 + pick(-6, 6)
			local out = pick(200, 300)
			local height = pick(130, 180)
			Kit.backdrop(
				Kit.pillar(scene, height, pick(16, 26), at(x, 0, side * out), c.barkDark, wood)
			)
			Kit.backdrop(
				Kit.ball(
					scene,
					pick(90, 130),
					at(x + pick(-10, 10), height + pick(10, 30), side * (out + pick(-10, 30))),
					if i % 2 == 0 then c.leafDark else c.leaf,
					leaves
				)
			)
		end
		for i = 0, 2 do
			Kit.mound(
				scene,
				at(14 + i * 56 + pick(-8, 8), 0, side * pick(440, 500)),
				pick(150, 180),
				pick(140, 180),
				c.leafDark,
				Enum.Material.LeafyGrass
			)
		end
	end
end
