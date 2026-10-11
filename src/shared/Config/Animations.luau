--!strict
-- Every animation in the game, by name, as the asset id it was published under in Roblox
-- (Animation Editor or Moon Animator -> Publish to Roblox). An animation only plays for players
-- if the game has permission to use it. One published by the game's own owner has it; for any
-- other, the game is granted it on the animation's Permissions page in Creator Hub
-- (Experiences -> the game's universe id). So publish as whoever owns the game at the time.
--
-- An empty id means the animation has not been made yet, and the game does without it: the
-- player's moves are simply not played, and an enemy moves by code alone (Logic/EnemyMotion).
-- Fill an id in and it is used from the next start; nothing else needs to change.

export type Motion = "walker" | "snake" | "giant" | "crawler" | "glider"

export type Enemy = {
	-- How the enemy moves by code while it has no animations of its own (Logic/EnemyMotion).
	motion: Motion,
	idle: string, -- standing in its zone while the camera shows it
	run: string, -- chasing the player
	catch: string, -- the moment it catches the player
}

local Animations = {}

-- The player's own moves. They are made on the R15 body.
Animations.player = {
	-- The kunai throw with a short run-up. Has a marker named "Release" on the frame the kunai
	-- leaves the hand; the kunai flies from that moment.
	Throw = "",
	-- Meditation: sitting down into a half lotus and rising a little off the ground, the pose
	-- held in a loop (rising and sinking a little), and getting up again.
	MeditateStart = "122527617398687",
	MeditateLoop = "120597008126969",
	MeditateEnd = "108324337250224",
	-- Chakra control: gathering chakra between the palms, in a loop, and a short jolt on a hit.
	ChakraLoop = "",
	ChakraHit = "92010342009522",
}

-- When in the throw animation the kunai leaves the hand, seconds from its start: where its
-- "Release" marker sits. The server lets the kunai fly this long after the press, so that every
-- client sees it leave the hand; with no throw animation it flies at once, as it always did.
Animations.THROW_RELEASE = 0.75

-- Each zone's enemy, by zone id (Config/Zones).
Animations.enemies = {
	academy = { motion = "walker", idle = "", run = "", catch = "" }, -- Mizuki
	land_of_waves = { motion = "walker", idle = "", run = "", catch = "" }, -- Zabuza
	forest_of_death = { motion = "snake", idle = "", run = "", catch = "" }, -- Giant Snake
	chunin_exam_finals = { motion = "giant", idle = "", run = "", catch = "" }, -- Shukaku
	valley_of_the_end = { motion = "walker", idle = "", run = "", catch = "" }, -- Sasuke
	hidden_sand = { motion = "crawler", idle = "", run = "", catch = "" }, -- Hiruko
	akatsuki_lair = { motion = "walker", idle = "", run = "", catch = "" }, -- Itachi
	hidden_rain = { motion = "glider", idle = "", run = "", catch = "" }, -- Pain
	kamui_dimension = { motion = "walker", idle = "", run = "", catch = "" }, -- Obito
	great_ninja_war = { motion = "giant", idle = "", run = "", catch = "" }, -- Ten-Tails
} :: { [string]: Enemy }

-- The full asset id for an id as written above, or nil when it is empty. Takes a bare number as
-- well as one that already starts with "rbxassetid://".
function Animations.asset(id: string?): string?
	if id == nil or id == "" then
		return nil
	end
	if string.match(id, "^%d+$") then
		return "rbxassetid://" .. id
	end
	return id
end

-- Whether the throw animation has been made, so the kunai waits for the hand.
function Animations.hasThrow(): boolean
	return Animations.asset(Animations.player.Throw) ~= nil
end

-- How long after a press the kunai leaves the hand.
function Animations.throwDelay(): number
	return if Animations.hasThrow() then Animations.THROW_RELEASE else 0
end

return Animations
