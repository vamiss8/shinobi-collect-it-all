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
		workspaceForTests = workspace,
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
	parts: { any }, -- the zone's parts, in the order they were made
	gate: { [any]: boolean }, -- which of them are its gate
	lights: number,
	from: number,
	to: number,
}

-- Builds one zone's scenery and returns what it is made of.
function Zones.build(id: string): Built
	local zone = Catalog.zoneById[id]
	local scene = load("Kit").scene(zone, Catalog.zoneOrder[id], Looks.zones[id])
	load(id)(scene)
	local gate: { [any]: boolean } = {}
	for _, part in scene.arch do
		gate[part] = true
	end
	return {
		id = id,
		parts = scene.folder:GetChildren(),
		gate = gate,
		lights = scene.lights,
		from = zone.startsAt,
		to = Catalog.zoneEnd(zone),
	}
end

-- The box a part fits in, along the world's axes: its lowest and highest corner.
function Zones.bounds(part: any): (any, any)
	local half = part.Size / 2
	local frame = part.CFrame
	local right, up, look = frame.RightVector, frame.UpVector, frame.LookVector
	local reach = roblox.Vector3.new(
		math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z,
		math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z,
		math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
	)
	return frame.Position - reach, frame.Position + reach
end

-- One part as plain numbers and names, for comparing two builds piece by piece.
function Zones.describe(part: any): { any }
	local size = part.Size
	local color = part.Color
	local described: { any } = {
		part.ClassName,
		part.Shape.Name,
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

-- Runs source that is not one of the zone modules: the old scenery, to make the last zone's
-- reference from. `siblings` resolves its string requires; returns what the source returns and
-- the folder standing in for Workspace.
function Zones.runOther(source: string, siblings: { [string]: any }): (any, any)
	local other = environment(function(path: string): any
		local value = siblings[path]
		if value == nil then
			error(`the zone harness does not know {path}`)
		end
		return value
	end)
	return run(source, "other", other), other.workspaceForTests
end

Zones.hub = hub

return Zones
