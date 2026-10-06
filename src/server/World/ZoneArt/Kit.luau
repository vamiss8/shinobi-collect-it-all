--!strict
-- What the zones' scenery is built with: a scene per zone (its folder, colors, random numbers
-- and a count of what was built) and the shapes to put in it. The village behind the lane's
-- start, where the dojos stand, is a scene too.
--
-- Everything made here is only to be looked at: anchored, and neither collided with nor found
-- by a ray, so no kunai, runner or camera ever notices it. Small pieces cast no shadow.
--
-- Positions are given the way a zone sees them: `along` is studs from the zone's own start down
-- the lane, `up` is height above the lane, `side` is studs from the lane's middle, negative to
-- the left of someone looking down the lane.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Hub = require("../Hub")
local Particles = require(ReplicatedStorage.Shared.View.Particles)
local ZoneArt = require(ReplicatedStorage.Shared.Config.ZoneArt)

local Kit = {}

-- The nearest to the lane's middle that scenery may stand: just outside the invisible walls.
Kit.EDGE = Hub.LANE_WIDTH / 2 + Hub.WALL_THICKNESS + 1
-- Nothing hangs over the lane below this: a kunai rises to 60 studs and the camera that
-- chases it rides 10 above that.
Kit.CLEAR = 80
-- How far out from the lane's middle a zone's own scenery stands. Past it there is only the
-- backdrop: hills, far towers, whatever closes the view.
Kit.REACH = 190
-- How far the ground itself goes on, every way: far enough for its edge to be lost in the haze
-- of the clearest zone, so that the world is never seen to end. (A part can be 2048 long.)
Kit.FAR = 2000

-- A piece whose longest side is under this casts no shadow.
local SHADOW_FROM = 10

export type Scene = {
	folder: Folder,
	id: string,
	art: ZoneArt.Art,
	from: number, -- where the scene begins on the lane, studs
	length: number,
	rng: Random,
	colors: { [string]: Color3 },
	parts: number,
	lights: number,
	-- The pieces of the zone's gate. They are the only scenery allowed to cross the lane low.
	arch: { BasePart },
	inGateway: boolean,
}

-- A scene called `id` that begins `from` studs down the lane. Its random numbers come from
-- `seed`, so the world comes out the same on every server.
function Kit.place(id: string, seed: number, art: ZoneArt.Art, from: number, length: number): Scene
	local folder = Instance.new("Folder")
	folder.Name = id

	-- A color the module asks for and its palette lacks is a mistake to be told about, not a
	-- nil to trip over later.
	local colors: { [string]: Color3 } = {}
	for name, hex in art.palette do
		colors[name] = Color3.fromHex(hex)
	end
	setmetatable(colors :: any, {
		__index = function(_, name)
			error(`{id} has no color named "{name}" in Config/ZoneArt`, 2)
		end,
	})

	return {
		folder = folder,
		id = id,
		art = art,
		from = from,
		length = length,
		rng = Random.new(seed),
		colors = colors,
		parts = 0,
		lights = 0,
		arch = {},
		inGateway = false,
	}
end

-- A scene for the zone that is `index`-th on the lane.
function Kit.scene(zone: Catalog.Zone, index: number, art: ZoneArt.Art): Scene
	return Kit.place(
		zone.id,
		index * 7919,
		art,
		zone.startsAt,
		Catalog.zoneEnd(zone) - zone.startsAt
	)
end

-- Builds the zone's gate: whatever `build` makes is marked as part of it. A gate stands where
-- the zone begins, its posts outside the walls and its beams over the lane, high enough for
-- the tallest enemy to run under and below the zone's sign, which the Hub hangs above it.
function Kit.gateway(scene: Scene, build: () -> ())
	scene.inGateway = true
	build()
	scene.inGateway = false
end

-- A point of the zone in the world.
function Kit.at(scene: Scene, along: number, up: number, side: number): Vector3
	return Hub.at(scene.from + along, up, side)
end

function Kit.material(name: string): Enum.Material
	return (Enum.Material :: any)[name]
end

local function dress(scene: Scene, part: BasePart, color: Color3, material: Enum.Material?)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local size = part.Size
	part.CastShadow = math.max(size.X, size.Y, size.Z) >= SHADOW_FROM
	part.Parent = scene.folder
	scene.parts += 1
	if scene.inGateway then
		table.insert(scene.arch, part)
	end
end

-- Marks a piece as backdrop: too far off to be worth a shadow, and a hill between the sun and
-- the lane would otherwise put a whole zone in the dark.
function Kit.backdrop<T>(part: T): T
	(part :: any).CastShadow = false
	return part
end

-- A block at any angle.
function Kit.block(
	scene: Scene,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	dress(scene, part, color, material)
	return part
end

-- A block standing square on the point under its middle, turned `turn` degrees about the
-- upright.
function Kit.box(
	scene: Scene,
	size: Vector3,
	base: Vector3,
	color: Color3,
	material: Enum.Material?,
	turn: number?
): Part
	local cframe = CFrame.new(base + Vector3.new(0, size.Y / 2, 0))
		* CFrame.Angles(0, math.rad(turn or 0), 0)
	return Kit.block(scene, size, cframe, color, material)
end

function Kit.ball(
	scene: Scene,
	diameter: number,
	center: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(diameter, diameter, diameter)
	part.CFrame = CFrame.new(center)
	dress(scene, part, color, material)
	return part
end

-- An upright cylinder standing on `base`. A cylinder part lies along its X axis, hence the turn.
function Kit.pillar(
	scene: Scene,
	height: number,
	diameter: number,
	base: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	dress(scene, part, color, material)
	return part
end

-- A bar from one point to another: a beam, a rope, a root, a pipe. Round ones are cylinders.
function Kit.rod(
	scene: Scene,
	from: Vector3,
	to: Vector3,
	thickness: number,
	color: Color3,
	material: Enum.Material?,
	round: boolean?
): Part
	local length = (to - from).Magnitude
	local middle = (from + to) / 2
	-- Looking straight up or down needs another notion of "up".
	local up = if math.abs((to - from).Unit.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local facing = CFrame.lookAt(middle, to, up)
	local part = Instance.new("Part")
	if round then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(length, thickness, thickness)
		part.CFrame = facing * CFrame.Angles(0, math.rad(90), 0)
	else
		part.Size = Vector3.new(thickness, thickness, length)
		part.CFrame = facing
	end
	dress(scene, part, color, material)
	return part
end

-- A wedge: a block cut corner to corner. Its tall side is its back (+Z), and the slope faces
-- up and to its front.
function Kit.wedge(
	scene: Scene,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local part = Instance.new("WedgePart")
	part.Size = size
	part.CFrame = cframe
	dress(scene, part, color, material)
	return part
end

-- A pitched roof, solid from every side: two wedges back to back under one ridge. `ridge` is
-- the middle of the ridge line, `length` runs along it, `reach` is how far each side goes out
-- from under it, flat on the ground, and `pitch` is the slope in degrees. The ridge runs down
-- the lane unless `across`.
--
-- It used to be two slabs leaning together, and from either end one looked straight through.
function Kit.roof(
	scene: Scene,
	ridge: Vector3,
	length: number,
	reach: number,
	pitch: number,
	color: Color3,
	material: Enum.Material?,
	across: boolean?
)
	local rise = reach * math.tan(math.rad(pitch))
	for _, side in { -1, 1 } do
		-- Each half is turned so that its tall back stands under the ridge.
		local out, turn
		if across then
			out = Vector3.new(side * reach / 2, -rise / 2, 0)
			turn = -side * math.pi / 2
		else
			out = Vector3.new(0, -rise / 2, side * reach / 2)
			turn = if side == 1 then math.pi else 0
		end
		Kit.wedge(
			scene,
			Vector3.new(length, rise, reach),
			CFrame.new(ridge + out) * CFrame.Angles(0, turn, 0),
			color,
			material
		)
	end
end

-- A hill: the top of a great ball sunk into the ground, `height` tall over `foot` and `radius`
-- wide where it meets the ground. Taller than it is wide, it bulges out above its foot.
function Kit.mound(
	scene: Scene,
	foot: Vector3,
	radius: number,
	height: number,
	color: Color3,
	material: Enum.Material?
): Part
	local ball = (radius * radius + height * height) / (2 * height)
	local part = Kit.ball(scene, ball * 2, foot + Vector3.new(0, height - ball, 0), color, material)
	return Kit.backdrop(part)
end

-- A boulder: a block sunk a little into the ground and turned at random.
function Kit.rock(
	scene: Scene,
	at: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local rng = scene.rng
	local turned = CFrame.new(at + Vector3.new(0, size.Y * 0.35, 0))
		* CFrame.Angles(
			math.rad(rng:NextNumber(-12, 12)),
			math.rad(rng:NextNumber(0, 180)),
			math.rad(rng:NextNumber(-12, 12))
		)
	return Kit.block(scene, size, turned, color, material or Enum.Material.Slate)
end

-- A tree: a trunk and a crown of one ball, or of `crowns` balls bunched together.
function Kit.tree(
	scene: Scene,
	at: Vector3,
	trunkHeight: number,
	trunkWidth: number,
	crown: number,
	bark: Color3,
	leaves: Color3,
	crowns: number?
)
	Kit.pillar(scene, trunkHeight, trunkWidth, at, bark, Enum.Material.Wood)
	local top = at + Vector3.new(0, trunkHeight + crown * 0.3, 0)
	Kit.ball(scene, crown, top, leaves, Enum.Material.Grass)
	for i = 2, crowns or 1 do
		local turn = i * 2.4
		local off = Vector3.new(math.cos(turn), -0.25, math.sin(turn)) * crown * 0.45
		Kit.ball(scene, crown * 0.7, top + off, leaves, Enum.Material.Grass)
	end
end

-- Both stretches of the zone's ground, either side of the lane and all the way out to Kit.FAR.
-- They lie a hair above the grass that is under the playable world, and begin at the lane's
-- very edge: begun outside the walls, they left a strip of that grass along the lane in every
-- zone, bright green in the cave and on the sea.
function Kit.ground(scene: Scene): { Part }
	local surface = scene.art.ground
	local near = Hub.LANE_WIDTH / 2
	local width = Kit.FAR - near
	local parts = {}
	for _, side in { -1, 1 } do
		local part = Kit.block(
			scene,
			Vector3.new(scene.length, 1, width),
			CFrame.new(Kit.at(scene, scene.length / 2, -0.55, side * (near + width / 2))),
			Color3.fromHex(surface.color),
			Kit.material(surface.material)
		)
		part.CastShadow = false
		table.insert(parts, part)
	end
	return parts
end

-- The ground past the far end of the lane, for the last zone: the world goes on there too.
function Kit.beyond(scene: Scene): { Part }
	local surface = scene.art.ground
	local parts = {}
	for _, side in { -1, 1 } do
		local part = Kit.block(
			scene,
			Vector3.new(Kit.FAR, 1, Kit.FAR),
			CFrame.new(Kit.at(scene, scene.length + Kit.FAR / 2, -0.55, side * Kit.FAR / 2)),
			Color3.fromHex(surface.color),
			Kit.material(surface.material)
		)
		part.CastShadow = false
		table.insert(parts, part)
	end
	return parts
end

-- A light on a piece of scenery. Kept few, and none of them casts shadows.
function Kit.light(scene: Scene, part: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
	scene.lights += 1
end

-- Particles coming off a piece of scenery: a flame in a bowl, the spray of a waterfall.
function Kit.emit(part: BasePart, layer: Particles.Layer, color: Color3)
	Particles.emitter(layer, color).Parent = part
end

-- A number between two, from the scene's own random numbers.
function Kit.pick(scene: Scene, low: number, high: number): number
	return scene.rng:NextNumber(low, high)
end

-- One of the given colors.
function Kit.oneOf(scene: Scene, colors: { Color3 }): Color3
	return colors[scene.rng:NextInteger(1, #colors)]
end

return Kit
