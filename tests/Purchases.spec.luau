--!strict
-- What is sold for Robux (Config/Products, Logic/Purchases): what it pays, how long it runs,
-- and that a purchase is granted once.
local Catalog = require("../src/shared/Config/Catalog")
local Purchases = require("../src/shared/Logic/Purchases")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

local NOW = 1_000_000

return {
	["the config checks out: every product sells something there is"] = function()
		local problems = Catalog.validate()
		T.eq(#problems, 0, table.concat(problems, "; "))
		T.ok(#Catalog.passes > 0 and #Catalog.products > 0, "nothing for sale")
	end,

	-- The owner's word of 2026-10-15: no Auto Train or Auto Kick for now.
	["Auto Train and Auto Kick are not on sale"] = function()
		T.eq(Catalog.passByKey.AutoTrain, nil)
		T.eq(Catalog.passByKey.AutoKick, nil)
	end,

	["no price is written into the config"] = function()
		for _, pass in Catalog.passes do
			T.eq((pass :: any).price, nil, `{pass.key} has a price in the code`)
		end
		for _, product in Catalog.products do
			T.eq((product :: any).price, nil, `{product.key} has a price in the code`)
		end
	end,

	["a pack of Ryo pays its minutes of the dojo's income, whole"] = function()
		T.eq(Purchases.ryoPack(10, 30), 18000)
		T.eq(Purchases.ryoPack(1.5, 1), 90)
		T.eq(Purchases.ryoPack(0, 480), 0, "a dojo that earns nothing")
		T.eq(Purchases.ryoPack(-5, 30), 0)
		-- The packs grow with their minutes, so the dearer pays more.
		local last = 0
		for _, product in Catalog.products do
			if product.kind == "ryo" then
				local minutes = product.incomeMinutes or 0
				T.ok(minutes > last, `{product.key} pays no more than the pack before it`)
				last = minutes
			end
		end
	end,

	["a potion runs for its minutes, and on from a running one"] = function()
		local potions: { [string]: number } = {}
		Purchases.drink(potions, "gama_charm", NOW, 15)
		T.eq(potions.gama_charm, NOW + 900)
		Purchases.drink(potions, "gama_charm", NOW + 60, 15)
		T.eq(potions.gama_charm, NOW + 1800, "a second potion should add to the first")
		local left = Purchases.potionsLeft(potions, NOW + 1800 - 30)
		T.eq(left.gama_charm, 30)
		T.eq(Purchases.potionsLeft(potions, NOW + 1800).gama_charm, nil, "a spent potion is shown")
	end,

	["the bundle starts every potion it holds for its minutes"] = function()
		local bundle = Catalog.productByKey.AcademyBundle
		T.ok(bundle ~= nil and bundle.once ~= true, "the bundle is sold once only")
		local potions: { [string]: number } = { sage_oil = NOW + 100 }
		Purchases.drinkBundle(potions, bundle, NOW)
		local minutes = bundle.minutes or 0
		for _, potionId in bundle.potions or {} do
			local from = if potionId == "sage_oil" then NOW + 100 else NOW
			T.eq(potions[potionId], from + minutes * 60, `{potionId} was not started`)
		end
	end,

	["a purchase is remembered, and only the newest are kept"] = function()
		local receipts: { string } = {}
		T.eq(Purchases.granted(receipts, "a"), false)
		Purchases.remember(receipts, "a", 3)
		T.eq(Purchases.granted(receipts, "a"), true)
		for _, id in { "b", "c", "d" } do
			Purchases.remember(receipts, id, 3)
		end
		T.eq(#receipts, 3)
		T.eq(Purchases.granted(receipts, "a"), false, "the oldest is not dropped")
		T.eq(Purchases.granted(receipts, "d"), true)
		T.ok(Tuning.Shop.receiptsKept >= 20, "too few purchases remembered")
	end,

	["the passes owned are told in the config's order"] = function()
		local owned = Purchases.owned({ ExtraPads = true, Vip = true, Nothing = true })
		T.eq(#owned, 2)
		T.eq(owned[1], "Vip")
		T.eq(owned[2], "ExtraPads")
	end,
}
