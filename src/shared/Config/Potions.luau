--!strict
-- Boosts that run for a while once drunk. A player keeps them in a pouch (Data `stock`) and
-- drinks one when they like (Logic/Pouch); drinking one while the same is running adds its
-- minutes to it. They come into the pouch two ways: bought for Herbs at the Herb Shop on the
-- plaza, Herbs being paid for every catch brought home (Tuning.Herbs), or bought for Robux as developer
-- products (Config/Products).
--
-- `herbs` is what one costs at the Herb Shop: the Chakra one dearest, Chakra being what holds
-- a player back late in the game; the luck ones cheapest, being for the hunt more than for the
-- pace. Herbs are paid by the zone of the catch, so they come faster as a player goes
-- farther: by `lune run sim` an average player earns about 220 in the first hour, 300 to 370
-- an hour after that and 440 an hour over the whole game (a skilled one a third more).
-- Throwing with Chakra 1 over and over, the trick that the old payment rewarded, earns about
-- 280 to 550 an hour and nothing else.
--
-- FIVE MINUTES A POTION AT A THIRD OF THE PRICE (owner, 2026-10-18: "let us make all the
-- potions five minutes and lower the price three times"). They were 15 minutes for 480, 400,
-- 240 and 320 Herbs. A minute of a boost costs what it did, so a potion is drunk three times as
-- often and an hour of play buys three or four of them.
--
-- TWICE THE PRICE SINCE THE ACHIEVEMENTS PAY HERBS (owner, 2026-10-18: "Herbs now come more
-- ways, raise the potions' prices; work it out"). The achievements' tiers pay about 14,000
-- Herbs and 17 potions in all, the group's gift 250 and 4 potions, most of it early: by the
-- sim's average player, play pays about 600 in the first two hours, 3,300 by ten and 16,200
-- by forty, and the achievements about 2,300, 5,300 and 10,000 by then. So a player has 5,
-- 2.6 and 1.6 times the Herbs of play alone at those marks; at twice the price they buy 2.6,
-- 1.3 and 0.8 times the potions that play alone bought before: more in the first hours, about
-- the same over a day's play, a little less late. They were 160, 135, 80 and 105.
--
-- ONE BOUGHT FOR ROBUX IS PREMIUM AND RUNS `premiumMinutes`, 15 (owner, the same day: "let the
-- versions for Robux stay at 15 minutes, a premium version; the price stays, and the shop says
-- so"). A potion product or the bundle puts premium ones into the pouch (Data `premium`), kept
-- apart from those bought for Herbs, and the player picks which to drink.

export type Effect = "ryo" | "chakra" | "luck" | "mutationLuck"

export type Potion = {
	id: string,
	name: string,
	effect: Effect,
	multiplier: number,
	minutes: number, -- how long one bought for Herbs runs
	premiumMinutes: number, -- how long one bought for Robux runs
	herbs: number,
}

local Potions: { Potion } = {
	{
		id = "soldier_pill",
		name = "Soldier Pill",
		effect = "chakra",
		multiplier = 2,
		minutes = 5,
		premiumMinutes = 15,
		herbs = 320,
	},
	{
		id = "ichiraku_ramen",
		name = "Ichiraku Ramen",
		effect = "ryo",
		multiplier = 2,
		minutes = 5,
		premiumMinutes = 15,
		herbs = 270,
	},
	{
		id = "gama_charm",
		name = "Gama-chan Charm",
		effect = "luck",
		multiplier = 2,
		minutes = 5,
		premiumMinutes = 15,
		herbs = 160,
	},
	{
		id = "sage_oil",
		name = "Sage Oil",
		effect = "mutationLuck",
		multiplier = 2,
		minutes = 5,
		premiumMinutes = 15,
		herbs = 210,
	},
}

return Potions
