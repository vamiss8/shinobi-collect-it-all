--!strict
-- Decorations for the lane, built from plain parts. Every zone gets its own kind of scenery on
-- the strips of ground either side of the lane, beyond the invisible walls, and a gate where it
-- begins. None of it can be touched or walked on; it only sets the place apart from the others.
-- Placement is seeded per zone, so the world looks the same on every server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Hub = require("./Hub")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Scenery = {}

-- How close to the lane's center line a prop may stand, and how far out props go, studs.
local NEAR = Hub.LANE_WIDTH / 2 + 10
local FAR = NEAR + 54
-- Width of the tinted strip of ground on each side of the lane.
local STRIP_WIDTH = 70

type Theme = {
	ground: Color3,
	material: Enum.Material,
	spacing: number, -- average distance between props along the lane, studs
	-- Builds one prop standing on the ground at `at`. `side` is -1 or 1: which side of the lane.
	place: (folder: Folder, rng: Random, at: Vector3, side: number) -> (),
}

local function block(
	parent: Instance,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function ball(
	parent: Instance,
	diameter: number,
	center: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = block(
		parent,
		Vector3.new(diameter, diameter, diameter),
		CFrame.new(center),
		color,
		material
	)
	part.Shape = Enum.PartType.Ball
	return part
end

-- An upright cylinder standing on `base`. A cylinder part lies along its X axis, hence the turn.
local function column(
	parent: Instance,
	height: number,
	diameter: number,
	base: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local upright = CFrame.new(base + Vector3.new(0, height / 2, 0))
		* CFrame.Angles(0, 0, math.rad(90))
	local part = block(parent, Vector3.new(height, diameter, diameter), upright, color, material)
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- A boulder: a block sunk a little into the ground and turned at random.
local function rock(parent: Instance, rng: Random, at: Vector3, size: Vector3, color: Color3)
	local turned = CFrame.new(at + Vector3.new(0, size.Y * 0.35, 0))
		* CFrame.Angles(
			math.rad(rng:NextNumber(-12, 12)),
			math.rad(rng:NextNumber(0, 180)),
			math.rad(rng:NextNumber(-12, 12))
		)
	block(parent, size, turned, color, Enum.Material.Slate)
end

local function tree(
	parent: Instance,
	at: Vector3,
	trunkHeight: number,
	trunkWidth: number,
	crown: number,
	bark: Color3,
	leaves: Color3
)
	column(parent, trunkHeight, trunkWidth, at, bark, Enum.Material.Wood)
	ball(
		parent,
		crown,
		at + Vector3.new(0, trunkHeight + crown * 0.3, 0),
		leaves,
		Enum.Material.Grass
	)
end

local BARK = Color3.fromRGB(109, 76, 65)
local DARK_BARK = Color3.fromRGB(62, 39, 35)
local STONE = Color3.fromRGB(117, 117, 117)
local PALE_STONE = Color3.fromRGB(189, 183, 171)
local CLAY = Color3.fromRGB(214, 172, 108)

-- Depth of one tier of the arena's stands, and the colors its spectators come in.
local TIER_DEPTH = 5
local SEAT_WIDTH = 3.5
local CROWD = {
	Color3.fromRGB(229, 115, 115),
	Color3.fromRGB(100, 181, 246),
	Color3.fromRGB(255, 213, 79),
	Color3.fromRGB(129, 199, 132),
	Color3.fromRGB(245, 245, 245),
}

local THEMES: { [string]: Theme } = {
	-- Training grounds: young trees, practice posts and targets.
	academy = {
		ground = Color3.fromRGB(124, 179, 66),
		material = Enum.Material.Grass,
		spacing = 12,
		place = function(folder, rng, at)
			local pick = rng:NextNumber()
			if pick < 0.6 then
				tree(
					folder,
					at,
					rng:NextNumber(6, 9),
					1.6,
					rng:NextNumber(8, 11),
					BARK,
					Color3.fromRGB(104, 159, 56)
				)
			elseif pick < 0.85 then
				-- A practice post with a red band.
				column(folder, 6, 1.6, at, BARK, Enum.Material.Wood)
				column(
					folder,
					0.8,
					1.8,
					at + Vector3.new(0, 4, 0),
					Color3.fromRGB(198, 40, 40),
					Enum.Material.Fabric
				)
			else
				-- A target board on a stand.
				column(folder, 4, 0.6, at, BARK, Enum.Material.Wood)
				block(
					folder,
					Vector3.new(0.4, 4, 4),
					CFrame.new(at + Vector3.new(0, 6, 0)),
					Color3.fromRGB(245, 245, 245),
					Enum.Material.Wood
				)
				ball(
					folder,
					1.4,
					at + Vector3.new(0, 6, 0),
					Color3.fromRGB(198, 40, 40),
					Enum.Material.SmoothPlastic
				)
			end
		end,
	},

	-- Open water with mooring piles and the odd rowing boat.
	land_of_waves = {
		ground = Color3.fromRGB(41, 152, 209),
		material = Enum.Material.Glass,
		spacing = 13,
		place = function(folder, rng, at)
			if rng:NextNumber() < 0.8 then
				column(
					folder,
					rng:NextNumber(5, 12),
					1.3,
					at,
					Color3.fromRGB(121, 85, 72),
					Enum.Material.Wood
				)
			else
				local turned = CFrame.new(at + Vector3.new(0, 0.8, 0))
					* CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), 0)
				block(
					folder,
					Vector3.new(9, 1.6, 3.4),
					turned,
					Color3.fromRGB(141, 110, 99),
					Enum.Material.WoodPlanks
				)
			end
		end,
	},

	-- Giant trees that close over the sky.
	forest_of_death = {
		ground = Color3.fromRGB(51, 105, 30),
		material = Enum.Material.LeafyGrass,
		spacing = 16,
		place = function(folder, rng, at)
			local height = rng:NextNumber(42, 70)
			local width = rng:NextNumber(6, 10)
			tree(
				folder,
				at,
				height,
				width,
				rng:NextNumber(30, 42),
				DARK_BARK,
				Color3.fromRGB(27, 94, 32)
			)
			-- A root at the foot of the trunk.
			rock(
				folder,
				rng,
				at + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)),
				Vector3.new(width, 3, width * 1.6),
				DARK_BARK
			)
		end,
	},

	-- The exam arena: stepped stands with rows of spectators, and trees between them.
	chunin_exam_finals = {
		ground = Color3.fromRGB(196, 178, 138),
		material = Enum.Material.Ground,
		spacing = 20,
		place = function(folder, rng, at, side)
			if rng:NextNumber() < 0.3 then
				tree(
					folder,
					at,
					rng:NextNumber(8, 12),
					2,
					rng:NextNumber(10, 14),
					BARK,
					Color3.fromRGB(85, 139, 47)
				)
				return
			end
			-- Three tiers that climb away from the lane, each with a row of spectators on top.
			local width = rng:NextNumber(14, 20)
			local seats = math.floor(width / SEAT_WIDTH)
			for tier = 1, 3 do
				local height = tier * 4
				local foot = at + Vector3.new(0, 0, side * (tier - 1) * TIER_DEPTH)
				block(
					folder,
					Vector3.new(width, height, TIER_DEPTH),
					CFrame.new(foot + Vector3.new(0, height / 2, 0)),
					PALE_STONE,
					Enum.Material.Concrete
				)
				for seat = 1, seats do
					ball(
						folder,
						1.8,
						foot + Vector3.new((seat - (seats + 1) / 2) * SEAT_WIDTH, height + 0.9, 0),
						CROWD[rng:NextInteger(1, #CROWD)],
						Enum.Material.SmoothPlastic
					)
				end
			end
		end,
	},

	-- Cliffs on both sides, with waterfalls coming down some of them.
	valley_of_the_end = {
		ground = Color3.fromRGB(121, 134, 92),
		material = Enum.Material.Ground,
		spacing = 18,
		place = function(folder, rng, at, side)
			local height = rng:NextNumber(22, 56)
			local width = rng:NextNumber(16, 28)
			local cliff = block(
				folder,
				Vector3.new(width, height, width),
				CFrame.new(at + Vector3.new(0, height / 2 - 2, 0))
					* CFrame.Angles(0, math.rad(rng:NextNumber(-20, 20)), 0),
				STONE,
				Enum.Material.Slate
			)
			if rng:NextNumber() < 0.25 then
				-- A sheet of water down the face that looks onto the lane.
				block(
					folder,
					Vector3.new(6, height, 0.6),
					cliff.CFrame * CFrame.new(0, 0, -side * (width / 2 + 0.3)),
					Color3.fromRGB(129, 212, 250),
					Enum.Material.Glass
				)
			end
		end,
	},

	-- A desert village: round clay houses under domes, and wind-worn rocks.
	hidden_sand = {
		ground = Color3.fromRGB(222, 184, 115),
		material = Enum.Material.Sand,
		spacing = 15,
		place = function(folder, rng, at, side)
			if rng:NextNumber() < 0.6 then
				local height = rng:NextNumber(10, 24)
				local width = rng:NextNumber(10, 16)
				column(folder, height, width, at, CLAY, Enum.Material.Sandstone)
				ball(folder, width, at + Vector3.new(0, height, 0), CLAY, Enum.Material.Sandstone)
				-- A dark window on the side that faces the lane, sunk a little into the wall.
				block(
					folder,
					Vector3.new(2.4, 3, 0.6),
					CFrame.new(at + Vector3.new(0, height * 0.6, -side * (width / 2 - 0.1))),
					DARK_BARK,
					Enum.Material.SmoothPlastic
				)
			else
				local size = rng:NextNumber(5, 12)
				rock(
					folder,
					rng,
					at,
					Vector3.new(size, size * rng:NextNumber(0.5, 1.1), size),
					Color3.fromRGB(188, 143, 86)
				)
			end
		end,
	},

	-- Dark rock and stone pillars with red lanterns.
	akatsuki_lair = {
		ground = Color3.fromRGB(78, 52, 46),
		material = Enum.Material.Slate,
		spacing = 14,
		place = function(folder, rng, at)
			if rng:NextNumber() < 0.45 then
				local height = rng:NextNumber(16, 30)
				column(folder, height, 3.2, at, Color3.fromRGB(55, 48, 46), Enum.Material.Slate)
				ball(
					folder,
					3,
					at + Vector3.new(0, height + 1.5, 0),
					Color3.fromRGB(229, 57, 53),
					Enum.Material.Neon
				)
			else
				local size = rng:NextNumber(6, 16)
				rock(
					folder,
					rng,
					at,
					Vector3.new(size, size * rng:NextNumber(0.6, 1.4), size),
					Color3.fromRGB(62, 39, 35)
				)
			end
		end,
	},

	-- A city of steel towers with lit windows.
	hidden_rain = {
		ground = Color3.fromRGB(69, 90, 100),
		material = Enum.Material.Concrete,
		spacing = 15,
		place = function(folder, rng, at, side)
			local height = rng:NextNumber(40, 95)
			local width = rng:NextNumber(8, 14)
			local tower = block(
				folder,
				Vector3.new(width, height, width),
				CFrame.new(at + Vector3.new(0, height / 2, 0)),
				Color3.fromRGB(55, 71, 79),
				Enum.Material.Metal
			)
			-- A strip of lit windows on the side that faces the lane.
			block(
				folder,
				Vector3.new(2, height * 0.6, 0.4),
				tower.CFrame * CFrame.new(0, 0, -side * (width / 2 + 0.2)),
				Color3.fromRGB(255, 213, 79),
				Enum.Material.Neon
			)
			-- A pipe up one corner.
			column(
				folder,
				height * 0.9,
				1.4,
				at + Vector3.new(width / 2 + 0.7, 0, 0),
				Color3.fromRGB(38, 50, 56),
				Enum.Material.Metal
			)
		end,
	},

	-- An empty dimension of pale cuboids of every height, in pairs.
	kamui_dimension = {
		ground = Color3.fromRGB(38, 42, 64),
		material = Enum.Material.SmoothPlastic,
		spacing = 13,
		place = function(folder, rng, at)
			local width = rng:NextNumber(8, 16)
			local height = rng:NextNumber(6, 44)
			block(
				folder,
				Vector3.new(width, height, width),
				CFrame.new(at + Vector3.new(0, height / 2, 0)),
				Color3.fromRGB(120, 132, 158),
				Enum.Material.SmoothPlastic
			)
			-- A lower block set against it, up or down the lane.
			local step = width * rng:NextNumber(0.5, 0.8)
			local lower = height * rng:NextNumber(0.3, 0.7)
			local shift = (width + step) / 2 * (if rng:NextNumber() < 0.5 then -1 else 1)
			block(
				folder,
				Vector3.new(step, lower, step),
				CFrame.new(at + Vector3.new(shift, lower / 2, 0)),
				Color3.fromRGB(96, 106, 132),
				Enum.Material.SmoothPlastic
			)
		end,
	},

	-- A battlefield: scorched ground, boulders and broken wooden spikes.
	great_ninja_war = {
		ground = Color3.fromRGB(62, 50, 46),
		material = Enum.Material.Ground,
		spacing = 13,
		place = function(folder, rng, at)
			if rng:NextNumber() < 0.5 then
				local length = rng:NextNumber(12, 26)
				local leaning = CFrame.new(at + Vector3.new(0, length * 0.4, 0))
					* CFrame.Angles(
						math.rad(rng:NextNumber(-35, 35)),
						math.rad(rng:NextNumber(0, 180)),
						math.rad(rng:NextNumber(-35, 35))
					)
				block(folder, Vector3.new(2.4, length, 2.4), leaning, BARK, Enum.Material.Wood)
			else
				local size = rng:NextNumber(5, 14)
				rock(
					folder,
					rng,
					at,
					Vector3.new(size, size * 0.8, size),
					Color3.fromRGB(66, 66, 66)
				)
			end
		end,
	},
}

-- A torii-style gate over the lane at `along` studs: two posts outside the walls and two beams.
local function gate(folder: Folder, along: number)
	local red = Color3.fromRGB(198, 40, 40)
	local reach = Hub.LANE_WIDTH / 2 + 5
	for _, side in { -1, 1 } do
		column(folder, 26, 3, Hub.at(along, 0, side * reach), red, Enum.Material.Wood)
	end
	block(
		folder,
		Vector3.new(3, 2.6, reach * 2 + 14),
		CFrame.new(Hub.at(along, 26, 0)),
		red,
		Enum.Material.Wood
	)
	block(
		folder,
		Vector3.new(2, 1.8, reach * 2 + 4),
		CFrame.new(Hub.at(along, 21, 0)),
		red,
		Enum.Material.Wood
	)
end

-- Call after Hub.start(): positions are in the Hub's coordinates.
function Scenery.start()
	local folder = Instance.new("Folder")
	folder.Name = "Scenery"

	for index, zone in Catalog.zones do
		local theme = THEMES[zone.id]
		if not theme then
			continue
		end
		local from, to = zone.startsAt, Catalog.zoneEnd(zone)
		local rng = Random.new(index * 7919)

		for _, side in { -1, 1 } do
			-- The zone's own ground, a hair above the grass that lies under the whole world.
			local strip = block(
				folder,
				Vector3.new(to - from, 1, STRIP_WIDTH),
				CFrame.new(
					Hub.at(
						(from + to) / 2,
						-0.55,
						side * (Hub.LANE_WIDTH / 2 + Hub.WALL_THICKNESS + STRIP_WIDTH / 2)
					)
				),
				theme.ground,
				theme.material
			)
			if theme.material == Enum.Material.Glass then
				strip.Transparency = 0.25
			end

			local along = from + theme.spacing / 2
			while along < to do
				local out = rng:NextNumber(NEAR, FAR)
				theme.place(folder, rng, Hub.at(along, 0, side * out), side)
				along += theme.spacing * rng:NextNumber(0.7, 1.3)
			end
		end

		if index > 1 then
			gate(folder, from)
		end
	end

	-- What the lane leads to: a colossal tree past its far end.
	local past = Tuning.Kick.trackLength + 90
	column(folder, 150, 44, Hub.at(past, 0, 0), DARK_BARK, Enum.Material.Wood)
	ball(folder, 130, Hub.at(past, 170, 0), Color3.fromRGB(136, 14, 79), Enum.Material.Grass)

	folder.Parent = Workspace
end

return Scenery
