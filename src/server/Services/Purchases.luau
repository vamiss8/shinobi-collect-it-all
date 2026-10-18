--!strict
-- What is bought for Robux (Config/Products) reaching the player. The client opens Roblox's own
-- purchase windows (client ShopPanel, WelcomeBack; the dojo's pass pad opens one from here
-- through Services/Dojo); what a purchase gives is decided here alone.
--
-- Game passes are bought once. Each is kept in the save as well (Data `passes`), so what it
-- gives is there the moment the save loads, and is asked of Roblox again at every join, so a
-- pass bought on the website or on another server is not missed. The legendary shinobi's
-- passes are Services/Legends' business.
--
-- Developer products go through MarketplaceService.ProcessReceipt, which there may be only
-- one of in the game: this is it. Roblox offers a purchase again and again until it is told
-- the purchase was granted, so a purchase is granted, its id written into the save, and only
-- once that save has gone out to the DataStore is Roblox told so; an id already in the save
-- is not granted again. A purchase that cannot be granted yet (its buyer has left, or a pack of
-- Ryo for a dojo that earns nothing) is left for Roblox to offer again later.
--
-- Potions bought for Robux go into the pouch (Logic/Pouch) as premium ones, which run longer
-- than those bought for Herbs, and both are drunk out of it from here, wherever the player is.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boosts = require(ReplicatedStorage.Shared.Logic.Boosts)
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Data = require("../Data")
local Dojo = require("./Dojo")
local Gifts = require("../Gifts")
local Net = require(ReplicatedStorage.Shared.Net)
local Pouch = require(ReplicatedStorage.Shared.Logic.Pouch)
local PurchaseLogic = require(ReplicatedStorage.Shared.Logic.Purchases)
local Remotes = require("../Remotes")
local Session = require("../Session")
local State = require("./State")
local Stats = require("./Stats")
local Titles = require("./Titles")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Purchases = {}

-- How long a purchase waits for its save to go out before Roblox is told to offer it again
-- later, seconds.
local SAVE_WAIT = 20

-- What follows a pass coming into a save: whatever it changes in the world is put right, and
-- the client is told.
local function took(player: Player, data: Data.Data, key: string)
	data.passes[key] = true
	if key == "ExtraPads" then
		Dojo.redraw(player)
	elseif key == Boosts.VIP then
		Titles.dress(player)
	end
	State.push(player)
end

-- Asks Roblox which of the passes the save does not have yet the player owns; and gives the
-- passes the owner gave them (server/Gifts), which Roblox knows nothing of.
local function check(player: Player, data: Data.Data)
	local gifts: { string } = Gifts[player.UserId] or {}
	for _, key in gifts do
		local pass = Catalog.passByKey[key]
		if pass and pass.kind ~= "legend" and not data.passes[key] then
			took(player, data, key)
			State.notify(player, "PassBought", pass.name)
		end
	end
	for _, pass in Catalog.passes do
		if pass.kind ~= "legend" and pass.assetId > 0 and not data.passes[pass.key] then
			task.spawn(function()
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.assetId)
				end)
				-- The call yields: the player may have left meanwhile.
				if ok and owns and Data.get(player) == data then
					took(player, data, pass.key)
				end
			end)
		end
	end
end

-- Gives what a product buys. Says whether it could be given now.
local function grant(player: Player, data: Data.Data, product: Catalog.Product): boolean
	if product.kind == "potion" then
		local potion = if product.potion then Catalog.potionById[product.potion] else nil
		if not potion then
			return false
		end
		Pouch.add(data.premium, potion.id, 1)
		State.notify(player, "PotionPremiumStocked", potion.name, potion.premiumMinutes)
	elseif product.kind == "bundle" then
		Pouch.bundle(data.premium, product)
		if product.once then
			data.bought[product.key] = true
		end
		State.notify(player, "BundleStocked", product.name, product.each or 0)
	elseif product.kind == "ryo" then
		local amount = PurchaseLogic.ryoPack(Stats.income(data), product.incomeMinutes or 0)
		if amount < 1 then
			return false
		end
		data.ryo += amount
		State.notify(player, "RyoPackBought", amount)
	elseif product.kind == "offline" then
		local session = Session.of(player)
		local amount = session.offlineOffer
		if amount < 1 then
			return false
		end
		data.ryo += amount
		local doubled: Net.Offline = { earned = amount * 2, away = 0, doubled = true }
		Remotes.Offline:FireClient(player, doubled)
		State.notify(player, "OfflineDoubled", amount)
	else
		return false
	end
	return true
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = if player then Data.get(player) else nil
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	if not PurchaseLogic.granted(data.receipts, purchaseId) then
		local product = Catalog.productById[info.ProductId]
		if not product then
			warn(`[Purchases] no product has the id {info.ProductId}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if not grant(player, data, product) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		PurchaseLogic.remember(data.receipts, purchaseId, Tuning.Shop.receiptsKept)
		State.push(player)
	end
	local saved = Data.saveAndWait(player, function(written)
		local receipts = if typeof(written) == "table" then written.receipts else nil
		return typeof(receipts) == "table" and table.find(receipts, purchaseId) ~= nil
	end, SAVE_WAIT)
	return if saved
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Drinks a potion out of the pouch, a premium one or one bought for Herbs: anywhere, at any
-- time.
local function drink(player: Player, potionId: unknown, premium: unknown)
	local data = Data.get(player)
	local potion = if typeof(potionId) == "string" then Catalog.potionById[potionId] else nil
	if not data or not potion then
		return
	end
	local isPremium = premium == true
	if Pouch.drink(data, potion.id, os.time(), isPremium) then
		Data.count(data, "potions")
		State.notify(player, "PotionDrunk", potion.name, Pouch.minutes(potion, isPremium))
		State.push(player)
	end
end

function Purchases.start()
	Data.onLoaded(check)
	Remotes.Drink.OnServerEvent:Connect(drink)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = Catalog.passById[passId]
		local data = Data.get(player)
		if purchased and pass and pass.kind ~= "legend" and data and not data.passes[pass.key] then
			took(player, data, pass.key)
			State.notify(player, "PassBought", pass.name)
		end
	end)
	MarketplaceService.ProcessReceipt = processReceipt
end

return Purchases
