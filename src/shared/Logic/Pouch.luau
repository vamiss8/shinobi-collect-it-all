--!strict
-- A player's pouch of potions (Config/Potions) and the Herbs that buy them, kept apart from
-- Roblox so that it can be tested. Potions are kept, not drunk, when they come (owner,
-- 2026-10-16: "potions as a stock"): bought for Herbs at the Herb Shop, bought for Robux, or
-- several at once in a bundle, they go into the pouch, and the player drinks one when they
-- like, from the Herb Shop or from the Shop window anywhere. Those bought for Robux are premium
-- and run longer (Config/Potions `premiumMinutes`): they are kept apart, and the player says
-- which of the two to drink.

local Catalog = require("../Config/Catalog")
local Purchases = require("./Purchases")
local Tuning = require("../Config/Tuning")

local Pouch = {}

-- The fields of a save the pouch keeps.
export type Save = {
	herbs: number,
	stock: { [string]: number }, -- potion id -> how many bought for Herbs are in the pouch
	premium: { [string]: number }, -- potion id -> how many premium ones, bought for Robux
	potions: { [string]: number }, -- potion id -> when the one running ends, unix seconds
}

-- Herbs a throw pays once its catch is brought home: by the number of the zone it came from
-- (1 for the first, Catalog.zoneOrder) and the grade of its press (Logic/Kick).
function Pouch.earned(grade: string, zone: number): number
	local herbs = Tuning.Herbs
	return herbs.perZone * math.max(zone, 1) * (if grade == "Perfect" then herbs.perfect else 1)
end

-- How many of a potion are in the pouch.
function Pouch.count(stock: { [string]: number }, potionId: string): number
	return math.max(stock[potionId] or 0, 0)
end

-- Puts `count` of a potion into the pouch.
function Pouch.add(stock: { [string]: number }, potionId: string, count: number)
	stock[potionId] = Pouch.count(stock, potionId) + count
end

-- Puts what a bundle holds into the pouch: `each` of every potion in it.
function Pouch.bundle(stock: { [string]: number }, product: Catalog.Product)
	local held: { string } = product.potions or {}
	for _, potionId in held do
		Pouch.add(stock, potionId, product.each or 0)
	end
end

-- Buys one of a potion for Herbs, into the pouch. Says whether it was bought: not when there
-- is no such potion or the Herbs are short.
function Pouch.buy(save: Save, potionId: string): boolean
	local potion = Catalog.potionById[potionId]
	if not potion or save.herbs < potion.herbs then
		return false
	end
	save.herbs -= potion.herbs
	Pouch.add(save.stock, potionId, 1)
	return true
end

-- How long a potion runs once drunk: a premium one, bought for Robux, longer.
function Pouch.minutes(potion: Catalog.Potion, premium: boolean?): number
	return if premium then potion.premiumMinutes else potion.minutes
end

-- Drinks one of a potion out of the pouch, a premium one or one bought for Herbs: it runs for
-- its minutes, or on from where the one running ends. Says whether there was one to drink.
function Pouch.drink(save: Save, potionId: string, now: number, premium: boolean?): boolean
	local potion = Catalog.potionById[potionId]
	local stock = if premium then save.premium else save.stock
	local count = Pouch.count(stock, potionId)
	if not potion or count < 1 then
		return false
	end
	-- An empty slot is taken out, so that the save keeps only what there is.
	if count > 1 then
		stock[potionId] = count - 1
	elseif premium then
		save.premium[potionId] = nil
	else
		save.stock[potionId] = nil
	end
	Purchases.drink(save.potions, potionId, now, Pouch.minutes(potion, premium))
	return true
end

-- What is in the pouch, as the client is told: only the potions there are.
function Pouch.contents(stock: { [string]: number }): { [string]: number }
	local out: { [string]: number } = {}
	for _, potion in Catalog.potions do
		local count = Pouch.count(stock, potion.id)
		if count > 0 then
			out[potion.id] = count
		end
	end
	return out
end

return Pouch
