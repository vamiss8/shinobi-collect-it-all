--!strict
-- Prices in Robux as Roblox gives them to this player, by asset id: asked once each and kept.
-- No price is written in the game (Config/Products): the owner may switch on regional pricing,
-- and a player may then be offered less than the pass's own price. Both the Shop window
-- (client ShopPanel) and the Herb Shop's (Stores/HerbShop) read them here.

local MarketplaceService = game:GetService("MarketplaceService")

local Prices = {}

local known: { [number]: number } = {}
local asking: { [number]: boolean } = {}
local listeners: { () -> () } = {}

-- The price of a pass or a product, if Roblox has told it yet.
function Prices.get(assetId: number): number?
	return known[assetId]
end

-- Asks Roblox for a price not known yet; whoever listens is told when it comes. One that does
-- not come may be asked for again.
function Prices.ask(assetId: number, pass: boolean)
	if assetId <= 0 or known[assetId] or asking[assetId] then
		return
	end
	asking[assetId] = true
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(
				assetId,
				if pass then Enum.InfoType.GamePass else Enum.InfoType.Product
			)
		end)
		asking[assetId] = nil
		local robux = if ok and typeof(info) == "table" then info.PriceInRobux else nil
		if typeof(robux) == "number" then
			known[assetId] = robux
			for _, fn in listeners do
				fn()
			end
		end
	end)
end

-- Calls `fn` whenever a price comes.
function Prices.onChange(fn: () -> ())
	table.insert(listeners, fn)
end

return Prices
