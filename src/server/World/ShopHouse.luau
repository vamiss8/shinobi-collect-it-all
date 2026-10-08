--!strict
-- The house the market's shops are built in (World/TentenShop, World/MissionDesk): a small
-- Konoha house on a stone base, open at the front, under a gable roof whose gable faces the
-- customers with a sign on it. Plaster walls in a timber frame with latticed windows, a counter
-- across the open front under a curtain, behind it a raised floor where the keeper stands, and
-- lanterns at the front and inside. A shop gives its colors and words (Style) and furnishes the
-- house itself with the Kit of shapes that build() hands back.
--
-- A house stands wherever it is put: `place` is the middle of its front on the ground, looking
-- out of the front at the customers. House-local coordinates, in studs: x runs across the
-- front, left to right as a customer sees it; y is height above the ground; z runs inward, from
-- the front (0) to the back (DEPTH).
--
-- The base, walls, posts, counter and roof are solid, and an invisible wall closes the open
-- front: the house is seen into but not walked into. Everything else is only for show.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Net = require(ReplicatedStorage.Shared.Net)

local ShopHouse = {}

local V = Vector3.new
local UP = V(0, 1, 0)

local HALF = 9 -- half the width, to the outer faces of the corner posts
local DEPTH = 12 -- to the outer faces of the back posts
local POST = 1 -- square posts at the corners and halfway along each side
local WALL = 0.6 -- plaster walls, centered in the line of the posts
local BEAM = WALL + 0.2 -- timber beams, standing out a little from the plaster on both faces
local BASE = 0.5 -- top of the stone base, which reaches out in front as a porch
local PORCH = 2
local FLOOR = 0.6 -- top of the floor boards
local EAVE = 9 -- top of the walls
local INNER = HALF - POST -- the inner faces of the posts, and the roof's line over them
local SIDE_WALL = HALF - POST / 2 -- middle of a side wall
local BACK_WALL = DEPTH - POST / 2 -- middle of the back wall
local HEADER = 1.2 -- depth of the beam across the open front

-- The roof's underside rests on the walls at the inner faces of the posts and rises to a ridge
-- running from the front to the back.
local SLOPE = math.tan(math.rad(30))
local RIDGE = EAVE + INNER * SLOPE -- underside of the roof at the ridge
local TILE = 0.8 -- thickness of the roof
local REACH = HALF + 2 -- how far out the eaves reach on each side
local ROOF_FRONT = -2.5
local ROOF_BACK = DEPTH + 1.5

local COUNTER_TOP = 3.6
-- Behind the counter the floor is raised, as in the shops of old; the keeper stands on it.
local STAGE = FLOOR + 1
local STAGE_FRONT = 3.4
local NOREN_BOTTOM = 6.6

ShopHouse.FLOOR = FLOOR
ShopHouse.EAVE = EAVE
ShopHouse.RIDGE = RIDGE
ShopHouse.STAGE = STAGE
ShopHouse.STAGE_FRONT = STAGE_FRONT
ShopHouse.COUNTER_TOP = COUNTER_TOP
ShopHouse.INNER = INNER
-- The inner faces of the side walls (at plus and minus this x) and of the back wall, and the
-- outer face of the back wall.
ShopHouse.SIDE_INSIDE = SIDE_WALL - WALL / 2
ShopHouse.BACK_INSIDE = BACK_WALL - WALL / 2
ShopHouse.BACK_OUTSIDE = BACK_WALL + WALL / 2
-- Where the keeper stands, behind the middle of the counter.
ShopHouse.KEEPER = V(0, STAGE, 4.6)
-- How far from the middle of the counter its prompt can be used, studs: anywhere on the porch
-- in front of it, but not from beside the house.
ShopHouse.REACH = 8

-- Colors the shops share.
ShopHouse.TIMBER = Color3.fromRGB(62, 44, 36)
ShopHouse.WOOD = Color3.fromRGB(121, 85, 61)
ShopHouse.PALE_WOOD = Color3.fromRGB(188, 158, 130)
ShopHouse.PAPER = Color3.fromRGB(236, 220, 188)
ShopHouse.INK = Color3.fromRGB(30, 24, 20)
ShopHouse.GOLD = Color3.fromRGB(255, 202, 40)
ShopHouse.IRON = Color3.fromRGB(70, 70, 74)
ShopHouse.LACQUER = Color3.fromRGB(183, 40, 32)

local TIMBER = ShopHouse.TIMBER
local WOOD = ShopHouse.WOOD
local PALE_WOOD = ShopHouse.PALE_WOOD
local PAPER = ShopHouse.PAPER
local INK = ShopHouse.INK
local GOLD = ShopHouse.GOLD
local FLOOR_WOOD = Color3.fromRGB(150, 108, 74)
local STONE = Color3.fromRGB(150, 145, 138)
local LANTERN = Color3.fromRGB(235, 90, 50)
local LIGHT = Color3.fromRGB(255, 196, 120)
-- How bright a lantern's light is at night, when it is brightest (client Lanterns), and how far
-- the two at the front and the one inside reach. A house is small and its keeper stands three
-- studs from the lantern inside and nine from the two in front: at 0.9 and a reach of 22 and 18
-- the three of them washed the keeper's model out at night. The shades glow as they did; it
-- is the light they throw that is a third of what it was where the keeper stands.
local LANTERN_LIGHT = 0.45
local FRONT_REACH = 15
local INSIDE_REACH = 12

-- What makes one shop's house look unlike another's.
export type Style = {
	name: string, -- of the house's folder
	title: string, -- floating over the roof
	sign: string, -- the characters on the board on the front gable
	plaster: Color3, -- the walls
	tiles: Color3, -- the roof
	ridge: Color3,
	trim: Color3, -- the boards along the edges of the roof
	noren: Color3, -- the curtain over the counter
	cloth: Color3, -- hanging on the front of the counter
}

export type Ring = { diameter: number, color: Color3 }

-- Shapes placed in house-local coordinates, all going into the house's folder.
export type Kit = {
	folder: Folder,
	out: Vector3, -- world direction out of the front
	-- House-local point to world position, and house-local direction to world direction.
	at: (p: Vector3) -> Vector3,
	dir: (d: Vector3) -> Vector3,
	-- A block between two opposite corners, square to the house.
	box: (name: string, a: Vector3, b: Vector3, color: Color3, material: Enum.Material?) -> Part,
	-- A cylinder from `a` to `b`.
	rod: (
		name: string,
		a: Vector3,
		b: Vector3,
		diameter: number,
		color: Color3,
		material: Enum.Material?
	) -> Part,
	-- A round, flat disc on `center`, its faces turned towards `facing` and away from it.
	disc: (
		name: string,
		center: Vector3,
		facing: Vector3,
		diameter: number,
		thick: number,
		color: Color3,
		material: Enum.Material?
	) -> Part,
	-- A block centered on `center`, `size` along the directions `across` (its X), `along` (its
	-- Y) and the one square to both (its Z). The directions are square to each other.
	plate: (
		name: string,
		center: Vector3,
		across: Vector3,
		along: Vector3,
		size: Vector3,
		color: Color3,
		material: Enum.Material?
	) -> Part,
	-- Rings, largest first, each a little thicker than the one around it so it stands proud.
	rings: (name: string, center: Vector3, facing: Vector3, rings: { Ring }) -> (),
	-- A paper lantern hanging on a cord from `hang`, its top at `top`, casting a warm light.
	lantern: (hang: Vector3, top: number, size: number, range: number) -> (),
	-- Stands a figure (pivot at its feet) on `feet`, looking out of the front.
	stand: (figure: Model, feet: Vector3) -> (),
}

-- Leaves a part in place for the eye only: nothing bumps into it, touches it or finds it with
-- a raycast, and the camera, which only backs off from solid parts, ignores it.
function ShopHouse.decor<T>(part: T): T
	local base = (part :: any) :: BasePart
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	return part
end

local decor = ShopHouse.decor

-- The shapes for building into `folder` in the local coordinates of `place` (the middle of a
-- front on the ground, looking out of it), as a house is built. World/TrainingGround builds its
-- yard with them too.
function ShopHouse.kit(folder: Folder, place: CFrame): Kit
	local turn = place.Rotation

	local function at(p: Vector3): Vector3
		return place:PointToWorldSpace(V(-p.X, p.Y, p.Z))
	end

	local function dir(d: Vector3): Vector3
		return place:VectorToWorldSpace(V(-d.X, d.Y, d.Z))
	end

	local function box(
		name: string,
		a: Vector3,
		b: Vector3,
		color: Color3,
		material: Enum.Material?
	): Part
		local size = V(math.abs(b.X - a.X), math.abs(b.Y - a.Y), math.abs(b.Z - a.Z))
		local center = at((a + b) / 2)
		local part = Build.part(folder, name, size, center, color, material)
		part.CFrame = CFrame.new(center) * turn
		return part
	end

	local function rod(
		name: string,
		a: Vector3,
		b: Vector3,
		diameter: number,
		color: Color3,
		material: Enum.Material?
	): Part
		local from, to = at(a), at(b)
		local along = (to - from).Unit
		local other = if math.abs(along.Y) < 0.9 then UP else place.XVector
		local up = (other - along * along:Dot(other)).Unit
		local center = (from + to) / 2
		local size = V((to - from).Magnitude, diameter, diameter)
		local part = Build.part(folder, name, size, center, color, material)
		-- A cylinder lies along its X axis.
		part.Shape = Enum.PartType.Cylinder
		part.CFrame = CFrame.fromMatrix(center, along, up)
		return part
	end

	local function disc(
		name: string,
		center: Vector3,
		facing: Vector3,
		diameter: number,
		thick: number,
		color: Color3,
		material: Enum.Material?
	): Part
		local half = facing.Unit * (thick / 2)
		return rod(name, center - half, center + half, diameter, color, material)
	end

	local function plate(
		name: string,
		center: Vector3,
		across: Vector3,
		along: Vector3,
		size: Vector3,
		color: Color3,
		material: Enum.Material?
	): Part
		local position = at(center)
		local part = Build.part(folder, name, size, position, color, material)
		part.CFrame = CFrame.fromMatrix(position, dir(across).Unit, dir(along).Unit)
		return part
	end

	local function rings(name: string, center: Vector3, facing: Vector3, list: { Ring })
		for i, ring in list do
			local thick = 0.3 + 0.08 * (i - 1)
			decor(disc(name, center, facing, ring.diameter, thick, ring.color))
		end
	end

	local function lantern(hang: Vector3, top: number, size: number, range: number)
		local bottom = top - size * 1.3
		local x, z = hang.X, hang.Z
		local body =
			decor(rod("Lantern", V(x, bottom, z), V(x, top, z), size, LANTERN, Enum.Material.Neon))
		for _, y in { bottom, top } do
			decor(rod("LanternCap", V(x, y - 0.12, z), V(x, y + 0.12, z), size * 0.72, TIMBER))
		end
		decor(rod("LanternCord", V(x, top + 0.12, z), hang, 0.12, TIMBER, Enum.Material.Fabric))
		local light = Instance.new("PointLight")
		light.Color = LIGHT
		light.Range = range
		light.Brightness = LANTERN_LIGHT
		light.Parent = body
		-- The evening lights it and the morning dims it, with the rest of the village's.
		body:AddTag(Net.LANTERN_TAG)
	end

	local function stand(figure: Model, feet: Vector3)
		local position = at(feet)
		figure:PivotTo(CFrame.lookAt(position, position + place.LookVector))
		figure.Parent = folder
	end

	return {
		folder = folder,
		out = place.LookVector,
		at = at,
		dir = dir,
		box = box,
		rod = rod,
		disc = disc,
		plate = plate,
		rings = rings,
		lantern = lantern,
		stand = stand,
	}
end

-- How high the underside of the roof is at x.
function ShopHouse.roofAt(x: number): number
	return RIDGE - math.abs(x) * SLOPE
end

local roofAt = ShopHouse.roofAt

-- A slab along a slope of the roof: its underside runs from `from` to `to` (their z is
-- ignored) and it reaches from `z0` to `z1`, `thick` thick.
local function slab(
	kit: Kit,
	name: string,
	from: Vector3,
	to: Vector3,
	z0: number,
	z1: number,
	thick: number,
	color: Color3,
	material: Enum.Material?
): Part
	local z = (z0 + z1) / 2
	local a, b = kit.at(V(from.X, from.Y, z)), kit.at(V(to.X, to.Y, z))
	local along = (b - a).Unit
	local across = kit.dir(V(0, 0, 1))
	local normal = along:Cross(across)
	if normal.Y < 0 then
		normal = -normal
	end
	local center = (a + b) / 2 + normal * (thick / 2)
	local size = V(math.abs(z1 - z0), thick, (b - a).Magnitude)
	local part = Build.part(kit.folder, name, size, center, color, material)
	part.CFrame = CFrame.fromMatrix(center, across, normal)
	return part
end

-- The triangle under one side of a gable, in the wall from `z0` to `z1`: its foot runs along
-- y = EAVE from x = `xLow`, where it comes to a point, to x = 0, where it reaches the ridge.
local function gableHalf(kit: Kit, xLow: number, z0: number, z1: number, color: Color3)
	local height = RIDGE - EAVE
	local rising = kit.dir(V(-xLow, 0, 0)).Unit
	local center = kit.at(V(xLow / 2, EAVE + height / 2, (z0 + z1) / 2))
	local part = Instance.new("WedgePart")
	part.Name = "Gable"
	part.Anchored = true
	part.Size = V(math.abs(z1 - z0), height, math.abs(xLow))
	-- A wedge's slope rises towards its back face, at +Z.
	part.CFrame = CFrame.fromMatrix(center, UP:Cross(rising), UP)
	part.Color = color
	part.Material = Enum.Material.Plaster
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = kit.folder
	return part
end

-- The stone base and porch, the floors, the posts, the walls with their timber frame and the
-- windows on the sides.
local function buildShell(kit: Kit, style: Style)
	local box = kit.box
	box(
		"Base",
		V(-HALF - 0.6, 0, -PORCH),
		V(HALF + 0.6, BASE, DEPTH + 0.4),
		STONE,
		Enum.Material.Pavement
	)
	local inside = ShopHouse.SIDE_INSIDE
	box(
		"Floor",
		V(-inside, 0.4, 0.6),
		V(inside, FLOOR, BACK_WALL),
		FLOOR_WOOD,
		Enum.Material.WoodPlanks
	)
	local stageBack = ShopHouse.BACK_INSIDE
	box(
		"Stage",
		V(-inside, FLOOR - 0.1, STAGE_FRONT),
		V(inside, STAGE, stageBack),
		PALE_WOOD,
		Enum.Material.WoodPlanks
	)
	decor(
		box(
			"StageEdge",
			V(-inside, FLOOR, STAGE_FRONT - 0.15),
			V(inside, STAGE + 0.05, STAGE_FRONT + 0.25),
			TIMBER,
			Enum.Material.Wood
		)
	)

	for _, side in { -1, 1 } do
		for _, z in { 0, DEPTH / 2 - POST / 2, DEPTH - POST } do
			box(
				"Post",
				V(side * INNER, BASE, z),
				V(side * HALF, EAVE, z + POST),
				TIMBER,
				Enum.Material.Wood
			)
		end

		-- The side wall: plaster between the posts, with a sill, a rail and a plate of timber.
		local x0, x1 = side * (SIDE_WALL - WALL / 2), side * (SIDE_WALL + WALL / 2)
		box(
			"Wall",
			V(x0, BASE, POST),
			V(x1, EAVE, DEPTH - POST),
			style.plaster,
			Enum.Material.Plaster
		)
		local b0, b1 = side * (SIDE_WALL - BEAM / 2), side * (SIDE_WALL + BEAM / 2)
		for _, span in { { POST, DEPTH / 2 - POST / 2 }, { DEPTH / 2 + POST / 2, DEPTH - POST } } do
			for _, y in { { BASE, BASE + 0.5 }, { 4.4, 4.9 }, { EAVE - 0.6, EAVE } } do
				box("Beam", V(b0, y[1], span[1]), V(b1, y[2], span[2]), TIMBER, Enum.Material.Wood)
			end
		end

		-- A latticed window on the outside of each half of the wall.
		local face = side * (SIDE_WALL + WALL / 2)
		for _, span in { { 1.9, 4.6 }, { 7.4, 10.1 } } do
			local z0, z1 = span[1], span[2]
			-- The dark pane stops inside the frame, so no two faces share a plane.
			decor(box("Window", V(face, 5.5, z0 + 0.1), V(face + side * 0.04, 7.7, z1 - 0.1), INK))
			for _, edge in { { z0, z0 + 0.22 }, { z1 - 0.22, z1 } } do
				decor(
					box(
						"WindowFrame",
						V(face, 5.4, edge[1]),
						V(face + side * 0.18, 7.8, edge[2]),
						TIMBER
					)
				)
			end
			for _, y in { { 5.4, 5.62 }, { 7.58, 7.8 } } do
				decor(
					box("WindowFrame", V(face, y[1], z0), V(face + side * 0.18, y[2], z1), TIMBER)
				)
			end
			local slats = 5
			for k = 1, slats do
				local z = z0 + (z1 - z0) * k / (slats + 1)
				decor(
					box(
						"WindowSlat",
						V(face, 5.62, z - 0.07),
						V(face + side * 0.12, 7.58, z + 0.07),
						TIMBER
					)
				)
			end
		end
	end

	-- The back wall, framed the same way.
	local z0, z1 = BACK_WALL - WALL / 2, BACK_WALL + WALL / 2
	box("Wall", V(-INNER, BASE, z0), V(INNER, EAVE, z1), style.plaster, Enum.Material.Plaster)
	for _, y in { { BASE, BASE + 0.5 }, { 4.4, 4.9 }, { EAVE - 0.6, EAVE } } do
		box(
			"Beam",
			V(-INNER, y[1], BACK_WALL - BEAM / 2),
			V(INNER, y[2], BACK_WALL + BEAM / 2),
			TIMBER,
			Enum.Material.Wood
		)
	end

	-- The beam across the open front, and the invisible wall under it, which stops characters
	-- but not raycasts, as Build.wall does.
	box("Header", V(-INNER, EAVE - HEADER, 0), V(INNER, EAVE, POST), TIMBER, Enum.Material.Wood)
	local guard = box("FrontGuard", V(-INNER, BASE, 0.5), V(INNER, EAVE - HEADER, 0.9), WOOD)
	guard.Transparency = 1
	guard.CanQuery = false
	guard.CastShadow = false
end

-- The roof: two slopes of tiles, the ridge with the shop's name floating over it, boards along
-- its edges, the gables under it, and the sign on the front gable.
local function buildRoof(kit: Kit, style: Style)
	local eaveY = roofAt(REACH)
	for _, side in { -1, 1 } do
		slab(
			kit,
			"Roof",
			V(0, RIDGE, 0),
			V(side * REACH, eaveY, 0),
			ROOF_FRONT,
			ROOF_BACK,
			TILE,
			style.tiles,
			Enum.Material.ClayRoofTiles
		)
		-- Boards along the gable ends and the eave cover the edges of the tiles.
		local low = V(side * (REACH + 0.1), roofAt(REACH + 0.1) - 0.25, 0)
		local high = V(0, RIDGE - 0.25, 0)
		for _, z in { { ROOF_FRONT - 0.3, ROOF_FRONT + 0.1 }, { ROOF_BACK - 0.1, ROOF_BACK + 0.3 } } do
			decor(
				slab(
					kit,
					"Barge",
					high,
					low,
					z[1],
					z[2],
					TILE + 0.5,
					style.trim,
					Enum.Material.Wood
				)
			)
		end
		local eaveFrom = V(side * (REACH - 0.6), roofAt(REACH - 0.6) - 0.2, 0)
		local eaveTo = V(side * (REACH + 0.1), roofAt(REACH + 0.1) - 0.2, 0)
		decor(slab(
			kit,
			"EaveTrim",
			eaveFrom,
			eaveTo,
			-- Its ends stop just inside the boards along the gables.
			ROOF_FRONT - 0.25,
			ROOF_BACK + 0.25,
			TILE + 0.4,
			style.trim,
			Enum.Material.Wood
		))
	end
	local ridge = kit.box(
		"Ridge",
		V(-0.7, RIDGE + 0.1, ROOF_FRONT - 0.4),
		V(0.7, RIDGE + 1.1, ROOF_BACK + 0.4),
		style.ridge,
		Enum.Material.Slate
	)
	Build.label(ridge, style.title, 3.4, Vector2.new(24, 4))
	-- A gold crest under the peak of the front gable.
	decor(
		kit.disc(
			"Crest",
			V(0, RIDGE - 0.75, ROOF_FRONT - 0.35),
			V(0, 0, -1),
			1,
			0.12,
			GOLD,
			Enum.Material.Metal
		)
	)

	-- The gables: plaster triangles with a post up the middle.
	for _, wall in { { 0.2, 0.8 }, { BACK_WALL - WALL / 2, BACK_WALL + WALL / 2 } } do
		for _, side in { -1, 1 } do
			gableHalf(kit, side * INNER, wall[1], wall[2], style.plaster)
		end
		kit.box(
			"KingPost",
			V(-0.4, EAVE, wall[1] - 0.1),
			V(0.4, RIDGE - 0.25, wall[2] + 0.1),
			TIMBER,
			Enum.Material.Wood
		)
	end

	-- The sign: gold characters on a dark board in a gold frame.
	decor(kit.box("SignFrame", V(-3.5, 9.35, -0.1), V(3.5, 11.65, 0.1), GOLD, Enum.Material.Metal))
	local signAt = kit.at(V(0, 10.5, -0.1))
	local sign =
		decor(Build.part(kit.folder, "Sign", V(6.6, 2, 0.3), signAt, TIMBER, Enum.Material.Wood))
	sign.CFrame = CFrame.lookAt(signAt, signAt + kit.out)
	local characters = Build.faceLabel(sign, Enum.NormalId.Front, style.sign)
	characters.TextColor3 = GOLD
end

-- The front: the curtain hanging from the beam, the counter, and lanterns at the corners of the
-- front and inside. Returns the counter.
local function buildFront(kit: Kit, style: Style): Part
	local rodY = EAVE - HEADER - 0.05
	decor(
		kit.rod("NorenRod", V(-7.4, rodY, 0.5), V(7.4, rodY, 0.5), 0.14, TIMBER, Enum.Material.Wood)
	)
	-- Four panels; the middle two carry a crest of rings.
	for i, x in { -5.4, -1.8, 1.8, 5.4 } do
		decor(
			kit.box(
				"Noren",
				V(x - 1.7, NOREN_BOTTOM, 0.45),
				V(x + 1.7, EAVE - HEADER, 0.55),
				style.noren,
				Enum.Material.Fabric
			)
		)
		if i == 2 or i == 3 then
			-- Each ring stands 0.04 proud of the one round it; their backs sink into the cloth.
			local crest = { 0.9, 0.6, 0.3 }
			for k, diameter in crest do
				local color = if k == 2 then style.noren else PAPER
				local thick = 0.08 * k
				decor(
					kit.disc(
						"NorenCrest",
						V(x, 7.2, 0.41),
						V(0, 0, -1),
						diameter,
						thick,
						color,
						Enum.Material.Fabric
					)
				)
			end
		end
	end

	local counter = kit.box(
		"Counter",
		V(-5.4, BASE, 1.4),
		V(5.4, COUNTER_TOP - 0.4, 3.2),
		WOOD,
		Enum.Material.WoodPlanks
	)
	kit.box(
		"CounterTop",
		V(-5.7, COUNTER_TOP - 0.4, 1.2),
		V(5.7, COUNTER_TOP, 3.4),
		PALE_WOOD,
		Enum.Material.Wood
	)
	decor(
		kit.box(
			"CounterCloth",
			V(-4.9, 1.1, 1.32),
			V(4.9, COUNTER_TOP - 0.7, 1.4),
			style.cloth,
			Enum.Material.Fabric
		)
	)

	for _, side in { -1, 1 } do
		local hang = roofAt(6.3) - 0.05
		kit.lantern(V(side * 6.3, hang, -1.5), hang - 0.4, 1, FRONT_REACH)
	end
	kit.lantern(V(0, RIDGE - 0.05, 6.5), 8.6, 0.9, INSIDE_REACH)
	return counter
end

-- Builds the house into a folder under `parent`, standing on `place` (the middle of its front
-- on the ground, looking out). Returns the kit to furnish it with and its counter, which gets
-- the shop's prompt.
function ShopHouse.build(parent: Instance, place: CFrame, style: Style): (Kit, Part)
	local folder = Instance.new("Folder")
	folder.Name = style.name
	local kit = ShopHouse.kit(folder, place)
	buildShell(kit, style)
	buildRoof(kit, style)
	local counter = buildFront(kit, style)
	folder.Parent = parent
	return kit, counter
end

return ShopHouse
