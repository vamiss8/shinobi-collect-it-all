--!strict
-- Builds the zones' scenery outside Roblox, so that what Studio would show can be counted and
-- checked here. The real builders (src/server/World/ZoneArt) are loaded as they are and run
-- against Lune's own Instances and data types; only what they reach for in the game is stood
-- in for: the Hub's coordinates (here the lane starts at the origin), the services, and random
-- numbers, which come from a plain generator so that every run is the same.
--
-- Not a spec itself: tests/ZoneBuild.spec and `lune run zones` use it.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Catalog = require("../src/shared/Config/Catalog")
local Looks = require("../src/shared/Config/ZoneArt")
local Tuning = require("../src/shared/Config/Tuning")

local Zones = {}

local SOURCE = "src/server/World/ZoneArt/"

-- The Hub's numbers the scenery goes by (src/server/World/Hub).
Zones.LANE_WIDTH = 60
Zones.WALL_THICKNESS = 2
-- How far out a zone's own scenery stands and how far its ground goes on (ZoneArt/Kit).
Zones.REACH = 190
Zones.FAR = 2000
-- The village round the dojos is built as a scene of this name.
Zones.HOME = "home"
-- The place's own spawn pad lies at the world's origin, which the Hub's coordinates put here:
-- 780 studs down the lane and 300 to its left. A player stands on it for a moment before being
-- sent to a dojo.
Zones.SPAWN = { along = 780, side = -300 }

-- A stand-in for Roblox's Random: the same numbers for the same seed, every run.
local FakeRandom = {}
FakeRandom.__index = FakeRandom

function FakeRandom.new(seed: number?)
	return setmetatable({ state = (seed or 1) % 2147483648 }, FakeRandom)
end

function FakeRandom.step(self: any): number
	self.state = (self.state * 1103515245 + 12345) % 2147483648
	return self.state / 2147483648
end

function FakeRandom.NextNumber(self: any, low: number?, high: number?): number
	local share = FakeRandom.step(self)
	if low == nil or high == nil then
		return share
	end
	return low + share * (high - low)
end

function FakeRandom.NextInteger(self: any, low: number, high: number): number
	return low + math.floor(FakeRandom.step(self) * (high - low + 1))
end

local hub = {
	LANE_WIDTH = Zones.LANE_WIDTH,
	WALL_THICKNESS = Zones.WALL_THICKNESS,
	WALL_HEIGHT = 80,
	at = function(x: number, y: number, z: number)
		return roblox.Vector3.new(x, y, z)
	end,
}

-- Particles are not looked at here: an emitter is anything that can be given a parent.
local particles = {
	SPARKLE = "sparkle",
	FIRE = "fire",
	SMOKE = "smoke",
	emitter = function()
		return {}
	end,
}

-- What `require(ReplicatedStorage.Shared...)` finds: a tree of markers, each standing for a
-- module that is loaded here by its file.
local markers: { [any]: any } = {}
local function marker(value: any): any
	local key = {}
	markers[key] = value
	return key
end

local replicated = {
	Shared = {
		Config = { Catalog = marker(Catalog), ZoneArt = marker(Looks), Tuning = marker(Tuning) },
		View = { Particles = marker(particles) },
	},
}

-- Builds an environment the game's own source can run in. `siblings` says what its string
-- requires resolve to.
local function environment(siblings: (path: string) -> any): { [string]: any }
	local workspace = roblox.Instance.new("Folder")
	return {
		game = {
			GetService = function(_, name: string): any
				if name == "ReplicatedStorage" then
					return replicated
				elseif name == "Workspace" then
					return workspace
				end
				error(`the zone harness has no service {name}`)
			end,
		},
		require = function(what: any): any
			if typeof(what) == "string" then
				return siblings(what)
			end
			local value = markers[what]
			if value == nil then
				error("the zone harness cannot require that")
			end
			return value
		end,
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		Random = FakeRandom,
	}
end

-- Runs a piece of the game's source in `scope` and returns what it returns.
local function run(source: string, name: string, scope: { [string]: any }): any
	local chunk = luau.load(luau.compile(source), { debugName = name, environment = scope })
	return chunk()
end

local modules: { [string]: any } = {}
local scope: { [string]: any }

local function load(name: string): any
	if modules[name] == nil then
		modules[name] = run(fs.readFile(SOURCE .. name .. ".luau"), name, scope)
	end
	return modules[name]
end

scope = environment(function(path: string): any
	if path == "./Kit" then
		return load("Kit")
	elseif path == "../Hub" then
		return hub
	end
	error(`the zone harness does not know {path}`)
end)

export type Built = {
	id: string,
	parts: { any }, -- the scene's parts, in the order they were made
	gate: { [any]: boolean }, -- which of them are its gate
	lights: number,
	from: number,
	to: number,
}

local function built(scene: any, from: number, to: number): Built
	local gate: { [any]: boolean } = {}
	for _, part in scene.arch do
		gate[part] = true
	end
	return {
		id = scene.id,
		parts = scene.folder:GetChildren(),
		gate = gate,
		lights = scene.lights,
		from = from,
		to = to,
	}
end

-- Builds one zone's scenery, or the village's when asked for Zones.HOME, and returns what it
-- is made of.
function Zones.build(id: string): Built
	local kit = load("Kit")
	if id == Zones.HOME then
		-- As World/ZoneArt builds it.
		local scene = kit.place(Zones.HOME, 104729, Looks.village, 0, 0)
		load(Zones.HOME)(scene)
		return built(scene, 0, 0)
	end
	local zone = Catalog.zoneById[id]
	local scene = kit.scene(zone, Catalog.zoneOrder[id], Looks.zones[id])
	load(id)(scene)
	return built(scene, zone.startsAt, Catalog.zoneEnd(zone))
end

-- The box a part fits in, along the world's axes: its lowest and highest corner. A ball that
-- is sunk into the ground, as a hill is, is taken by what shows of it: it is as wide as it is
-- where it meets the ground, or at its middle if that is above ground.
function Zones.bounds(part: any): (any, any)
	local frame = part.CFrame
	if part.ClassName == "Part" and part.Shape == roblox.Enum.PartType.Ball then
		local radius = part.Size.X / 2
		local middle = frame.Position
		local wide = if middle.Y < 0
			then math.sqrt(math.max(radius * radius - middle.Y * middle.Y, 0))
			else radius
		return roblox.Vector3.new(middle.X - wide, middle.Y - radius, middle.Z - wide),
			roblox.Vector3.new(middle.X + wide, middle.Y + radius, middle.Z + wide)
	end
	local half = part.Size / 2
	local right, up, look = frame.RightVector, frame.UpVector, frame.LookVector
	local reach = roblox.Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
	)
	return frame.Position - reach, frame.Position + reach
end

-- What shape a part is: a wedge has no Shape of its own.
function Zones.shape(part: any): string
	return if part.ClassName == "Part" then part.Shape.Name else part.ClassName
end

-- One part as plain numbers and names, for comparing two builds piece by piece.
function Zones.describe(part: any): { any }
	local size = part.Size
	local color = part.Color
	local described: { any } = {
		part.ClassName,
		Zones.shape(part),
		part.Material.Name,
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255),
		size.X,
		size.Y,
		size.Z,
	}
	for _, component in { part.CFrame:GetComponents() } do
		table.insert(described, component)
	end
	return described
end

Zones.hub = hub

return Zones
