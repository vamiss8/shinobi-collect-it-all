--!strict
-- Every balance number in one place. Tweak here, not in the logic.

return {
	Training = {
		-- Meditation (AFK): a tick every `meditateInterval` seconds while sitting still, each
		-- worth `meditateReps` reps. Half a rep a second keeps it well behind active play,
		-- which averages about one rep a second once throws and errands are counted in.
		meditateInterval = 1,
		meditateReps = 0.5,
		-- Chakra control (active): a ring closes in on a target ring; press as they meet.
		-- Every round the ring's speed and the target's size are drawn at random, so pressing
		-- on a fixed beat does not work.
		ringPeriodMin = 1.0, -- seconds for the ring to close all the way; it then starts over
		ringPeriodMax = 1.6,
		ringTargetMin = 0.55, -- the point in the period at which the two rings meet, 0..1
		ringTargetMax = 0.8,
		-- How far off a press may be, as a share of the period, and how many reps it pays.
		-- Checked top-down; a press outside every window is a miss and pays nothing.
		ringGrades = {
			{ id = "Perfect", within = 0.04, reps = 4 },
			{ id = "Great", within = 0.09, reps = 2 },
			{ id = "Good", within = 0.16, reps = 1 },
		},
		-- Bonus bubbles pop up while training; popping one multiplies training gains for a while.
		-- With every bubble popped a boost runs about 40% of the time, which multiplies
		-- training by 1.8 on average.
		bubbleEveryMin = 15,
		bubbleEveryMax = 30,
		bubbleSeconds = 3, -- how long a bubble stays on screen
		boostSeconds = 10, -- how long a popped bubble's multiplier lasts
		bubbles = {
			{ multiplier = 2, weight = 70 },
			{ multiplier = 5, weight = 25 },
			{ multiplier = 10, weight = 5 },
		},
	},

	Kick = {
		barPeriod = 1.4, -- seconds for one full 0 -> 1 -> 0 sweep of the power bar
		-- A throw's power is Chakra times the share of it the press earns: the marker's position
		-- on the bar (0..1) raised to `powerCurve`. The higher the press, the farther the kunai,
		-- and nothing is left to chance. Power picks the zone by the zones' own thresholds
		-- (Config/Zones), and how far past a threshold it is picks the spot inside the zone, on a
		-- log scale: every doubling carries the kunai equally far.
		-- The curve is what makes a sloppy press cost something. Zones are about 7.5 times apart
		-- in Chakra, so with the plain position a press from the middle of the bar still landed
		-- in the zone a perfect one reached. Cubed, a press keeps 83% of the power at the edge
		-- of Perfect, 51% at the edge of Great and 17% at the edge of Good: at most a tenth of a
		-- zone lost, a third, nine tenths, and below that a zone or more.
		powerCurve = 3,
		-- The grades name a press; Perfects in a row charge the Sage kick. Checked top-down
		-- against the bar position; the first match wins.
		grades = {
			{ id = "Perfect", from = 0.94 },
			{ id = "Great", from = 0.8 },
			{ id = "Good", from = 0.55 },
			{ id = "Miss", from = 0 },
		},
		lastZoneSpan = 8, -- the last zone's far end takes this many times its threshold
		trackLength = 3600, -- studs; throws never land past the end
		-- A kunai's flight: it covers `flightSpeed` studs a second, but is never in the air for
		-- less or more than `flightSeconds`, and rises `flightArc` of the way it goes, between
		-- the two heights of `flightHeight`. Scenery keeps clear of the highest (World/ZoneArt).
		flightSpeed = 500,
		flightSeconds = { 0.8, 4.5 },
		flightArc = 0.075,
		flightHeight = { 6, 60 },
		stripDepth = 10, -- depth of the throwing strip at the start of the lane, studs
		sageStreak = 5, -- Perfects in a row that charge the Sage kick
		sageMultiplier = 2, -- a Sage kick's power; worth about a third of a zone
		-- How far the client's claimed timing may drift from the server's estimate, seconds.
		timingTolerance = 0.15,
	},

	-- The run home after a throw.
	Chase = {
		rollSeconds = 2.6, -- the roulette of shinobi where the kunai landed
		holdSeconds = 0.9, -- the rolled shinobi stays on screen
		-- The camera shows the enemy and says who it is, then swings back behind the player;
		-- the player cannot move yet. Long enough to read a name: at 1.4 the run began
		-- almost as the roulette stopped.
		introSeconds = 3,
		-- On the lane everyone covers this many times the ground their run speed says, the
		-- runner and the enemy alike; in the village a runner's speed is what the Speed Store
		-- sold. The zones are twice as long as they were first built: at village speed the way
		-- home took twice as long too, and it now takes a third longer, which leaves time to
		-- look at a zone without the run dragging.
		laneSpeed = 1.5,
		enemyGap = 65, -- the enemy appears this many studs farther down the lane
		enemyDelay = 0.5, -- head start once the player can move, seconds
		catchRadius = 5, -- studs
		-- An enemy runs at its zone's speed for a kunai on the zone's near edge and speeds up
		-- to the next zone's speed by the far end, so reaching deep into a zone is not yet a
		-- way out. The last zone has no next one: its enemy gains this share instead.
		farSpeedBonus = 0.15,
		consolationSeconds = 3, -- getting caught still pays this many seconds of the unit's income
	},

	-- A zone drops its own rank; the next rank up has this chance at the zone's start, rising
	-- in a straight line to the chance at its far end. Luck multiplies it.
	-- The last zone has no next rank, so depth there pays in mutation luck instead: x1 on its
	-- near edge, rising in a straight line to `deepMutationLuck` at the end of the lane.
	Zones = {
		nextRankAtStart = 0.02,
		nextRankAtEnd = 0.12,
		deepMutationLuck = 2,
	},

	-- Leveling up a unit that stands on a pad. The numbers are Kick an Uma's: each level
	-- multiplies income by 1.25 and the next upgrade's price by 1.5.
	Upgrade = {
		incomeGrowth = 1.25, -- income is multiplied by this with every upgrade
		costSeconds = 5, -- the first upgrade costs this many seconds of the unit's income
		costGrowth = 1.5, -- and each next one this many times more
		maxUpgrades = 199, -- so the highest level shown is 200
	},

	Luck = {
		-- Every Nth kick rolls with extra luck. Checked top-down; the first match wins.
		milestones = {
			{ every = 100, luck = 10 },
			{ every = 20, luck = 5 },
			{ every = 10, luck = 2 },
		},
	},

	-- A dojo has 30 pads (Logic/DojoPlan): the free ones, those bought for Ryo one after another,
	-- each at `padPriceGrowth` times the last, and those of the +4 pads game pass. The pass's
	-- pads are the last ones, at the back of the top floor.
	Dojo = {
		startPads = 5,
		buyablePads = 21,
		gamePassPads = 4,
		padBasePrice = 500,
		padPriceGrowth = 2.5,
		mergeMultiplier = 2.5, -- a merged unit earns this many times one of its parts
		-- Away from the game the dojo earns at `offlineRate` of its income, for at most
		-- `offlineCapHours`: three days off pay like a day and a half of standing in the dojo.
		offlineRate = 0.5,
		offlineCapHours = 72,
		sellSeconds = 30, -- selling a unit pays this many seconds of its income
	},

	-- Run speed is what gets a catch home (Logic/Chase). Every zone from the third on asks
	-- for about four more levels at its near edge, and the far end of the lane for all but
	-- the last of the forty. Prices grow as the kunai's do, thirty-five times a zone, so the
	-- four levels a zone asks for stay the same small share of what its two kunai cost: run
	-- speed is to be there by the time the Chakra is (see `lune run sim`).
	Speed = {
		base = 16, -- Roblox default WalkSpeed
		perLevel = 1,
		maxLevel = 40,
		basePrice = 20,
		priceGrowth = 2.43,
	},

	Index = {
		discoveryRewardSeconds = 10, -- first find pays this many seconds of the unit's income
		pageCompleteBonus = 0.1, -- +10% income per fully collected page (one per mutation)
	},
}
