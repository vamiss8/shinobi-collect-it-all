--!strict
-- The legendary shinobi (Config/Legends): three that are bought for Robux, each with a game
-- pass of its own, and stay for good. They stand on show on pedestals on the plaza
-- (World/Plaza builds the stones), each with what it earns written over it and its price at
-- its feet; the prompt at a pedestal offers Roblox's own purchase window.
--
-- A legendary shinobi is a unit like any other once owned: it goes into the inventory, onto a
-- pad, and is levelled up there. What is different is that it cannot be lost: the Mission Desk
-- does not take it (Services/Shop), a rebirth leaves it with its levels (Logic/Rebirth), and
-- whoever owns the pass and has no such unit is given one when their save loads. So the unit
-- in the save is what says it is owned; the pass is asked only to make good a save that lacks
-- one (bought while the game was down, or a save started over).
--
-- A pass's id is 0 until the pass is made on the Creator Dashboard (Config/Products): until
-- then the pedestal says the shinobi is coming and the prompt explains.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Data = require("../Data")
local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Hub = require("../World/Hub")
local Inventory = require("./Inventory")
local Net = require(ReplicatedStorage.Shared.Net)
local Plaza = require("../World/Plaza")
local State = require("./State")

local Legends = {}

-- The price tag at a pedestal's foot: parchment in a gilt outline with a round red seal, like
-- every other sign of the game. Its size in studs, how far out from the middle of the pedestal
-- it hangs, and how far over the ground its own middle is: the same for all three, under the
-- top of the lowest pedestal, so that the tags read as one row.
local TAG = Vector2.new(7, 2.4)
local TAG_OUT = 3.4
local TAG_HEIGHT = 1.5
local TAG_FAR = 140
-- A shinobi on show stands this many times its size, to be looked at from the lane.
local SHOW = 1.5
local PARCHMENT = Color3.fromRGB(236, 220, 188)
local INK = Color3.fromRGB(58, 40, 30)
local SEAL = Color3.fromRGB(198, 40, 40)
local GILT = Color3.fromRGB(255, 202, 40)
-- The prompt is offered from this far, studs: the pedestal is wide and the tag hangs before it.
local REACH = 13

-- Game pass id of each legendary shinobi, by the shinobi's id; 0 while the pass is not made.
local passOf: { [string]: number } = {}
local legendOfPass: { [number]: Catalog.Legend } = {}
for _, legend in Catalog.legends do
	local pass = Catalog.legendPass(legend.id)
	passOf[legend.id] = pass
	if pass > 0 then
		legendOfPass[pass] = legend
	end
end

-- The labels that say each pedestal's price, by the shinobi's id.
local priceLabels: { [string]: TextLabel } = {}

-- The id of the unit that is this legendary shinobi in a save, if the save has one.
function Legends.unitOf(data: Data.Data, legendId: string): string?
	for unitId, unit in data.units do
		if unit.character == legendId then
			return unitId
		end
	end
	return nil
end

-- Gives the player a legendary shinobi they do not have yet: a new unit in their inventory.
-- Says whether it did.
function Legends.grant(player: Player, legendId: string): boolean
	local data = Data.get(player)
	if not data or not Catalog.legendById[legendId] or Legends.unitOf(data, legendId) then
		return false
	end
	Inventory.add(player, data, { character = legendId, mutation = Catalog.NONE, level = 1 })
	State.push(player)
	return true
end

-- What a pedestal's prompt does for whoever uses it.
local function offer(player: Player, legend: Catalog.Legend)
	local data = Data.get(player)
	if not data then
		return
	end
	if Legends.unitOf(data, legend.id) then
		State.notify(player, "LegendOwned", legend.name)
		return
	end
	local pass = passOf[legend.id]
	if pass <= 0 then
		State.notify(player, "LegendSoon", legend.name)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass)
end

-- A purchase that went through: the shinobi joins the buyer, and everyone hears of it.
local function bought(player: Player, legend: Catalog.Legend)
	if not Legends.grant(player, legend.id) then
		return
	end
	State.notify(player, "LegendJoined", legend.name)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			State.notify(other, "LegendBy", player.DisplayName, legend.name)
		end
	end
end

-- Makes good a save that lacks a legendary shinobi its player has the pass for.
local function restore(player: Player, data: Data.Data)
	for _, legend in Catalog.legends do
		local pass = passOf[legend.id]
		if pass > 0 and not Legends.unitOf(data, legend.id) then
			task.spawn(function()
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass)
				end)
				-- The call yields: the player may have left meanwhile.
				if ok and owns and Data.get(player) == data then
					Legends.grant(player, legend.id)
				end
			end)
		end
	end
end

local function words(parent: Instance, from: number, share: number, ink: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromScale(0.3, from)
	label.Size = UDim2.fromScale(0.66, share)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.PermanentMarker
	label.TextScaled = true
	label.TextColor3 = INK
	label.TextTransparency = ink
	label.Parent = parent
	return label
end

-- Hangs the price tag before a pedestal: the price large, and under it what the price buys.
-- Everything on it is measured in shares of the tag, which is as many pixels as its distance
-- makes it.
local function priceTag(folder: Instance, stand: Part, legend: Catalog.Legend, out: Vector3)
	local board = Instance.new("BillboardGui")
	board.Name = "PriceTag"
	board.Adornee = stand
	board.Size = UDim2.fromScale(TAG.X, TAG.Y)
	-- Over the plaza's ground, which is not the world's zero: reckoned from zero, the tags
	-- hung half sunk into the paving.
	local ground = Hub.at(0, 0, 0).Y
	board.StudsOffsetWorldSpace = out * TAG_OUT
		+ Vector3.yAxis * (ground + TAG_HEIGHT - stand.Position.Y)
	board.MaxDistance = TAG_FAR
	board.LightInfluence = 0
	board:SetAttribute(Net.LEGEND_ATTRIBUTE, legend.id)

	local paper = Instance.new("Frame")
	paper.AnchorPoint = Vector2.new(0.5, 0.5)
	paper.Position = UDim2.fromScale(0.5, 0.5)
	paper.Size = UDim2.fromScale(0.96, 0.9)
	paper.BackgroundColor3 = PARCHMENT
	paper.BorderSizePixel = 0
	paper.Parent = board
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.16, 0)
	corner.Parent = paper
	local edge = Instance.new("UIStroke")
	edge.Color = GILT
	edge.Thickness = 3
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = paper

	local seal = Instance.new("TextLabel")
	seal.AnchorPoint = Vector2.new(0, 0.5)
	seal.Position = UDim2.fromScale(0.04, 0.5)
	seal.Size = UDim2.fromScale(0.22, 0.74)
	seal.BackgroundColor3 = SEAL
	seal.BorderSizePixel = 0
	seal.Font = Enum.Font.PermanentMarker
	seal.TextScaled = true
	seal.TextColor3 = PARCHMENT
	seal.Text = "R$"
	seal.Parent = paper
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.Parent = seal
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = seal
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0.16, 0)
	inset.PaddingRight = UDim.new(0.16, 0)
	inset.Parent = seal

	local price = words(paper, 0.08, 0.52, 0)
	price.Name = Net.LEGEND_PRICE
	price.Text = "COMING SOON"
	priceLabels[legend.id] = price
	words(paper, 0.6, 0.32, 0.2).Text = "Yours for good, through every rebirth"
	board.Parent = folder
end

-- Reads each pass's price off Roblox and writes it on its tag. The call can fail and is tried
-- again: a tag without a price sells nothing. This is the price as the server is told it, the
-- one the pass was given; a client that is told another for its own player (Roblox prices by
-- region when the owner lets it) writes that over this (client LegendShow).
local function priceTags()
	for _, legend in Catalog.legends do
		local pass = passOf[legend.id]
		local label = priceLabels[legend.id]
		if pass > 0 and label then
			task.spawn(function()
				for _ = 1, 5 do
					local ok, info = pcall(function()
						return MarketplaceService:GetProductInfo(pass, Enum.InfoType.GamePass)
					end)
					local robux = if ok and typeof(info) == "table" then info.PriceInRobux else nil
					if typeof(robux) == "number" then
						label.Text = `{robux} ROBUX`
						return
					end
					task.wait(20)
				end
			end)
		end
	end
end

-- Stands the legendary shinobi on their pedestals, each looking down the plaza at the lane,
-- with its price tag and the prompt that offers it.
local function exhibit()
	local folder = Instance.new("Folder")
	folder.Name = Net.LEGENDS_FOLDER
	local laneward = (Hub.at(1, 0, 0) - Hub.at(0, 0, 0)).Unit
	for _, legend in Catalog.legends do
		local stand = Plaza.stands[legend.id]
		if stand then
			local top = stand.Position + Vector3.yAxis * (stand.Size.Y / 2)
			local unit = { character = legend.id, mutation = Catalog.NONE, level = 1 }
			local figure = Figure.build(unit, SHOW)
			figure:PivotTo(CFrame.lookAt(top, top + laneward))
			figure.Parent = folder
			priceTag(folder, stand, legend, laneward)

			local prompt = Build.prompt(stand, "Buy", legend.name)
			prompt.MaxActivationDistance = REACH
			prompt:SetAttribute(Net.LEGEND_ATTRIBUTE, legend.id)
			prompt.Triggered:Connect(function(player)
				offer(player, legend)
			end)
		end
	end
	folder.Parent = Workspace
end

-- Call after Plaza.start(): the pedestals have to be standing.
function Legends.start()
	exhibit()
	priceTags()

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local legend = legendOfPass[passId]
		if purchased and legend then
			bought(player, legend)
		end
	end)
	Data.onLoaded(restore)
end

return Legends
