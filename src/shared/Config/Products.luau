--!strict
-- Game passes and developer products. `assetId` stays 0 until the place is published and the
-- item is created on the Creator Dashboard. Prices live there too and are fetched at runtime.

export type GamePass = {
	key: string,
	name: string,
	assetId: number,
}

export type Product = {
	key: string,
	name: string,
	assetId: number,
	potion: string?, -- potion id, for potion products
	incomeMinutes: number?, -- for Ryo packs: grants this many minutes of current income
}

local GamePasses: { GamePass } = {
	{ key = "DoubleRyo", name = "x2 Ryo", assetId = 0 },
	{ key = "DoubleChakra", name = "x2 Chakra", assetId = 0 },
	{ key = "DoubleLuck", name = "x2 Luck", assetId = 0 },
	{ key = "DoubleMutationLuck", name = "x2 Mutation Luck", assetId = 0 },
	{ key = "AutoTrain", name = "Auto Train", assetId = 0 },
	{ key = "AutoKick", name = "Auto Kick", assetId = 0 },
	{ key = "ExtraPads", name = "+4 Pads", assetId = 0 },
}

local Products: { Product } = {
	{ key = "SoldierPill", name = "Soldier Pill", assetId = 0, potion = "soldier_pill" },
	{ key = "IchirakuRamen", name = "Ichiraku Ramen", assetId = 0, potion = "ichiraku_ramen" },
	{ key = "GamaCharm", name = "Gama-chan Charm", assetId = 0, potion = "gama_charm" },
	{ key = "SageOil", name = "Sage Oil", assetId = 0, potion = "sage_oil" },
	{ key = "RyoPackSmall", name = "Ryo Pouch", assetId = 0, incomeMinutes = 30 },
	{ key = "RyoPackLarge", name = "Ryo Chest", assetId = 0, incomeMinutes = 240 },
}

return {
	GamePasses = GamePasses,
	Products = Products,
}
