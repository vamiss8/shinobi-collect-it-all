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
local Net = require(ReplicatedStorage.Shared.Net)
local Signs = require(ReplicatedStorage.Shared.Logic.Signs)
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
-- where the last zone's scenery stands a colossal tree.
local GROUND_MARGIN = 40
local FAR_END_MARGIN = 200

local WOOD = Color3.fromRGB(121, 85, 61)
local STONE = Color3.fromRGB(99, 95, 98)
local GRASS = Color3.fromRGB(104, 159, 56)
-- The throwing strip.
local PLANKS = Color3.fromRGB(96, 68, 52)
local DARK_WOOD = Color3.fromRGB(62, 44, 36)
local CHAKRA = Color3.fromRGB(79, 195, 247)
local PAPER = Color3.fromRGB(236, 220, 188)
local ROPE = Color3.fromRGB(196, 172, 128)
local LANTERN = Color3.fromRGB(255, 196, 120)
local POST_HEIGHT = 10

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

-- The throwing strip: a deck of dark planks across the start of the lane. A thin line of
-- Chakra runs along the edge the kunai are thrown over, motes of it drift up from the boards,
-- the strip's name is painted on them, and a rope hung with paper tags spans the lane between
-- two lantern posts. Only the line and the lanterns glow.
local function buildStrip(folder: Folder): Part
	local depth = Tuning.Kick.stripDepth
	local strip = Build.part(
		folder,
		"ThrowStrip",
		Vector3.new(depth, 0.2, LANE_WIDTH),
		Hub.at(depth / 2, 0.1, 0),
		PLANKS,
		Enum.Material.WoodPlanks
	)

	-- A piece that is only there to be looked at.
	local function piece(
		name: string,
		size: Vector3,
		at: Vector3,
		color: Color3,
		material: Enum.Material?
	): Part
		local part = Build.part(folder, name, size, at, color, material)
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		return part
	end

	local beam = Vector3.new(0.5, 0.3, LANE_WIDTH)
	piece("StripBack", beam, Hub.at(0.25, 0.15, 0), DARK_WOOD, Enum.Material.Wood)
	piece("StripFront", beam, Hub.at(depth - 0.25, 0.15, 0), DARK_WOOD, Enum.Material.Wood)
	local line = piece(
		"StripLine",
		Vector3.new(0.2, 0.06, LANE_WIDTH),
		Hub.at(depth - 0.25, 0.33, 0),
		CHAKRA,
		Enum.Material.Neon
	)
	line.Transparency = 0.2

	-- The name, painted on the boards so that it reads the right way up for someone facing
	-- down the lane: the unseen slab lies flat, its front face up and its top towards the lane.
	local paint = piece("StripName", Vector3.new(34, 6, 0.05), Hub.at(depth / 2, 0.24, 0), PAPER)
	paint.Transparency = 1
	paint.CFrame = CFrame.lookAt(paint.Position, paint.Position + Vector3.yAxis, Vector3.xAxis)
	local name = Build.faceLabel(paint, Enum.NormalId.Front, "THROW")
	name.TextColor3 = PAPER
	name.TextTransparency = 0.15

	-- Motes of Chakra rising from all over the deck.
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Rate = 16
	motes.Lifetime = NumberRange.new(2, 3.5)
	motes.Speed = NumberRange.new(1.2, 2.6)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.SpreadAngle = Vector2.new(12, 12)
	motes.Acceleration = Vector3.new(0, 0.4, 0)
	motes.Rotation = NumberRange.new(0, 360)
	motes.RotSpeed = NumberRange.new(-40, 40)
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.3, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.2),
		NumberSequenceKeypoint.new(0.7, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Color = ColorSequence.new(CHAKRA, Color3.fromRGB(225, 245, 254))
	motes.LightEmission = 0.7
	motes.LightInfluence = 0
	motes.Parent = strip

	-- A post at each end of the far edge, a lantern hanging on its inner side.
	local postX = depth - 1
	for _, side in { -1, 1 } do
		local z = side * (LANE_WIDTH / 2 - 1.5)
		Build.part(
			folder,
			"StripPost",
			Vector3.new(1, POST_HEIGHT, 1),
			Hub.at(postX, POST_HEIGHT / 2, z),
			DARK_WOOD,
			Enum.Material.Wood
		)
		piece(
			"StripPostCap",
			Vector3.new(1.6, 0.4, 1.6),
			Hub.at(postX, POST_HEIGHT + 0.2, z),
			DARK_WOOD,
			Enum.Material.Wood
		)
		piece(
			"LanternArm",
			Vector3.new(0.3, 0.3, 2.2),
			Hub.at(postX, POST_HEIGHT - 1, z - side * 1.1),
			DARK_WOOD,
			Enum.Material.Wood
		)
		local lanternAt = Hub.at(postX, POST_HEIGHT - 2.3, z - side * 1.7)
		local lantern =
			piece("Lantern", Vector3.new(1.3, 1.8, 1.3), lanternAt, LANTERN, Enum.Material.Neon)
		for _, lift in { -1, 1 } do
			piece(
				"LanternCap",
				Vector3.new(1.5, 0.25, 1.5),
				lanternAt + Vector3.new(0, lift, 0),
				DARK_WOOD,
				Enum.Material.Wood
			)
		end
		local light = Instance.new("PointLight")
		light.Color = LANTERN
		light.Range = 18
		light.Brightness = 1.2
		light.Parent = lantern
	end

	piece(
		"StripRope",
		Vector3.new(0.25, 0.25, LANE_WIDTH - 3),
		Hub.at(postX, POST_HEIGHT - 0.4, 0),
		ROPE,
		Enum.Material.Fabric
	)
	for i = -3, 3 do
		piece(
			"StripTag",
			Vector3.new(0.08, 1.3, 0.8),
			Hub.at(postX, POST_HEIGHT - 1.2, i * 7),
			PAPER
		)
	end

	return strip
end

-- A zone's sign: a board across the lane where the zone begins, with its name and what it asks
-- of a thrower written on both faces, so that it reads from the strip and on the run home. Where
-- it hangs and what it says is in Logic/Signs; the zone's scenery (World/ZoneArt) paints the
-- board and builds a frame round it in the zone's own style.
local function buildSign(folder: Folder, zone: Catalog.Zone, boarded: boolean)
	local box = Signs.box(zone)
	local board = Build.part(
		folder,
		`Sign_{zone.id}`,
		Vector3.new(Signs.THICKNESS, box.height, box.width),
		Hub.at(box.along, (box.foot + box.top) / 2, 0),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)
	board.CanCollide = false
	board.CanQuery = false
	board.CastShadow = false
	board.Transparency = if boarded then 0 else 1

	-- The faces that look up the lane and down it. Writing on a part's side reads the right way
	-- round from outside whichever side it is.
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		-- The name's row comes out 100 pixels tall, the largest that scaled text is drawn at.
		gui.PixelsPerStud = 24
		-- Lit by itself, as the floating labels were: it has to be read at night too.
		gui.LightInfluence = 0
		gui.Parent = board

		-- A row of writing, `top` studs below the board's top edge and `tall` studs high.
		local function row(text: string, top: number, tall: number)
			local label = Instance.new("TextLabel")
			label.Position = UDim2.fromScale(0.03, top / box.height)
			label.Size = UDim2.fromScale(0.94, tall / box.height)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.PermanentMarker
			label.TextScaled = true
			label.RichText = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0.4
			label.Text = text
			label.Parent = gui
		end
		row(`<font color="#{PAPER:ToHex()}">{zone.name}</font>`, Signs.MARGIN, Signs.NAME)
		for line, text in Signs.details(zone) do
			row(text, Signs.MARGIN + Signs.NAME + (line - 1) * Signs.LINE, Signs.LINE)
		end
	end
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
			marker = buildStrip(folder)
			Build.label(marker, "THROW", 5, Vector2.new(14, 4)).TextColor3 = PAPER
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

		-- The first sign hangs in front of whoever stands on the strip, so it is writing with
		-- nothing behind it: a board there would stand in the thrower's view.
		buildSign(folder, zone, i > 1)
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
