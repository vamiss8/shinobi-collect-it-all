--!strict
-- The Youth Training Ground, where run speed is bought: an open yard of beaten earth edged
-- with logs, its front to the fountain. At the front, a counter with Might Duy behind it and his
-- turtle sitting on it; behind him, the gate of the Eight Gates, with a lantern hanging for each
-- Gate. Every player sees as many of them lit, green, as they have opened; the rest hang gray
-- (Config/SpeedStages, client/GateLanterns). Behind the gate: posts to kick, a bench of
-- weights, a boulder, a log and a high bar. Two banners stand at the front corners.
--
-- It is built with the shapes of World/ShopHouse, in the same local coordinates: x runs across
-- the front, left to right as a customer sees it; y is height above the ground; z runs inward,
-- from the front (0) to the back. Might Duy and the turtle are figures (View/Figure,
-- Config/Keepers): models named "duy" and "turtle" in ReplicatedStorage.Models take the
-- placeholders' places once they are supplied.
--
-- The counter, the gate, the posts, the bench, the boulder, the log and the bar are solid;
-- the yard is open to walk round. The rest is only for show.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Net = require(ReplicatedStorage.Shared.Net)
local ShopHouse = require("./ShopHouse")

local TrainingGround = {}

local V = Vector3.new
local UP = V(0, 1, 0)
local ACROSS = V(1, 0, 0)

local GROUND = 0.2 -- top of the beaten earth
local HALF = 10.5 -- half the width of the yard
local FRONT = -1.5 -- where the yard begins, out in front of the counter
local BACK = 12.5
local COUNTER_TOP = 3.6
-- Behind the counter a low wooden platform, which Might Duy stands on to be seen over it.
local PLATFORM = 1.2
local GATE_Z = 4 -- the line of the gate's posts
local POST_X = 7.6
local TIE = 8.4 -- underside of the gate's lower beam, which the lanterns hang from

local TIMBER = ShopHouse.TIMBER
local WOOD = ShopHouse.WOOD
local PALE_WOOD = ShopHouse.PALE_WOOD
local INK = ShopHouse.INK
local GOLD = ShopHouse.GOLD
local IRON = ShopHouse.IRON
local EARTH = Color3.fromRGB(196, 170, 124)
local BARK = Color3.fromRGB(109, 76, 65)
local GREEN = Color3.fromRGB(46, 125, 50)
local ORANGE = Color3.fromRGB(255, 143, 0) -- the color of the training weights stage
local STRAW = Color3.fromRGB(214, 186, 120)
local STEEL = Color3.fromRGB(176, 190, 197)
local STONE = Color3.fromRGB(150, 145, 138)
local BRONZE = Color3.fromRGB(196, 150, 70)
-- A lantern of a Gate not yet opened: pale gray paper, unlit.
local UNLIT = Color3.fromRGB(176, 178, 174)

local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local decor = ShopHouse.decor

local TITLE = "YOUTH TRAINING GROUND"
-- The characters on each lantern: the Eight Gates, from the first to the last.
local GATES = { "開", "休", "生", "傷", "杜", "景", "驚", "死" }

-- Text on the front face of a part that looks out of the yard.
local function letter(part: BasePart, text: string, color: Color3)
	local label = Build.faceLabel(part, Enum.NormalId.Front, text)
	label.TextColor3 = color
end

-- A weight for the leg lying flat on a surface at height `y`: a thick ring of orange cloth.
local function legWeight(kit: ShopHouse.Kit, at: Vector3, under: Color3)
	decor(kit.disc("LegWeight", at + UP * 0.15, UP, 0.95, 0.3, ORANGE, FABRIC))
	-- Through the middle shows what it lies on; the plug stands a little proud of the ring.
	decor(kit.disc("LegWeightHole", at + UP * 0.15, UP, 0.5, 0.38, under))
end

-- A dumbbell lying across, its middle at `at` on a surface: a bar with a plate at each end.
local function dumbbell(kit: ShopHouse.Kit, at: Vector3, length: number)
	local y = at.Y + 0.35
	local from, to = V(at.X - length / 2, y, at.Z), V(at.X + length / 2, y, at.Z)
	decor(kit.rod("DumbbellBar", from, to, 0.14, STEEL, METAL))
	for _, x in { from.X + 0.15, to.X - 0.15 } do
		decor(kit.disc("DumbbellPlate", V(x, y, at.Z), ACROSS, 0.7, 0.2, IRON, METAL))
	end
end

-- The beaten earth, its edging of logs and the banners at the front corners.
local function buildYard(kit: ShopHouse.Kit)
	kit.box("Earth", V(-HALF, 0, FRONT), V(HALF, GROUND, BACK), EARTH, Enum.Material.Ground)
	local edge, y = HALF + 0.3, GROUND + 0.3
	for _, side in { -1, 1 } do
		kit.rod(
			"Edging",
			V(side * edge, y, FRONT),
			V(side * edge, y, BACK + 0.3),
			0.6,
			BARK,
			Enum.Material.Wood
		)
	end
	kit.rod(
		"Edging",
		V(-edge, y, BACK + 0.3),
		V(edge, y, BACK + 0.3),
		0.6,
		BARK,
		Enum.Material.Wood
	)

	-- Banners on poles: "youth" on the left in green, "hard work" on the right in orange.
	for _, banner in
		{
			{ side = -1, color = GREEN, text = "青\n春" },
			{ side = 1, color = ORANGE, text = "努\n力" },
		}
	do
		local x = banner.side * 9.8
		decor(kit.rod("BannerPole", V(x, 0, -0.8), V(x, 9, -0.8), 0.2, TIMBER, Enum.Material.Wood))
		local inner = banner.side * 8.45
		local cloth = decor(
			kit.box(
				"Banner",
				V(x - banner.side * 0.15, 3, -0.85),
				V(inner, 8.6, -0.75),
				banner.color,
				FABRIC
			)
		)
		letter(cloth, banner.text, Color3.new(1, 1, 1))
		decor(
			kit.rod(
				"BannerBar",
				V(x, 8.65, -0.8),
				V(inner - banner.side * 0.1, 8.65, -0.8),
				0.12,
				TIMBER,
				Enum.Material.Wood
			)
		)
	end
end

-- The counter at the front, with weights laid on it, and the platform behind it. Returns the
-- counter.
local function buildCounter(kit: ShopHouse.Kit): Part
	local counter = kit.box(
		"Counter",
		V(-4, 0, 0.6),
		V(4, COUNTER_TOP - 0.4, 2),
		WOOD,
		Enum.Material.WoodPlanks
	)
	kit.box(
		"CounterTop",
		V(-4.3, COUNTER_TOP - 0.4, 0.4),
		V(4.3, COUNTER_TOP, 2.2),
		PALE_WOOD,
		Enum.Material.Wood
	)
	-- A green cloth on its front: "youth".
	local cloth =
		decor(kit.box("CounterCloth", V(-3.6, 0.9, 0.52), V(3.6, 2.9, 0.6), GREEN, FABRIC))
	letter(cloth, "青春", Color3.new(1, 1, 1))

	kit.box("Platform", V(-4.5, 0, 2), V(4.5, PLATFORM, 4.8), PALE_WOOD, Enum.Material.WoodPlanks)

	legWeight(kit, V(-3.2, COUNTER_TOP, 1.3), PALE_WOOD)
	legWeight(kit, V(-2.1, COUNTER_TOP, 1.4), PALE_WOOD)
	dumbbell(kit, V(1.1, COUNTER_TOP, 1.2), 1.4)
	return counter
end

-- The gate of the Eight Gates: two posts, a lower beam with the eight lanterns hanging from it,
-- a name board, and a top beam capped in green with the shop's name floating over it.
local function buildGate(kit: ShopHouse.Kit)
	local z0, z1 = GATE_Z - 0.5, GATE_Z + 0.5
	for _, side in { -1, 1 } do
		local x = side * POST_X
		kit.box("GatePost", V(x - 0.5, 0, z0), V(x + 0.5, 11, z1), TIMBER, Enum.Material.Wood)
		decor(
			kit.box(
				"GatePostFoot",
				V(x - 0.6, 0, z0 - 0.1),
				V(x + 0.6, 0.8, z1 + 0.1),
				BRONZE,
				METAL
			)
		)
	end
	kit.box(
		"GateTie",
		V(-8.6, TIE, GATE_Z - 0.4),
		V(8.6, TIE + 0.8, GATE_Z + 0.4),
		TIMBER,
		Enum.Material.Wood
	)
	local top = kit.box(
		"GateTop",
		V(-9.4, 10.6, GATE_Z - 0.7),
		V(9.4, 11.4, GATE_Z + 0.7),
		TIMBER,
		Enum.Material.Wood
	)
	decor(
		kit.box(
			"GateCap",
			V(-9.6, 11.4, GATE_Z - 0.8),
			V(9.6, 11.7, GATE_Z + 0.8),
			GREEN,
			Enum.Material.Wood
		)
	)
	Build.label(top, TITLE, 3.6, Vector2.new(24, 4))
	-- The name board between the beams: "eight gates".
	local board = decor(
		kit.box(
			"GateBoard",
			V(-1.6, TIE + 0.8, GATE_Z - 0.25),
			V(1.6, 10.6, GATE_Z + 0.25),
			GREEN,
			Enum.Material.Wood
		)
	)
	letter(board, "八門", GOLD)

	-- The lanterns, first Gate on the left: square paper lanterns, each with its Gate's
	-- character, unlit until a client lights its own player's.
	for gate, character in GATES do
		local x = -6.3 + (gate - 1) * 1.8
		decor(
			kit.rod("LanternCord", V(x, TIE - 0.3, GATE_Z), V(x, TIE, GATE_Z), 0.08, TIMBER, FABRIC)
		)
		decor(
			kit.box(
				"LanternCap",
				V(x - 0.45, TIE - 0.45, GATE_Z - 0.45),
				V(x + 0.45, TIE - 0.3, GATE_Z + 0.45),
				TIMBER,
				Enum.Material.Wood
			)
		)
		local body = decor(
			kit.box(
				Net.GATE_LANTERN,
				V(x - 0.4, TIE - 1.45, GATE_Z - 0.4),
				V(x + 0.4, TIE - 0.45, GATE_Z + 0.4),
				UNLIT
			)
		)
		body:SetAttribute(Net.GATE_ATTRIBUTE, gate)
		letter(body, character, INK)
		local light = Instance.new("PointLight")
		light.Range = 12
		light.Brightness = 1.2
		light.Enabled = false
		light.Parent = body
		decor(
			kit.box(
				"LanternCap",
				V(x - 0.45, TIE - 1.6, GATE_Z - 0.45),
				V(x + 0.45, TIE - 1.45, GATE_Z + 0.45),
				TIMBER,
				Enum.Material.Wood
			)
		)
	end
end

-- Behind the gate: posts to kick on the left, a bench of weights and a boulder on the right, a
-- log in the middle and a high bar at the back.
local function buildTraining(kit: ShopHouse.Kit)
	for _, spot in { V(-8, 0, 6), V(-6.2, 0, 8.6), V(-8.4, 0, 10.8) } do
		kit.rod("KickPost", spot, spot + UP * 4.4, 0.9, WOOD, Enum.Material.Wood)
		for _, y in { 1.2, 2.6 } do
			decor(kit.rod("Rope", spot + UP * y, spot + UP * (y + 0.3), 1.02, STRAW, FABRIC))
		end
	end

	kit.box("WeightBench", V(6.2, 0, 6.2), V(9.6, 1.2, 9.8), WOOD, Enum.Material.WoodPlanks)
	dumbbell(kit, V(7.3, 1.2, 6.9), 1.5)
	dumbbell(kit, V(7.3, 1.2, 7.9), 1.5)
	legWeight(kit, V(8.8, 1.2, 8.8), WOOD)
	legWeight(kit, V(7.6, 1.2, 9.1), WOOD)
	local boulder =
		kit.box("Boulder", V(6.4, 0, 10.1), V(8.8, 2.4, 12.5), STONE, Enum.Material.Slate)
	boulder.Shape = Enum.PartType.Ball

	kit.rod("Log", V(-2.8, 0.75, 8.2), V(2.8, 0.75, 8.2), 1.1, BARK, Enum.Material.Wood)

	for _, side in { -1, 1 } do
		kit.rod(
			"BarPost",
			V(side * 2.4, 0, 11.6),
			V(side * 2.4, 6.4, 11.6),
			0.35,
			TIMBER,
			Enum.Material.Wood
		)
	end
	kit.rod("HighBar", V(-2.4, 6.2, 11.6), V(2.4, 6.2, 11.6), 0.16, STEEL, METAL)
end

-- Builds the training ground under `parent`, standing on `place` (the middle of its front on
-- the ground, looking out at the customers). Returns its counter, which gets the prompt.
function TrainingGround.build(parent: Instance, place: CFrame): Part
	local folder = Instance.new("Folder")
	folder.Name = "TrainingGround"
	local kit = ShopHouse.kit(folder, place)
	buildYard(kit)
	local counter = buildCounter(kit)
	buildGate(kit)
	buildTraining(kit)

	local duy = Figure.keeper(Catalog.keeperById.duy)
	duy.Name = Net.KEEPER
	kit.stand(duy, V(0, PLATFORM, 3.2))
	-- The turtle sits on the counter beside the dumbbell.
	kit.stand(Figure.keeper(Catalog.keeperById.turtle), V(2.9, COUNTER_TOP, 1.4))

	folder.Parent = parent
	return counter
end

return TrainingGround
