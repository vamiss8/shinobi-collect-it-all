--!strict
-- Tenten's Ninja Tools, the shop that sells kunai: a small Konoha shop on the middle line of
-- the plaza, between the fountain and the lane (Logic/PlazaPlan says where). Its open front
-- faces the fountain, where the players come from their dojos: a counter with Tenten behind
-- it, a curtain over it and every kunai of Config/Kunai hung on the back wall in the order they
-- are sold. Inside are a target and a rack of weapons; outside, a big target on the back wall
-- faces the strip. Using the counter's prompt opens the shop window, as at the stalls
-- (World/Market).
--
-- Tenten is a figure (View/Figure): a model named "tenten" in ReplicatedStorage.Models takes
-- the placeholder's place once it is supplied. Supplied kunai models (View/KunaiModel) hang
-- on the wall in place of the plain ones.
--
-- The base, walls, posts, counter, barrels and roof are solid, and an invisible wall closes
-- the open front: the shop is seen into but not walked into. Everything else is only for show.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Hub = require("./Hub")
local KunaiModel = require(ReplicatedStorage.Shared.View.KunaiModel)
local Net = require(ReplicatedStorage.Shared.Net)
local PlazaPlan = require(ReplicatedStorage.Shared.Logic.PlazaPlan)

local TentenShop = {}

-- How far from the middle of the counter its prompt can be used, studs: anywhere on the porch
-- in front of it, but not from the street along the sides of the shop.
TentenShop.REACH = 8

local V = Vector3.new
local UP = V(0, 1, 0)

-- Shop-local coordinates, in studs: x runs across the front, from left to right as seen from
-- the plaza; y is height above the paving; z runs inward, from the front (0) to the back.
local FRONT_X = PlazaPlan.SHOP.along -- Hub x of the front; the back is towards the lane
local MIDDLE = PlazaPlan.SHOP.side -- Hub z of the shop's middle line
local HALF = 9 -- half the width, to the outer faces of the corner posts
local DEPTH = 12 -- to the outer face of the back posts
local POST = 1 -- the posts are square, at the corners and halfway along each side
local WALL = 0.6 -- plaster walls, centered in the line of the posts
local BEAM = WALL + 0.2 -- timber beams, standing out a little from the plaster on both faces
local BASE = 0.5 -- height of the stone base, which reaches out in front as a porch
local PORCH = 2
local FLOOR = 0.6 -- top of the floor boards
local EAVE = 9 -- top of the walls
local INNER = HALF - POST -- the inner faces of the posts, and the roof's line over them
local SIDE_WALL = HALF - POST / 2 -- middle of a side wall
local BACK_WALL = DEPTH - POST / 2 -- middle of the back wall

-- A gable roof, its ridge running from the front to the back, so that its gable faces the
-- street with the sign on it. Its underside rests on the walls at the inner faces of the posts.
local SLOPE = math.tan(math.rad(30))
local RIDGE = EAVE + INNER * SLOPE -- underside of the roof at the ridge
local TILE = 0.8 -- thickness of the roof
local REACH = HALF + 2 -- how far out the eaves reach on each side
local ROOF_FRONT = -2.5
local ROOF_BACK = DEPTH + 1.5

local COUNTER_TOP = 3.6
-- Behind the counter the floor is raised, as in the shops of old, and Tenten stands on it.
local STAGE = FLOOR + 1
local STAGE_FRONT = 3.4
local KUNAI = 2.07 -- length of a kunai from the point to the far edge of its ring

local TIMBER = Color3.fromRGB(62, 44, 36)
local WOOD = Color3.fromRGB(121, 85, 61)
local PALE_WOOD = Color3.fromRGB(188, 158, 130)
local FLOOR_WOOD = Color3.fromRGB(150, 108, 74)
local PLASTER = Color3.fromRGB(238, 230, 214)
local STONE = Color3.fromRGB(150, 145, 138)
local TILES = Color3.fromRGB(58, 66, 82)
local RIDGE_COLOR = Color3.fromRGB(40, 45, 56)
local LACQUER = Color3.fromRGB(183, 40, 32)
local INDIGO = Color3.fromRGB(32, 44, 74)
local PAPER = Color3.fromRGB(236, 220, 188)
local INK = Color3.fromRGB(30, 24, 20)
local GOLD = Color3.fromRGB(255, 202, 40)
local IRON = Color3.fromRGB(70, 70, 74)
local STEEL = Color3.fromRGB(176, 190, 197)
local LANTERN = Color3.fromRGB(235, 90, 50)
local LIGHT = Color3.fromRGB(255, 196, 120)
local KEEPER_COLOR = Color3.fromRGB(233, 128, 160) -- the placeholder's body, until a model comes

local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric

-- The two characters on the sign over the front: "ninja tools".
local SIGN = "忍具"
local TITLE = "TENTEN'S NINJA TOOLS"

-- Shop-local point to world position, and shop-local direction to world direction.
local function at(p: Vector3): Vector3
	return Hub.at(FRONT_X + p.Z, p.Y, MIDDLE + p.X)
end

local function dir(d: Vector3): Vector3
	return V(d.Z, d.Y, d.X)
end

local OUT = dir(V(0, 0, -1)) -- out of the front, towards the fountain

-- Leaves a part in place for the eye only: nothing bumps into it, touches it or finds it with
-- a raycast, and the camera, which only backs off from solid parts, ignores it.
local function decor<T>(part: T): T
	local base = (part :: any) :: BasePart
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	return part
end

-- A block between two opposite corners.
local function box(
	folder: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local size = V(math.abs(b.X - a.X), math.abs(b.Y - a.Y), math.abs(b.Z - a.Z))
	return Build.part(folder, name, dir(size), at((a + b) / 2), color, material)
end

-- A cylinder from `a` to `b`.
local function rod(
	folder: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	local from, to = at(a), at(b)
	local along = (to - from).Unit
	local other = if math.abs(along.Y) < 0.9 then UP else V(1, 0, 0)
	local up = (other - along * along:Dot(other)).Unit
	local center = (from + to) / 2
	local size = V((to - from).Magnitude, diameter, diameter)
	local part = Build.part(folder, name, size, center, color, material)
	-- A cylinder lies along its X axis.
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.fromMatrix(center, along, up)
	return part
end

-- A round, flat disc on `center`, its faces turned towards `facing` and away from it.
local function disc(
	folder: Instance,
	name: string,
	center: Vector3,
	facing: Vector3,
	diameter: number,
	thick: number,
	color: Color3,
	material: Enum.Material?
): Part
	local half = facing.Unit * (thick / 2)
	return rod(folder, name, center - half, center + half, diameter, color, material)
end

-- A flat block centered on `center`, `size` along the directions `across` (its X), `along`
-- (its Y) and the one square to both (its Z). The directions are shop-local and square to each
-- other.
local function plate(
	folder: Instance,
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

-- A slab along a slope of the roof: its underside runs from `from` to `to` (points in a plane
-- of constant z; their z is ignored) and it reaches from `z0` to `z1`, `thick` thick.
local function slab(
	folder: Instance,
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
	local a, b = at(V(from.X, from.Y, z)), at(V(to.X, to.Y, z))
	local along = (b - a).Unit
	local across = dir(V(0, 0, 1))
	local normal = along:Cross(across)
	if normal.Y < 0 then
		normal = -normal
	end
	local center = (a + b) / 2 + normal * (thick / 2)
	local size = V(math.abs(z1 - z0), thick, (b - a).Magnitude)
	local part = Build.part(folder, name, size, center, color, material)
	part.CFrame = CFrame.fromMatrix(center, across, normal)
	return part
end

-- The triangle under one side of a gable, in the wall from `z0` to `z1`: its foot runs along
-- y = EAVE from x = `xLow`, where it comes to a point, to x = 0, where it reaches the ridge.
local function gableHalf(folder: Instance, name: string, xLow: number, z0: number, z1: number)
	local height = RIDGE - EAVE
	local rising = dir(V(-xLow, 0, 0)).Unit
	local center = at(V(xLow / 2, EAVE + height / 2, (z0 + z1) / 2))
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Anchored = true
	part.Size = V(math.abs(z1 - z0), height, math.abs(xLow))
	-- A wedge's slope rises towards its back face, at +Z.
	part.CFrame = CFrame.fromMatrix(center, UP:Cross(rising), UP)
	part.Color = PLASTER
	part.Material = Enum.Material.Plaster
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = folder
	return part
end

-- How high the underside of the roof is at x.
local function roofAt(x: number): number
	return RIDGE - math.abs(x) * SLOPE
end

-- A paper lantern hanging on a cord from `hang`, its top at `top`: a glowing cylinder with dark
-- caps, casting a warm light.
local function lantern(folder: Instance, hang: Vector3, top: number, size: number, range: number)
	local height = size * 1.3
	local bottom = top - height
	local x, z = hang.X, hang.Z
	local body = decor(
		rod(folder, "Lantern", V(x, bottom, z), V(x, top, z), size, LANTERN, Enum.Material.Neon)
	)
	for _, y in { bottom, top } do
		decor(rod(folder, "LanternCap", V(x, y - 0.12, z), V(x, y + 0.12, z), size * 0.72, TIMBER))
	end
	decor(rod(folder, "LanternCord", V(x, top + 0.12, z), hang, 0.12, TIMBER, FABRIC))
	local light = Instance.new("PointLight")
	light.Color = LIGHT
	light.Range = range
	light.Brightness = 0.9
	light.Parent = body
	-- The evening lights it and the morning dims it, with the rest of the village's.
	body:AddTag(Net.LANTERN_TAG)
end

-- A kunai with its point at `tip`, its blade pointing `down` from the ring and its flat side
-- towards `facing` (shop-local directions, square to each other). The supplied model if there
-- is one, else a blade, a point, a wrapped handle and a ring in the kunai's colors. `behind`
-- is the color that shows through the ring.
local function kunai(
	folder: Instance,
	look: Catalog.Kunai,
	tip: Vector3,
	down: Vector3,
	facing: Vector3,
	behind: Color3
)
	local model = KunaiModel.supplied(look.id, KUNAI)
	if model then
		local middle = at(tip - down * (KUNAI / 2))
		model:PivotTo(CFrame.lookAt(middle, middle + dir(down), dir(facing)))
		model.Parent = folder
		return
	end

	local across = down:Cross(facing)
	local blade = Color3.fromHex(look.color)
	local material = if look.glow then Enum.Material.Neon else METAL
	local up = -down
	decor(
		plate(folder, "KunaiBlade", tip + up * 0.6, across, up, V(0.4, 0.8, 0.08), blade, material)
	)
	-- The point: a square turned on its corner, so the blade ends in a tip.
	local point = decor(
		plate(
			folder,
			"KunaiPoint",
			tip + up * 0.2,
			across,
			up,
			V(0.28, 0.28, 0.14),
			blade,
			material
		)
	)
	point.CFrame *= CFrame.Angles(0, 0, math.rad(45))
	local wrap = Color3.fromHex(look.trail):Lerp(INK, 0.6)
	decor(rod(folder, "KunaiHandle", tip + up * 1.0, tip + up * 1.7, 0.2, wrap, FABRIC))
	local ring = tip + up * 1.88
	decor(disc(folder, "KunaiRing", ring, facing, 0.38, 0.07, IRON, METAL))
	decor(disc(folder, "KunaiHole", ring, facing, 0.2, 0.13, behind))
end

-- A kunai stuck in a target: only the handle and the ring stand out of it, pointing `out`
-- from the point `at` on its face.
local function stuck(folder: Instance, from: Vector3, out: Vector3)
	local unit = out.Unit
	local handle = from + unit * 0.75
	decor(rod(folder, "StuckKunai", from, handle, 0.2, INK, FABRIC))
	local side = unit:Cross(V(0, 1, 0))
	if side.Magnitude < 0.1 then
		side = V(1, 0, 0)
	end
	decor(disc(folder, "StuckRing", handle + unit * 0.18, side, 0.38, 0.07, IRON, METAL))
end

-- A shuriken lying flat against a surface whose outward direction is `normal`: two crossed
-- blades and a hub, turned `spin` radians about the normal.
local function shuriken(folder: Instance, center: Vector3, normal: Vector3, spin: number)
	local base = if math.abs(normal.Y) > 0.9 then V(1, 0, 0) else V(0, 1, 0)
	local a = (base - normal * base:Dot(normal)).Unit
	local b = normal:Cross(a)
	local turnedA = a * math.cos(spin) + b * math.sin(spin)
	local turnedB = normal:Cross(turnedA)
	for _, blade in { turnedA, turnedB } do
		local edge = blade:Cross(normal)
		decor(plate(folder, "Shuriken", center, edge, blade, V(0.16, 0.8, 0.05), IRON, METAL))
	end
	decor(disc(folder, "ShurikenHub", center, normal, 0.24, 0.12, STEEL, METAL))
end

-- A target of rings, each a little thicker than the one around it so it stands proud of it.
local function target(
	folder: Instance,
	name: string,
	center: Vector3,
	facing: Vector3,
	rings: { { diameter: number, color: Color3 } }
)
	for i, ring in rings do
		decor(disc(folder, name, center, facing, ring.diameter, 0.3 + 0.08 * (i - 1), ring.color))
	end
end

-- The stone base and porch, the floor, the posts, the walls with their timber frame, and the
-- windows on the sides.
local function buildShell(folder: Folder)
	box(
		folder,
		"Base",
		V(-HALF - 0.6, 0, -PORCH),
		V(HALF + 0.6, BASE, DEPTH + 0.4),
		STONE,
		Enum.Material.Pavement
	)
	box(
		folder,
		"Floor",
		V(-INNER - 0.2, 0.4, 0.6),
		V(INNER + 0.2, FLOOR, BACK_WALL),
		FLOOR_WOOD,
		Enum.Material.WoodPlanks
	)
	local inside = SIDE_WALL - WALL / 2
	box(
		folder,
		"Stage",
		V(-inside, FLOOR - 0.1, STAGE_FRONT),
		V(inside, STAGE, BACK_WALL - WALL / 2),
		PALE_WOOD,
		Enum.Material.WoodPlanks
	)
	decor(
		box(
			folder,
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
				folder,
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
			folder,
			"Wall",
			V(x0, BASE, POST),
			V(x1, EAVE, DEPTH - POST),
			PLASTER,
			Enum.Material.Plaster
		)
		local b0, b1 = side * (SIDE_WALL - BEAM / 2), side * (SIDE_WALL + BEAM / 2)
		for _, span in { { POST, DEPTH / 2 - POST / 2 }, { DEPTH / 2 + POST / 2, DEPTH - POST } } do
			for _, y in { { BASE, BASE + 0.5 }, { 4.4, 4.9 }, { EAVE - 0.6, EAVE } } do
				box(
					folder,
					"Beam",
					V(b0, y[1], span[1]),
					V(b1, y[2], span[2]),
					TIMBER,
					Enum.Material.Wood
				)
			end
		end

		-- A latticed window on the outside of each half of the wall.
		local face = side * (SIDE_WALL + WALL / 2)
		for _, span in { { 1.9, 4.6 }, { 7.4, 10.1 } } do
			local z0, z1 = span[1], span[2]
			-- The dark pane stops inside the frame, so no two faces share a plane.
			local pane0, pane1 = V(face, 5.5, z0 + 0.1), V(face + side * 0.04, 7.7, z1 - 0.1)
			decor(box(folder, "Window", pane0, pane1, INK))
			for _, edge in { { z0, z0 + 0.22 }, { z1 - 0.22, z1 } } do
				decor(
					box(
						folder,
						"WindowFrame",
						V(face, 5.4, edge[1]),
						V(face + side * 0.18, 7.8, edge[2]),
						TIMBER
					)
				)
			end
			for _, y in { { 5.4, 5.62 }, { 7.58, 7.8 } } do
				decor(
					box(
						folder,
						"WindowFrame",
						V(face, y[1], z0),
						V(face + side * 0.18, y[2], z1),
						TIMBER
					)
				)
			end
			local slats = 5
			for k = 1, slats do
				local z = z0 + (z1 - z0) * k / (slats + 1)
				decor(
					box(
						folder,
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
	box(folder, "Wall", V(-INNER, BASE, z0), V(INNER, EAVE, z1), PLASTER, Enum.Material.Plaster)
	for _, y in { { BASE, BASE + 0.5 }, { 4.4, 4.9 }, { EAVE - 0.6, EAVE } } do
		box(
			folder,
			"Beam",
			V(-INNER, y[1], BACK_WALL - BEAM / 2),
			V(INNER, y[2], BACK_WALL + BEAM / 2),
			TIMBER,
			Enum.Material.Wood
		)
	end

	-- The beam across the open front, and the invisible wall under it.
	box(
		folder,
		"Header",
		V(-INNER, EAVE - 1.2, 0),
		V(INNER, EAVE, POST),
		TIMBER,
		Enum.Material.Wood
	)
	Build.wall(
		folder,
		"FrontGuard",
		dir(V(INNER * 2, EAVE - 1.2 - BASE, 0.4)),
		at(V(0, (BASE + EAVE - 1.2) / 2, 0.7))
	)
end

-- The gable roof: two slopes of tiles, a ridge, red boards along its edges, the gables under
-- it with the sign on the front one, and the shop's name floating above it.
local function buildRoof(folder: Folder)
	local eaveY = roofAt(REACH)
	for _, side in { -1, 1 } do
		slab(
			folder,
			"Roof",
			V(0, RIDGE, 0),
			V(side * REACH, eaveY, 0),
			ROOF_FRONT,
			ROOF_BACK,
			TILE,
			TILES,
			Enum.Material.ClayRoofTiles
		)
		-- Red boards along the gable ends and the eave, covering the edges of the tiles.
		local low, high =
			V(side * (REACH + 0.1), roofAt(REACH + 0.1) - 0.25, 0), V(0, RIDGE - 0.25, 0)
		for _, z in { { ROOF_FRONT - 0.3, ROOF_FRONT + 0.1 }, { ROOF_BACK - 0.1, ROOF_BACK + 0.3 } } do
			decor(
				slab(
					folder,
					"Barge",
					high,
					low,
					z[1],
					z[2],
					TILE + 0.5,
					LACQUER,
					Enum.Material.Wood
				)
			)
		end
		local eaveFrom = V(side * (REACH - 0.6), roofAt(REACH - 0.6) - 0.2, 0)
		decor(
			slab(
				folder,
				"EaveTrim",
				eaveFrom,
				V(side * (REACH + 0.1), roofAt(REACH + 0.1) - 0.2, 0),
				ROOF_FRONT - 0.24,
				ROOF_BACK + 0.24,
				TILE + 0.4,
				LACQUER,
				Enum.Material.Wood
			)
		)
	end
	local ridge = box(
		folder,
		"Ridge",
		V(-0.7, RIDGE + 0.1, ROOF_FRONT - 0.4),
		V(0.7, RIDGE + 1.1, ROOF_BACK + 0.4),
		RIDGE_COLOR,
		Enum.Material.Slate
	)
	Build.label(ridge, TITLE, 3.4, Vector2.new(24, 4))
	-- A gold crest under the peak of the front gable.
	decor(
		disc(
			folder,
			"Crest",
			V(0, RIDGE - 0.75, ROOF_FRONT - 0.35),
			V(0, 0, -1),
			1,
			0.12,
			GOLD,
			METAL
		)
	)

	-- The gables: plaster triangles with a post up the middle.
	for _, wall in { { 0.2, 0.8 }, { BACK_WALL - WALL / 2, BACK_WALL + WALL / 2 } } do
		for _, side in { -1, 1 } do
			gableHalf(folder, "Gable", side * INNER, wall[1], wall[2])
		end
		box(
			folder,
			"KingPost",
			V(-0.4, EAVE, wall[1] - 0.1),
			V(0.4, RIDGE - 0.25, wall[2] + 0.1),
			TIMBER,
			Enum.Material.Wood
		)
	end

	-- The sign: gold characters on a dark board in a gold frame, on the front gable.
	decor(box(folder, "SignFrame", V(-3.5, 9.35, -0.1), V(3.5, 11.65, 0.1), GOLD, METAL))
	local signAt = at(V(0, 10.5, -0.1))
	local sign =
		decor(Build.part(folder, "Sign", V(6.6, 2, 0.3), signAt, TIMBER, Enum.Material.Wood))
	sign.CFrame = CFrame.lookAt(signAt, signAt + OUT)
	local characters = Build.faceLabel(sign, Enum.NormalId.Front, SIGN)
	characters.TextColor3 = GOLD
end

-- The front: a curtain hanging from the beam, the counter with its wares, barrels of weapons
-- at its ends and lanterns at the corners. Returns the counter.
local function buildFront(folder: Folder): Part
	-- The noren, a curtain of four panels; the middle two carry a target as a crest.
	decor(
		rod(
			folder,
			"NorenRod",
			V(-7.4, EAVE - 1.25, 0.5),
			V(7.4, EAVE - 1.25, 0.5),
			0.14,
			TIMBER,
			Enum.Material.Wood
		)
	)
	for i, x in { -5.4, -1.8, 1.8, 5.4 } do
		decor(
			box(
				folder,
				"Noren",
				V(x - 1.7, 6.6, 0.45),
				V(x + 1.7, EAVE - 1.2, 0.55),
				INDIGO,
				FABRIC
			)
		)
		if i == 2 or i == 3 then
			local crest = V(x, 7.2, 0.43)
			local rings = {
				{ diameter = 0.9, color = PAPER },
				{ diameter = 0.6, color = INDIGO },
				{ diameter = 0.3, color = PAPER },
			}
			for k, ring in rings do
				-- Each ring stands clearly proud of the one under it: a hundredth of a stud
				-- apart, two faces flicker.
				local thick = 0.06 + 0.05 * k
				decor(
					disc(
						folder,
						"NorenCrest",
						crest,
						V(0, 0, -1),
						ring.diameter,
						thick,
						ring.color,
						FABRIC
					)
				)
			end
		end
	end

	local counter = box(
		folder,
		"Counter",
		V(-5.4, BASE, 1.4),
		V(5.4, COUNTER_TOP - 0.4, 3.2),
		WOOD,
		Enum.Material.WoodPlanks
	)
	box(
		folder,
		"CounterTop",
		V(-5.7, COUNTER_TOP - 0.4, 1.2),
		V(5.7, COUNTER_TOP, 3.4),
		PALE_WOOD,
		Enum.Material.Wood
	)
	decor(
		box(
			folder,
			"CounterCloth",
			V(-4.9, 1.1, 1.32),
			V(4.9, COUNTER_TOP - 0.7, 1.4),
			INDIGO,
			FABRIC
		)
	)

	-- On the counter: three kunai laid out, a tray of shuriken and a pile of scrolls.
	local lying = V(0.15, 0, -1).Unit
	for i, index in { 2, 5, 9 } do
		local look = Catalog.kunai[math.min(index, #Catalog.kunai)]
		kunai(folder, look, V(-5.5 + i * 1.05, COUNTER_TOP + 0.045, 1.3), lying, UP, PALE_WOOD)
	end
	decor(
		box(
			folder,
			"Tray",
			V(-1, COUNTER_TOP, 1.35),
			V(1, COUNTER_TOP + 0.08, 2.25),
			TIMBER,
			Enum.Material.Wood
		)
	)
	for i, x in { -0.55, 0, 0.55 } do
		shuriken(folder, V(x, COUNTER_TOP + 0.12, 1.8), UP, i * 0.5)
	end
	for _, scroll in
		{
			{ y = 0.25, z = 1.9, x0 = 2.4, x1 = 4.6, color = PAPER },
			{ y = 0.25, z = 2.5, x0 = 2.4, x1 = 4.6, color = LACQUER },
			{ y = 0.68, z = 2.2, x0 = 2.6, x1 = 4.4, color = PAPER },
		}
	do
		local y = COUNTER_TOP + scroll.y
		decor(
			rod(
				folder,
				"Scroll",
				V(scroll.x0, y, scroll.z),
				V(scroll.x1, y, scroll.z),
				0.5,
				scroll.color,
				FABRIC
			)
		)
	end

	-- Barrels at the ends of the counter: spears in the left one, swords in the right one.
	for _, side in { -1, 1 } do
		local x, z = side * 7, 2.3
		rod(folder, "Barrel", V(x, FLOOR, z), V(x, FLOOR + 2.2, z), 1.7, WOOD, Enum.Material.Wood)
		for _, y in { 0.35, 1.65 } do
			decor(
				rod(
					folder,
					"BarrelBand",
					V(x, FLOOR + y, z),
					V(x, FLOOR + y + 0.2, z),
					1.78,
					IRON,
					METAL
				)
			)
		end
		for k, lean in { V(-0.35, 0, -0.2), V(0.3, 0, -0.25), V(0, 0, 0.35) } do
			local foot = V(x + lean.X * 0.3, FLOOR + 1, z + lean.Z * 0.3)
			if side < 0 then
				local head = V(x + lean.X, FLOOR + 5.6 + k * 0.3, z + lean.Z)
				local up = (head - foot).Unit
				decor(rod(folder, "Spear", foot, head, 0.16, TIMBER, Enum.Material.Wood))
				local flat = up:Cross(V(0, 0, 1)).Unit
				decor(
					plate(
						folder,
						"SpearHead",
						head + up * 0.4,
						flat,
						up,
						V(0.3, 0.8, 0.06),
						STEEL,
						METAL
					)
				)
				decor(
					rod(
						folder,
						"SpearBinding",
						head - up * 0.05,
						head + up * 0.12,
						0.24,
						LACQUER,
						FABRIC
					)
				)
			else
				local guard = V(x + lean.X * 0.8, FLOOR + 3.9 + k * 0.15, z + lean.Z * 0.8)
				local up = (guard - foot).Unit
				decor(rod(folder, "Sheath", foot, guard - up * 0.05, 0.24, INK))
				decor(disc(folder, "Guard", guard, up, 0.5, 0.08, GOLD, METAL))
				local hilt = if k == 2 then PAPER else LACQUER
				decor(rod(folder, "Hilt", guard + up * 0.05, guard + up * 1.05, 0.2, hilt, FABRIC))
			end
		end
	end

	-- Lanterns under the eaves at the front corners, and one inside over the counter.
	for _, side in { -1, 1 } do
		local hang = roofAt(6.3) - 0.05
		lantern(folder, V(side * 6.3, hang, -1.5), hang - 0.4, 1, 22)
	end
	lantern(folder, V(0, RIDGE - 0.05, 6.5), 8.6, 0.9, 18)

	return counter
end

-- Inside: every kunai on the back wall, a target on the left wall, a weapon rack on the right.
local function buildInside(folder: Folder)
	local wall = BACK_WALL - WALL / 2
	local boardFront = wall - 0.25
	decor(
		box(
			folder,
			"KunaiBoard",
			V(-6.6, 2.4, boardFront),
			V(6.6, 7.8, wall),
			TIMBER,
			Enum.Material.Wood
		)
	)
	-- In the order they are sold, cheapest at the top left, on two rows.
	local count = #Catalog.kunai
	local perRow = math.ceil(count / 2)
	local spacing = 1.2
	for index, look in Catalog.kunai do
		local row = if index <= perRow then 1 else 2
		local inRow = if row == 1 then perRow else count - perRow
		local slot = if row == 1 then index else index - perRow
		local x = (slot - (inRow + 1) / 2) * spacing
		local ringY = if row == 1 then 7.2 else 4.7
		local tip = V(x, ringY - 1.88, boardFront - 0.06)
		kunai(folder, look, tip, V(0, -1, 0), V(0, 0, -1), TIMBER)
	end

	-- The target on the left wall, with three kunai in the middle and shuriken around it.
	local face = -(SIDE_WALL - WALL / 2) + 0.15
	local center = V(face, 5.6, 8.3)
	local inward = V(1, 0, 0)
	target(folder, "Target", center, inward, {
		{ diameter = 3.4, color = TIMBER },
		{ diameter = 3, color = PAPER },
		{ diameter = 2.2, color = LACQUER },
		{ diameter = 1.4, color = PAPER },
		{ diameter = 0.6, color = LACQUER },
	})
	local surface = face + 0.3
	for _, hit in { V(0.12, 0.08, 0), V(-0.3, -0.3, 0.35), V(0.3, 0.28, -0.3) } do
		local from = V(surface, center.Y + hit.Y, center.Z + hit.Z)
		stuck(folder, from, V(1, hit.Y * 0.8, hit.Z * 0.8))
	end
	shuriken(folder, V(surface - 0.05, center.Y + 1.1, center.Z - 0.9), inward, 0.3)
	shuriken(folder, V(surface - 0.05, center.Y - 1.2, center.Z + 0.7), inward, 0.9)

	-- The rack on the right wall: a staff, a spear and a sword, each lying on two pegs.
	local x = SIDE_WALL - WALL / 2 - 0.45
	local pegFrom = SIDE_WALL - WALL / 2
	for _, y in { 7.4, 6.2, 5 } do
		for _, z in { 4.2, 8.6 } do
			decor(
				rod(
					folder,
					"Peg",
					V(pegFrom, y - 0.22, z),
					V(x - 0.15, y - 0.22, z),
					0.14,
					TIMBER,
					Enum.Material.Wood
				)
			)
		end
	end
	decor(
		rod(folder, "Staff", V(x, 7.4, 2.4), V(x, 7.4, 10.6), 0.26, PALE_WOOD, Enum.Material.Wood)
	)
	decor(rod(folder, "Spear", V(x, 6.2, 2.6), V(x, 6.2, 9.6), 0.2, TIMBER, Enum.Material.Wood))
	decor(rod(folder, "SpearBinding", V(x, 6.2, 9.55), V(x, 6.2, 9.75), 0.26, LACQUER, FABRIC))
	decor(
		plate(
			folder,
			"SpearHead",
			V(x, 6.2, 10.2),
			V(0, 1, 0),
			V(0, 0, 1),
			V(0.3, 0.9, 0.06),
			STEEL,
			METAL
		)
	)
	decor(rod(folder, "Hilt", V(x, 5, 2.6), V(x, 5, 3.6), 0.22, LACQUER, FABRIC))
	decor(disc(folder, "Guard", V(x, 5, 3.64), V(0, 0, 1), 0.55, 0.08, GOLD, METAL))
	decor(rod(folder, "Sheath", V(x, 5, 3.68), V(x, 5, 8.8), 0.24, INK))
end

-- Outside the back, facing the throwing strip: a big target with kunai in it.
local function buildBack(folder: Folder)
	local face = BACK_WALL + WALL / 2 + 0.1
	local center = V(0, 5, face)
	local outward = V(0, 0, 1)
	target(folder, "BackTarget", center, outward, {
		{ diameter = 6.8, color = TIMBER },
		{ diameter = 6.2, color = LACQUER },
		{ diameter = 5, color = PAPER },
		{ diameter = 3.8, color = LACQUER },
		{ diameter = 2.6, color = PAPER },
		{ diameter = 1.3, color = GOLD },
	})
	local surface = face + 0.4
	for _, hit in { V(0.15, 0.2, 0), V(-0.5, -0.45, 0), V(0.65, -0.3, 0) } do
		stuck(folder, V(hit.X, center.Y + hit.Y, surface), V(hit.X * 0.8, hit.Y * 0.8, 1))
	end
	-- Two shuriken on the red ring, a little short of the middle.
	local ring = face + 0.22
	shuriken(folder, V(2.3, 6.7, ring), outward, 0.4)
	shuriken(folder, V(-2.5, 3.5, ring), outward, 1.1)
end

-- Builds the shop into `folder` and returns its counter, which gets the shop's prompt.
function TentenShop.build(parent: Instance): Part
	local folder = Instance.new("Folder")
	folder.Name = "TentenShop"

	buildShell(folder)
	buildRoof(folder)
	local counter = buildFront(folder)
	buildInside(folder)
	buildBack(folder)

	-- Tenten herself, behind the counter, looking out at the street.
	local keeper = Figure.keeper("tenten", "Tenten", KEEPER_COLOR)
	keeper.Name = Net.KEEPER
	local feet = at(V(0, STAGE, 4.6))
	keeper:PivotTo(CFrame.lookAt(feet, feet + OUT))
	keeper.Parent = folder

	folder.Parent = parent
	return counter
end

return TentenShop
