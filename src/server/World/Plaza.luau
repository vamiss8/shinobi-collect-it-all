--!strict
-- The plaza behind the throwing strip, where players appear: paving with a path down its middle
-- to the lane and another across it from dojo to dojo, and where they cross a fountain of three
-- bowls. Round the fountain stand benches and lit lanterns; along the middle path, lantern
-- posts; in the alleys between the dojos, cherry trees that shed their petals; before every
-- dojo, a pair of stone lanterns and planters of shrubs; at the back, a red gate; and in the
-- plaza's four quarters a notice board, a training corner, a well and a small shrine.
-- Logic/PlazaPlan says where things stand; the dojos are World/Plots's and the stalls
-- World/Market's.
--
-- Unlike the zones' scenery (World/ZoneArt) this is ground that players walk on: the paving,
-- the fountain's rim and bowls, the benches, posts, lanterns, planters and trunks are solid,
-- and can be stood on. What is only for the eye, the water, the leaves and the patterns laid
-- into the paving, nothing bumps into.
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
local TILE = Color3.fromRGB(58, 118, 150)
local DEEP = Color3.fromRGB(52, 132, 176)
local WATER = Color3.fromRGB(120, 205, 240)
local SPRAY = Color3.fromRGB(214, 240, 252)
local FOAM = Color3.fromRGB(240, 250, 255)
local GOLD = Color3.fromRGB(255, 202, 40)
local RIM = 1.8 -- thickness of the basin's wall
local RIM_HEIGHT = 2.6
local RIM_SEGMENTS = 20
local POOL = 2.25 -- how high the water stands in the basin
-- Wood, cloth and leaves.
local TIMBER = Color3.fromRGB(62, 44, 36)
local WOOD = Color3.fromRGB(121, 85, 61)
local PALE_WOOD = Color3.fromRGB(188, 158, 130)
local LACQUER = Color3.fromRGB(183, 40, 32)
local LANTERN = Color3.fromRGB(255, 190, 110)
local PAPER = Color3.fromRGB(236, 220, 188)
local STRAW = Color3.fromRGB(214, 186, 120)
local BARK = Color3.fromRGB(109, 76, 65)
local LEAF = Color3.fromRGB(104, 159, 56)
local LEAF_LIGHT = Color3.fromRGB(156, 204, 101)
local BLOSSOM = Color3.fromRGB(248, 187, 208)
local BLOSSOM_DEEP = Color3.fromRGB(244, 143, 177)
local SOIL = Color3.fromRGB(92, 70, 52)
-- How tall a lantern post stands. Its lantern is solid and hangs over the edge of a path, so
-- it hangs clear of the tallest player's head: a character is five to seven studs tall, and
-- the lantern's foot is four under the post's top.
local POST = 12

-- Drops leaving a bowl with its water: they set off up and outward and fall with the stream.
-- The pull down and the life are matched to how far each has to fall.
local DROPS: Particles.Layer = {
	texture = Particles.SPARKLE,
	rate = 7,
	life = { 0.7, 0.85 },
	speed = { 4.5, 5.5 },
	spread = 14,
	size = { 0.35, 0.2 },
	lift = -34,
	spin = 90,
	glow = 0.5,
	fade = 0.15,
}
local LONG_DROPS: Particles.Layer = {
	texture = Particles.SPARKLE,
	rate = 7,
	life = { 0.85, 1 },
	speed = { 4.5, 5.5 },
	spread = 14,
	size = { 0.4, 0.2 },
	lift = -34,
	spin = 90,
	glow = 0.5,
	fade = 0.15,
}
-- Where water strikes water: the pool glitters all over, and a haze hangs on it.
local SPLASH: Particles.Layer = {
	texture = Particles.SPARKLE,
	rate = 26,
	life = { 0.35, 0.6 },
	speed = { 2, 5 },
	spread = 35,
	size = { 0.4, 0.1 },
	lift = -20,
	spin = 120,
	glow = 0.6,
	fade = 0.1,
}
local MIST: Particles.Layer = {
	texture = Particles.SMOKE,
	rate = 5,
	life = { 2, 3 },
	speed = { 0.6, 1.4 },
	spread = 50,
	size = { 3, 7 },
	lift = 0.3,
	spin = 15,
	glow = 0.2,
	fade = 0.9,
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

-- A small pitched roof, solid from every side: two wedges back to back under a ridge whose
-- middle is `ridge`. It is `length` along the ridge and `reach` out to each side, and falls
-- `rise`. The ridge runs down the lane unless `across`. (A wedge's tall side is its back.)
local function roof(
	folder: Folder,
	ridge: Vector3,
	length: number,
	reach: number,
	rise: number,
	across: boolean,
	color: Color3
)
	for _, side in { -1, 1 } do
		local out, turn
		if across then
			out = Vector3.new(side * reach / 2, -rise / 2, 0)
			turn = -side * math.pi / 2
		else
			out = Vector3.new(0, -rise / 2, side * reach / 2)
			turn = if side == 1 then math.pi else 0
		end
		local part = Instance.new("WedgePart")
		part.Name = "Roof"
		part.Anchored = true
		part.Size = Vector3.new(length, rise, reach)
		part.CFrame = CFrame.new(ridge + out) * CFrame.Angles(0, turn, 0)
		part.Color = color
		part.Material = Enum.Material.Slate
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = folder
	end
end

-- The level direction at `angle` radians from the lane's, turning towards the right.
local function heading(angle: number): Vector3
	return Vector3.new(math.cos(angle), 0, math.sin(angle))
end

-- A unit direction square to `direction`.
local function squareTo(direction: Vector3): Vector3
	local side = direction:Cross(UP)
	if side.Magnitude < 1e-3 then
		side = Vector3.new(1, 0, 0)
	end
	return side.Unit
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
	-- The path across stops at the bands along the plaza's edges.
	inlay(
		"PathAcross",
		Vector3.new(PATH_WIDTH, 0.07, 2 * half - 6),
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

-- The fountain: a round basin walled in stone and full of water, and in its middle a pillar
-- that carries two bowls, the smaller above the larger, under a gilded ball. Water springs
-- from under the ball into the upper bowl, pours over the rim of each bowl into what lies
-- below, and a ring of jets round the basin throws it in arcs back towards the pillar; the
-- pool glitters where it all comes down, and a haze hangs over it.
--
-- The streams are Beams: ribbons that turn to face whoever looks, bent along a curve. A beam
-- leaves its first end along that end's own right-hand side and comes into its second end
-- along that end's, which is how every stream below is given its arc.
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

	-- Still water, one sheet of it: a darker body with a bright, half-clear skin on top.
	-- (Not of Glass: whatever is see-through and behind glass is not drawn at all.)
	local function sheet(base: Vector3, depth: number, diameter: number)
		if depth > 0.5 then
			local body = show(column(folder, "WaterBody", base, depth - 0.3, diameter, DEEP))
			body.Transparency = 0.1
			body.CastShadow = false
		end
		local skin =
			show(column(folder, "WaterSkin", base + UP * (depth - 0.3), 0.3, diameter, WATER))
		skin.Transparency = 0.4
		skin.Reflectance = 0.25
		skin.CastShadow = false
	end
	local inner = 2 * (reach - RIM)
	show(column(folder, "BasinFloor", center, 0.3, inner + 0.4, TILE))
	sheet(center + UP * 0.3, POOL - 0.3, inner + 0.2)
	-- Foam where the water comes down: round the pillar's foot, and under every fall.
	local function foam(at: Vector3, diameter: number)
		local patch = show(column(folder, "Foam", at, 0.05, diameter, FOAM))
		patch.Transparency = 0.5
		patch.CastShadow = false
	end
	foam(center + UP * POOL, 14)

	-- The pillar and its bowls, from the ground up.
	column(folder, "Foot", center, 3.2, 8, STONE_DARK, slate)
	column(folder, "Shaft", center + UP * 3.2, 5.6, 4.4, STONE, slate)
	column(folder, "Collar", center + UP * 8.8, 1, 11, STONE_DARK, slate)
	column(folder, "Bowl", center + UP * 9.8, 1.5, 18, STONE, slate)
	column(folder, "UpperShaft", center + UP * 11.3, 4.6, 2.8, STONE, slate)
	column(folder, "UpperCollar", center + UP * 15.1, 0.8, 6, STONE_DARK, slate)
	column(folder, "UpperBowl", center + UP * 15.9, 1.2, 9.6, STONE, slate)
	column(folder, "Stem", center + UP * 17.1, 2.2, 1.2, STONE_DARK, slate)
	local ball = Build.part(
		folder,
		"Finial",
		Vector3.new(2.6, 2.6, 2.6),
		center + UP * 20.4,
		GOLD,
		Enum.Material.Metal
	)
	ball.Shape = Enum.PartType.Ball
	sheet(center + UP * 11.05, 0.35, 16.4)
	sheet(center + UP * 16.9, 0.35, 8.4)

	-- Every stream hangs from one unseen piece at the fountain's foot, so that a stream's ends
	-- can be given from there.
	local hold = show(Build.part(folder, "Streams", Vector3.new(1, 1, 1), center, WATER))
	hold.Transparency = 1
	hold.CastShadow = false
	local function tip(at: Vector3, along: Vector3): Attachment
		local attachment = Instance.new("Attachment")
		attachment.CFrame = CFrame.fromMatrix(at, along, squareTo(along))
		attachment.Parent = hold
		return attachment
	end
	-- A stream from `from`, which it leaves along `leave`, to `to`, where it arrives along
	-- `arrive`; `bend` is how far it carries on each way before turning, `width` how thick it
	-- is at each end. Points are from the fountain's foot.
	local function stream(
		from: Vector3,
		leave: Vector3,
		to: Vector3,
		arrive: Vector3,
		bend: { number },
		width: { number }
	)
		local beam = Instance.new("Beam")
		beam.Attachment0 = tip(from, leave.Unit)
		beam.Attachment1 = tip(to, arrive.Unit)
		beam.CurveSize0 = bend[1]
		beam.CurveSize1 = bend[2]
		beam.Segments = 16
		beam.FaceCamera = true
		beam.Width0 = width[1]
		beam.Width1 = width[2]
		beam.Color = ColorSequence.new(SPRAY, WATER)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.75, 0.35),
			NumberSequenceKeypoint.new(1, 0.75),
		})
		beam.LightEmission = 0.3
		beam.LightInfluence = 0.5
		beam.Parent = hold
	end
	-- Where drops leave a bowl's rim: an unseen piece tipped so that what it throws up sets
	-- off outward as well.
	local function lip(at: Vector3, out: Vector3, layer: Particles.Layer)
		local part = show(Build.part(folder, "Lip", Vector3.new(0.4, 0.4, 0.4), at, WATER))
		part.Transparency = 1
		part.CastShadow = false
		local up = (out * 0.55 + UP * 0.83).Unit
		part.CFrame = CFrame.fromMatrix(at, UP:Cross(out), up)
		Particles.emitter(layer, FOAM).Parent = part
	end

	-- From under the ball into the upper bowl.
	for i = 0, 5 do
		local out = heading(i * math.pi / 3 + 0.3)
		stream(
			UP * 19.2 + out * 0.5,
			out * 0.55 + UP * 0.84,
			UP * 17.2 + out * 3.4,
			-UP,
			{ 2.4, 1.4 },
			{ 0.4, 0.6 }
		)
	end
	-- Over the upper bowl's rim into the lower bowl.
	for i = 0, 9 do
		local out = heading(i * math.pi / 5)
		stream(
			UP * 17.05 + out * 4.7,
			out * 0.9 + UP * 0.44,
			UP * 11.4 + out * 7.3,
			-UP,
			{ 2.1, 3.4 },
			{ 0.9, 1.2 }
		)
		if i % 2 == 0 then
			lip(center + UP * 17 + out * 4.6, out, DROPS)
		end
	end
	-- Over the lower bowl's rim into the pool, a patch of foam under each fall.
	for i = 0, 15 do
		local out = heading(i * math.pi / 8 + math.pi / 16)
		stream(
			UP * 11.25 + out * 8.9,
			out * 0.9 + UP * 0.44,
			UP * (POOL + 0.05) + out * 12.4,
			-UP,
			{ 2.6, 5.4 },
			{ 1.2, 1.7 }
		)
		foam(center + UP * POOL + out * 12.4, 2.6)
		if i % 2 == 0 then
			lip(center + UP * 11.2 + out * 8.8, out, LONG_DROPS)
		end
	end
	-- A ring of jets from nozzles inside the wall, arcing in over the pool towards the pillar.
	for i = 0, 11 do
		local out = heading(i * math.pi / 6 + math.pi / 12)
		column(folder, "Nozzle", center + UP * 0.3 + out * 14.4, 2.3, 0.9, STONE_DARK, slate)
		stream(
			UP * 2.6 + out * 14.4,
			UP * 0.9 - out * 0.42,
			UP * (POOL + 0.05) + out * 6.2,
			-UP * 0.9 - out * 0.42,
			{ 8.5, 8.5 },
			{ 0.5, 0.35 }
		)
	end

	-- The pool glitters and steams from an unseen slab lying on it, level, so that what it
	-- gives off rises.
	local surface = show(
		Build.part(folder, "Surface", Vector3.new(22, 0.2, 22), center + UP * (POOL + 0.1), WATER)
	)
	surface.Transparency = 1
	surface.CastShadow = false
	Particles.emitter(SPLASH, FOAM).Parent = surface
	Particles.emitter(MIST, SPRAY).Parent = surface
end

-- A lantern post: a wooden post with an arm that reaches `towards`, braced from below, and a
-- paper lantern hanging from the arm's end on a cord, lit or not. The post, its arm and the
-- lantern are solid: a player who jumps touches the lantern. Only the thin pieces are not,
-- the brace, the cord and the tassel, which would catch on nothing but annoy.
local function lanternPost(folder: Folder, base: Vector3, towards: Vector3, lit: boolean)
	local wood = Enum.Material.Wood
	Build.part(
		folder,
		"LanternPost",
		Vector3.new(0.9, POST, 0.9),
		base + UP * (POST / 2),
		TIMBER,
		wood
	)
	Build.part(
		folder,
		"LanternPostCap",
		Vector3.new(1.5, 0.4, 1.5),
		base + UP * (POST + 0.2),
		TIMBER,
		wood
	)
	local angle = math.atan2(towards.Z, towards.X)
	block(
		folder,
		"LanternArm",
		Vector3.new(3, 0.45, 0.45),
		base + UP * (POST - 1.15) + towards * 1.5,
		angle,
		TIMBER,
		wood
	)
	-- The brace: from the post up to the arm, halfway along it.
	local low = base + UP * (POST - 2.6) + towards * 0.3
	local high = base + UP * (POST - 1.1) + towards * 1.7
	local brace = show(
		Build.part(
			folder,
			"LanternBrace",
			Vector3.new((high - low).Magnitude, 0.3, 0.3),
			(low + high) / 2,
			TIMBER,
			wood
		)
	)
	brace.CFrame = CFrame.fromMatrix((low + high) / 2, (high - low).Unit, squareTo(high - low))

	-- The lantern hangs under the arm's end, cord and all.
	local hang = base + towards * 2.4
	show(
		Build.part(
			folder,
			"LanternCord",
			Vector3.new(0.14, 0.7, 0.14),
			hang + UP * (POST - 1.5),
			TIMBER
		)
	)
	local body = Build.part(
		folder,
		"Lantern",
		Vector3.new(1.3, 1.8, 1.3),
		hang + UP * (POST - 3),
		LANTERN,
		Enum.Material.Neon
	)
	for _, under in { 4.02, 1.98 } do
		Build.part(
			folder,
			"LanternCap",
			Vector3.new(1.5, 0.25, 1.5),
			hang + UP * (POST - under),
			TIMBER,
			wood
		)
	end
	show(
		Build.part(
			folder,
			"LanternTassel",
			Vector3.new(0.16, 0.7, 0.16),
			hang + UP * (POST - 4.5),
			LACQUER
		)
	)
	if lit then
		local light = Instance.new("PointLight")
		light.Color = LANTERN
		light.Range = 18
		light.Brightness = 0.7
		light.Shadows = false
		light.Parent = body
	end
end

-- A stone lantern: a foot, a shaft, a table, a small lit house, its roof and a knob on top.
-- Solid from foot to knob: at first only the foot and the shaft were, and a player walked
-- through the rest.
local function stoneLantern(folder: Folder, base: Vector3)
	local slate = Enum.Material.Slate
	Build.part(folder, "StoneLantern", Vector3.new(3, 0.8, 3), base + UP * 0.4, STONE_DARK, slate)
	column(folder, "StoneLanternShaft", base + UP * 0.8, 3.4, 1.3, STONE, slate)
	Build.part(
		folder,
		"StoneLanternTable",
		Vector3.new(2.8, 0.5, 2.8),
		base + UP * 4.45,
		STONE_DARK,
		slate
	)
	Build.part(
		folder,
		"StoneLanternLight",
		Vector3.new(1.6, 1.6, 1.6),
		base + UP * 5.5,
		LANTERN,
		Enum.Material.Neon
	)
	Build.part(
		folder,
		"StoneLanternRoof",
		Vector3.new(3.4, 0.6, 3.4),
		base + UP * 6.6,
		STONE_DARK,
		slate
	)
	local knob =
		Build.part(folder, "StoneLanternKnob", Vector3.new(1, 1, 1), base + UP * 7.3, STONE, slate)
	knob.Shape = Enum.PartType.Ball
end

-- A bench of wood on stone legs, its back to `out` (a level direction) and its seat to the
-- other side. All of it is solid: it can be stood on, back and all.
local function bench(folder: Folder, base: Vector3, out: Vector3)
	local angle = math.atan2(out.Z, out.X)
	local across = UP:Cross(out)
	for _, along in { -3, 3 } do
		block(
			folder,
			"BenchLeg",
			Vector3.new(1.8, 1.5, 0.8),
			base + across * along,
			angle,
			STONE_DARK,
			Enum.Material.Slate
		)
		-- An upright of the back at each end, from the seat up.
		block(
			folder,
			"BenchUpright",
			Vector3.new(0.5, 2.4, 0.5),
			base + UP * 2 + out * 1.05 + across * along * 1.2,
			angle,
			TIMBER,
			Enum.Material.Wood
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
	for _, y in { 2.5, 3.5 } do
		block(
			folder,
			"BenchBack",
			Vector3.new(0.6, 0.8, 8),
			base + UP * y + out * 1.05,
			angle,
			WOOD,
			Enum.Material.WoodPlanks
		)
	end
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

-- A low stone planter with three shrubs in it.
local function shrubs(folder: Folder, base: Vector3)
	Build.part(
		folder,
		"Shrubbery",
		Vector3.new(6, 1.4, 3),
		base + UP * 0.7,
		STONE_DARK,
		Enum.Material.Slate
	)
	for i, shift in { -1.6, 0.2, 1.8 } do
		local size = 2.4 + (i % 2) * 0.6
		local bush = show(
			Build.part(
				folder,
				"Shrub",
				Vector3.new(size, size, size),
				base + UP * (1.5 + size * 0.3) + Vector3.new(shift, 0, 0),
				if i == 2 then LEAF_LIGHT else LEAF,
				Enum.Material.Grass
			)
		)
		bush.Shape = Enum.PartType.Ball
	end
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

-- The notice board: a board of jobs between two posts under a little roof, papers pinned to
-- the side that looks at the middle path, which is the way `face` points across the plaza.
local function noticeBoard(folder: Folder, base: Vector3, face: number)
	local wood = Enum.Material.Wood
	for _, x in { -4.4, 4.4 } do
		Build.part(
			folder,
			"NoticePost",
			Vector3.new(0.7, 7.4, 0.7),
			base + Vector3.new(x, 3.7, 0),
			TIMBER,
			wood
		)
	end
	Build.part(
		folder,
		"NoticeBoard",
		Vector3.new(8.2, 4.2, 0.5),
		base + UP * 4.6,
		WOOD,
		Enum.Material.WoodPlanks
	)
	roof(folder, base + UP * 8.6, 10.6, 1.8, 1.2, false, LACQUER)
	local papers = {
		{ -2.9, 5.3, 1.5, 1.9 },
		{ -1, 4.9, 1.6, 2.1 },
		{ 0.9, 5.5, 1.4, 1.7 },
		{ 2.8, 5, 1.7, 2.2 },
		{ -2, 3.4, 1.4, 1.2 },
		{ 1.8, 3.3, 1.9, 1.3 },
	}
	for index, paper in papers do
		local at = base + Vector3.new(paper[1], paper[2], face * 0.3)
		show(Build.part(folder, "Notice", Vector3.new(paper[3], paper[4], 0.1), at, PAPER))
		if index % 2 == 0 then
			show(
				Build.part(
					folder,
					"NoticeSeal",
					Vector3.new(0.5, 0.5, 0.12),
					at + Vector3.new(paper[3] / 2 - 0.5, -paper[4] / 2 + 0.5, face * 0.02),
					LACQUER
				)
			)
		end
	end
end

-- The training corner: three posts with a red band, a straw dummy and a target on a stand.
local function trainingCorner(folder: Folder, base: Vector3, face: number)
	local wood = Enum.Material.Wood
	for i = -1, 1 do
		local foot = base + Vector3.new(i * 6, 0, 0)
		column(folder, "TrainingPost", foot, 6.4, 1.6, BARK, wood)
		show(
			column(folder, "TrainingBand", foot + UP * 4.2, 0.8, 1.8, LACQUER, Enum.Material.Fabric)
		)
	end
	-- The dummy: a post, arms across it, a body of straw and a head.
	local dummy = base + Vector3.new(-7, 0, face * 8)
	Build.part(folder, "DummyPost", Vector3.new(0.7, 5.2, 0.7), dummy + UP * 2.6, BARK, wood)
	Build.part(folder, "DummyArms", Vector3.new(4.2, 0.5, 0.5), dummy + UP * 4, BARK, wood)
	column(folder, "DummyBody", dummy + UP * 1.6, 2.8, 1.8, STRAW, Enum.Material.Fabric)
	local head = Build.part(
		folder,
		"DummyHead",
		Vector3.new(1.7, 1.7, 1.7),
		dummy + UP * 5.9,
		STRAW,
		Enum.Material.Fabric
	)
	head.Shape = Enum.PartType.Ball
	-- The target: a board on a post, rings painted on the side that looks at the posts.
	local target = base + Vector3.new(7, 0, face * 8)
	Build.part(folder, "TargetPost", Vector3.new(0.7, 4, 0.7), target + UP * 2, BARK, wood)
	Build.part(
		folder,
		"TargetBoard",
		Vector3.new(4.4, 4.4, 0.5),
		target + UP * 5.6,
		PALE_WOOD,
		wood
	)
	for index, ring in { 3.4, 2, 0.8 } do
		local disc = show(
			Build.part(
				folder,
				"TargetRing",
				Vector3.new(0.1, ring, ring),
				target + UP * 5.6 + Vector3.new(0, 0, -face * (0.26 + index * 0.02)),
				if index % 2 == 1 then LACQUER else PAPER
			)
		)
		disc.Shape = Enum.PartType.Cylinder
		-- A cylinder lies along its X axis; this turns its round face across the plaza.
		disc.CFrame = CFrame.new(disc.Position) * CFrame.Angles(0, math.rad(90), 0)
	end
end

-- The well: a ring of stone with dark water in it, two posts, a roof and a bucket on a rope.
-- All but the water and the rope is solid.
local function well(folder: Folder, base: Vector3)
	local wood = Enum.Material.Wood
	column(folder, "Well", base, 2.8, 7, STONE, Enum.Material.Slate)
	column(folder, "WellRim", base + UP * 2.8, 0.3, 7.6, STONE_DARK, Enum.Material.Slate)
	show(column(folder, "WellWater", base + UP * 3.1, 0.06, 5.2, DEEP))
	for _, x in { -3.9, 3.9 } do
		Build.part(
			folder,
			"WellPost",
			Vector3.new(0.6, 8, 0.6),
			base + Vector3.new(x, 4, 0),
			TIMBER,
			wood
		)
	end
	Build.part(folder, "WellBar", Vector3.new(8.6, 0.5, 0.5), base + UP * 7.4, TIMBER, wood)
	roof(folder, base + UP * 10.2, 10.4, 3, 2, false, LACQUER)
	show(Build.part(folder, "WellRope", Vector3.new(0.14, 2.4, 0.14), base + UP * 6, PAPER))
	column(folder, "WellBucket", base + UP * 3.6, 1.3, 1.5, WOOD, wood)
end

-- A small shrine: a little house of dark wood under a red roof on a base of stone, its door
-- to the middle path (the way `face` points across the plaza), and a gate of its own before it.
local function shrine(folder: Folder, base: Vector3, face: number)
	local wood = Enum.Material.Wood
	Build.part(
		folder,
		"ShrineBase",
		Vector3.new(6, 1.8, 6),
		base + UP * 0.9,
		STONE_DARK,
		Enum.Material.Slate
	)
	Build.part(
		folder,
		"ShrineStep",
		Vector3.new(4, 0.9, 1.6),
		base + Vector3.new(0, 0.45, face * 3.6),
		STONE,
		Enum.Material.Slate
	)
	Build.part(folder, "ShrineHouse", Vector3.new(4, 3.6, 4), base + UP * 3.6, TIMBER, wood)
	show(
		Build.part(
			folder,
			"ShrineDoor",
			Vector3.new(2, 2.4, 0.2),
			base + Vector3.new(0, 3.2, face * 2.05),
			PAPER
		)
	)
	roof(folder, base + UP * 7.4, 6.4, 3.2, 2, false, LACQUER)
	Build.part(folder, "ShrineRidge", Vector3.new(6.8, 0.4, 0.5), base + UP * 7.5, TIMBER, wood)
	-- Its gate, a few steps out.
	local gate = base + Vector3.new(0, 0, face * 7.5)
	for _, x in { -2.4, 2.4 } do
		column(folder, "ShrineGatePost", gate + Vector3.new(x, 0, 0), 5, 0.6, LACQUER, wood)
	end
	show(
		Build.part(
			folder,
			"ShrineGateBeam",
			Vector3.new(6.6, 0.5, 0.7),
			gate + UP * 5.1,
			LACQUER,
			wood
		)
	)
	show(
		Build.part(
			folder,
			"ShrineGateTie",
			Vector3.new(5.4, 0.4, 0.4),
			gate + UP * 4,
			LACQUER,
			wood
		)
	)
end

-- Barrels and a crate set down beside a stall, at `base`.
local function goods(folder: Folder, base: Vector3)
	local wood = Enum.Material.Wood
	column(folder, "Barrel", base, 2.6, 2.2, WOOD, wood)
	column(folder, "Barrel", base + Vector3.new(2.3, 0, 1.2), 2.6, 2.2, BARK, wood)
	Build.part(
		folder,
		"Crate",
		Vector3.new(2.4, 2.4, 2.4),
		base + Vector3.new(0.6, 1.2, -2.5),
		PALE_WOOD,
		Enum.Material.WoodPlanks
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

	-- Before every dojo: a pair of stone lanterns either side of its middle, and beyond them
	-- two planters of shrubs, short of the end its staircase starts at.
	for index = 1, PlazaPlan.DOJOS do
		local dojo = PlazaPlan.dojo(index)
		for _, shift in { -1, 1 } do
			stoneLantern(
				folder,
				Hub.at(dojo.along + shift * (edge + 1), 0, dojo.side * (PlazaPlan.HALF_WIDTH - 8))
			)
		end
		for _, shift in { -22, 20 } do
			shrubs(folder, Hub.at(dojo.along + shift, 0, dojo.side * (PlazaPlan.HALF_WIDTH - 4)))
		end
	end
	-- Stone lanterns either side of the lane's start and of the gate at the back.
	for _, side in { -1, 1 } do
		stoneLantern(folder, Hub.at(-8, 0, side * (Hub.LANE_WIDTH / 2 + 10)))
		stoneLantern(folder, Hub.at(-PlazaPlan.DEPTH + 8, 0, side * 24))
	end

	-- The plaza's four quarters, between the paths: the notice board and the training corner
	-- on the lane's side, the well and the shrine at the back.
	local near, far = -40, -PlazaPlan.DEPTH + 42
	noticeBoard(folder, Hub.at(near, 0, -36), 1)
	trainingCorner(folder, Hub.at(near - 2, 0, 30), 1)
	well(folder, Hub.at(far, 0, -36))
	shrine(folder, Hub.at(far, 0, 40), -1)

	-- Goods set down beside each stall: on whichever side of it lies farther from both paths.
	for _, spot in PlazaPlan.stalls do
		local away = Vector3.new(spot.along - fountain.along, 0, spot.side - fountain.side).Unit
		local beside = UP:Cross(away)
		local best: Vector3? = nil
		local clear = -1
		for _, way in { 1, -1 } do
			local at = Vector3.new(spot.along, 0, spot.side) + beside * way * 11 + away * 1.5
			local off = math.min(math.abs(at.Z - fountain.side), math.abs(at.X - fountain.along))
			if off > clear then
				best, clear = at, off
			end
		end
		if best then
			goods(folder, Hub.at(best.X, 0, best.Z))
		end
	end

	folder.Parent = Workspace
end

return Plaza
