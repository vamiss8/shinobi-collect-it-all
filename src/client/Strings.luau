--!strict
-- Every piece of UI text, in one place so it can be localized. Templates use %s only; numbers
-- are shortened (1250 -> "1.25K") before they are substituted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Logic.Format)

local Strings = {}

local TEXT: { [string]: string } = {
	-- HUD
	HudRyo = "%s Ryo",
	HudIncome = "+%s per second",
	HudChakra = "%s Chakra",
	HudIdle = "Equip a tool and stand still",
	HudLoading = "Loading your save...",
	HudMeditating = "Meditating: +%s per second",
	HudFocus = "Chakra control: up to +%s per press",
	HudBoost = "  (x%s boost)",

	-- Throw power
	ThrowButton = "Throw power: %s of %s",
	ThrowButtonFull = "Throw power: all %s",
	ThrowTitle = "Throw power",
	ThrowAmount = "%s Chakra",
	ThrowAmountFull = "All %s Chakra",
	ThrowReachNext = "Perfect lands in %s  |  next zone at %s Chakra",
	ThrowReachDeep = "Perfect lands in %s  |  mutation luck x%s",
	ThrowReachDanger = "%s: the enemy there outruns you!",
	ThrowMax = "Use all",
	ThrowHint = "Use less Chakra to land in a nearer zone.",

	-- The luck board on the map
	LuckTitle = "LUCKY THROWS",
	LuckThrow = "Your next throw is #%s",
	LuckSoon = "x%s luck in %s throws",
	LuckNow = "x%s LUCK ON YOUR NEXT THROW!",
	LuckMilestone = "every %sth: x%s",

	-- Inventory
	InventoryButton = "Inventory",
	CarriedName = "Carrying: %s",
	CarriedPutAwayKey = "Put away [G]",
	InventoryTitle = "Inventory",
	InventoryHint = "Click a shinobi to carry it, then put it on a pad.",
	InventoryEmpty = "No shinobi here. Throw a kunai and bring one home!",
	InventoryPutAway = "Put away",

	-- Bingo Book
	IndexButton = "Bingo Book",
	IndexTitle = "Bingo Book",
	IndexPlain = "None",
	IndexTab = "%s  %s/%s",
	IndexProgress = "%s: %s of %s found. Find them all for +%s%% Ryo, forever.",
	IndexComplete = "%s: complete! +%s%% Ryo, forever.",

	-- Unit cards
	CardUnknown = "???",
	CardLevel = "Lvl %s",
	CardIncome = "+%s/s",
	CardBase = "Base: %s/s",

	-- Market stores
	ShopChakraTitle = "Chakra Store",
	ShopChakraHint = "A better kunai gives more Chakra from every kind of training and changes "
		.. "how your throw looks. They are bought in order.",
	ShopKunaiChakra = "+%s Chakra per rep",
	ShopInUse = "In use",
	ShopOwned = "Owned",
	ShopSpeedTitle = "Speed Store",
	ShopSpeedNow = "Run speed %s",
	ShopSpeedLevel = "Level %s of %s",
	ShopSpeedNext = "Next level: run speed %s -> %s",
	ShopSpeedMaxed = "Run speed is fully upgraded",
	ShopSpeedEnemies = "Who you can outrun",
	ShopSpeedEnemy = "%s (%s-%s)  |  %s",
	ShopSpeedSafe = "you get away",
	ShopSpeedPartly = "near side only",
	ShopSpeedSlower = "catches you",
	ShopMax = "MAX",
	ShopPrice = "%s Ryo",

	-- Sell stall
	SellTitle = "Sell Shinobi",
	SellHint = "Click a shinobi to sell it.",
	SellEmpty = "Nothing to sell. Shinobi on pads have to be taken off first.",
	SellAll = "Sell all",
	SellAllConfirm = "Sell %s for %s Ryo?",
	SellPrice = "Sell: %s",

	-- Throw
	KickHint = "Click, tap or press Space to throw!",
	KickStreak = "Perfect streak %s/%s  |  a full streak gives the next throw x%s power",
	KickSageReady = "SAGE THROW READY: this one has x%s power!",
	KickResult = "%s!  %s studs  |  %s",
	KickSage = "SAGE THROW!  ",
	KickLucky = "x%s LUCK!  ",

	-- Reveal and the run home
	Reveal = "%s!",
	RunStart = "%s!  Run home from %s!",
	RunEscaped = "Escaped!  %s is yours.",
	RunEscapedNew = "NEW!  %s is yours  |  +%s Ryo",
	RunCaught = "%s caught you.  %s is lost  |  +%s Ryo",

	-- Training
	Bubble = "x%s",
	BubbleKey = "[F]",
	BoostStarted = "x%s Chakra for %s seconds!",
	FocusHint = "Click as the rings meet",
	FocusHit = "%s  +%s",
	FocusMiss = "Miss",

	-- Notifications sent by the server
	NothingHeld = "Pick a shinobi in your Inventory first.",
	NotEnoughRyo = "Not enough Ryo.",
	NotYourDojo = "This is not your dojo.",
	Merged = "Merged into %s!",
	Sold = "Sold %s for %s Ryo.",
	SoldMany = "Sold %s shinobi for %s Ryo.",
	WelcomeBack = "Welcome back! Your dojo earned %s Ryo while you were away.",
}

-- Fills the template named `key`. An unknown key is shown as-is, so a typo is easy to spot.
function Strings.get(key: string, ...: any): string
	local template = TEXT[key]
	if not template then
		return key
	end
	local args = table.pack(...)
	for i = 1, args.n do
		if typeof(args[i]) == "number" then
			args[i] = Format.short(args[i])
		end
	end
	return string.format(template, table.unpack(args, 1, args.n))
end

return Strings
