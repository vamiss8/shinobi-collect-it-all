--!strict
-- The plaza behind the throwing strip, where players appear: paving with a path down its middle
-- to the lane and another across it from dojo to dojo, and where they cross a fountain of three
-- bowls with water running from each into the next. Round the fountain stand benches and
-- lanterns; along the middle path, lantern posts; in the alleys between the dojos, cherry trees
-- in stone planters that shed their petals; at the back, a red gate; and stone lanterns at the
-- lane's start, by the gate and where the cross path meets the dojos. Logic/PlazaPlan says
-- where things stand; the dojos are World/Plots's and the stalls World/Market's.
--
-- Unlike the zones' scenery (World/ZoneArt) this is ground that players walk on: the paving,
-- the fountain's rim and bowls, the benches, posts, planters and trunks are solid. What is only
-- for the eye, the water, the leaves and the patterns laid into the paving, nothing bumps into.
--
-- Built from plain parts in Hub coordinates; call start() after Hub.start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Hub = require("./Hub")
local Particles = require(ReplicatedStorage.Shared.View.Particles)
local PlazaPlan = require(ReplicatedStorage.Shared.Logic.PlazaPlan)

local Plaza = {}

local UP = Vector3.new(0, 1, 0)

-- The paving and what is laid into it.
local PAVING = Color3.fromRGB(168, 160, 147)
local PATH = Color3.fromRGB(204, 194, 172)
local BAND = Color3.fromRGB(126, 118, 108)
local PATH_WIDTH = 18
-- The fountain.
local STONE = Color3.fromRGB(210, 203, 188)
local STONE_DARK = Color3.fromRGB(146, 139, 127)
local TILE = Color3.fromRGB(74, 142, 170)
local WATER = Color3.fromRGB(120, 205, 240)
local SPRAY = Color3.fromRGB(205, 236, 250)
local GOLD = Color3.fromRGB(255, 202, 40)
local RIM = 1.8 -- thickness of the basin's wall
local RIM_HEIGHT = 2.6
local RIM_SEGMENTS = 20
-- Wood, cloth and leaves.
local TIMBER = Color3.fromRGB(62, 44, 36)
local WOOD = Color3.fromRGB(121, 85, 61)
local LACQUER = Color3.fromRGB(183, 40, 32)
local LANTERN = Color3.fromRGB(255, 190, 110)
local BARK = Color3.fromRGB(109, 76, 65)
local BLOSSOM = Color3.fromRGB(248, 187, 208)
local BLOSSOM_DEEP = Color3.fromRGB(244, 143, 177)
local SOIL = Color3.fromRGB(92, 70, 52)

-- Water leaving a bowl: it sets off up and outward and falls into the bowl below. The pull
-- down and the life are matched to how far each has to fall.
local FALL: Particles.Layer = {
	texture = Particles.SMOKE,
	rate = 12,
	life = { 0.7, 0.85 },
	speed = { 4.5, 5.5 },
	spread = 9,
	size = { 0.6, 1.1 },
	lift = -34,
	spin = 40,
	glow = 0.25,
	fade = 0.35,
}
local LONG_FALL: Particles.Layer = {
	texture = Particles.SMOKE,
	rate = 12,
	life = { 0.85, 1 },
	speed = { 4.5, 5.5 },
	spread = 9,
	size = { 0.7, 1.3 },
	lift = -34,
	spin = 40,
	glow = 0.25,
	fade = 0.35,
}
-- The jet at the very top.
local SPOUT: Particles.Layer = {
	texture = Particles.SMOKE,
	rate = 18,
	life = { 0.5, 0.6 },
	speed = { 7, 9 },
	spread = 12,
	size = { 0.4, 0.8 },
	lift = -34,
	spin = 40,
	glow = 0.3,
	fade = 0.3,
}
-- The haze that hangs over the basin.
local MIST: Particles.Layer = {
	texture = Particles.SMOKE,
	rate = 4,
	life = { 2, 3 },
	speed = { 0.5, 1.2 },
	spread = 60,
	size = { 3, 6 },
	lift = 0.3,
	spin = 15,
	glow = 0.2,
	fade = 0.88,
}
-- Petals coming down from a cherry tree.
local PETALS: Particles.Layer = {
	texture = Particles.SMOKE,
	rate = 1.5,
	life = { 5, 7 },
	speed = { 1, 2 },
	down = true,
	spread = 40,
	size = { 0.4, 0.3 },
	lift = -0.2,
	spin = 140,
	glow = 0,
	fade = 0.1,
}

-- Leaves a part in place for the eye only: nothing bumps into it, touches it or finds it with a
-- ray, and the camera, which only backs off from solid parts, ignores it.
local function show<T>(part: T): T
	local base = (part :: any) :: BasePart
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	return part
end

-- An upright cylinder standing on `base`. A cylinder part lies along its X axis, hence the turn.
local function column(
	folder: Folder,
	name: string,
	base: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	local center = base + UP * (height / 2)
	local part =
		Build.part(folder, name, Vector3.new(height, diameter, diameter), center, color, material)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- A block standing on `base`, turned `turn` radians about the upright so that its X side lies
-- along the direction at that angle from the lane's.
local function block(
	folder: Folder,
	name: string,
	size: Vector3,
	base: Vector3,
	turn: number,
	color: Color3,
	material: Enum.Material?
): Part
	local center = base + UP * (size.Y / 2)
	local part = Build.part(folder, name, size, center, color, material)
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, -turn, 0)
	return part
end

-- The level direction at `angle` radians from the lane's, turning towards the right.
local function heading(angle: number): Vector3
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

-- The paving of the whole plaza and the patterns laid into it. Each pattern lies a hair higher
-- than what it crosses, so that no two faces fight for the same plane.
local function buildPaving(folder: Folder)
	local depth, half = PlazaPlan.DEPTH, PlazaPlan.HALF_WIDTH
	local fountain = PlazaPlan.FOUNTAIN
	local middle = -depth / 2
	Build.part(
		folder,
		"Paving",
		Vector3.new(depth, 1, 2 * half),
		Hub.at(middle, -0.5, 0),
		PAVING,
		Enum.Material.Cobblestone
	)

	local slabs = Enum.Material.Pavement
	local function inlay(name: string, size: Vector3, at: Vector3, color: Color3)
		local part = show(Build.part(folder, name, size, at, color, slabs))
		part.CastShadow = false
	end
	inlay("PathAlong", Vector3.new(depth, 0.06, PATH_WIDTH), Hub.at(middle, 0.03, 0), PATH)
	inlay(
		"PathAcross",
		Vector3.new(PATH_WIDTH, 0.07, 2 * half),
		Hub.at(fountain.along, 0.035, 0),
		PATH
	)
	for _, side in { -1, 1 } do
		inlay(
			"Border",
			Vector3.new(depth, 0.09, 3),
			Hub.at(middle, 0.045, side * (half - 1.5)),
			BAND
		)
	end
	-- Round the fountain: a dark ring with a pale one inside it.
	local center = Hub.at(fountain.along, 0, fountain.side)
	local reach = PlazaPlan.FOUNTAIN_RADIUS
	local ring = show(column(folder, "Ring", center, 0.11, 2 * (reach + 15), BAND, slabs))
	ring.CastShadow = false
	local apron = show(column(folder, "Apron", center, 0.14, 2 * (reach + 10), PATH, slabs))
	apron.CastShadow = false
end

-- The fountain: a round basin walled in stone, and in its middle a pillar that carries two
-- bowls, the smaller above the larger, under a gilded ball. Water spouts at the top, runs over
-- the rim of each bowl into the one below and into the basin, and a haze hangs over it.
local function buildFountain(folder: Folder)
	local center = Hub.at(PlazaPlan.FOUNTAIN.along, 0, PlazaPlan.FOUNTAIN.side)
	local reach = PlazaPlan.FOUNTAIN_RADIUS
	local slate = Enum.Material.Slate

	-- The basin's wall: straight pieces set round a circle, each under a wider capstone.
	local chord = 2 * reach * math.tan(math.pi / RIM_SEGMENTS)
	for i = 0, RIM_SEGMENTS - 1 do
		local angle = i * 2 * math.pi / RIM_SEGMENTS
		local base = center + heading(angle) * (reach - RIM / 2)
		block(folder, "Rim", Vector3.new(RIM, RIM_HEIGHT, chord + 0.3), base, angle, STONE, slate)
		block(
			folder,
			"RimCap",
			Vector3.new(RIM + 0.9, 0.5, chord + 0.5),
			base + UP * RIM_HEIGHT,
			angle,
			STONE_DARK,
			slate
		)
	end
	local inner = 2 * (reach - RIM)
	show(column(folder, "BasinFloor", center, 0.3, inner + 0.4, TILE))
	local pool = show(
		column(folder, "Pool", center + UP * 1.7, 0.3, inner + 0.2, WATER, Enum.Material.Glass)
	)
	pool.Transparency = 0.35
	pool.Reflectance = 0.1
	pool.CastShadow = false
	Particles.emitter(MIST, SPRAY).Parent = pool

	-- The pillar and its bowls, from the ground up.
	column(folder, "Foot", center, 3.2, 8, STONE_DARK, slate)
	column(folder, "Shaft", center + UP * 3.2, 5.6, 4.4, STONE, slate)
	column(folder, "Collar", center + UP * 8.8, 1, 11, STONE_DARK, slate)
	column(folder, "Bowl", center + UP * 9.8, 1.5, 18, STONE, slate)
	column(folder, "UpperShaft", center + UP * 11.3, 4.6, 2.8, STONE, slate)
	column(folder, "UpperCollar", center + UP * 15.1, 0.8, 6, STONE_DARK, slate)
	column(folder, "UpperBowl", center + UP * 15.9, 1.2, 9.6, STONE, slate)
	local stem = column(folder, "Stem", center + UP * 17.1, 2.2, 1.2, STONE_DARK, slate)
	local ball = Build.part(
		folder,
		"Finial",
		Vector3.new(2.6, 2.6, 2.6),
		center + UP * 20.4,
		GOLD,
		Enum.Material.Metal
	)
	ball.Shape = Enum.PartType.Ball
	for _, water in { { 11.05, 16.4 }, { 16.9, 8.4 } } do
		local surface = show(
			column(
				folder,
				"Water",
				center + UP * water[1],
				0.3,
				water[2],
				WATER,
				Enum.Material.Glass
			)
		)
		surface.Transparency = 0.35
		surface.CastShadow = false
	end
	Particles.emitter(SPOUT, SPRAY).Parent = stem

	-- Where water leaves a bowl: an unseen piece on its rim, tipped so that what it throws up
	-- sets off outward as well.
	local function lip(at: Vector3, out: Vector3, layer: Particles.Layer)
		local part = show(Build.part(folder, "Lip", Vector3.new(0.4, 0.4, 0.4), at, WATER))
		part.Transparency = 1
		part.CastShadow = false
		local up = (out * 0.55 + UP * 0.83).Unit
		part.CFrame = CFrame.fromMatrix(at, UP:Cross(out), up)
		Particles.emitter(layer, SPRAY).Parent = part
	end
	for i = 0, 5 do
		local out = heading(i * math.pi / 3)
		lip(center + UP * 17 + out * 4.6, out, FALL)
	end
	for i = 0, 7 do
		local out = heading(i * math.pi / 4 + math.pi / 8)
		lip(center + UP * 11.2 + out * 8.8, out, LONG_FALL)
	end
end

-- A lantern post: a wooden post with an arm that reaches `towards` and a paper lantern hanging
-- from it, lit or not.
local function lanternPost(folder: Folder, base: Vector3, towards: Vector3, lit: boolean)
	Build.part(
		folder,
		"LanternPost",
		Vector3.new(0.9, 10, 0.9),
		base + UP * 5,
		TIMBER,
		Enum.Material.Wood
	)
	show(
		Build.part(
			folder,
			"LanternPostCap",
			Vector3.new(1.5, 0.4, 1.5),
			base + UP * 10.2,
			TIMBER,
			Enum.Material.Wood
		)
	)
	local angle = math.atan2(towards.Z, towards.X)
	show(
		block(
			folder,
			"LanternArm",
			Vector3.new(2.4, 0.3, 0.3),
			base + UP * 8.9 + towards * 1.2,
			angle,
			TIMBER,
			Enum.Material.Wood
		)
	)
	local hang = base + UP * 6.8 + towards * 1.9
	local body = show(
		Build.part(folder, "Lantern", Vector3.new(1.3, 1.8, 1.3), hang, LANTERN, Enum.Material.Neon)
	)
	for _, lift in { -1, 1 } do
		show(
			Build.part(
				folder,
				"LanternCap",
				Vector3.new(1.5, 0.25, 1.5),
				hang + UP * lift,
				TIMBER,
				Enum.Material.Wood
			)
		)
	end
	if lit then
		local light = Instance.new("PointLight")
		light.Color = LANTERN
		light.Range = 16
		light.Brightness = 0.7
		light.Shadows = false
		light.Parent = body
	end
end

-- A stone lantern: a foot, a shaft, a table, a small lit house and its roof.
local function stoneLantern(folder: Folder, base: Vector3)
	local slate = Enum.Material.Slate
	Build.part(folder, "StoneLantern", Vector3.new(3, 0.8, 3), base + UP * 0.4, STONE_DARK, slate)
	column(folder, "StoneLanternShaft", base + UP * 0.8, 3.4, 1.3, STONE, slate)
	show(
		Build.part(
			folder,
			"StoneLanternTable",
			Vector3.new(2.8, 0.5, 2.8),
			base + UP * 4.45,
			STONE_DARK,
			slate
		)
	)
	show(
		Build.part(
			folder,
			"StoneLanternLight",
			Vector3.new(1.6, 1.6, 1.6),
			base + UP * 5.5,
			LANTERN,
			Enum.Material.Neon
		)
	)
	show(
		Build.part(
			folder,
			"StoneLanternRoof",
			Vector3.new(3.4, 0.6, 3.4),
			base + UP * 6.6,
			STONE_DARK,
			slate
		)
	)
	local knob = show(
		Build.part(folder, "StoneLanternKnob", Vector3.new(1, 1, 1), base + UP * 7.3, STONE, slate)
	)
	knob.Shape = Enum.PartType.Ball
end

-- A bench of wood on stone legs, its back to `out` (a level direction) and its seat to the
-- other side.
local function bench(folder: Folder, base: Vector3, out: Vector3)
	local angle = math.atan2(out.Z, out.X)
	local across = UP:Cross(out)
	for _, end_ in { -3, 3 } do
		block(
			folder,
			"BenchLeg",
			Vector3.new(1.8, 1.5, 0.8),
			base + across * end_,
			angle,
			STONE_DARK,
			Enum.Material.Slate
		)
	end
	block(
		folder,
		"BenchSeat",
		Vector3.new(2.4, 0.5, 8),
		base + UP * 1.5,
		angle,
		WOOD,
		Enum.Material.WoodPlanks
	)
	show(
		block(
			folder,
			"BenchBack",
			Vector3.new(0.4, 2, 8),
			base + UP * 2 + out * 1,
			angle,
			WOOD,
			Enum.Material.WoodPlanks
		)
	)
end

-- A cherry tree in a stone planter, shedding petals. The planter stands on the grass of an
-- alley, a little below the paving.
local function cherryTree(folder: Folder, base: Vector3)
	Build.part(
		folder,
		"Planter",
		Vector3.new(7, 2, 7),
		base + UP * 0.9,
		STONE_DARK,
		Enum.Material.Slate
	)
	show(
		Build.part(
			folder,
			"PlanterSoil",
			Vector3.new(6, 0.3, 6),
			base + UP * 1.95,
			SOIL,
			Enum.Material.Ground
		)
	)
	column(folder, "CherryTrunk", base + UP * 1.9, 9, 1.6, BARK, Enum.Material.Wood)
	local top = base + UP * 13.5
	local function crown(size: number, offset: Vector3, color: Color3): Part
		local leaves = show(
			Build.part(
				folder,
				"CherryCrown",
				Vector3.new(size, size, size),
				top + offset,
				color,
				Enum.Material.Grass
			)
		)
		leaves.Shape = Enum.PartType.Ball
		return leaves
	end
	Particles.emitter(PETALS, BLOSSOM).Parent = crown(11, Vector3.zero, BLOSSOM)
	crown(8, Vector3.new(3.4, -1.6, 2), BLOSSOM_DEEP)
	crown(8, Vector3.new(-3, -1.2, -2.6), BLOSSOM)
end

-- The red gate at the back of the plaza, over the middle path: two pillars on stone feet, two
-- beams across them and a third between.
local function buildGate(folder: Folder)
	local along = -PlazaPlan.DEPTH + 6
	local wood = Enum.Material.Wood
	for _, side in { -1, 1 } do
		local base = Hub.at(along, 0, side * 13)
		column(folder, "GatePillar", base, 17, 2, LACQUER, wood)
		Build.part(
			folder,
			"GateFoot",
			Vector3.new(3.2, 1, 3.2),
			base + UP * 0.5,
			STONE_DARK,
			Enum.Material.Slate
		)
	end
	show(
		Build.part(
			folder,
			"GateBeam",
			Vector3.new(2.2, 1.6, 34),
			Hub.at(along, 17.2, 0),
			LACQUER,
			wood
		)
	)
	show(
		Build.part(folder, "GateCap", Vector3.new(3, 0.6, 37), Hub.at(along, 18.3, 0), TIMBER, wood)
	)
	show(
		Build.part(
			folder,
			"GateTie",
			Vector3.new(1.4, 1.2, 29),
			Hub.at(along, 13, 0),
			LACQUER,
			wood
		)
	)
end

function Plaza.start()
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"

	buildPaving(folder)
	buildFountain(folder)
	buildGate(folder)

	local fountain = PlazaPlan.FOUNTAIN
	local center = Hub.at(fountain.along, 0, fountain.side)
	-- Round the fountain: benches between the stalls, facing the water and clear of both
	-- paths, and four lit lanterns on posts.
	for _, turn in { 60, 150, 210, 300 } do
		local out = heading(math.rad(turn))
		bench(folder, center + out * (PlazaPlan.FOUNTAIN_RADIUS + 13), out)
	end
	for _, turn in { 45, 135, 225, 315 } do
		local out = heading(math.rad(turn))
		lanternPost(folder, center + out * (PlazaPlan.FOUNTAIN_RADIUS + 9), -out, true)
	end

	-- Lantern posts along the middle path, either side of it, clear of the fountain's ring.
	local edge = PATH_WIDTH / 2 + 2
	for _, along in { -22, -50, -PlazaPlan.DEPTH + 50, -PlazaPlan.DEPTH + 22 } do
		for _, side in { -1, 1 } do
			lanternPost(folder, Hub.at(along, 0, side * edge), Vector3.new(0, 0, -side), false)
		end
	end

	-- A cherry tree in every alley beside the dojos: between one dojo and the next, and at
	-- both ends of each row. They stand well back from the plaza: a dojo's staircase starts at
	-- the mouth of the alley on its lane side, and the way onto it has to stay open.
	local out = PlazaPlan.HALF_WIDTH + 22
	local alleys = { -PlazaPlan.FRONT_GAP / 2 - 1, -PlazaPlan.DEPTH + PlazaPlan.BACK_GAP / 2 + 1 }
	for pair = 1, PlazaPlan.PER_SIDE - 1 do
		local dojo = PlazaPlan.dojo(pair * 2)
		table.insert(alleys, dojo.along - (PlazaPlan.PITCH / 2))
	end
	for _, along in alleys do
		for _, side in { -1, 1 } do
			-- The alleys are grass, which lies a hair below the paving.
			cherryTree(folder, Hub.at(along, -0.1, side * out))
		end
	end

	-- Stone lanterns: either side of the lane's start, either side of the gate, and where the
	-- cross path meets the dojos.
	for _, side in { -1, 1 } do
		stoneLantern(folder, Hub.at(-8, 0, side * (Hub.LANE_WIDTH / 2 + 10)))
		stoneLantern(folder, Hub.at(-PlazaPlan.DEPTH + 8, 0, side * 24))
		for _, shift in { -1, 1 } do
			stoneLantern(
				folder,
				Hub.at(fountain.along + shift * (edge + 1), 0, side * (PlazaPlan.HALF_WIDTH - 8))
			)
		end
	end

	folder.Parent = Workspace
end

return Plaza
