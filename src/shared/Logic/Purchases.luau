--!strict
-- The arithmetic of what is sold for Robux (Config/Products), kept apart from Roblox so that it
-- can be tested: what a pack of Ryo pays, how long the potions a player drinks have left, and
-- the record of purchases already granted.

local Boosts = require("./Boosts")
local Catalog = require("../Config/Catalog")

local Purchases = {}

-- What a pack of Ryo pays a dojo that earns `perSecond`: that many minutes of it, whole.
function Purchases.ryoPack(perSecond: number, minutes: number): number
	return math.floor(math.max(perSecond, 0) * minutes * 60)
end

-- Seconds left on each potion still running at `now`, by potion id; spent ones are left out.
function Purchases.potionsLeft(potions: { [string]: number }, now: number): { [string]: number }
	local left: { [string]: number } = {}
	for potionId, expiresAt in potions do
		if expiresAt > now then
			left[potionId] = expiresAt - now
		end
	end
	return left
end

-- Has a potion run for `minutes` longer: from now, or on from where a running one ends.
function Purchases.drink(
	potions: { [string]: number },
	potionId: string,
	now: number,
	minutes: number
)
	potions[potionId] = Boosts.extend(potions[potionId], now, minutes)
end

-- Every potion in a bundle, each for the bundle's minutes.
function Purchases.drinkBundle(potions: { [string]: number }, product: Catalog.Product, now: number)
	local held: { string } = product.potions or {}
	for _, potionId in held do
		Purchases.drink(potions, potionId, now, product.minutes or 0)
	end
end

-- Whether a purchase of that id has been granted already.
function Purchases.granted(receipts: { string }, purchaseId: string): boolean
	return table.find(receipts, purchaseId) ~= nil
end

-- Notes a purchase as granted, keeping only the newest `keep`.
function Purchases.remember(receipts: { string }, purchaseId: string, keep: number)
	table.insert(receipts, purchaseId)
	while #receipts > keep do
		table.remove(receipts, 1)
	end
end

-- The keys of the passes owned, in the order of the config: what the client is told.
function Purchases.owned(passes: { [string]: boolean }): { string }
	local list = {}
	for _, pass in Catalog.passes do
		if passes[pass.key] then
			table.insert(list, pass.key)
		end
	end
	return list
end

return Purchases
