--!strict
-- The market: three shops round the fountain in the middle of the plaza (Logic/PlazaPlan says
-- where), each with its open front to the fountain. Tenten's Ninja Tools (World/TentenShop)
-- sells kunai and the Mission Desk (World/MissionDesk) buys shinobi, both in houses; the Youth
-- Training Ground (World/TrainingGround), an open yard, sells run speed. Walking up to a
-- counter and using its prompt opens that shop's window on the client (the prompt's attribute
-- says which). The server only needs to know whether a player is standing at a counter when
-- they ask to buy or sell there.
--
-- Built from plain parts in Hub coordinates; call start() after Hub.start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(ReplicatedStorage.Shared.View.Build)
local Hub = require("./Hub")
local MissionDesk = require("./MissionDesk")
local Net = require(ReplicatedStorage.Shared.Net)
local PlazaPlan = require(ReplicatedStorage.Shared.Logic.PlazaPlan)
local ShopHouse = require("./ShopHouse")
local TentenShop = require("./TentenShop")
local TrainingGround = require("./TrainingGround")

local Market = {}

-- A player this close to a shop's counter may buy or sell there, studs.
local RANGE = 18

-- Each shop: what builds it on its place (the middle of its front on the ground, looking out at
-- the fountain) and returns its counter, and what its prompt says.
local SHOPS: { { id: string, title: string, build: (folder: Folder, place: CFrame) -> Part } } = {
	{ id = "tenten", title = "Tenten's Ninja Tools", build = TentenShop.build },
	{ id = "sell", title = "Mission Desk", build = MissionDesk.build },
	{ id = "speed", title = "Youth Training Ground", build = TrainingGround.build },
}

local counters: { [string]: Part } = {}

-- Where a shop stands: the middle of its front on the ground, looking at the fountain.
local function place(id: string): CFrame
	local shop = PlazaPlan.shops[id]
	local out = PlazaPlan.facing(shop)
	local front = Hub.at(shop.along, 0, shop.side)
	return CFrame.lookAt(front, front + Vector3.new(out.along, 0, out.side))
end

-- Whether the player is standing at the counter of the given shop: "tenten" (Tenten's Ninja
-- Tools), "speed" (the Youth Training Ground) or "sell" (the Mission Desk).
function Market.playerAt(player: Player, shopId: string): boolean
	local counter = counters[shopId]
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not counter or not root or not root:IsA("BasePart") then
		return false
	end
	return (counter.Position - root.Position).Magnitude <= RANGE
end

function Market.start()
	local folder = Instance.new("Folder")
	folder.Name = Net.MARKET_FOLDER
	for _, shop in SHOPS do
		local counter = shop.build(folder, place(shop.id))
		local prompt = Build.prompt(counter, "Open", shop.title)
		-- From anywhere in front of the counter, but not from beside the shop.
		prompt.MaxActivationDistance = ShopHouse.REACH
		prompt:SetAttribute(Net.SHOP_ATTRIBUTE, shop.id)
		counters[shop.id] = counter
	end
	folder.Parent = Workspace
end

return Market
