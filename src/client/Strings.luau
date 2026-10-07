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
	ThrowHint = "Use less Chakra to land in a nearer zone. Click the number to type one.",
	ThrowType = "3000, 3K, 1.5M...",
	ThrowTypeHint = "click to type",

	-- The luck board on the map
	LuckTitle = "LUCKY THROWS",
	LuckThrow = "Your next throw is #%s",
	LuckSoon = "x%s luck in %s throws",
	LuckNow = "x%s LUCK ON YOUR NEXT THROW!",
	LuckMilestone = "every %sth: x%s",

	-- The bar of slots at the bottom
	HotbarTip = "%s: %s",
	HotbarEmpty = "Empty slot: bring a shinobi home",

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
	ShopTentenTitle = "Tenten's Ninja Tools",
	ShopTentenHint = "A better kunai gives more Chakra from every kind of training and changes "
		.. "how your throw looks. They are bought in order.",
	-- What Tenten says when her shop is opened, one at random.
	TentenHello1 = "Welcome to my shop! Every kunai here flies true.",
	TentenHello2 = "A better kunai makes every rep of training count for more!",
	TentenHello3 = "Kunai, shuriken, scrolls... if it's sharp, I sell it!",
	TentenHello4 = "One at a time! Master each blade before the next.",
	ShopKunaiChakra = "+%s Chakra per rep",
	ShopKunaiGain = "x%s training",
	ShopYourKunai = "YOUR KUNAI",
	ShopNextKunai = "NEXT: %s",
	ShopNextProgress = "%s / %s Ryo",
	ShopAllKunai = "You own every kunai!",
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
	KickGrade = "%s!  %s%% power",
	GradePerfect = "PERFECT",
	GradeGreat = "GREAT",
	GradeGood = "GOOD",
	GradeMiss = "MISS",
	KickStreakLabel = "PERFECT STREAK",
	KickStreakGoal = "%s in a row: next throw x%s",
	KickSageLabel = "SAGE THROW READY",
	KickSageGoal = "this throw: x%s power!",
	KickResult = "%s!  %s studs  |  %s",
	KickSage = "SAGE THROW!  ",
	KickLucky = "x%s LUCK!  ",

	-- Reveal and the run home
	Reveal = "%s!",
	UpgradeGained = "+%s",
	UpgradeDone = "LEVEL UP!",
	UpgradeEarns = "%s Ryo / s",
	ChaseWarn = "is after you!",
	ChaseRun = "RUN HOME!",
	ChaseRunFrom = "before %s catches you",
	RunEscaped = "Escaped!  %s is yours.",
	RunEscapedNew = "NEW!  %s is yours  |  +%s Ryo",
	RunCaught = "%s caught you.  %s is lost  |  +%s Ryo",

	-- Welcome-back window
	OfflineTitle = "Welcome back!",
	OfflineAway = "You were away for %s",
	OfflineEarnedLabel = "Your dojo earned",
	OfflineEarned = "+%s Ryo",
	OfflineNote = "While you are away the dojo earns %s%% of its income, for up to %s.",
	OfflineCollect = "Collect",

	-- Training
	Bubble = "x%s",
	BubbleCaption = "CHAKRA",
	BoostStarted = "x%s Chakra for %s seconds!",
	FocusHint = "Click as the rings meet",
	FocusHit = "%s  +%s",
	FocusMiss = "Miss",

	-- Notifications sent by the server
	NothingHeld = "Pick a shinobi in your Inventory first.",
	HandsFull = "Your hands are full until you are back home.",
	NotEnoughRyo = "Not enough Ryo.",
	NotYourDojo = "This is not your dojo.",
	Merged = "Merged into %s!",
	FloorBuilt = "Your dojo grew! Floor %s is open.",
	Sold = "Sold %s for %s Ryo.",
	SoldMany = "Sold %s shinobi for %s Ryo.",
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
