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
	ThrowClose = "Close",
	ThrowHint = "Use less Chakra to land in a nearer zone. Click the number to type one.",
	ThrowType = "3000, 3K, 1.5M...",
	ThrowTypeHint = "click to type",

	-- The luck board on the map
	LuckTitle = "LUCKY THROWS",
	LuckWhat = "better odds of a higher rank and of a mutation",
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
	-- What a keeper says to whoever comes up to the counter (client Shops): what the shop is
	-- for, large, and one of the lines under it. The first line says what the shop's goods
	-- are good for and is the one said first; after that any of them.
	PitchTenten = "Buy a better kunai here!",
	TentenHello1 = "A better kunai gives more Chakra for every rep!",
	TentenHello2 = "Welcome to my shop! Every kunai here flies true.",
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
	ShopSpeedTitle = "Youth Training Ground",
	ShopSpeedHint = "Run speed decides which zones you can bring a shinobi home from. Every "
		.. "few levels reach a new stage, and its style shows on your character.",
	ShopSpeedStage = "YOUR STAGE",
	ShopSpeedLevel = "Speed %s  |  level %s of %s",
	ShopSpeedNext = "Next level: run speed %s -> %s",
	ShopSpeedOpens = "Next level: %s!",
	ShopSpeedToStage = "%s in %s levels",
	ShopSpeedMaxed = "All Eight Gates are open",
	-- On the scroll that names a new speed stage, under its name.
	StageGateOpened = "Gate %s of %s is open!  Run speed %s",
	StageReached = "A new stage of training!  Run speed %s",
	PitchSpeed = "Improve your run speed here!",
	DuyHello1 = "Run faster and you get home from the farther zones!",
	DuyHello2 = "Strap on those weights and run until the sun goes down!",
	DuyHello3 = "Even a genin can open the Gates with enough hard work!",
	DuyHello4 = "Your youth is burning bright today!",
	-- The speed the player runs at, which may be less than they have trained.
	ShopSpeedRunAt = "Run at speed",
	ShopSpeedFastest = "Fastest",
	ShopSpeedHeldBack = "Your fastest is %s",
	ShopSpeedAtFastest = "As fast as you have trained",
	-- The list of speed stages and how each one looks on a runner.
	ShopSpeedStyles = "Styles",
	StyleLine = "Level %s  |  speed %s",
	StyleAdds = "+ %s",
	StyleNothing = "nothing to show yet",
	StyleWorn = "Wearing",
	StyleWear = "Wear",
	StyleLocked = "Level %s",
	Wear_dust = "dust at your feet",
	Wear_warmers = "leg warmers",
	Wear_weights = "iron weights on your shins",
	Wear_heavy = "a second weight on each shin",
	Wear_wrists = "weights on your wrists",
	Wear_steam = "steam off your body",
	Wear_trail = "a trail behind you",
	Wear_motes = "lights rising round you",
	Wear_flame = "flame at your feet",
	Wear_sparks = "sparks cracking off you",
	Wear_streaks = "trails from your hands",
	Wear_fan = "a fan of sparks on the run",
	Wear_burst = "steam bursting at your feet",
	Wear_embers = "embers overhead",
	ShopSpeedEnemies = "Who you can outrun",
	ShopSpeedEnemy = "%s (%s-%s)  |  %s",
	ShopSpeedSafe = "you get away",
	ShopSpeedPartly = "near side only",
	ShopSpeedSlower = "catches you",
	ShopMax = "MAX",
	ShopPrice = "%s Ryo",

	-- The Mission Desk. A shinobi handed in here is sent on its last mission: it does not come
	-- back, and the desk pays its reward. (It is a sale by another name: the keys say "Sell".)
	SellTitle = "Mission Desk",
	SellHint = "Send a shinobi on its last mission: it will not come back, and Shizune pays "
		.. "you its reward. Click one to send it.",
	PitchSell = "Send shinobi on a last mission here!",
	MissionHello1 = "Spare shinobi earn you Ryo on their last mission.",
	MissionHello2 = "Welcome to the Mission Desk! Shinobi are always needed.",
	MissionHello3 = "Tonton, those are mission reports, not snacks!",
	MissionHello4 = "Lady Tsunade wants all of these missions filled by tonight...",
	SellEmpty = "Nobody to send. Shinobi on pads have to be taken off first.",
	SellAll = "Send all",
	SellAllConfirm = "Send %s for %s Ryo?",
	SellPrice = "Reward: %s",

	-- Rebirth (client RebirthPanel): the tile, the window, and the scroll when one is done.
	RebirthButton = "Rebirth",
	RebirthTitle = "Rebirth",
	RebirthRanks = "RANKS",
	RebirthStep = "You are: %s",
	RebirthAllDone = "The highest rank",
	RebirthProgress = "%s / %s Chakra",
	RebirthRyo = "Income",
	RebirthPower = "Chakra",
	RebirthLuck = "Mutations",
	RebirthChange = "x%s -> x%s",
	RebirthHolds = "x%s",
	-- What a rebirth takes and what it leaves, a line each: the first word in color.
	RebirthLoses = '<font color="#EF5350">RESETS</font>   Chakra · shinobi · Ryo · run speed',
	RebirthKeeps = '<font color="#66BB6A">STAYS</font>   kunai · dojo floors · Bingo Book'
		.. " · legendary shinobi",
	RebirthDo = "REBIRTH",
	RebirthNeed = "Need %s more Chakra",
	RebirthSure = "Press again to confirm",
	RebirthNoMore = "Top rank reached",
	RebirthDone = "Income x%s  |  Chakra x%s  |  mutation luck x%s",

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

	-- The run home
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

	-- The list of players (client PlayerList): how many are here, and what a dojo earns.
	PlayersTitle = "ONLINE  %s/%s",
	PlayersCount = "x%s",
	PlayersIncome = "%s/s",

	-- The legendary shinobi on their pedestals (Services/Legends, client LegendShow).
	LegendYours = "YOURS",
	LegendPrice = "%s ROBUX",
	LegendOwned = "%s is already yours.",
	LegendSoon = "%s is not for sale yet. Soon!",
	LegendJoined = "%s has joined you! Find them in your Inventory.",
	LegendBy = "%s has %s at their side!",

	-- An event (client EventShow): what it brings, on the scroll that announces it; what is
	-- left of it, on its timer; and that it is over.
	EventBegins = "A chance of %s shinobi on every catch  |  x%s Ryo",
	EventLeft = "%s left",
	EventOver = "The %s is over.",

	-- Notifications sent by the server
	NothingHeld = "Pick a shinobi in your Inventory first.",
	HandsFull = "Your hands are full until you are back home.",
	NotEnoughRyo = "Not enough Ryo.",
	NotYourDojo = "This is not your dojo.",
	Merged = "Merged into %s!",
	FloorBuilt = "Your dojo grew! Floor %s is open.",
	GateOpenedBy = "%s opened the %s!",
	RebirthBy = "%s was reborn as %s!",
	Sold = "%s left on a last mission. Reward: %s Ryo.",
	SoldMany = "%s shinobi left on their last mission. Reward: %s Ryo.",
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
