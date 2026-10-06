--!strict
-- Great Ninja War: a battlefield of scorched ground, boulders and broken wooden spikes, and past
-- the end of the lane the colossal tree it all leads to.
--
-- NOT TO BE CHANGED. The owner likes this zone as it is (2026-10-06), with its moon and light
-- (Config/ZoneArt). This is the scenery it had before every zone got a module of its own, moved
-- here piece for piece: the same shapes, the same order of random numbers, the same shadows.
-- It builds its parts by hand instead of through Kit, whose pieces differ in small ways.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hub = require("../Hub")
local Kit = require("./Kit")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

-- How close to the lane's center line a prop may stand, and how far out props go, studs.
local NEAR = Hub.LANE_WIDTH / 2 + 10
local FAR = NEAR + 54
-- Width of the tinted strip of ground on each side of the lane.
local STRIP_WIDTH = 70
-- Average distance between props along the lane, studs.
local SPACING = 13

return function(scene: Kit.Scene)
	local colors = scene.colors
	local rng = scene.rng
	local from, to = scene.from, scene.from + scene.length

	local function block(
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
		part.Parent = scene.folder
		scene.parts += 1
		return part
	end

	-- An upright cylinder standing on `base`. A cylinder part lies along its X axis, hence the turn.
	local function column(
		height: number,
		diameter: number,
		base: Vector3,
		color: Color3,
		material: Enum.Material
	)
		local upright = CFrame.new(base + Vector3.new(0, height / 2, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		block(Vector3.new(height, diameter, diameter), upright, color, material).Shape =
			Enum.PartType.Cylinder
	end

	local ground = Color3.fromHex(scene.art.ground.color)
	for _, side in { -1, 1 } do
		-- The zone's own ground, a hair above the grass that lies under the whole world.
		block(
			Vector3.new(to - from, 1, STRIP_WIDTH),
			CFrame.new(
				Hub.at(
					(from + to) / 2,
					-0.55,
					side * (Hub.LANE_WIDTH / 2 + Hub.WALL_THICKNESS + STRIP_WIDTH / 2)
				)
			),
			ground,
			Kit.material(scene.art.ground.material)
		)

		local along = from + SPACING / 2
		while along < to do
			local out = rng:NextNumber(NEAR, FAR)
			local at = Hub.at(along, 0, side * out)
			if rng:NextNumber() < 0.5 then
				-- A broken spike, leaning.
				local length = rng:NextNumber(12, 26)
				local leaning = CFrame.new(at + Vector3.new(0, length * 0.4, 0))
					* CFrame.Angles(
						math.rad(rng:NextNumber(-35, 35)),
						math.rad(rng:NextNumber(0, 180)),
						math.rad(rng:NextNumber(-35, 35))
					)
				block(Vector3.new(2.4, length, 2.4), leaning, colors.spike, Enum.Material.Wood)
			else
				-- A boulder, sunk a little into the ground and turned at random.
				local width = rng:NextNumber(5, 14)
				local size = Vector3.new(width, width * 0.8, width)
				local turned = CFrame.new(at + Vector3.new(0, size.Y * 0.35, 0))
					* CFrame.Angles(
						math.rad(rng:NextNumber(-12, 12)),
						math.rad(rng:NextNumber(0, 180)),
						math.rad(rng:NextNumber(-12, 12))
					)
				block(size, turned, colors.boulder, Enum.Material.Slate)
			end
			along += SPACING * rng:NextNumber(0.7, 1.3)
		end
	end

	-- A torii-style gate over the lane where the zone begins: two posts outside the walls and
	-- two beams.
	local reach = Hub.LANE_WIDTH / 2 + 5
	for _, side in { -1, 1 } do
		column(26, 3, Hub.at(from, 0, side * reach), colors.gate, Enum.Material.Wood)
	end
	block(
		Vector3.new(3, 2.6, reach * 2 + 14),
		CFrame.new(Hub.at(from, 26, 0)),
		colors.gate,
		Enum.Material.Wood
	)
	block(
		Vector3.new(2, 1.8, reach * 2 + 4),
		CFrame.new(Hub.at(from, 21, 0)),
		colors.gate,
		Enum.Material.Wood
	)

	-- What the lane leads to: a colossal tree past its far end.
	local past = Tuning.Kick.trackLength + 90
	column(150, 44, Hub.at(past, 0, 0), colors.trunk, Enum.Material.Wood)
	block(
		Vector3.new(130, 130, 130),
		CFrame.new(Hub.at(past, 170, 0)),
		colors.crown,
		Enum.Material.Grass
	).Shape =
		Enum.PartType.Ball
end
