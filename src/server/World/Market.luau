--!strict
-- The market: three stalls in a row down the middle of the street, each a counter under a
-- tiered roof with its wares laid out on top. Walking up to a counter and using its prompt opens
-- that shop's window on the client (the prompt's attribute says which). The server only needs to
-- know whether a player is standing at a stall when they ask to buy or sell there.
--
-- Built from plain parts in Hub coordinates; call start() after Hub.start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Hub = require("./Hub")
local Net = require(ReplicatedStorage.Shared.Net)

local Market = {}

-- A player this close to a stall's counter may buy or sell there, studs.
local RANGE = 18

local WOOD = Color3.fromRGB(121, 85, 61)
local DARK_WOOD = Color3.fromRGB(78, 52, 46)
local PALE_WOOD = Color3.fromRGB(188, 158, 130)
local GOLD = Color3.fromRGB(255, 202, 40)

type Stall = {
	id: string, -- also the shop window the prompt opens
	along: number, -- where on the street it stands, Hub x
	title: string,
	color: Color3,
	-- Lays the stall's wares on the counter, whose top is centered on `top`.
	wares: (folder: Folder, top: Vector3) -> (),
}

local counters: { [string]: Part } = {}

-- A small decorative part that nothing collides with.
local function prop(
	folder: Folder,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Build.part(folder, "Ware", size, cframe.Position, color, material)
	part.CFrame = cframe
	part.CanCollide = false
	part.CanQuery = false
	return part
end

local STALLS: { Stall } = {
	{
		id = "chakra",
		along = -20,
		title = "CHAKRA STORE",
		color = Color3.fromRGB(79, 195, 247),
		-- A row of kunai, cheapest to dearest, and a glowing orb of chakra.
		wares = function(folder, top)
			local shown = { 2, 5, 9 }
			for i, index in shown do
				local kunai = Catalog.kunai[math.min(index, #Catalog.kunai)]
				local lying = CFrame.new(top + Vector3.new((i - 2) * 1.6, 0.15, -1.2))
					* CFrame.Angles(0, math.rad(25), 0)
				prop(
					folder,
					Vector3.new(0.3, 0.3, 2.6),
					lying,
					Color3.fromHex(kunai.color),
					if kunai.glow then Enum.Material.Neon else Enum.Material.Metal
				)
			end
			local orb = prop(
				folder,
				Vector3.new(1.6, 1.6, 1.6),
				CFrame.new(top + Vector3.new(0, 1, 1.4)),
				Color3.fromRGB(79, 195, 247),
				Enum.Material.Neon
			)
			orb.Shape = Enum.PartType.Ball
		end,
	},
	{
		id = "speed",
		along = -36,
		title = "SPEED STORE",
		color = GOLD,
		-- A pair of sandals and a stack of scrolls.
		wares = function(folder, top)
			for _, side in { -1, 1 } do
				prop(
					folder,
					Vector3.new(0.9, 0.35, 2.2),
					CFrame.new(top + Vector3.new(side * 0.7 - 1.4, 0.18, -1)),
					DARK_WOOD,
					Enum.Material.Wood
				)
			end
			for i = 1, 3 do
				-- A cylinder part lies along its X axis, which is how a scroll should lie.
				local scroll = prop(
					folder,
					Vector3.new(2.4, 0.7, 0.7),
					CFrame.new(top + Vector3.new(1.3, 0.35 + (i - 1) * 0.02, i * 0.8 - 0.6)),
					if i == 2 then GOLD else Color3.fromRGB(245, 245, 245),
					Enum.Material.Fabric
				)
				scroll.Shape = Enum.PartType.Cylinder
			end
		end,
	},
	{
		id = "sell",
		along = -52,
		title = "SELL",
		color = Color3.fromRGB(229, 57, 53),
		-- A money chest and a stack of coins.
		wares = function(folder, top)
			prop(
				folder,
				Vector3.new(2.8, 1.6, 1.9),
				CFrame.new(top + Vector3.new(-1, 0.8, 0)),
				DARK_WOOD,
				Enum.Material.Wood
			)
			prop(
				folder,
				Vector3.new(2.9, 0.3, 2),
				CFrame.new(top + Vector3.new(-1, 1.2, 0)),
				GOLD,
				Enum.Material.Metal
			)
			for i = 1, 4 do
				-- Coins: flat cylinders stood on end, hence the turn.
				local coin = prop(
					folder,
					Vector3.new(0.25, 1.2, 1.2),
					CFrame.new(top + Vector3.new(1.6, 0.13 + (i - 1) * 0.25, 0.4))
						* CFrame.Angles(0, 0, math.rad(90)),
					GOLD,
					Enum.Material.Metal
				)
				coin.Shape = Enum.PartType.Cylinder
			end
		end,
	},
}

local function build(folder: Folder, stall: Stall)
	local base = Hub.at(stall.along, 0, 0)
	local function at(x: number, y: number, z: number): Vector3
		return base + Vector3.new(x, y, z)
	end

	local counter = Build.part(
		folder,
		`Counter_{stall.id}`,
		Vector3.new(7, 3.2, 7),
		at(0, 1.6, 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	Build.part(
		folder,
		"CounterTop",
		Vector3.new(7.8, 0.4, 7.8),
		at(0, 3.4, 0),
		PALE_WOOD,
		Enum.Material.Wood
	)
	stall.wares(folder, at(0, 3.6, 0))

	-- Four posts carry a two-tier roof in the shop's color, with a lantern at each corner.
	for _, x in { -3.6, 3.6 } do
		for _, z in { -3.6, 3.6 } do
			Build.part(
				folder,
				"Post",
				Vector3.new(0.7, 10, 0.7),
				at(x, 5, z),
				DARK_WOOD,
				Enum.Material.Wood
			)
			local lantern = Build.part(
				folder,
				"Lantern",
				Vector3.new(0.9, 0.9, 0.9),
				at(x * 1.25, 9.3, z * 1.25),
				stall.color,
				Enum.Material.Neon
			)
			lantern.Shape = Enum.PartType.Ball
			lantern.CanCollide = false
		end
	end
	Build.part(
		folder,
		"Roof",
		Vector3.new(11, 0.7, 11),
		at(0, 10.35, 0),
		stall.color,
		Enum.Material.Fabric
	)
	local cap = Build.part(
		folder,
		"RoofCap",
		Vector3.new(6.5, 0.7, 6.5),
		at(0, 11.05, 0),
		stall.color:Lerp(Color3.new(0, 0, 0), 0.3),
		Enum.Material.Fabric
	)
	Build.label(cap, stall.title, 3.4, Vector2.new(18, 4))

	local prompt = Build.prompt(counter, "Open", stall.title)
	prompt.MaxActivationDistance = 12
	prompt:SetAttribute(Net.SHOP_ATTRIBUTE, stall.id)
	counters[stall.id] = counter
end

-- Whether the player is standing at the given stall ("chakra", "speed" or "sell").
function Market.playerAt(player: Player, stallId: string): boolean
	local counter = counters[stallId]
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not counter or not root or not root:IsA("BasePart") then
		return false
	end
	return (counter.Position - root.Position).Magnitude <= RANGE
end

function Market.start()
	local folder = Instance.new("Folder")
	folder.Name = "Market"
	for _, stall in STALLS do
		build(folder, stall)
	end
	folder.Parent = Workspace
end

return Market
