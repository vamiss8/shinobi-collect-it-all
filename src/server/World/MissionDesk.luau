--!strict
-- The Mission Desk, where shinobi are sold for Ryo, in a house of World/ShopHouse: Shizune
-- behind the desk with Tonton sitting on it among piles of mission papers, the mission board on
-- the back wall with requests pinned under the ranks D to S, a cabinet of scrolls on the left
-- wall and a hanging scroll over a chest on the right. Outside, a board of requests hangs on
-- the back wall.
--
-- Shizune and Tonton are figures (View/Figure, Config/Keepers): models named "shizune" and
-- "tonton" in ReplicatedStorage.Models take the placeholders' places once they are supplied.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Net = require(ReplicatedStorage.Shared.Net)
local ShopHouse = require("./ShopHouse")

local MissionDesk = {}

local V = Vector3.new
local UP = V(0, 1, 0)
local OUTWARD = V(0, 0, -1) -- house-local: out of the front

local TIMBER = ShopHouse.TIMBER
local WOOD = ShopHouse.WOOD
local PALE_WOOD = ShopHouse.PALE_WOOD
local PAPER = ShopHouse.PAPER
local INK = ShopHouse.INK
local GOLD = ShopHouse.GOLD
local IRON = ShopHouse.IRON
local LACQUER = ShopHouse.LACQUER
local SHEET = Color3.fromRGB(246, 241, 228) -- fresh paper
local GREEN = Color3.fromRGB(46, 94, 62)

local METAL = Enum.Material.Metal
local FABRIC = Enum.Material.Fabric
local decor = ShopHouse.decor

local STYLE: ShopHouse.Style = {
	name = "MissionDesk",
	title = "MISSION DESK",
	sign = "任務", -- "mission"
	plaster = Color3.fromRGB(242, 236, 222),
	tiles = Color3.fromRGB(201, 92, 52),
	ridge = Color3.fromRGB(140, 56, 34),
	trim = Color3.fromRGB(120, 40, 30),
	noren = GREEN,
	cloth = GREEN,
}

-- The mission board's columns, by rank, and how many requests are pinned under each: the
-- higher the rank, the fewer.
local BOARD: { { rank: string, requests: number } } = {
	{ rank = "D", requests = 4 },
	{ rank = "C", requests = 3 },
	{ rank = "B", requests = 3 },
	{ rank = "A", requests = 2 },
	{ rank = "S", requests = 1 },
}

-- A flat block whose face looks out of the front, turned `spin` radians in its own plane.
local function sheet(
	kit: ShopHouse.Kit,
	name: string,
	center: Vector3,
	size: Vector3,
	spin: number,
	color: Color3,
	material: Enum.Material?
): Part
	local across = V(math.cos(spin), math.sin(spin), 0)
	local along = V(-math.sin(spin), math.cos(spin), 0)
	return decor(kit.plate(name, center, across, along, size, color, material))
end

-- A paper pinned to a board whose face is at z = `face`: two lines of ink on it, a red pin.
local function request(kit: ShopHouse.Kit, center: Vector3, face: number, spin: number)
	local paper = V(center.X, center.Y, face - 0.03)
	sheet(kit, "Request", paper, V(1.5, 0.85, 0.04), spin, SHEET)
	local down = V(math.sin(spin), -math.cos(spin), 0)
	for k = 0, 1 do
		local line = V(paper.X, paper.Y, face - 0.06) + down * (0.05 + 0.24 * k)
		sheet(kit, "Writing", line, V(1 - 0.3 * k, 0.07, 0.02), spin, INK)
	end
	local pin = V(paper.X, paper.Y, face - 0.08) - down * 0.32
	decor(kit.disc("Pin", pin, OUTWARD, 0.16, 0.08, LACQUER))
end

-- A board of text, its face looking out of the front.
local function lettered(
	kit: ShopHouse.Kit,
	name: string,
	center: Vector3,
	size: Vector3,
	color: Color3,
	text: string,
	ink: Color3
)
	local position = kit.at(center)
	local plate = decor(Build.part(kit.folder, name, size, position, color, Enum.Material.Wood))
	plate.CFrame = CFrame.lookAt(position, position + kit.out)
	local label = Build.faceLabel(plate, Enum.NormalId.Front, text)
	label.TextColor3 = ink
end

-- On the desk: piles of mission papers, an ink stone and brush, the ledger, a stamp and its
-- pad, and the Ryo the desk pays out. At its ends, crates and a basket of scrolls.
local function buildDesk(kit: ShopHouse.Kit)
	local top = ShopHouse.COUNTER_TOP
	for i, pile in
		{ { x = -4.6, height = 0.5 }, { x = -3.6, height = 0.8 }, { x = -2.7, height = 0.35 } }
	do
		local spin = (i - 2) * 0.12
		local h = pile.height
		local center = V(pile.x, top + h / 2, 2.3)
		decor(
			kit.plate(
				"Papers",
				center,
				V(math.cos(spin), 0, math.sin(spin)),
				UP,
				V(0.85, h, 1.15),
				SHEET
			)
		)
		local cover = V(pile.x, top + h + 0.02, 2.3)
		local turn = spin + 0.15
		decor(
			kit.plate(
				"Paper",
				cover,
				V(math.cos(turn), 0, math.sin(turn)),
				UP,
				V(0.85, 0.03, 1.15),
				PAPER
			)
		)
	end
	-- The ink stone with a brush across it.
	decor(
		kit.box("InkStone", V(-1.8, top, 1.7), V(-1.0, top + 0.14, 2.3), INK, Enum.Material.Slate)
	)
	decor(
		kit.rod(
			"Brush",
			V(-1.9, top + 0.22, 2.5),
			V(-0.8, top + 0.22, 2.2),
			0.08,
			PALE_WOOD,
			Enum.Material.Wood
		)
	)
	decor(
		kit.rod("BrushTip", V(-0.8, top + 0.22, 2.2), V(-0.6, top + 0.22, 2.15), 0.1, INK, FABRIC)
	)
	-- The ledger, open in front of Shizune.
	decor(kit.box("Ledger", V(-0.75, top, 1.6), V(0.75, top + 0.12, 2.6), GREEN, FABRIC))
	decor(kit.box("LedgerPages", V(-0.68, top + 0.12, 1.66), V(0.68, top + 0.18, 2.54), SHEET))
	-- The stamp and its red pad.
	decor(
		kit.rod(
			"Stamp",
			V(1.3, top, 2.0),
			V(1.3, top + 0.6, 2.0),
			0.28,
			LACQUER,
			Enum.Material.Wood
		)
	)
	decor(kit.disc("InkPad", V(1.8, top + 0.04, 2.1), UP, 0.5, 0.08, LACQUER, FABRIC))
	-- Stacks of gold Ryo on a tray.
	decor(
		kit.box("CoinTray", V(4.2, top, 1.6), V(5.4, top + 0.08, 2.8), TIMBER, Enum.Material.Wood)
	)
	for _, coins in
		{
			{ x = 4.5, z = 1.9, h = 0.5 },
			{ x = 5.05, z = 2.0, h = 0.3 },
			{ x = 4.75, z = 2.5, h = 0.4 },
		}
	do
		local from = V(coins.x, top + 0.08, coins.z)
		decor(kit.rod("Coins", from, from + UP * coins.h, 0.5, GOLD, METAL))
	end

	local floor = ShopHouse.FLOOR
	-- Crates on the left.
	kit.box("Crate", V(-7.8, floor, 1.5), V(-6.2, floor + 1.4, 3.1), WOOD, Enum.Material.WoodPlanks)
	decor(
		kit.box(
			"Crate",
			V(-7.5, floor + 1.4, 1.8),
			V(-6.5, floor + 2.3, 2.8),
			PALE_WOOD,
			Enum.Material.WoodPlanks
		)
	)
	for _, y in { 0.2, 1.1 } do
		decor(
			kit.box(
				"CrateBand",
				V(-7.85, floor + y, 1.45),
				V(-6.15, floor + y + 0.12, 3.15),
				IRON,
				METAL
			)
		)
	end
	-- A basket of scrolls on the right.
	kit.rod("Basket", V(7, floor, 2.3), V(7, floor + 1.5, 2.3), 1.6, PALE_WOOD, FABRIC)
	decor(kit.rod("BasketRim", V(7, floor + 1.4, 2.3), V(7, floor + 1.6, 2.3), 1.7, WOOD, FABRIC))
	for i, lean in
		{ V(-0.3, 0, -0.25), V(0.3, 0, -0.2), V(0, 0, 0.3), V(-0.25, 0, 0.3), V(0.3, 0, 0.3) }
	do
		local foot = V(7 + lean.X * 0.5, floor + 0.6, 2.3 + lean.Z * 0.5)
		local head = V(7 + lean.X, floor + 2.4 + (i % 3) * 0.25, 2.3 + lean.Z)
		local color = if i % 2 == 0 then LACQUER else PAPER
		decor(kit.rod("BasketScroll", foot, head, 0.4, color, FABRIC))
	end
end

-- Inside: the mission board on the back wall, a cabinet of scrolls on the left wall, and on the
-- right a hanging scroll over a chest of drawers.
local function buildInside(kit: ShopHouse.Kit)
	local wall = ShopHouse.BACK_INSIDE
	local face = wall - 0.25
	decor(
		kit.box("MissionBoard", V(-6.6, 2.4, face), V(6.6, 7.8, wall), TIMBER, Enum.Material.Wood)
	)
	local spacing = 2.6
	for column, entry in BOARD do
		local x = (column - (#BOARD + 1) / 2) * spacing
		local rank = Catalog.ranks[Catalog.rankOrder[entry.rank]]
		local color = if rank then Color3.fromHex(rank.color) else PAPER
		lettered(kit, "Rank", V(x, 7.15, face - 0.05), V(1.4, 0.7, 0.1), color, entry.rank, INK)
		for k = 1, entry.requests do
			local spin = math.rad(((column * 7 + k * 5) % 9) - 4)
			request(kit, V(x, 7.15 - 1.05 * k, 0), face, spin)
		end
	end

	-- The cabinet: four rows of three pigeonholes, each with a scroll or two in it.
	local stage = ShopHouse.STAGE
	local x0, x1 = -ShopHouse.SIDE_INSIDE, -ShopHouse.SIDE_INSIDE + 1.3
	local z0, z1 = 6.7, 10.9
	local rows, columns = 4, 3
	local rowHeight = 1.45
	local columnWidth = (z1 - z0) / columns
	for r = 0, rows do
		local y = stage + r * rowHeight
		decor(kit.box("Shelf", V(x0, y, z0), V(x1, y + 0.15, z1), WOOD, Enum.Material.Wood))
	end
	for c = 0, columns do
		-- Each divider stands a little proud of the shelves and runs up under the top one, so
		-- that no face of one lies in a face of another.
		local z = z0 + c * columnWidth
		local top = stage + rows * rowHeight
		decor(
			kit.box(
				"Divider",
				V(x0, stage, z - 0.075),
				V(x1 + 0.04, top, z + 0.075),
				WOOD,
				Enum.Material.Wood
			)
		)
	end
	local colors = { PAPER, LACQUER, SHEET, GREEN, PAPER }
	for r = 0, rows - 1 do
		for c = 0, columns - 1 do
			local count = 1 + (r + c) % 2
			-- One or two scrolls lying side by side on the shelf, ends out.
			for k = 1, count do
				local y = stage + r * rowHeight + 0.15 + 0.21
				local z = z0 + (c + 0.5) * columnWidth + (if count == 2 then (k - 1.5) * 0.5 else 0)
				local color = colors[(r * 3 + c + k) % #colors + 1]
				decor(
					kit.rod("Scroll", V(x0 + 0.05, y, z), V(x1 - 0.05, y, z), 0.42, color, FABRIC)
				)
			end
		end
	end

	-- The hanging scroll and the chest of drawers under it.
	local wallX = ShopHouse.SIDE_INSIDE
	local inward = kit.dir(V(-1, 0, 0))
	local scrollAt = kit.at(V(wallX - 0.15, 5.8, 8.6))
	local hanging =
		decor(Build.part(kit.folder, "HangingScroll", V(1.4, 3, 0.06), scrollAt, SHEET, FABRIC))
	hanging.CFrame = CFrame.lookAt(scrollAt, scrollAt + inward)
	local words = Build.faceLabel(hanging, Enum.NormalId.Front, "火\nの\n意\n志") -- "will of fire"
	words.TextColor3 = INK
	for _, y in { 4.25, 7.35 } do
		decor(
			kit.rod(
				"ScrollRod",
				V(wallX - 0.2, y, 7.75),
				V(wallX - 0.2, y, 9.45),
				0.16,
				TIMBER,
				Enum.Material.Wood
			)
		)
	end
	local chest0, chest1 = V(wallX - 1.2, stage, 7.2), V(wallX, stage + 1.8, 10)
	kit.box("Chest", chest0, chest1, WOOD, Enum.Material.Wood)
	for _, drawer in { { 0.15, 0.85 }, { 0.95, 1.65 } } do
		local y0, y1 = stage + drawer[1], stage + drawer[2]
		for _, span in { { 7.35, 8.55 }, { 8.65, 9.85 } } do
			decor(
				kit.box(
					"Drawer",
					V(chest0.X - 0.05, y0, span[1]),
					V(chest0.X, y1, span[2]),
					PALE_WOOD,
					Enum.Material.Wood
				)
			)
			local handle = V(chest0.X - 0.1, (y0 + y1) / 2, (span[1] + span[2]) / 2)
			decor(kit.disc("Handle", handle, V(-1, 0, 0), 0.22, 0.08, IRON, METAL))
		end
	end
end

-- Outside the back: a board of requests under a little roof, with its name over it.
local function buildBack(kit: ShopHouse.Kit)
	local face = ShopHouse.BACK_OUTSIDE
	local back = V(0, 0, 1)
	local function outside(x: number, y: number, depth: number): Vector3
		return V(x, y, face + depth)
	end
	decor(
		kit.box(
			"RequestBoard",
			outside(-3.8, 2.4, 0.1),
			outside(3.8, 6.4, 0.35),
			TIMBER,
			Enum.Material.Wood
		)
	)
	decor(
		kit.box(
			"BoardRoof",
			outside(-4.2, 6.6, 0.1),
			outside(4.2, 6.85, 1.0),
			STYLE.tiles,
			Enum.Material.ClayRoofTiles
		)
	)
	for i, spot in
		{
			V(-2.6, 5.4, 0),
			V(-0.9, 5.5, 0),
			V(0.9, 5.35, 0),
			V(2.6, 5.5, 0),
			V(-1.8, 3.6, 0),
			V(1.6, 3.5, 0),
		}
	do
		local paper = outside(spot.X, spot.Y, 0.37)
		local spin = math.rad((i * 37) % 11 - 5)
		local across = V(math.cos(spin), math.sin(spin), 0)
		local along = V(-math.sin(spin), math.cos(spin), 0)
		decor(kit.plate("Request", paper, across, along, V(1.4, 1.2, 0.04), SHEET))
		decor(kit.disc("Pin", paper + along * 0.45 + back * 0.07, back, 0.16, 0.08, LACQUER))
	end
	-- Its name, "requests", on a plate over it, turned to face the way the back does.
	local plateAt = kit.at(outside(0, 7.35, 0.1))
	local plate = decor(
		Build.part(kit.folder, "BoardName", V(2.4, 0.8, 0.12), plateAt, TIMBER, Enum.Material.Wood)
	)
	plate.CFrame = CFrame.lookAt(plateAt, plateAt - kit.out)
	local name = Build.faceLabel(plate, Enum.NormalId.Front, "依頼")
	name.TextColor3 = GOLD
end

-- Builds the desk under `parent`, standing on `place` (the middle of its front on the ground,
-- looking out at the customers). Returns its counter, which gets the shop's prompt.
function MissionDesk.build(parent: Instance, place: CFrame): Part
	local kit, counter = ShopHouse.build(parent, place, STYLE)
	buildDesk(kit)
	buildInside(kit)
	buildBack(kit)

	local shizune = Figure.keeper(Catalog.keeperById.shizune)
	shizune.Name = Net.KEEPER
	kit.stand(shizune, ShopHouse.KEEPER)
	-- Tonton sits on the desk next to the coins.
	local tonton = Figure.keeper(Catalog.keeperById.tonton)
	kit.stand(tonton, V(3.2, ShopHouse.COUNTER_TOP, 2.4))
	return counter
end

return MissionDesk
