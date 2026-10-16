--!strict
-- Everything sold for Robux, as the shop window (client ShopPanel) lists it: game passes,
-- bought once and kept for good, and developer products, bought as often as a player likes.
-- `assetId` stays 0 until the item is made on the Creator Dashboard; the shop then shows it as
-- coming soon. Prices live on the Dashboard too and are read off Roblox at runtime: no price is
-- written here (the owner may switch on regional pricing, and a price in the code would lie).
--
-- What each does is decided by its `kind` (Services/Purchases grants it, Logic/Boosts turns
-- what a player owns into multipliers); what each is called and how it is described on the
-- screen is in client/Strings, under Goods_<key> and GoodsWhat_<key>.
--
-- Auto Train and Auto Kick were planned as passes and are not sold for now (owner,
-- 2026-10-15): they change the pace most of anything, and want a sim of their own first.

export type PassKind =
	"boost" -- doubles one multiplier (Logic/Boosts)
	| "vip" -- the Daimyo's favor: income, offline income and a mark by the name
	| "pads" -- the dojo's last pads (Tuning.Dojo.gamePassPads)
	| "legend" -- a legendary shinobi (Config/Legends, Services/Legends)

export type GamePass = {
	key: string,
	name: string,
	assetId: number,
	kind: PassKind,
}

export type ProductKind =
	"potion" -- one potion of Config/Potions, for its minutes
	| "bundle" -- several potions at once, each for `minutes`; once a player
	| "ryo" -- `incomeMinutes` of the dojo's income as it stands, paid at once
	| "offline" -- the welcome-back window's Ryo paid a second time

export type Product = {
	key: string,
	name: string,
	assetId: number,
	kind: ProductKind,
	potion: string?, -- potion id, for a potion
	potions: { string }?, -- potion ids, for a bundle
	minutes: number?, -- how long a bundle's potions last
	incomeMinutes: number?, -- for Ryo
	once: boolean?, -- sold to a player once only
}

local GamePasses: { GamePass } = {
	{ key = "Vip", name = "Daimyo VIP", assetId = 2037590762, kind = "vip" },
	{ key = "DoubleRyo", name = "x2 Ryo", assetId = 2037938811, kind = "boost" },
	{ key = "DoubleChakra", name = "x2 Chakra", assetId = 2037500777, kind = "boost" },
	{ key = "DoubleLuck", name = "x2 Luck", assetId = 2036912767, kind = "boost" },
	{ key = "DoubleMutationLuck", name = "x2 Mutation Luck", assetId = 2037194736, kind = "boost" },
	{ key = "ExtraPads", name = "+4 Pads", assetId = 2036216754, kind = "pads" },
	-- The legendary shinobi (Config/Legends), a pass each: bought once, kept for good.
	{ key = "LegendTsunade", name = "Tsunade", assetId = 2022434275, kind = "legend" },
	{ key = "LegendTobirama", name = "Tobirama", assetId = 2022398273, kind = "legend" },
	{ key = "LegendHagoromo", name = "Hagoromo", assetId = 2023364274, kind = "legend" },
}

local Products: { Product } = {
	{
		key = "SoldierPill",
		name = "Soldier Pill",
		assetId = 0,
		kind = "potion",
		potion = "soldier_pill",
	},
	{
		key = "IchirakuRamen",
		name = "Ichiraku Ramen",
		assetId = 0,
		kind = "potion",
		potion = "ichiraku_ramen",
	},
	{
		key = "GamaCharm",
		name = "Gama-chan Charm",
		assetId = 0,
		kind = "potion",
		potion = "gama_charm",
	},
	{ key = "SageOil", name = "Sage Oil", assetId = 0, kind = "potion", potion = "sage_oil" },
	-- All four potions for half an hour each, for less than the four cost. Sold any number of
	-- times (owner, 2026-10-16: once a player "is nonsense, let purchases be endless").
	{
		key = "AcademyBundle",
		name = "Academy Bundle",
		assetId = 0,
		kind = "bundle",
		potions = { "soldier_pill", "ichiraku_ramen", "gama_charm", "sage_oil" },
		minutes = 30,
	},
	-- Minutes of the dojo's income, so that a pack is worth as much late in the game as early.
	{ key = "RyoPouch", name = "Ryo Pouch", assetId = 0, kind = "ryo", incomeMinutes = 30 },
	{ key = "RyoPurse", name = "Ryo Purse", assetId = 0, kind = "ryo", incomeMinutes = 120 },
	{ key = "RyoChest", name = "Ryo Chest", assetId = 0, kind = "ryo", incomeMinutes = 480 },
	-- Offered in the welcome-back window only.
	{ key = "DoubleOffline", name = "x2 Offline Ryo", assetId = 0, kind = "offline" },
}

return {
	GamePasses = GamePasses,
	Products = Products,
}
