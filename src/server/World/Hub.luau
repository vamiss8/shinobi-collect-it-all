--!strict
-- The shared part of the placeholder world, built once at startup: the lane with its zones, the
-- throwing strip across its start, and the walls that keep players on it. Everyone throws from
-- the same strip. The dojos along the street belong to World/Plots, the stalls to World/Market.
--
-- Hub-local coordinates, used for everything in the world: x is distance down the lane (0 is
-- where the lane starts; the street and the dojos are at negative x), y is height above the
-- floor, z is sideways from the center line.

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Chase = require(ReplicatedStorage.Shared.Logic.Chase)
local Format = require(ReplicatedStorage.Shared.Logic.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Roll = require(ReplicatedStorage.Shared.Logic.Roll)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Hub = {}

-- World position of the lane start at floor level. The floor sits one stud above the template
-- baseplate so the two never z-fight, and off to the side of the template's spawn pad.
local ORIGIN = Vector3.new(-780, 1, 300)
local LANE_WIDTH = 60
-- Invisible walls keep players on the map; too tall to jump over.
local WALL_HEIGHT = 80
local WALL_THICKNESS = 2
-- The gate across the lane behind the throwing strip stops players from walking into the zones.
-- Someone running home from a throw is put in the runner group, which passes through it.
-- Every other character is in the player group. Characters pass through one another whatever
-- group they are in: a player who bumps into one sitting in meditation would otherwise knock
-- them out of it, or send them flying.
local GATE_GROUP = "Gate"
local RUNNER_GROUP = "Runner"
local PLAYER_GROUP = "Player"

Hub.LANE_WIDTH = LANE_WIDTH
Hub.WALL_HEIGHT = WALL_HEIGHT
Hub.WALL_THICKNESS = WALL_THICKNESS

-- How far the grass reaches past the playable area, studs. More past the far end of the lane,
-- where Scenery stands a colossal tree.
local GROUND_MARGIN = 40
local FAR_END_MARGIN = 200

local WOOD = Color3.fromRGB(121, 85, 61)
local STONE = Color3.fromRGB(99, 95, 98)
local GRASS = Color3.fromRGB(104, 159, 56)

-- Hub-local coordinates to a world position.
function Hub.at(x: number, y: number, z: number): Vector3
	return ORIGIN + Vector3.new(x, y, z)
end

-- World position to hub-local coordinates.
function Hub.toLocal(position: Vector3): Vector3
	return position - ORIGIN
end

-- Whether a world position is on the throwing strip.
function Hub.onStrip(position: Vector3): boolean
	local p = position - ORIGIN
	return p.X >= 0
		and p.X <= Tuning.Kick.stripDepth
		and math.abs(p.Z) <= LANE_WIDTH / 2
		and p.Y > -2
		and p.Y < 12
end

-- The collision group of each character. Parts that arrive after the body, such as
-- accessories and the shinobi carried overhead, take the group the character has by then.
local groups: { [Model]: string } = {}

local function setGroup(character: Model, group: string)
	groups[character] = group
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = group
		end
	end
end

-- Lets a character through the gate behind the strip (while it runs home), or blocks it again.
function Hub.setRunner(character: Model, isRunner: boolean)
	setGroup(character, if isRunner then RUNNER_GROUP else PLAYER_GROUP)
end

-- Puts a freshly spawned character in the player group and keeps its later parts in step.
local function adopt(character: Model)
	setGroup(character, PLAYER_GROUP)
	character.DescendantAdded:Connect(function(part)
		if part:IsA("BasePart") then
			part.CollisionGroup = groups[character] or PLAYER_GROUP
		end
	end)
	character.Destroying:Connect(function()
		groups[character] = nil
	end)
end

function Hub.start()
	local folder = Instance.new("Folder")
	folder.Name = Net.HUB_FOLDER
	-- Clients read this to turn world positions into distances down the lane.
	folder:SetAttribute(Net.ORIGIN_ATTRIBUTE, ORIGIN)

	-- Grass under everything, a touch below floor level so nothing z-fights with it. It shows
	-- through the gaps between the dojos, the street and the lane. Two slabs, because a part
	-- cannot be longer than 2048 studs.
	local length = Tuning.Kick.trackLength
	for _, span in { { -GROUND_MARGIN - 220, 0 }, { 0, length + FAR_END_MARGIN } } do
		Build.part(
			folder,
			"Ground",
			Vector3.new(span[2] - span[1], 1, LANE_WIDTH + 2 * GROUND_MARGIN + 100),
			Hub.at((span[1] + span[2]) / 2, -0.6, 0),
			GRASS,
			Enum.Material.Grass
		)
	end

	-- The lane: one slab per zone, a marker line where each zone begins and a sign naming it.
	for i, zone in Catalog.zones do
		local following = Catalog.zones[i + 1]
		local finish = if following then following.startsAt else Tuning.Kick.trackLength
		local zoneLength = finish - zone.startsAt
		Build.part(
			folder,
			`Lane_{zone.id}`,
			Vector3.new(zoneLength, 1, LANE_WIDTH),
			Hub.at(zone.startsAt + zoneLength / 2, -0.5, 0),
			Color3.fromHex(zone.color),
			Enum.Material.Grass
		)

		-- The first zone begins at the throwing strip; the others get a plain line.
		local marker: Part
		if i == 1 then
			marker = Build.part(
				folder,
				"ThrowStrip",
				Vector3.new(Tuning.Kick.stripDepth, 0.2, LANE_WIDTH),
				Hub.at(Tuning.Kick.stripDepth / 2, 0.1, 0),
				Color3.fromRGB(255, 152, 0),
				Enum.Material.Neon
			)
			Build.label(marker, "THROW", 5, Vector2.new(14, 4))
		else
			marker = Build.part(
				folder,
				`Line_{zone.id}`,
				Vector3.new(1, 0.2, LANE_WIDTH),
				Hub.at(zone.startsAt + 0.5, 0.1, 0),
				Color3.new(1, 1, 1),
				Enum.Material.Neon
			)
		end
		marker.CanCollide = false

		-- Past the first zone the sign hangs above the gate that Scenery raises at each border.
		local signAt = if i == 1 then Tuning.Kick.stripDepth + 14 else zone.startsAt + 0.5
		local signHeight = if i == 1 then 14 else 32
		local post =
			Build.part(folder, `Sign_{zone.id}`, Vector3.one, Hub.at(signAt, signHeight, 0), WOOD)
		post.Transparency = 1
		post.CanCollide = false
		local rank = Catalog.ranks[Catalog.rankOrder[zone.rank]]
		local slowest = Format.short(zone.enemy.speed)
		local fastest = Format.short(Chase.farSpeed(zone))
		local lines = {
			zone.name,
			`<font color="{rank.color}">{rank.name}</font>  |  {Format.short(zone.chakra)}+ Chakra`,
			`<font color="#FF8A80">{zone.enemy.name} - speed {slowest} to {fastest}</font>`,
		}
		-- The last zone rewards depth with mutation luck (see Roll.depthMutationLuck).
		local deepLuck = Roll.depthMutationLuck(zone, finish)
		if deepLuck > 1 then
			table.insert(
				lines,
				`<font color="#B39DDB">the deeper, the luckier: up to x{Format.short(deepLuck)} mutations</font>`
			)
		end
		Build.label(post, table.concat(lines, "\n"), 0, Vector2.new(40, 4 * #lines))
	end

	Build.part(
		folder,
		"LaneEnd",
		Vector3.new(2, 24, LANE_WIDTH),
		Hub.at(length + 1, 11, 0),
		STONE,
		Enum.Material.Slate
	)

	-- Invisible walls along both sides of the lane and past its end, so nobody runs off it or
	-- around it, and the one-way gate behind the strip.
	for _, side in { -1, 1 } do
		Build.wall(
			folder,
			"LaneWall",
			Vector3.new(length, WALL_HEIGHT, WALL_THICKNESS),
			Hub.at(length / 2, WALL_HEIGHT / 2, side * (LANE_WIDTH + WALL_THICKNESS) / 2)
		)
	end
	Build.wall(
		folder,
		"LaneEndWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, LANE_WIDTH),
		Hub.at(length + 2 + WALL_THICKNESS / 2, WALL_HEIGHT / 2, 0)
	)

	-- Registering a group twice is an error, and groups saved with the place persist.
	for _, group in { GATE_GROUP, RUNNER_GROUP, PLAYER_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(GATE_GROUP, RUNNER_GROUP, false)
	for _, pair in
		{
			{ PLAYER_GROUP, PLAYER_GROUP },
			{ PLAYER_GROUP, RUNNER_GROUP },
			{ RUNNER_GROUP, RUNNER_GROUP },
		}
	do
		PhysicsService:CollisionGroupSetCollidable(pair[1], pair[2], false)
	end

	-- The groups exist from here on, so characters can be sorted into them.
	local function watch(player: Player)
		player.CharacterAdded:Connect(adopt)
		if player.Character then
			adopt(player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	local gate = Build.wall(
		folder,
		"Gate",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, LANE_WIDTH),
		Hub.at(Tuning.Kick.stripDepth + WALL_THICKNESS / 2, WALL_HEIGHT / 2, 0)
	)
	gate.CollisionGroup = GATE_GROUP

	-- A signpost beside the strip. Each client hangs its own luck board on the top part, since
	-- the countdown to the next lucky throw is different for every player.
	Build.part(folder, "LuckPost", Vector3.new(1, 9, 1), Hub.at(-5, 4.5, -24), WOOD)
	local board =
		Build.part(folder, Net.LUCK_BOARD, Vector3.new(1, 1, 1), Hub.at(-5, 11, -24), WOOD)
	board.Transparency = 1
	board.CanCollide = false

	folder.Parent = Workspace
end

return Hub
