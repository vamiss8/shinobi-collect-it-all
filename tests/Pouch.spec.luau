--!strict
-- The pouch of potions and the Herbs that buy them (Logic/Pouch): what a throw brings, what a
-- potion costs, that a purchase goes into the pouch and is drunk out of it, and the bundle.
local Catalog = require("../src/shared/Config/Catalog")
local Pouch = require("../src/shared/Logic/Pouch")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

local NOW = 1_000_000

local function save(herbs: number): Pouch.Save
	return { herbs = herbs, stock = {}, premium = {}, potions = {} }
end

return {
	["a catch pays Herbs by its zone, a Perfect more"] = function()
		local herbs = Tuning.Herbs
		T.ok(herbs.perZone >= 1, "a catch brings nothing")
		T.eq(Pouch.earned("Great", 1), herbs.perZone)
		T.eq(Pouch.earned("Miss", 1), herbs.perZone, "a missed press still brought a catch")
		T.eq(Pouch.earned("Great", 7), 7 * herbs.perZone)
		T.eq(Pouch.earned("Perfect", 3), 3 * herbs.perZone * herbs.perfect)
		T.ok(Pouch.earned("Perfect", 1) > Pouch.earned("Good", 1), "a Perfect is worth no more")
		-- The nearest throw, the one a player can make over and over in a few seconds, pays
		-- least: the last zone's catch pays many times as much.
		local last = #Catalog.zones
		T.ok(Pouch.earned("Good", last) >= 5 * Pouch.earned("Good", 1), "a far catch pays little")
	end,

	["every potion has a price in Herbs"] = function()
		for _, potion in Catalog.potions do
			T.ok(potion.herbs >= 1 and potion.herbs == math.floor(potion.herbs), potion.id)
		end
	end,

	["a potion bought for Herbs goes into the pouch"] = function()
		local pill = Catalog.potionById.soldier_pill
		local mine = save(pill.herbs + 5)
		T.eq(Pouch.buy(mine, pill.id), true)
		T.eq(mine.herbs, 5, "the price was not taken")
		T.eq(Pouch.count(mine.stock, pill.id), 1)
		T.eq(mine.potions[pill.id], nil, "a potion bought is not drunk")
		T.eq(Pouch.buy(mine, pill.id), false, "bought with Herbs short")
		T.eq(mine.herbs, 5, "Herbs taken for nothing")
		T.eq(Pouch.buy(mine, "no_such_potion"), false)
	end,

	["a potion is drunk out of the pouch, and on from a running one"] = function()
		local oil = Catalog.potionById.sage_oil
		local mine = save(0)
		T.eq(Pouch.drink(mine, oil.id, NOW), false, "drunk out of an empty pouch")
		Pouch.add(mine.stock, oil.id, 2)
		T.eq(Pouch.drink(mine, oil.id, NOW), true)
		T.eq(mine.potions[oil.id], NOW + oil.minutes * 60)
		T.eq(Pouch.count(mine.stock, oil.id), 1)
		T.eq(Pouch.drink(mine, oil.id, NOW + 60), true)
		T.eq(mine.potions[oil.id], NOW + 2 * oil.minutes * 60, "the second does not add on")
		T.eq(mine.stock[oil.id], nil, "an empty slot is kept in the save")
	end,

	-- The owner: potions for Robux are premium, 15 minutes, those for Herbs 5.
	["a premium potion is kept apart and runs longer"] = function()
		local pill = Catalog.potionById.soldier_pill
		T.ok(pill.premiumMinutes > pill.minutes, "a premium potion runs no longer")
		local mine = save(0)
		Pouch.add(mine.premium, pill.id, 1)
		T.eq(Pouch.drink(mine, pill.id, NOW), false, "a premium one drunk as one for Herbs")
		T.eq(Pouch.drink(mine, pill.id, NOW, true), true)
		T.eq(mine.potions[pill.id], NOW + pill.premiumMinutes * 60)
		T.eq(mine.premium[pill.id], nil, "an empty slot is kept in the save")
	end,

	["the bundle puts its count of every potion it holds into the pouch"] = function()
		local bundle = Catalog.productByKey.AcademyBundle
		T.ok(bundle ~= nil and bundle.once ~= true, "the bundle is sold once only")
		local each = bundle.each or 0
		T.ok(each >= 1, "the bundle holds nothing")
		local stock: { [string]: number } = { sage_oil = 3 }
		Pouch.bundle(stock, bundle)
		for _, potionId in bundle.potions or {} do
			local before = if potionId == "sage_oil" then 3 else 0
			T.eq(stock[potionId], before + each, `{potionId} was not put in`)
		end
	end,

	["the client is told only of the potions there are"] = function()
		local contents = Pouch.contents({ soldier_pill = 2, sage_oil = 0, gone = 4 })
		T.eq(contents.soldier_pill, 2)
		T.eq(contents.sage_oil, nil)
		T.eq(contents.gone, nil, "a potion there is not")
	end,
}
