--!strict
-- The Herb Shop, where potions are bought for Herbs (Config/Potions, Logic/Pouch), in a house of
-- World/ShopHouse: shelves of jars on the back wall, bunches of herbs drying under the roof, a
-- mortar and the four potions on the counter, and the herbalist behind it.
--
-- A STAND-IN (2026-10-16): the owners are making the shop and its keeper themselves. Until
-- then the keeper is the placeholder "herbalist" of Config/Keepers, whose model, once there is
-- one, goes into ReplicatedStorage.Models under that name like any other keeper's; the house
-- is the market's own with the colors of a herbalist's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Net = require(ReplicatedStorage.Shared.Net)
local ShopHouse = require("./ShopHouse")

local HerbShop = {}

local V = Vector3.new
local UP = V(0, 1, 0)

local TIMBER = ShopHouse.TIMBER
local WOOD = ShopHouse.WOOD
local PALE_WOOD = ShopHouse.PALE_WOOD
local PAPER = ShopHouse.PAPER
local LACQUER = ShopHouse.LACQUER
local LEAF = Color3.fromRGB(86, 139, 62)
local DRIED = Color3.fromRGB(150, 140, 72)
local SAGE = Color3.fromRGB(122, 156, 120)
local CLAY = Color3.fromRGB(176, 112, 74)
local STONE = Color3.fromRGB(128, 124, 118)

local FABRIC = Enum.Material.Fabric
local decor = ShopHouse.decor

local STYLE: ShopHouse.Style = {
	name = "HerbShop",
	title = "HERB SHOP",
	sign = "薬草", -- "medicinal herbs"
	plaster = Color3.fromRGB(236, 232, 210),
	tiles = Color3.fromRGB(70, 104, 74),
	ridge = Color3.fromRGB(44, 70, 48),
	trim = Color3.fromRGB(96, 64, 40),
	noren = Color3.fromRGB(84, 120, 60),
	cloth = Color3.fromRGB(84, 120, 60),
}

-- The jars' colors, along a shelf: clay, glazes and the potions' own.
local JARS = {
	CLAY,
	Color3.fromRGB(64, 120, 168),
	SAGE,
	Color3.fromRGB(196, 150, 62),
	Color3.fromRGB(120, 86, 160),
	PAPER,
	Color3.fromRGB(150, 72, 52),
}

-- Shelves of jars across the back wall: three boards, each with a row of jars of a few sizes,
-- lids on some.
local function buildShelves(kit: ShopHouse.Kit)
	local wall = ShopHouse.BACK_INSIDE
	local stage = ShopHouse.STAGE
	local front = wall - 1.1
	for row, y in { stage + 1.3, stage + 2.8, stage + 4.3 } do
		decor(kit.box("Shelf", V(-6.4, y - 0.12, front), V(6.4, y, wall), WOOD, Enum.Material.Wood))
		local count = 9
		for k = 0, count - 1 do
			local x = -5.6 + k * 1.4
			local tall = 0.55 + ((k + row) % 3) * 0.2
			local wide = 0.55 + ((k * 2 + row) % 3) * 0.12
			local color = JARS[(k + row * 3) % #JARS + 1]
			local z = front + 0.55
			local foot = V(x, y, z)
			decor(kit.rod("Jar", foot, foot + UP * tall, wide, color, Enum.Material.SmoothPlastic))
			if (k + row) % 2 == 0 then
				-- A lid a little wider than its jar, so that their sides do not meet in one face.
				local lid = foot + UP * tall
				decor(
					kit.rod("JarLid", lid, lid + UP * 0.12, wide + 0.1, TIMBER, Enum.Material.Wood)
				)
			end
		end
	end
	-- The boards' brackets, under the ends of each.
	for _, x in { -6.1, 6.1 } do
		decor(
			kit.box(
				"ShelfSide",
				V(x - 0.15, stage, front + 0.05),
				V(x + 0.15, stage + 4.45, wall),
				TIMBER,
				Enum.Material.Wood
			)
		)
	end
end

-- Bunches of herbs drying head down on cords from a pole under the roof, behind the keeper.
local function buildBunches(kit: ShopHouse.Kit)
	local z = 8.2
	local poleY = 8.5
	decor(kit.rod("HerbPole", V(-7, poleY, z), V(7, poleY, z), 0.18, TIMBER, Enum.Material.Wood))
	for k, x in { -6, -4.5, -3, -1.5, 1.5, 3, 4.5, 6 } do
		local drop = 0.5 + (k % 3) * 0.2
		local top = poleY - 0.05
		decor(kit.rod("HerbCord", V(x, top, z), V(x, top - drop, z), 0.05, PAPER, FABRIC))
		local color = if k % 3 == 0 then DRIED elseif k % 3 == 1 then LEAF else SAGE
		local tie = top - drop
		-- A bunch: tied at the top, fanning out downwards.
		decor(kit.rod("HerbTie", V(x, tie, z), V(x, tie - 0.18, z), 0.22, LACQUER, FABRIC))
		decor(kit.rod("Herbs", V(x, tie - 0.18, z), V(x, tie - 1.1, z), 0.55, color, FABRIC))
		decor(
			kit.rod(
				"HerbTips",
				V(x, tie - 1.1, z),
				V(x, tie - 1.35, z),
				0.75,
				color,
				Enum.Material.Grass
			)
		)
	end
end

-- On the counter: a mortar with its pestle, and the four potions the shop sells, from the
-- Soldier Pill's box to the Sage Oil's bottle.
local function buildCounter(kit: ShopHouse.Kit)
	local top = ShopHouse.COUNTER_TOP
	local mortar = V(-3.6, top, 2.3)
	decor(kit.rod("Mortar", mortar, mortar + UP * 0.55, 0.95, STONE, Enum.Material.Slate))
	decor(
		kit.rod(
			"MortarHerbs",
			mortar + UP * 0.55,
			mortar + UP * 0.6,
			0.7,
			LEAF,
			Enum.Material.Grass
		)
	)
	decor(
		kit.rod(
			"Pestle",
			mortar + V(0.1, 0.3, 0),
			mortar + V(0.55, 1.15, -0.15),
			0.16,
			PALE_WOOD,
			Enum.Material.Wood
		)
	)
	-- The Soldier Pill: a small blue box of pills.
	decor(
		kit.box("PillBox", V(1.0, top, 1.9), V(1.7, top + 0.35, 2.6), Color3.fromRGB(64, 120, 168))
	)
	-- Ichiraku's ramen: a bowl with its broth.
	local bowl = V(2.6, top, 2.3)
	decor(kit.rod("RamenBowl", bowl, bowl + UP * 0.4, 0.8, Color3.fromRGB(196, 72, 44)))
	decor(
		kit.rod(
			"RamenBroth",
			bowl + UP * 0.4,
			bowl + UP * 0.43,
			0.65,
			Color3.fromRGB(236, 196, 120)
		)
	)
	-- Gama-chan, the toad purse: a round green body.
	local toad = V(3.6, top, 2.2)
	decor(kit.rod("ToadCharm", toad, toad + UP * 0.45, 0.6, Color3.fromRGB(110, 170, 70), FABRIC))
	-- The Sage Oil: a violet bottle with a cork.
	local bottle = V(4.5, top, 2.4)
	decor(kit.rod("OilBottle", bottle, bottle + UP * 0.7, 0.4, Color3.fromRGB(120, 86, 160)))
	decor(
		kit.rod("OilNeck", bottle + UP * 0.7, bottle + UP * 0.9, 0.18, Color3.fromRGB(120, 86, 160))
	)
	decor(
		kit.rod(
			"OilCork",
			bottle + UP * 0.9,
			bottle + UP * 1.0,
			0.22,
			PALE_WOOD,
			Enum.Material.Wood
		)
	)
end

-- Builds the shop under `parent`, standing on `place` (the middle of its front on the ground,
-- looking out at the customers). Returns its counter, which gets the shop's prompt.
function HerbShop.build(parent: Instance, place: CFrame): Part
	local kit, counter = ShopHouse.build(parent, place, STYLE)
	buildShelves(kit)
	buildBunches(kit)
	buildCounter(kit)

	local keeper = Figure.keeper(Catalog.keeperById.herbalist)
	keeper.Name = Net.KEEPER
	kit.stand(keeper, ShopHouse.KEEPER)
	return counter
end

return HerbShop
