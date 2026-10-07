--!strict
-- Tenten's Ninja Tools, the shop that sells kunai, in a house of World/ShopHouse: Tenten behind
-- the counter, three kunai, a tray of shuriken and scrolls on it, barrels of spears and swords
-- at its ends, and every kunai of Config/Kunai hung on the back wall in the order they are sold.
-- Inside are a target on the left wall and a rack of weapons on the right; outside, a big
-- target hangs on the back wall.
--
-- Tenten is a figure (View/Figure, Config/Keepers): a model named "tenten" in
-- ReplicatedStorage.Models takes the placeholder's place once it is supplied. Supplied kunai models (View/KunaiModel) hang on
-- the wall in place of the plain ones.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local KunaiModel = require(ReplicatedStorage.Shared.View.KunaiModel)
local Net = require(ReplicatedStorage.Shared.Net)
local ShopHouse = require("./ShopHouse")

local TentenShop = {}

local V = Vector3.new
local UP = V(0, 1, 0)

local KUNAI = 2.07 -- length of a kunai from the point to the far edge of its ring

local TIMBER = ShopHouse.TIMBER
local WOOD = ShopHouse.WOOD
local PALE_WOOD = ShopHouse.PALE_WOOD
local PAPER = ShopHouse.PAPER
local INK = ShopHouse.INK
local GOLD = ShopHouse.GOLD
local IRON = ShopHouse.IRON
local LACQUER = ShopHouse.LACQUER
local STEEL = Color3.fromRGB(176, 190, 197)

local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local decor = ShopHouse.decor

local STYLE: ShopHouse.Style = {
	name = "TentenShop",
	title = "TENTEN'S NINJA TOOLS",
	sign = "忍具", -- "ninja tools"
	plaster = Color3.fromRGB(238, 230, 214),
	tiles = Color3.fromRGB(58, 66, 82),
	ridge = Color3.fromRGB(40, 45, 56),
	trim = LACQUER,
	noren = Color3.fromRGB(32, 44, 74),
	cloth = Color3.fromRGB(32, 44, 74),
}

-- A kunai with its point at `tip`, its blade pointing `down` from the ring and its flat side
-- towards `facing` (house-local directions, square to each other). The supplied model if there
-- is one, else a blade, a point, a wrapped handle and a ring in the kunai's colors. `behind`
-- is the color that shows through the ring.
local function kunai(
	kit: ShopHouse.Kit,
	look: Catalog.Kunai,
	tip: Vector3,
	down: Vector3,
	facing: Vector3,
	behind: Color3
)
	local model = KunaiModel.supplied(look.id, KUNAI)
	if model then
		local middle = kit.at(tip - down * (KUNAI / 2))
		model:PivotTo(CFrame.lookAt(middle, middle + kit.dir(down), kit.dir(facing)))
		model.Parent = kit.folder
		return
	end

	local across = down:Cross(facing)
	local blade = Color3.fromHex(look.color)
	local material = if look.glow then Enum.Material.Neon else METAL
	local up = -down
	decor(kit.plate("KunaiBlade", tip + up * 0.6, across, up, V(0.4, 0.8, 0.08), blade, material))
	-- The point: a square turned on its corner, so the blade ends in a tip. It is thinner than
	-- the blade, so that where the two overlap no face of one lies in a face of the other.
	local point = decor(
		kit.plate("KunaiPoint", tip + up * 0.2, across, up, V(0.28, 0.28, 0.04), blade, material)
	)
	point.CFrame *= CFrame.Angles(0, 0, math.rad(45))
	local wrap = Color3.fromHex(look.trail):Lerp(INK, 0.6)
	decor(kit.rod("KunaiHandle", tip + up * 1.0, tip + up * 1.7, 0.2, wrap, FABRIC))
	-- The ring, and through it a plug of what is behind, standing a little proud of it.
	local ring = tip + up * 1.88
	decor(kit.disc("KunaiRing", ring, facing, 0.38, 0.07, IRON, METAL))
	decor(kit.disc("KunaiHole", ring, facing, 0.2, 0.15, behind))
end

-- A kunai stuck in a target: only the handle and the ring stand out of it, pointing `out` from
-- the point `from` on its face.
local function stuck(kit: ShopHouse.Kit, from: Vector3, out: Vector3)
	local unit = out.Unit
	local handle = from + unit * 0.75
	decor(kit.rod("StuckKunai", from, handle, 0.2, INK, FABRIC))
	local side = unit:Cross(UP)
	if side.Magnitude < 0.1 then
		side = V(1, 0, 0)
	end
	decor(kit.disc("StuckRing", handle + unit * 0.18, side, 0.38, 0.07, IRON, METAL))
end

-- A shuriken lying flat against a surface whose outward direction is `normal`: two crossed
-- blades and a hub, turned `spin` radians about the normal.
local function shuriken(kit: ShopHouse.Kit, center: Vector3, normal: Vector3, spin: number)
	local base = if math.abs(normal.Y) > 0.9 then V(1, 0, 0) else UP
	local a = (base - normal * base:Dot(normal)).Unit
	local b = normal:Cross(a)
	local turnedA = a * math.cos(spin) + b * math.sin(spin)
	local turnedB = normal:Cross(turnedA)
	-- The second blade lies a little above the first, so that their faces do not meet.
	for k, blade in { turnedA, turnedB } do
		local edge = blade:Cross(normal)
		local at = center + normal * (0.02 * (k - 1))
		decor(kit.plate("Shuriken", at, edge, blade, V(0.16, 0.8, 0.05), IRON, METAL))
	end
	decor(kit.disc("ShurikenHub", center + normal * 0.01, normal, 0.24, 0.14, STEEL, METAL))
end

-- On the counter: three kunai laid out, a tray of shuriken and a pile of scrolls. At its ends,
-- barrels of spears and swords.
local function buildCounter(kit: ShopHouse.Kit)
	local top = ShopHouse.COUNTER_TOP
	local lying = V(0.15, 0, -1).Unit
	for i, index in { 2, 5, 9 } do
		local look = Catalog.kunai[math.min(index, #Catalog.kunai)]
		kunai(kit, look, V(-5.5 + i * 1.05, top + 0.045, 1.3), lying, UP, PALE_WOOD)
	end
	decor(kit.box("Tray", V(-1, top, 1.35), V(1, top + 0.08, 2.25), TIMBER, Enum.Material.Wood))
	for i, x in { -0.55, 0, 0.55 } do
		shuriken(kit, V(x, top + 0.12, 1.8), UP, i * 0.5)
	end
	for _, scroll in
		{
			{ y = 0.25, z = 1.9, x0 = 2.4, x1 = 4.6, color = PAPER },
			{ y = 0.25, z = 2.5, x0 = 2.4, x1 = 4.6, color = LACQUER },
			{ y = 0.68, z = 2.2, x0 = 2.6, x1 = 4.4, color = PAPER },
		}
	do
		local y = top + scroll.y
		decor(
			kit.rod(
				"Scroll",
				V(scroll.x0, y, scroll.z),
				V(scroll.x1, y, scroll.z),
				0.5,
				scroll.color,
				FABRIC
			)
		)
	end

	local floor = ShopHouse.FLOOR
	for _, side in { -1, 1 } do
		local x, z = side * 7, 2.3
		kit.rod("Barrel", V(x, floor, z), V(x, floor + 2.2, z), 1.7, WOOD, Enum.Material.Wood)
		for _, y in { 0.35, 1.65 } do
			decor(
				kit.rod(
					"BarrelBand",
					V(x, floor + y, z),
					V(x, floor + y + 0.2, z),
					1.78,
					IRON,
					METAL
				)
			)
		end
		for k, lean in { V(-0.35, 0, -0.2), V(0.3, 0, -0.25), V(0, 0, 0.35) } do
			local foot = V(x + lean.X * 0.3, floor + 1, z + lean.Z * 0.3)
			if side < 0 then
				local head = V(x + lean.X, floor + 5.6 + k * 0.3, z + lean.Z)
				local up = (head - foot).Unit
				decor(kit.rod("Spear", foot, head, 0.16, TIMBER, Enum.Material.Wood))
				local flat = up:Cross(V(0, 0, 1)).Unit
				decor(
					kit.plate(
						"SpearHead",
						head + up * 0.4,
						flat,
						up,
						V(0.3, 0.8, 0.06),
						STEEL,
						METAL
					)
				)
				decor(
					kit.rod(
						"SpearBinding",
						head - up * 0.05,
						head + up * 0.12,
						0.24,
						LACQUER,
						FABRIC
					)
				)
			else
				local guard = V(x + lean.X * 0.8, floor + 3.9 + k * 0.15, z + lean.Z * 0.8)
				local up = (guard - foot).Unit
				decor(kit.rod("Sheath", foot, guard - up * 0.05, 0.24, INK))
				decor(kit.disc("Guard", guard, up, 0.5, 0.08, GOLD, METAL))
				local hilt = if k == 2 then PAPER else LACQUER
				decor(kit.rod("Hilt", guard + up * 0.05, guard + up * 1.05, 0.2, hilt, FABRIC))
			end
		end
	end
end

-- Inside: every kunai on the back wall, a target on the left wall, a weapon rack on the right.
local function buildInside(kit: ShopHouse.Kit)
	local wall = ShopHouse.BACK_INSIDE
	local boardFront = wall - 0.25
	decor(
		kit.box(
			"KunaiBoard",
			V(-6.6, 2.4, boardFront),
			V(6.6, 7.8, wall),
			TIMBER,
			Enum.Material.Wood
		)
	)
	-- In the order they are sold, cheapest at the top left, on two rows.
	local count = #Catalog.kunai
	local perRow = math.ceil(count / 2)
	local spacing = 1.2
	for index, look in Catalog.kunai do
		local row = if index <= perRow then 1 else 2
		local inRow = if row == 1 then perRow else count - perRow
		local slot = if row == 1 then index else index - perRow
		local x = (slot - (inRow + 1) / 2) * spacing
		local ringY = if row == 1 then 7.2 else 4.7
		kunai(kit, look, V(x, ringY - 1.88, boardFront - 0.06), V(0, -1, 0), V(0, 0, -1), TIMBER)
	end

	-- The target on the left wall, with three kunai in the middle and shuriken around it.
	local face = -ShopHouse.SIDE_INSIDE + 0.15
	local center = V(face, 5.6, 8.3)
	local inward = V(1, 0, 0)
	kit.rings("Target", center, inward, {
		{ diameter = 3.4, color = TIMBER },
		{ diameter = 3, color = PAPER },
		{ diameter = 2.2, color = LACQUER },
		{ diameter = 1.4, color = PAPER },
		{ diameter = 0.6, color = LACQUER },
	})
	local surface = face + 0.3
	for _, hit in { V(0.12, 0.08, 0), V(-0.3, -0.3, 0.35), V(0.3, 0.28, -0.3) } do
		local from = V(surface, center.Y + hit.Y, center.Z + hit.Z)
		stuck(kit, from, V(1, hit.Y * 0.8, hit.Z * 0.8))
	end
	shuriken(kit, V(surface - 0.05, center.Y + 1.1, center.Z - 0.9), inward, 0.3)
	shuriken(kit, V(surface - 0.05, center.Y - 1.2, center.Z + 0.7), inward, 0.9)

	-- The rack on the right wall: a staff, a spear and a sword, each lying on two pegs.
	local x = ShopHouse.SIDE_INSIDE - 0.45
	for _, y in { 7.4, 6.2, 5 } do
		for _, z in { 4.2, 8.6 } do
			local from = V(ShopHouse.SIDE_INSIDE, y - 0.22, z)
			decor(kit.rod("Peg", from, V(x - 0.15, y - 0.22, z), 0.14, TIMBER, Enum.Material.Wood))
		end
	end
	decor(kit.rod("Staff", V(x, 7.4, 2.4), V(x, 7.4, 10.6), 0.26, PALE_WOOD, Enum.Material.Wood))
	decor(kit.rod("Spear", V(x, 6.2, 2.6), V(x, 6.2, 9.6), 0.2, TIMBER, Enum.Material.Wood))
	decor(kit.rod("SpearBinding", V(x, 6.2, 9.55), V(x, 6.2, 9.75), 0.26, LACQUER, FABRIC))
	decor(kit.plate("SpearHead", V(x, 6.2, 10.2), UP, V(0, 0, 1), V(0.3, 0.9, 0.06), STEEL, METAL))
	decor(kit.rod("Hilt", V(x, 5, 2.6), V(x, 5, 3.6), 0.22, LACQUER, FABRIC))
	decor(kit.disc("Guard", V(x, 5, 3.64), V(0, 0, 1), 0.55, 0.08, GOLD, METAL))
	decor(kit.rod("Sheath", V(x, 5, 3.68), V(x, 5, 8.8), 0.24, INK))
end

-- Outside the back: a big target with kunai and shuriken in it.
local function buildBack(kit: ShopHouse.Kit)
	local face = ShopHouse.BACK_OUTSIDE + 0.1
	local center = V(0, 5, face)
	local outward = V(0, 0, 1)
	kit.rings("BackTarget", center, outward, {
		{ diameter = 6.8, color = TIMBER },
		{ diameter = 6.2, color = LACQUER },
		{ diameter = 5, color = PAPER },
		{ diameter = 3.8, color = LACQUER },
		{ diameter = 2.6, color = PAPER },
		{ diameter = 1.3, color = GOLD },
	})
	local surface = face + 0.4
	for _, hit in { V(0.15, 0.2, 0), V(-0.5, -0.45, 0), V(0.65, -0.3, 0) } do
		stuck(kit, V(hit.X, center.Y + hit.Y, surface), V(hit.X * 0.8, hit.Y * 0.8, 1))
	end
	-- Two shuriken on the red ring, a little short of the middle.
	local ring = face + 0.22
	shuriken(kit, V(2.3, 6.7, ring), outward, 0.4)
	shuriken(kit, V(-2.5, 3.5, ring), outward, 1.1)
end

-- Builds the shop under `parent`, standing on `place` (the middle of its front on the ground,
-- looking out at the customers). Returns its counter, which gets the shop's prompt.
function TentenShop.build(parent: Instance, place: CFrame): Part
	local kit, counter = ShopHouse.build(parent, place, STYLE)
	buildCounter(kit)
	buildInside(kit)
	buildBack(kit)

	local keeper = Figure.keeper(Catalog.keeperById.tenten)
	keeper.Name = Net.KEEPER
	kit.stand(keeper, ShopHouse.KEEPER)
	return counter
end

return TentenShop
