--!strict
-- Kabuto's Remedies, where the potions that boost for a while are sold, for Herbs and for Robux
-- (Config/Potions, Logic/Pouch; the shop "herbs"): a small wooden cart under a sloping purple
-- roof, far less than a shop, for what the game is played well enough without (the owner and
-- the co-author's kabuto-stall.zip, 2026-10-17, carried over by hand: it was made before the
-- Herbs and opened the Robux shop's page of potions; it opens the Herb Shop's window now). Its front, to the fountain, is the cart itself: a counter on two
-- wheels, a purple cloth on it with "薬師" (yakushi, "healer", and Kabuto's family name), and
-- the four potions set out on its top. Three curtains hang from the beam over it, "回", "復",
-- "薬" ("medicine that restores"), a bundle of herbs and a medicine gourd from the posts either
-- side, a paper lantern under each front corner of the roof, and the stall's name floats over
-- it. Behind the cart Kabuto stands on a step, before a cabinet of jars, some of them glowing,
-- and one with a white snake in it.
--
-- It is built with the shapes of World/ShopHouse, in the same local coordinates: x runs across
-- the front, left to right as a customer sees it; y is height above the ground; z runs inward,
-- from the front (0) to the back. Kabuto is a figure (View/Figure, Config/Keepers): the model
-- named "kabuto_shop" in ReplicatedStorage.Models (their Kabuto_Shop.glb, a keeper of his own
-- with a flask in his hand, not the shinobi Kabuto Yakushi's model) takes the placeholder's
-- place once it is supplied.
--
-- The cart, the step, the posts, the cabinet and the roof are solid; the stall can be walked
-- round. The rest is only for show.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Net = require(ReplicatedStorage.Shared.Net)
local ShopHouse = require("./ShopHouse")

local PotionStall = {}

local V = Vector3.new
local UP = V(0, 1, 0)
local ACROSS = V(1, 0, 0)

-- The cart: its body runs between these, and stands clear of the ground on its wheels.
local CART_HALF = 3.8
local CART_FRONT = 0.5
local CART_BACK = 2.3
local CART_BOTTOM = 0.6
local COUNTER_TOP = 3.4
local BOARD = 0.4 -- the counter's top board, reaching out a little all round
local WHEEL_Z = 1.4
local WHEEL_Y = 1.2 -- the middle of a wheel: they stand on the ground
local WHEEL = 2.4
-- Behind the cart, the step Kabuto stands on, so that he is seen over the counter.
local STEP = 1
local STEP_BACK = 6.2
-- The posts: two on the counter's front corners, two behind Kabuto.
local POST_X = 3.55
local POST = 0.4
local FRONT_POST_Z = 0.7
local BACK_POST_Z = 5.6
-- The roof slopes down to the front: the line of its underside, from the front edge to the
-- back one, and how far out it reaches to either side.
local ROOF_FRONT = V(0, 7.6, -1.4)
local ROOF_BACK = V(0, 9, 6.4)
local ROOF_HALF = 4.8
local TILE = 0.35 -- thickness of the roof
local BEAM = 7.2 -- underside of the beam over the counter, which the curtains hang from
local NOREN_BOTTOM = 6.1
-- The cabinet: its back and its shelves, between the back posts.
local CABINET_FRONT = 4.7
local CABINET_BACK = 6
-- Tops of the shelves: low enough to be seen between the counter and the curtains.
local SHELVES = { 2.6, 4, 5.4 }
local CABINET_TOP = 6.8

local TIMBER = ShopHouse.TIMBER
local WOOD = ShopHouse.WOOD
local PALE_WOOD = ShopHouse.PALE_WOOD
local PAPER = ShopHouse.PAPER
local INK = ShopHouse.INK
local GOLD = ShopHouse.GOLD
local IRON = ShopHouse.IRON
local LACQUER = ShopHouse.LACQUER
-- Kabuto's purple, on the roof, the cloth and the curtains.
local PURPLE = Color3.fromRGB(81, 45, 168)
local PLUM = Color3.fromRGB(49, 27, 96)
local LAVENDER = Color3.fromRGB(179, 157, 219)
local WHITE = Color3.new(1, 1, 1)
-- The potions' colors: chakra, luck, sage oil, and the jars of the cabinet besides.
local CHAKRA = Color3.fromRGB(66, 165, 245)
local LUCK = Color3.fromRGB(102, 187, 106)
local SAGE = Color3.fromRGB(255, 145, 0)
local VIOLET = Color3.fromRGB(171, 71, 188)
local ROSE = Color3.fromRGB(240, 98, 146)
local BROTH = Color3.fromRGB(230, 180, 90)
local HERB = Color3.fromRGB(85, 139, 47)
local DRIED = Color3.fromRGB(141, 110, 60)
local CORK = Color3.fromRGB(176, 132, 82)
local GLASS = Color3.fromRGB(200, 170, 110)
local SNAKE = Color3.fromRGB(236, 232, 214)
local GOURD = Color3.fromRGB(214, 160, 70)

local FABRIC = Enum.Material.Fabric
local NEON = Enum.Material.Neon
local decor = ShopHouse.decor

local TITLE = "KABUTO'S REMEDIES"

-- Text on the front face of a part that looks out of the stall.
local function letter(part: BasePart, text: string, color: Color3)
	local label = Build.faceLabel(part, Enum.NormalId.Front, text)
	label.TextColor3 = color
end

-- How high the underside of the roof is at z.
local function roofAt(z: number): number
	local t = (z - ROOF_FRONT.Z) / (ROOF_BACK.Z - ROOF_FRONT.Z)
	return ROOF_FRONT.Y + (ROOF_BACK.Y - ROOF_FRONT.Y) * t
end

-- A jar standing on a surface at `at`: its body, its lid, and, when `glow`, lit from inside.
local function jar(
	kit: ShopHouse.Kit,
	at: Vector3,
	width: number,
	tall: number,
	color: Color3,
	glow: boolean
)
	decor(
		kit.rod("Jar", at, at + UP * tall, width, color, if glow then NEON else Enum.Material.Glass)
	)
	decor(kit.rod("JarLid", at + UP * tall, at + UP * (tall + 0.15), width * 0.7, CORK))
end

-- The cart: its body (the counter, which is returned), its top board, its legs and wheels,
-- and the cloth on its front.
local function buildCart(kit: ShopHouse.Kit): Part
	local counter = kit.box(
		"Counter",
		V(-CART_HALF, CART_BOTTOM, CART_FRONT),
		V(CART_HALF, COUNTER_TOP - BOARD, CART_BACK),
		WOOD,
		Enum.Material.WoodPlanks
	)
	kit.box(
		"CounterTop",
		V(-CART_HALF - 0.2, COUNTER_TOP - BOARD, CART_FRONT - 0.2),
		V(CART_HALF + 0.2, COUNTER_TOP, CART_BACK + 0.2),
		PALE_WOOD,
		Enum.Material.Wood
	)
	-- A purple cloth on its front: "healer".
	local cloth = decor(
		kit.box(
			"CounterCloth",
			V(-3, CART_BOTTOM + 0.4, CART_FRONT - 0.08),
			V(3, COUNTER_TOP - BOARD - 0.25, CART_FRONT),
			PURPLE,
			FABRIC
		)
	)
	letter(cloth, "薬師", WHITE)

	-- It rests on four short legs while it stands, and on its wheels when pulled.
	for _, x in { -3.4, 3.4 } do
		for _, z in { CART_FRONT + 0.2, CART_BACK - 0.5 } do
			kit.box("CartLeg", V(x - 0.15, 0, z), V(x + 0.15, CART_BOTTOM, z + 0.3), TIMBER)
		end
	end
	for _, side in { -1, 1 } do
		kit.rings("Wheel", V(side * (CART_HALF + 0.3), WHEEL_Y, WHEEL_Z), ACROSS, {
			{ diameter = WHEEL, color = TIMBER },
			{ diameter = WHEEL - 0.45, color = WOOD },
			{ diameter = 0.6, color = IRON },
		})
	end
	return counter
end

-- The four potions on the counter, two either side of Kabuto: Ichiraku Ramen and a jar of
-- Soldier Pills on the left, the Gama-chan Charm and a bottle of Sage Oil on the right.
local function buildGoods(kit: ShopHouse.Kit)
	local top = COUNTER_TOP

	-- A bowl of ramen, with chopsticks across it.
	local bowl = V(-2.6, top, 1.4)
	decor(kit.disc("RamenBowl", bowl + UP * 0.25, UP, 1.2, 0.5, LACQUER))
	decor(kit.disc("RamenBroth", bowl + UP * 0.47, UP, 1, 0.1, BROTH))
	for _, z in { 1.25, 1.4 } do
		decor(
			kit.rod("Chopstick", V(-3.2, top + 0.53, z), V(-2.1, top + 0.53, z + 0.1), 0.06, WOOD)
		)
	end

	-- A jar of Soldier Pills, three of them before it.
	jar(kit, V(-1.5, top, 1.5), 0.8, 0.8, CHAKRA, false)
	for index, x in { -1.75, -1.45, -1.15 } do
		local z = if index == 2 then 0.75 else 0.85
		decor(kit.disc("SoldierPill", V(x, top + 0.06, z), UP, 0.22, 0.12, DRIED))
	end

	-- The Gama-chan Charm: a green frog purse, with its two eyes on top.
	local purse = V(1.5, top, 1.3)
	decor(kit.disc("GamaCharm", purse + UP * 0.28, UP, 0.95, 0.55, LUCK, FABRIC))
	for _, x in { -0.2, 0.2 } do
		decor(kit.disc("GamaEye", purse + V(x, 0.6, -0.25), UP, 0.22, 0.12, WHITE))
		decor(kit.disc("GamaPupil", purse + V(x, 0.68, -0.27), UP, 0.1, 0.06, INK))
	end

	-- A bottle of Sage Oil, glowing.
	local bottle = V(2.6, top, 1.4)
	decor(kit.rod("SageOil", bottle, bottle + UP * 0.9, 0.55, SAGE, NEON))
	decor(kit.rod("SageOilNeck", bottle + UP * 0.9, bottle + UP * 1.2, 0.22, GLASS))
	decor(kit.rod("SageOilCork", bottle + UP * 1.2, bottle + UP * 1.35, 0.18, CORK))
end

-- The posts, the roof on them, the beam over the counter with the curtains hanging from it,
-- and the lanterns under the front corners. The name floats over the roof.
local function buildRoof(kit: ShopHouse.Kit)
	for _, side in { -1, 1 } do
		local x = side * POST_X
		kit.box(
			"Post",
			V(x - POST / 2, COUNTER_TOP, FRONT_POST_Z - POST / 2),
			V(x + POST / 2, roofAt(FRONT_POST_Z) + 0.1, FRONT_POST_Z + POST / 2),
			TIMBER,
			Enum.Material.Wood
		)
		kit.box(
			"Post",
			V(x - POST / 2, 0, BACK_POST_Z - POST / 2),
			V(x + POST / 2, roofAt(BACK_POST_Z) + 0.1, BACK_POST_Z + POST / 2),
			TIMBER,
			Enum.Material.Wood
		)
	end

	-- The roof: a slab along the slope, its underside on the line from front to back.
	local slope = (ROOF_BACK - ROOF_FRONT).Unit
	local normal = V(0, slope.Z, -slope.Y)
	local length = (ROOF_BACK - ROOF_FRONT).Magnitude
	local roof = kit.plate(
		"Roof",
		(ROOF_FRONT + ROOF_BACK) / 2 + normal * (TILE / 2),
		ACROSS,
		slope,
		V(2 * ROOF_HALF, length, TILE),
		PURPLE,
		Enum.Material.Slate
	)
	Build.label(roof, TITLE, 2.6, Vector2.new(17, 3))
	-- Dark boards along its front and back edges, a little below it.
	for _, edge in { ROOF_FRONT, ROOF_BACK } do
		decor(
			kit.box(
				"RoofTrim",
				V(-ROOF_HALF - 0.05, edge.Y - 0.3, edge.Z - 0.12),
				V(ROOF_HALF + 0.05, edge.Y + 0.02, edge.Z + 0.12),
				PLUM,
				Enum.Material.Wood
			)
		)
	end

	-- The beam between the front posts, and the curtains on it: "medicine that restores".
	kit.box(
		"Beam",
		V(-POST_X + POST / 2, BEAM, FRONT_POST_Z - POST / 2),
		V(POST_X - POST / 2, roofAt(FRONT_POST_Z + POST / 2) + 0.05, FRONT_POST_Z + POST / 2),
		TIMBER,
		Enum.Material.Wood
	)
	local front = FRONT_POST_Z - POST / 2
	for index, character in { "回", "復", "薬" } do
		local x = -3.3 + (index - 1) * 2.25
		local strip = decor(
			kit.box(
				"Noren",
				V(x, NOREN_BOTTOM, front - 0.06),
				V(x + 2.1, BEAM + 0.3, front),
				LAVENDER,
				FABRIC
			)
		)
		letter(strip, character, PLUM)
	end

	for _, side in { -1, 1 } do
		local x = side * 4.3
		kit.lantern(V(x, roofAt(-0.9), -0.9), 7, 0.9, 14)
	end
end

-- The step behind the cart, and the cabinet of jars at the back, with the snake in its jar.
local function buildBack(kit: ShopHouse.Kit)
	kit.box(
		"Step",
		V(-CART_HALF, 0, CART_BACK),
		V(CART_HALF, STEP, STEP_BACK),
		PALE_WOOD,
		Enum.Material.WoodPlanks
	)

	local inner = POST_X - POST / 2
	kit.box(
		"CabinetBack",
		V(-inner, STEP, CABINET_BACK - 0.2),
		V(inner, CABINET_TOP + 0.2, CABINET_BACK),
		WOOD,
		Enum.Material.WoodPlanks
	)
	for _, y in SHELVES do
		kit.box(
			"Shelf",
			V(-inner, y - 0.15, CABINET_FRONT),
			V(inner, y, CABINET_BACK - 0.2),
			PALE_WOOD,
			Enum.Material.Wood
		)
	end
	kit.box(
		"CabinetTop",
		V(-inner, CABINET_TOP, CABINET_FRONT),
		V(inner, CABINET_TOP + 0.2, CABINET_BACK - 0.2),
		TIMBER,
		Enum.Material.Wood
	)

	-- Jars of every potion's color on the shelves, a few of them glowing. On the middle shelf,
	-- at the end, a big jar of spirits with a white snake coiled in it.
	local z = (CABINET_FRONT + CABINET_BACK - 0.2) / 2
	local rows: { { Color3? } } = {
		{ CHAKRA, VIOLET, LUCK, PAPER, SAGE, ROSE },
		{ nil, SAGE, CHAKRA, LUCK, VIOLET, CHAKRA },
		{ LUCK, PAPER, VIOLET, SAGE, CHAKRA, LUCK },
	}
	for shelf, colors in rows do
		for index = 1, 6 do
			local color = colors[index]
			if color then
				local x = -2.75 + (index - 1) * 1.1
				local tall = 0.55 + ((index + shelf) % 3) * 0.2
				local width = if (index + shelf) % 2 == 0 then 0.6 else 0.75
				jar(kit, V(x, SHELVES[shelf], z), width, tall, color, (index + shelf) % 3 == 0)
			end
		end
	end
	local glass = V(-2.75, SHELVES[2], z)
	local big = decor(kit.rod("SnakeJar", glass, glass + UP * 0.9, 1, GLASS, Enum.Material.Glass))
	big.Transparency = 0.45
	decor(kit.rod("SnakeJarLid", glass + UP * 0.9, glass + UP * 1, 0.8, CORK))
	for turn = 0, 2 do
		local y = 0.2 + turn * 0.22
		decor(kit.disc("Snake", glass + UP * y, UP, 0.62 - turn * 0.12, 0.1, SNAKE))
	end
end

-- From a peg on the outer side of each front post: a bundle of herbs on the left, a medicine
-- gourd on the right, as an apothecary's sign.
local function buildHangings(kit: ShopHouse.Kit)
	local z = FRONT_POST_Z
	local peg = 5.6
	for _, side in { -1, 1 } do
		local x = side * (POST_X + POST / 2)
		local hang = side * 3.95
		decor(kit.rod("Peg", V(x, peg, z), V(side * 4.1, peg, z), 0.1, TIMBER))
		decor(kit.rod("Cord", V(hang, peg, z), V(hang, 5.1, z), 0.05, INK, FABRIC))
	end

	local herbs = -3.95
	decor(
		kit.box(
			"Herbs",
			V(herbs - 0.18, 4.2, z - 0.18),
			V(herbs + 0.18, 5.1, z + 0.18),
			HERB,
			Enum.Material.Grass
		)
	)
	decor(kit.rod("HerbTie", V(herbs, 4.85, z), V(herbs, 4.95, z), 0.42, GOLD, FABRIC))

	local gourd = 3.95
	for _, ball in { { y = 4.55, size = 0.7 }, { y = 4.98, size = 0.45 } } do
		local half = ball.size / 2
		local part = decor(
			kit.box(
				"Gourd",
				V(gourd - half, ball.y - half, z - half),
				V(gourd + half, ball.y + half, z + half),
				GOURD,
				Enum.Material.Wood
			)
		)
		part.Shape = Enum.PartType.Ball
	end
	decor(kit.disc("GourdTie", V(gourd, 4.86, z), UP, 0.32, 0.08, LACQUER, FABRIC))
end

-- Builds the stall under `parent`, standing on `place` (the middle of its front on the ground,
-- looking out at the customers). Returns its counter, which gets the prompt.
function PotionStall.build(parent: Instance, place: CFrame): Part
	local folder = Instance.new("Folder")
	folder.Name = "PotionStall"
	local kit = ShopHouse.kit(folder, place)
	local counter = buildCart(kit)
	buildGoods(kit)
	buildRoof(kit)
	buildHangings(kit)
	buildBack(kit)

	local kabuto = Figure.keeper(Catalog.keeperById.kabuto_shop)
	kabuto.Name = Net.KEEPER
	kit.stand(kabuto, V(0, STEP, 3.4))

	folder.Parent = parent
	return counter
end

return PotionStall
