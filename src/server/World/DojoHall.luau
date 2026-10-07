--!strict
-- The dojo building, built from plain parts around the pads that World/Plots lays out: up to
-- three floors under a tiled roof, open to the street at the front, with a staircase that
-- climbs the facade in one straight line (Logic/DojoPlan has the layout).
--
-- The dojo grows with its owner. It starts with one floor; when the pads of a floor are all
-- bought, the next floor goes up, the roof rises onto it and the staircase reaches it
-- (setFloors). Each floor, with the flight of stairs that leads to it, is a folder of its own
-- that is only in the world while the floor stands.
--
-- Floors, walls, pillars, the roof with its ridge, gables and water tank, the small roofs round
-- the upper floors and the ramps under the stairs are solid. Steps, railings, lanterns and the
-- rest are only for show: nothing collides with them and the camera never zooms in because of
-- them. Invisible walls along the
-- railings keep players from walking off an edge by accident; a deliberate jump still clears
-- them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.View.Build)
local DojoPlan = require(ReplicatedStorage.Shared.Logic.DojoPlan)

local DojoHall = {}

-- One dojo's place in the world: turns dojo-local coordinates (Logic/DojoPlan) into world
-- space. The dojos on the two sides of the street are mirror images of each other, so every
-- part that is turned is built from world-space directions rather than by turning a frame.
export type Frame = {
	at: (x: number, y: number, z: number) -> Vector3,
	inward: Vector3, -- world direction of local +z: away from the street
}

-- A built dojo. World/Plots puts each pad into the folder of its floor.
export type Hall = {
	folder: Folder, -- the dojo's folder, which the standing floors are in
	sign: TextLabel, -- the name board on the roof
	storeys: { Folder }, -- per floor: its walls, ceiling, front, the flight up to it, its pads
	tops: { Folder }, -- per floor: the railing that closes its landing while it is the top floor
	roof: Folder, -- the roof and everything on it, which moves up as the dojo grows
	floors: number, -- how many floors stand now
}

type Ctx = { folder: Folder, frame: Frame }

local V = Vector3.new
local UP = V(0, 1, 0)

local HALF = DojoPlan.HALF_WIDTH
local FRONT = DojoPlan.FRONT
local BACK = DojoPlan.BACK
local WALL = DojoPlan.WALL
local SLAB = DojoPlan.SLAB
local TOP = DojoPlan.TOP
local NEAR = DojoPlan.STAIR_NEAR
local FAR = DojoPlan.STAIR_FAR
local MID = (FRONT + BACK) / 2 -- z of the roof's ridge

local HEADER = 1.4 -- depth of the beam under each floor's front edge
local RAIL = 3.4 -- height of a railing above what it guards
local GUARD = 5 -- height of the invisible wall behind a railing
local STRINGER = 0.6 -- width of the beams the steps sit between
local NOSING = 0.6 -- how far the top of a stringer stands above its ramp
local POST_EVERY = 6 -- the most a railing runs between two posts, studs

-- The roof: it overhangs the walls, rises gently from the eaves and steeply to the ridge.
local EAVE_FRONT = FRONT - 5
local EAVE_SIDE = HALF + 3
local EAVE_Y = TOP - 1
local BREAK = 9 -- from the eaves to where the slope steepens, along z
local LOW_SLOPE = math.tan(math.rad(18))
local HIGH_SLOPE = math.tan(math.rad(35))
local BREAK_Y = EAVE_Y + BREAK * LOW_SLOPE
local RIDGE_Y = BREAK_Y + (MID - EAVE_FRONT - BREAK) * HIGH_SLOPE
local TILE = 1.2 -- thickness of the roof
local SIGN_HALF = 9 -- half the width of the name board
local SIGN_HEIGHT = 4
local OPEN_FOOT = 4 -- how far up the first flight its street-side railing starts

local TIMBER = Color3.fromRGB(62, 44, 36)
local FLOOR_WOOD = Color3.fromRGB(150, 108, 74)
local STEP_WOOD = Color3.fromRGB(128, 90, 62)
local PLASTER = Color3.fromRGB(238, 230, 214)
local LACQUER = Color3.fromRGB(183, 40, 32)
local BRONZE = Color3.fromRGB(196, 150, 70)
local TILES = Color3.fromRGB(58, 66, 82)
local RIDGE = Color3.fromRGB(40, 45, 56)
local STONE = Color3.fromRGB(150, 145, 138)
local GRAVEL = Color3.fromRGB(176, 168, 152)
local INDIGO = Color3.fromRGB(32, 44, 74)
local PAPER = Color3.fromRGB(236, 220, 188)
local INK = Color3.fromRGB(30, 24, 20)
local GOLD = Color3.fromRGB(255, 202, 40)
local LANTERN = Color3.fromRGB(235, 90, 50)
local LIGHT = Color3.fromRGB(255, 196, 120)
local TANK = Color3.fromRGB(139, 102, 68)
local IRON = Color3.fromRGB(70, 70, 74)

local WOOD = Enum.Material.Wood
local PLANKS = Enum.Material.WoodPlanks
local TILED = Enum.Material.ClayRoofTiles

-- The two characters on the curtain over the entrance, as read from the street: "dojo".
local NOREN = { "道", "場" }
-- The scroll on the back wall of each floor: endurance, fire, shadow.
local SCROLLS = { "忍", "火", "影" }
-- The nobori, banners at the ends of the facade: "the ninja way", one character over the other.
local NOBORI = "忍\n道"

-- Leaves a part in place for the eye only: nothing bumps into it, touches it or finds it with
-- a raycast, and the camera, which only backs off from solid parts, ignores it.
local function decor<T>(part: T): T
	local base = (part :: any) :: BasePart
	base.CanCollide = false
	base.CanQuery = false
	base.CanTouch = false
	return part
end

-- Hides a solid part: the ramps under the stairs and the walls behind the railings.
local function hidden(part: BasePart)
	part.Transparency = 1
	part.CastShadow = false
end

-- An upright block between two opposite corners, in dojo-local coordinates.
local function block(
	ctx: Ctx,
	name: string,
	a: Vector3,
	b: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local mid = (a + b) / 2
	local center = ctx.frame.at(mid.X, mid.Y, mid.Z)
	local size = V(math.abs(b.X - a.X), math.abs(b.Y - a.Y), math.abs(b.Z - a.Z))
	return Build.part(ctx.folder, name, size, center, color, material)
end

-- A straight beam whose middle line runs from `a` to `b` (dojo-local points): `width` across
-- it, level, and `depth` square to both. `lift` moves it square to its length, upwards when
-- positive: -depth / 2 puts its top face on the line from `a` to `b`.
local function plank(
	ctx: Ctx,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	depth: number,
	lift: number,
	color: Color3,
	material: Enum.Material?
): Part
	local from = ctx.frame.at(a.X, a.Y, a.Z)
	local to = ctx.frame.at(b.X, b.Y, b.Z)
	local along = (to - from).Unit
	local across = along:Cross(UP)
	if across.Magnitude < 1e-6 then
		across = V(1, 0, 0) -- an upright beam: any level direction will do
	end
	across = across.Unit
	local normal = across:Cross(along)
	if normal.Y < 0 then
		across, normal = -across, -normal
	end
	local center = (from + to) / 2 + normal * lift
	local size = V(width, depth, (to - from).Magnitude)
	local part = Build.part(ctx.folder, name, size, center, color, material)
	part.CFrame = CFrame.fromMatrix(center, across, normal)
	return part
end

-- A wedge standing in the plane x = `x`. Its slope climbs from (`zLow`, `y`) to (`zHigh`,
-- `y + height`), so its tall face is at `zHigh`.
local function wedge(
	ctx: Ctx,
	name: string,
	x: number,
	zLow: number,
	zHigh: number,
	y: number,
	height: number,
	color: Color3,
	material: Enum.Material
): WedgePart
	local frame = ctx.frame
	local rising = (frame.at(x, y, zHigh) - frame.at(x, y, zLow)).Unit
	local center = frame.at(x, y + height / 2, (zLow + zHigh) / 2)
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Anchored = true
	part.Size = V(WALL, height, math.abs(zHigh - zLow))
	-- A wedge's slope rises towards its back face, at +Z.
	part.CFrame = CFrame.fromMatrix(center, UP:Cross(rising), UP)
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = ctx.folder
	return part
end

-- An upright cylinder standing on `base` (a dojo-local point), `height` tall.
local function column(
	ctx: Ctx,
	name: string,
	base: Vector3,
	height: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	local center = ctx.frame.at(base.X, base.Y + height / 2, base.Z)
	local size = V(height, diameter, diameter)
	local part = Build.part(ctx.folder, name, size, center, color, material)
	part.Shape = Enum.PartType.Cylinder
	-- A cylinder lies along its X axis; this stands it up.
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	return part
end

-- A cylinder lying from `a` to `b` (dojo-local points).
local function rod(
	ctx: Ctx,
	name: string,
	a: Vector3,
	b: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): Part
	local from = ctx.frame.at(a.X, a.Y, a.Z)
	local to = ctx.frame.at(b.X, b.Y, b.Z)
	local along = (to - from).Unit
	local other = if math.abs(along.Y) < 0.9 then UP else V(1, 0, 0)
	local up = (other - along * along:Dot(other)).Unit
	local center = (from + to) / 2
	local size = V((to - from).Magnitude, diameter, diameter)
	local part = Build.part(ctx.folder, name, size, center, color, material)
	part.Shape = Enum.PartType.Cylinder
	part.CFrame = CFrame.fromMatrix(center, along, up)
	return part
end

-- A flat panel between two corners in a plane of constant z, `thickness` thick, with its face
-- (and any text on it) turned towards the street.
local function panel(
	ctx: Ctx,
	name: string,
	a: Vector3,
	b: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?
): Part
	local mid = (a + b) / 2
	local center = ctx.frame.at(mid.X, mid.Y, mid.Z)
	local size = V(math.abs(b.X - a.X), math.abs(b.Y - a.Y), thickness)
	local part = Build.part(ctx.folder, name, size, center, color, material)
	part.CFrame = CFrame.lookAt(center, center - ctx.frame.inward)
	return part
end

-- A paper lantern hanging on a cord from `hang` (a dojo-local point): a glowing cylinder with
-- dark caps, `size` across. A lit one casts a warm light.
local function lantern(ctx: Ctx, hang: Vector3, size: number, lit: boolean)
	local height = size * 1.3
	local top = hang.Y - size * 0.5
	local bottom = V(hang.X, top - height, hang.Z)
	local body = decor(column(ctx, "Lantern", bottom, height, size, LANTERN, Enum.Material.Neon))
	for _, y in { top - height, top } do
		decor(column(ctx, "LanternCap", V(hang.X, y - 0.12, hang.Z), 0.24, size * 0.72, TIMBER))
	end
	local cord = V(hang.X, top + 0.12, hang.Z)
	decor(column(ctx, "LanternCord", cord, hang.Y - cord.Y, 0.12, TIMBER, Enum.Material.Fabric))
	if lit then
		local light = Instance.new("PointLight")
		light.Color = LIGHT
		light.Range = 22
		light.Brightness = 0.9
		light.Parent = body
	end
end

-- A railing along a path of dojo-local points, each at the height of what it guards: a post at
-- every corner and every few studs between, a top rail and a middle rail, and an invisible
-- wall behind it all. On a slope the posts stay upright and the rails slant with it. A railing
-- that carries on from another one leaves out its first post, which the other already has.
local function railing(ctx: Ctx, path: { Vector3 }, continues: boolean)
	local posts: { Vector3 } = if continues then {} else { path[1] }
	for i = 2, #path do
		local a, b = path[i - 1], path[i]
		local count = math.ceil((b - a).Magnitude / POST_EVERY)
		for k = 1, count do
			table.insert(posts, a:Lerp(b, k / count))
		end
		for _, height in { RAIL, RAIL / 2 } do
			local lift = UP * height
			decor(plank(ctx, "Rail", a + lift, b + lift, 0.32, 0.32, 0, LACQUER, WOOD))
		end
		hidden(plank(ctx, "RailGuard", a, b, 0.4, GUARD, GUARD / 2, LACQUER))
	end
	for _, at in posts do
		local half = V(0.22, 0, 0.22)
		local top = at + UP * (RAIL + 0.2)
		decor(block(ctx, "RailPost", at - half, top + half, LACQUER, WOOD))
		-- A bronze cap on the post, as on the railings of old bridges.
		local cap =
			decor(block(ctx, "RailCap", top - V(0.31, 0, 0.31), top + V(0.31, 0.62, 0.31), BRONZE))
		cap.Shape = Enum.PartType.Ball
		cap.Material = Enum.Material.Metal
	end
end

-- The ground floor, the paving under the staircase and the gravel garden behind.
local function buildGround(ctx: Ctx)
	block(ctx, "Porch", V(-HALF, -1, 0), V(HALF, 0, FRONT), STONE, Enum.Material.Pavement)
	block(ctx, "Floor", V(-HALF, -1, FRONT), V(HALF, 0, BACK), FLOOR_WOOD, PLANKS)
	local garden = V(HALF, 0, DojoPlan.DEPTH)
	block(ctx, "Garden", V(-HALF, -1, BACK), garden, GRAVEL, Enum.Material.Pebble)
end

-- One storey: from its floor up to its ceiling, which is the next floor up or the base of the
-- roof. White plaster walls in a dark timber frame, pillars along the open front, a beam across
-- the front under the ceiling, two lanterns over the aisle and a scroll on the back wall.
local function buildStorey(ctx: Ctx, floor: number)
	local y0, y1 = DojoPlan.level(floor), DojoPlan.level(floor + 1)
	local plaster = Enum.Material.Plaster

	-- The ceiling stops short of the front pillars' faces, so the beam under it covers its
	-- edge. The beam's top is the threshold that a landing leads over.
	local inner = HALF - WALL
	local name = if floor == DojoPlan.FLOORS then "Ceiling" else `Floor{floor + 1}`
	block(
		ctx,
		name,
		V(-inner, y1 - SLAB, FRONT + 0.05),
		V(inner, y1, BACK - WALL),
		FLOOR_WOOD,
		PLANKS
	)
	local a = V(-HALF - 0.05, y1 - SLAB - HEADER, FRONT - 0.05)
	local b = V(HALF + 0.05, y1 + 0.05, FRONT + WALL - 0.05)
	decor(block(ctx, "Header", a, b, TIMBER, WOOD))

	for _, side in { -1, 1 } do
		local x = side * HALF
		block(
			ctx,
			"SideWall",
			V(x - side * WALL, y0, FRONT + WALL),
			V(x, y1, BACK - WALL),
			PLASTER,
			plaster
		)
	end
	block(ctx, "BackWall", V(-HALF, y0, BACK - WALL), V(HALF, y1, BACK), PLASTER, plaster)

	-- Pillars along the open front; those of the ground floor stand on stone footings.
	for _, x in DojoPlan.pillars do
		block(
			ctx,
			"Pillar",
			V(x - WALL / 2, y0, FRONT),
			V(x + WALL / 2, y1, FRONT + WALL),
			TIMBER,
			WOOD
		)
		if floor == 1 then
			local footing, center = V(0.8, 0, 0.8), V(x, 0, FRONT + WALL / 2)
			local top = center + footing + V(0, 0.5, 0)
			block(ctx, "Footing", center - footing, top, STONE, Enum.Material.Slate)
		end
	end

	-- The frame on the walls: posts, a beam under the ceiling and a rail halfway up. Posts stand
	-- out a little more than beams, so their faces never meet in one plane.
	local beams = { { y1 - 1.6, y1 - 0.2 }, { y0 + 6.2, y0 + 6.9 } }
	for _, side in { -1, 1 } do
		local x = side * (HALF - WALL / 2)
		for _, z in { MID - 7, MID + 7 } do
			decor(
				block(ctx, "Post", V(x - 0.68, y0, z - 0.5), V(x + 0.68, y1, z + 0.5), TIMBER, WOOD)
			)
		end
		for _, beam in beams do
			local lo, hi = V(x - 0.62, beam[1], FRONT + WALL), V(x + 0.62, beam[2], BACK - WALL)
			decor(block(ctx, "Beam", lo, hi, TIMBER, WOOD))
		end
	end
	local back = BACK - WALL / 2
	for i, x in DojoPlan.pillars do
		-- At the corners the post wraps around onto the side walls.
		local corner = i == 1 or i == #DojoPlan.pillars
		local half = if corner then WALL / 2 + 0.18 else 0.5
		decor(
			block(
				ctx,
				"Post",
				V(x - half, y0, back - 0.68),
				V(x + half, y1, back + 0.68),
				TIMBER,
				WOOD
			)
		)
	end
	for _, beam in beams do
		local lo, hi = V(-HALF - 0.1, beam[1], back - 0.62), V(HALF + 0.1, beam[2], back + 0.62)
		decor(block(ctx, "Beam", lo, hi, TIMBER, WOOD))
	end

	-- Two lit lanterns over the aisle.
	local aisle = (DojoPlan.FRONT_ROW + DojoPlan.BACK_ROW) / 2
	for _, x in { -DojoPlan.PAD_PITCH, DojoPlan.PAD_PITCH } do
		lantern(ctx, V(x, y1 - SLAB, aisle), 1.6, true)
	end

	-- A hanging scroll on the back wall, between two posts. Its face is towards the street,
	-- which from the back wall is into the room.
	local pillars = DojoPlan.pillars
	local x = (pillars[3] + pillars[4]) / 2
	local wall = BACK - WALL - 0.25
	local corner, opposite = V(x - 1.5, y0 + 4.4, wall), V(x + 1.5, y0 + 9.6, wall)
	local scroll = decor(panel(ctx, "Scroll", corner, opposite, 0.1, PAPER, Enum.Material.Fabric))
	Build.faceLabel(scroll, Enum.NormalId.Front, SCROLLS[floor] or SCROLLS[1]).TextColor3 = INK
	for _, rodY in { y0 + 4.3, y0 + 9.7 } do
		local middle, ends = V(x, rodY, wall), V(1.9, 0, 0)
		decor(rod(ctx, "ScrollRod", middle - ends, middle + ends, 0.35, TIMBER, WOOD))
	end
end

-- One flight of the staircase: steps between two stringers, and under them the ramp that
-- players actually walk on.
local function buildFlight(ctx: Ctx, flight: DojoPlan.Flight)
	local rise, run = DojoPlan.stepRise(flight), DojoPlan.stepRun(flight)
	local middle = (NEAR + FAR) / 2

	-- The ramp: one straight slope from the level below to the landing above. A step's top is
	-- level with it halfway along the step, so feet never sink far into a step or float above.
	local low = V(flight.from, flight.low, middle)
	local high = V(flight.to, flight.high, middle)
	hidden(plank(ctx, "Ramp", low, high, FAR - NEAR, 1, -0.5, STEP_WOOD))

	-- The steps. The last is half as deep: the landing begins where the ramp reaches it.
	for step = 1, DojoPlan.STEPS do
		local x0 = flight.from + (step - 0.5) * run
		local x1 = math.min(x0 + run, flight.to)
		local top = flight.low + step * rise
		local a, b = V(x0, top - rise - 0.5, NEAR + STRINGER), V(x1, top, FAR - STRINGER)
		decor(block(ctx, "Step", a, b, STEP_WOOD, PLANKS))
	end

	-- A stringer stands a hair out past the landing it runs up to: flush with the landing's
	-- side, the two flickered where they met.
	local proud = 0.06
	for _, z in { NEAR + STRINGER / 2 - proud, FAR - STRINGER / 2 + proud } do
		local a = V(flight.from, flight.low + NOSING, z)
		local b = V(flight.to, flight.high + NOSING, z)
		decor(plank(ctx, "Stringer", a, b, STRINGER + 2 * proud, 1.8, -0.9, TIMBER, WOOD))
	end
end

-- The flight that leads up to `floor` and the landing at its head, with their railings, the
-- posts under them and the lanterns hanging from the landing. `closing` gets the railing across
-- the far end of the landing, which is only there while `floor` is the top floor.
local function buildStairsTo(ctx: Ctx, closing: Ctx, floor: number)
	local flight = DojoPlan.flights[floor - 1]
	local landing = DojoPlan.landings[floor - 1]
	local y = landing.y
	buildFlight(ctx, flight)
	block(
		ctx,
		`Landing{floor}`,
		V(landing.from, y - 1, NEAR),
		V(landing.to, y, FAR),
		FLOOR_WOOD,
		PLANKS
	)
	-- The landing below carries on under this flight's first step, which starts half a step in.
	local below = DojoPlan.landings[floor - 2]
	if below then
		local lip = V(flight.from + DojoPlan.stepRun(flight) / 2, below.y, FAR)
		decor(block(ctx, "LandingLip", V(below.to, below.y - 1, NEAR), lip, FLOOR_WOOD, PLANKS))
	end

	-- On the street side the railing runs along the flight and the landing. On the first flight
	-- it starts a few steps up, so they can be stepped onto from the street; higher up it
	-- carries on from the railing of the floor below.
	local railZ = NEAR + STRINGER / 2
	local slope = (flight.high - flight.low) / (flight.to - flight.from)
	local start = if floor == 2 then flight.from + OPEN_FOOT else flight.from
	local stop = math.min(landing.to, HALF - STRINGER / 2)
	local outer = {
		V(start, flight.low + (start - flight.from) * slope, railZ),
		V(flight.to, flight.high, railZ),
		V(stop, y, railZ),
	}
	railing(ctx, outer, floor > 2)
	railing(closing, { V(stop, y, railZ), V(stop, y, FAR - STRINGER / 2) }, true)
	-- On the building side the flight has a railing of its own; the landing opens onto the floor.
	local innerZ = FAR - STRINGER / 2
	railing(ctx, { V(flight.from, flight.low, innerZ), V(flight.to, flight.high, innerZ) }, false)

	-- Posts under the street side of the landing and halfway along the flight.
	local postZ = NEAR + 0.45
	local function post(x: number, top: number)
		block(
			ctx,
			"StairPost",
			V(x - 0.4, 0, postZ - 0.4),
			V(x + 0.4, top, postZ + 0.4),
			TIMBER,
			WOOD
		)
	end
	post(landing.from + 0.5, y - 1)
	post(landing.to - 0.5, y - 1)
	local x = (flight.from + flight.to) / 2
	local height = flight.low + (x - flight.from) * slope
	if height > 3 then
		post(x, height - 1.45) -- up into the stringer, which hangs about 1.5 below the ramp
	end

	-- Big lanterns under the street side of the landing; the first landing's light the entrance.
	for _, lx in { landing.from + 1.4, landing.to - 1.6 } do
		lantern(ctx, V(lx, y - 1, NEAR + 2.2), 2, floor == 2)
	end
end

-- The open front of an upper floor: a railing in every bay between the pillars but the one the
-- landing leads into, with an invisible wall behind it.
local function buildFront(ctx: Ctx, floor: number)
	local pillars = DojoPlan.pillars
	local z = FRONT + WALL / 2
	local y = DojoPlan.level(floor)
	local from, to = DojoPlan.entrance(DojoPlan.landings[floor - 1])
	for i = 1, #pillars - 1 do
		local a, b = pillars[i] + WALL / 2, pillars[i + 1] - WALL / 2
		if b > from and a < to then
			continue -- the entrance
		end
		for _, height in { 0.3, RAIL / 2, RAIL } do
			local lo, hi = V(a, y + height - 0.32, z - 0.16), V(b, y + height, z + 0.16)
			decor(block(ctx, "Rail", lo, hi, LACQUER, WOOD))
		end
		local middle = (a + b) / 2
		local lo, hi = V(middle - 0.2, y, z - 0.2), V(middle + 0.2, y + RAIL + 0.15, z + 0.2)
		decor(block(ctx, "RailPost", lo, hi, LACQUER, WOOD))
		hidden(block(ctx, "RailGuard", V(a, y, z - 0.2), V(b, y + GUARD, z + 0.2), LACQUER))
	end

	-- A smaller roof along the side walls and the back wall, at this floor's level. It is
	-- solid: it can be reached from the end of a landing, and whoever steps onto it stands on it.
	for _, side in { -1, 1 } do
		local zFrom, zTo = FRONT - 0.5, BACK - WALL
		local zMid = (zFrom + zTo) / 2
		local a, b = V(side * HALF, y + 1.5, zMid), V(side * (HALF + 2.8), y - 0.1, zMid)
		plank(ctx, "Eave", a, b, zTo - zFrom, 0.7, -0.35, TILES, TILED)
	end
	local a, b = V(0, y + 1.5, BACK), V(0, y - 0.1, BACK + 2.8)
	plank(ctx, "Eave", a, b, 2 * HALF + 0.6, 0.7, -0.35, TILES, TILED)
end

-- A lattice screen in the bays of the ground floor that the first flight passes low in front
-- of, with an invisible wall in it: there is no room to walk under the stairs there.
local function buildLattice(ctx: Ctx)
	local pillars = DojoPlan.pillars
	local z = FRONT + WALL / 2
	local flight = DojoPlan.flights[1]
	local slope = (flight.high - flight.low) / (flight.to - flight.from)
	local top = DojoPlan.level(2) - SLAB - HEADER
	for i = 1, #pillars - 1 do
		local a, b = pillars[i] + WALL / 2, pillars[i + 1] - WALL / 2
		local clearance = flight.low + (b - flight.from) * slope
		if b > flight.from and clearance < 7 then
			local count = math.floor((b - a) / 0.9)
			local step = (b - a) / count
			for k = 1, count - 1 do
				local x = a + k * step
				decor(
					block(
						ctx,
						"Lattice",
						V(x - 0.16, 0, z - 0.25),
						V(x + 0.16, top, z + 0.25),
						TIMBER,
						WOOD
					)
				)
			end
			for _, y in { 0.6, top - 0.6 } do
				decor(
					block(
						ctx,
						"Lattice",
						V(a, y - 0.3, z - 0.3),
						V(b, y + 0.3, z + 0.3),
						TIMBER,
						WOOD
					)
				)
			end
			hidden(block(ctx, "LatticeWall", V(a, 0, z - 0.2), V(b, top, z + 0.2), TIMBER))
		end
	end
end

-- The entrance of the ground floor: the noren, two panels of indigo cloth on a pole between the
-- pillars under the first landing, which read "dojo" from the street; and a tall banner on a
-- pole at each end of the facade.
local function buildEntrance(ctx: Ctx)
	local from, to = DojoPlan.entrance(DojoPlan.landings[1])
	local top = DojoPlan.level(2) - SLAB - HEADER
	local z = FRONT + WALL + 0.12
	local gap = 0.3
	local width = (to - from - gap) / 2
	local panels: { Part } = {}
	for i = 0, 1 do
		local x0 = from + i * (width + gap)
		local a, b = V(x0, top - 3.8, z), V(x0 + width, top - 0.2, z)
		table.insert(panels, decor(panel(ctx, "Noren", a, b, 0.12, INDIGO, Enum.Material.Fabric)))
	end
	decor(rod(ctx, "NorenPole", V(from, top - 0.2, z), V(to, top - 0.2, z), 0.3, TIMBER, WOOD))
	-- The dojos across the street are mirror images, so which panel is on the left depends on
	-- the side: sort them by how far right they are for someone looking in from the street.
	local right = ctx.frame.inward:Cross(UP)
	table.sort(panels, function(a, b)
		return a.Position:Dot(right) < b.Position:Dot(right)
	end)
	for i, cloth in panels do
		Build.faceLabel(cloth, Enum.NormalId.Front, NOREN[i]).TextColor3 = PAPER
	end

	-- The banner's cloth hangs from a bar at the top of the pole, towards the middle of the
	-- facade, and faces the street.
	for _, side in { -1, 1 } do
		local x = side * (HALF - 0.4)
		local poleZ = NEAR - 0.25
		decor(column(ctx, "NoboriPole", V(x, 0, poleZ), 15, 0.4, TIMBER, WOOD))
		local toMiddle = V(-side, 0, 0)
		local bar = V(x, 14.4, poleZ)
		decor(rod(ctx, "NoboriBar", bar, bar + toMiddle * 2.3, 0.25, TIMBER, WOOD))
		local a, b = V(x, 5.4, poleZ) + toMiddle * 0.25, V(x, 14.25, poleZ) + toMiddle * 2.2
		local flag = decor(panel(ctx, "Nobori", a, b, 0.1, LACQUER, Enum.Material.Fabric))
		Build.faceLabel(flag, Enum.NormalId.Front, NOBORI).TextColor3 = PAPER
	end
end

-- The roof, built over the full three floors and moved down onto the top floor that stands:
-- tiles that rise gently from the eaves and steeply to the ridge, plaster gables, red
-- bargeboards that cross over the ridge, a wooden water tank on top as on the roofs of the Leaf
-- village, and small lanterns along the beam under the eaves.
local function buildRoof(ctx: Ctx)
	-- Each half of the roof, front and back: two slabs of tiles, slightly overlapping where the
	-- slope changes so no gap shows from below.
	for _, half in { { eave = EAVE_FRONT, dir = 1 }, { eave = 2 * MID - EAVE_FRONT, dir = -1 } } do
		local dir = half.dir
		local breakZ = half.eave + dir * BREAK
		local eave = V(0, EAVE_Y, half.eave)
		local bend = V(0, BREAK_Y, breakZ)
		local ridge = V(0, RIDGE_Y, MID)
		local lowEnd = bend + V(0, 0.5 * LOW_SLOPE, dir * 0.5)
		local highStart = bend - V(0, 0.5 * HIGH_SLOPE, dir * 0.5)
		local highEnd = ridge + V(0, 0.3 * HIGH_SLOPE, dir * 0.3)
		plank(ctx, "Roof", eave, lowEnd, 2 * EAVE_SIDE, TILE, -TILE / 2, TILES, TILED)
		plank(ctx, "Roof", highStart, highEnd, 2 * EAVE_SIDE, TILE, -TILE / 2, TILES, TILED)

		-- The gable under the steep part, set in from the ends of the roof, and the bargeboards
		-- along both ends.
		local rise = (MID - breakZ) * dir * HIGH_SLOPE
		for _, side in { -1, 1 } do
			local x = side * (HALF - WALL / 2)
			wedge(ctx, "Gable", x, breakZ, MID, TOP, rise, PLASTER, Enum.Material.Plaster)
			local edge = side * (EAVE_SIDE + 0.25)
			-- The boards lap over one another where the slope breaks and at the ridge, so no two
			-- that meet are of one thickness: their outer sides would lie in one plane and
			-- flicker. Each keeps its inner side against the end of the roof.
			local steep = if dir > 0 then 0.58 else 0.66
			for index, segment in { { eave, lowEnd }, { highStart, ridge } } do
				local thick = if index == 1 then 0.5 else steep
				local out = side * (EAVE_SIDE + thick / 2)
				local a = V(out, segment[1].Y, segment[1].Z)
				local b = V(out, segment[2].Y, segment[2].Z)
				decor(plank(ctx, "Bargeboard", a, b, thick, 1.6, -0.4, LACQUER, WOOD))
			end
			-- The bargeboards of the steep part run on past the ridge and cross over it.
			local over = V(edge, RIDGE_Y + 0.4 + 4 * HIGH_SLOPE, MID + dir * 4)
			local under = V(edge, RIDGE_Y + 0.4 - 3 * HIGH_SLOPE, MID - dir * 3)
			decor(plank(ctx, "Chigi", under, over, 0.45, 0.8, 0, LACQUER, WOOD))
		end
	end

	local ridgeA = V(-EAVE_SIDE - 0.6, RIDGE_Y - 0.4, MID - 1.1)
	local ridgeB = V(EAVE_SIDE + 0.6, RIDGE_Y + 1.2, MID + 1.1)
	-- What stands on the roof is solid, like the roof: the ridge, the logs across it and the
	-- water tank can be stood on and are not walked through.
	block(ctx, "Ridge", ridgeA, ridgeB, RIDGE, Enum.Material.Slate)
	for _, side in { -1, 1 } do
		local x = side * (EAVE_SIDE + 1)
		local a, b = V(x - 0.7, RIDGE_Y - 0.6, MID - 1.3), V(x + 0.7, RIDGE_Y + 2.2, MID + 1.3)
		block(ctx, "RidgeEnd", a, b, RIDGE, Enum.Material.Slate)
	end
	-- Short logs laid across the ridge.
	for _, x in { -20, -8, 4 } do
		local y = RIDGE_Y + 1.7
		rod(ctx, "RidgeLog", V(x, y, MID - 2.4), V(x, y, MID + 2.4), 1, TIMBER, WOOD)
	end

	-- The water tank, on legs that stand on the roof either side of the ridge.
	local tankX = 20
	local base = RIDGE_Y + 1.2
	local stand = V(3.5, 0, 3.5)
	local center = V(tankX, base, MID)
	block(ctx, "TankStand", center - stand, center + stand + V(0, 0.5, 0), TIMBER, PLANKS)
	local foot = RIDGE_Y - 3 * HIGH_SLOPE - 0.4
	for _, dx in { -3, 3 } do
		for _, dz in { -3, 3 } do
			local leg = V(tankX + dx, foot, MID + dz)
			local top = V(leg.X, base, leg.Z)
			block(ctx, "TankLeg", leg - V(0.3, 0, 0.3), top + V(0.3, 0, 0.3), TIMBER, WOOD)
		end
	end
	column(ctx, "Tank", V(tankX, base + 0.5, MID), 5.2, 5.6, TANK, WOOD)
	for _, y in { base + 1.2, base + 4.6 } do
		column(ctx, "TankBand", V(tankX, y, MID), 0.4, 5.8, IRON, Enum.Material.Metal)
	end
	column(ctx, "TankLid", V(tankX, base + 5.7, MID), 0.45, 6, TIMBER, WOOD)

	-- A small lantern in each bay along the beam over the top floor, but those in the middle.
	local beam = TOP - SLAB - HEADER
	local pillars = DojoPlan.pillars
	for i = 1, #pillars - 1 do
		local x = (pillars[i] + pillars[i + 1]) / 2
		if math.abs(x) > SIGN_HALF + 1 then
			lantern(ctx, V(x, beam, FRONT - 0.7), 1.1, false)
		end
	end
end

-- The name board, standing on the front edge of the roof on two posts: dark lacquer framed in
-- gold, with the owner's name in gold. It goes up with the roof.
local function buildSign(ctx: Ctx): TextLabel
	local z = EAVE_FRONT + 1.2
	local y0 = EAVE_Y + (z - EAVE_FRONT) * LOW_SLOPE - 0.2
	local y1 = y0 + SIGN_HEIGHT
	local w = SIGN_HALF
	local board = decor(panel(ctx, "NameBoard", V(-w, y0, z), V(w, y1, z), 0.4, INK, WOOD))
	local trim = 0.25
	local metal = Enum.Material.Metal
	for _, y in { y0, y1 } do
		local a, b = V(-w - trim, y - trim / 2, z - 0.3), V(w + trim, y + trim / 2, z + 0.3)
		decor(block(ctx, "NameBoardTrim", a, b, GOLD, metal))
	end
	for _, x in { -w, w } do
		local a, b = V(x - trim / 2, y0, z - 0.3), V(x + trim / 2, y1, z + 0.3)
		decor(block(ctx, "NameBoardTrim", a, b, GOLD, metal))
	end
	local postZ = z + 0.5
	local foot = EAVE_Y + (postZ - EAVE_FRONT) * LOW_SLOPE - 0.4
	for _, x in { -w + 2, w - 2 } do
		local a, b = V(x - 0.25, foot, postZ - 0.25), V(x + 0.25, y1 - 0.4, postZ + 0.25)
		decor(block(ctx, "NameBoardPost", a, b, TIMBER, WOOD))
	end
	local label = Build.faceLabel(board, Enum.NormalId.Front, "Empty Dojo")
	label.TextColor3 = GOLD
	return label
end

-- Puts up the first `count` floors and takes down the rest, closes off the landing of the top
-- floor and sets the roof on it.
function DojoHall.setFloors(hall: Hall, count: number)
	count = math.clamp(count, 1, DojoPlan.FLOORS)
	for floor, storey in hall.storeys do
		storey.Parent = if floor <= count then hall.folder else nil
	end
	for floor, top in hall.tops do
		top.Parent = if floor == count then hall.folder else nil
	end
	local rise = (count - hall.floors) * DojoPlan.STOREY
	if rise ~= 0 then
		local shift = V(0, rise, 0)
		for _, item in hall.roof:GetDescendants() do
			if item:IsA("BasePart") then
				item.CFrame += shift
			end
		end
	end
	hall.floors = count
end

-- Builds a dojo into `folder`, standing with one floor.
function DojoHall.build(folder: Folder, frame: Frame): Hall
	local function group(name: string): Ctx
		local child = Instance.new("Folder")
		child.Name = name
		child.Parent = folder
		return { folder = child, frame = frame }
	end
	local storeys: { Ctx } = {}
	local tops: { Ctx } = {}
	for floor = 1, DojoPlan.FLOORS do
		storeys[floor] = group(`Floor{floor}`)
		tops[floor] = group(`TopOfFloor{floor}`)
	end
	local roof = group("Roof")

	buildGround(storeys[1])
	buildEntrance(storeys[1])
	for floor = 1, DojoPlan.FLOORS do
		buildStorey(storeys[floor], floor)
		if floor >= 2 then
			buildStairsTo(storeys[floor], tops[floor], floor)
			buildFront(storeys[floor], floor)
		end
	end
	if storeys[2] then
		buildLattice(storeys[2])
	end
	buildRoof(roof)
	local sign = buildSign(roof)

	local function folders(list: { Ctx }): { Folder }
		local out = {}
		for i, ctx in list do
			out[i] = ctx.folder
		end
		return out
	end
	local hall: Hall = {
		folder = folder,
		sign = sign,
		storeys = folders(storeys),
		tops = folders(tops),
		roof = roof.folder,
		floors = DojoPlan.FLOORS,
	}
	DojoHall.setFloors(hall, 1)
	return hall
end

return DojoHall
