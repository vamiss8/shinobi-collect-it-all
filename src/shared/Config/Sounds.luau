--!strict
-- Every sound the game makes, by the moment it is made for (client Audio plays them), and the
-- music. An id is a Roblox audio asset; 0 is silence, so a moment without a sound chosen yet is
-- simply quiet.
--
-- The effects are CANDIDATES for the owner to listen to (2026-10-17: "find sound effects and
-- propose them"; I cannot hear them): all are free to use in any game, taken from the Creator
-- Store's licensed libraries only, Roblox's own sounds, ProSoundEffects' and APM's (the two
-- libraries Roblox licensed for every creator), never from sounds users cut out of other games.
-- To hear one outside the game: create.roblox.com/store/asset/<id>. To change one, put another
-- id in its place.
--
-- The music is the owner's own tracks (uploaded by the group, which owns the game), none in yet:
-- the village plays its calm track; a runner hears the boss of the zone they run from; an event
-- plays its own track over both (owner, 2026-10-14: "no boss track during an event").

export type Effect = {
	id: number,
	volume: number?, -- 0.5 if not given; the player's Effects slider is over all of them
	speed: number?, -- PlaybackSpeed, 1 if not given
	overlap: boolean?, -- may play again while the last one still sounds (ticks, presses)
}

export type Cue =
	-- The interface
	"click" -- a button pressed
	| "window" -- a window opens
	| "refuse" -- something could not be done: Herbs or Ryo short
	| "announce" -- the large scroll unrolls with a word from the developer
	-- The throw
	| "press" -- the power bar pressed, not a Perfect
	| "perfect" -- the power bar pressed in the Perfect band
	| "throw" -- the kunai leaves the hand
	| "land" -- the kunai strikes the ground
	| "tick" -- the roulette turns to the next shinobi
	| "reveal" -- the roulette stops on what was caught
	| "rare" -- it stopped on a mutation or on the rank above the zone's
	| "enemy" -- the look at the zone's enemy begins
	| "home" -- home safe with the catch
	| "caught" -- caught by the enemy
	| "herbs" -- a throw brought Herbs
	-- Training
	| "ring" -- the Chakra Control ring hit
	| "ringPerfect" -- hit in the Perfect band
	| "ringMiss" -- missed
	| "bubble" -- a bonus seal broken
	-- Buying and growing
	| "coins" -- Ryo paid or received (an upgrade, a pack, the welcome back)
	| "kunai" -- a new kunai bought
	| "speed" -- a level of run speed bought
	| "stage" -- a new speed stage reached
	| "pad" -- a pad bought
	| "sell" -- shinobi sent on their last mission
	| "potion" -- a potion into the pouch
	| "drink" -- a potion drunk
	| "pass" -- a game pass or a legendary shinobi bought
	| "rebirth" -- a rebirth
	| "event" -- an event begins

local Sounds = {}

Sounds.effects = {
	click = { id = 15675032796, volume = 0.4, overlap = true }, -- Roblox_UI_Small_Click
	window = { id = 15675037413, volume = 0.45 }, -- Roblox_UI_Paper_Swipe
	refuse = { id = 9120888980, volume = 0.5 }, -- Wood Hits Board Impacts On Fence Post 7
	announce = { id = 9117231544, volume = 0.5 }, -- Paper Scroll Unroll Handle 3

	press = { id = 9120704978, volume = 0.45 }, -- Whooshes Fast Wipes Quick Airy Slices 3
	perfect = { id = 9126073001, volume = 0.55 }, -- Synth Sparkle Tone High Pitch Bell Tone Ding
	throw = { id = 9120972444, volume = 0.6 }, -- Wood Whoosh Slicing Air Quick Swings 1
	land = { id = 9113161857, volume = 0.6 }, -- Arrow In And Hit 19
	tick = { id = 9125916812, volume = 0.35, overlap = true }, -- Scrolling Graphic Clicks Small
	reveal = { id = 9116394545, volume = 0.6 }, -- Magic Glows Soft Clusters Of Chiming Hits 1
	rare = { id = 9116384485, volume = 0.65 }, -- Magic Burst 1
	enemy = { id = 9046413546, volume = 0.7 }, -- APM taiko sting "Gekido"
	home = { id = 9046419161, volume = 0.6 }, -- APM taiko sting "Kyoso"
	caught = { id = 9113502635, volume = 0.6 }, -- Body Hits 10
	herbs = { id = 9114515381, volume = 0.4 }, -- Foliage Crunchy Rustle 4

	ring = { id = 9126071458, volume = 0.45, overlap = true }, -- Synth Sparkle Tone ... Burst
	ringPerfect = { id = 9126073318, volume = 0.55, overlap = true }, -- ... Bell Tone Ding
	ringMiss = { id = 9120888980, volume = 0.4 }, -- Wood Hits Board Impacts On Fence Post 7
	bubble = { id = 17208204604, volume = 0.55, overlap = true }, -- Roblox GUI - Bubble

	coins = { id = 9113849651, volume = 0.45, overlap = true }, -- Coin Throws 3
	kunai = { id = 9119742466, volume = 0.6 }, -- Sword Draw Clang Unsheathing Two Sabers 1
	speed = { id = 9126229255, volume = 0.5 }, -- Whoosh By Fast Airy Swooshing Whipping Thuds
	stage = { id = 9046417006, volume = 0.6 }, -- APM taiko sting "Swing Shime"
	pad = { id = 9113728625, volume = 0.5 }, -- Cash Register 1
	sell = { id = 9113728049, volume = 0.5 }, -- Cash Register 2
	potion = { id = 9113849492, volume = 0.45 }, -- Coins Or Keys Jingle 6
	drink = { id = 9114171855, volume = 0.55 }, -- Drinking Cu Gulping 2
	pass = { id = 9047073049, volume = 0.6 }, -- APM "Japanese Tradition Sting 3"
	rebirth = { id = 9114630316, volume = 0.7 }, -- Gong Hit Resonant Trail 1
	event = { id = 9047072745, volume = 0.6 }, -- APM "Japanese Tradition Sting 2"
} :: { [Cue]: Effect }

-- The music: the village's calm track, a track for each zone's boss (by zone id, while its
-- enemy chases the player) and one for each event (by event id). 0 until the owner's tracks
-- are uploaded.
Sounds.music = {
	village = 0,
	volume = 0.5,
	-- How long one track gives way to the next, seconds.
	crossfade = 1.5,
	bosses = {
		academy = 0,
		land_of_waves = 0,
		forest_of_death = 0,
		chunin_exam_finals = 0,
		valley_of_the_end = 0,
		hidden_sand = 0,
		akatsuki_lair = 0,
		hidden_rain = 0,
		kamui_dimension = 0,
		great_ninja_war = 0,
	} :: { [string]: number },
	events = {
		leaf_festival = 0,
		akatsuki_raid = 0,
		crimson_moon = 0,
	} :: { [string]: number },
}

return Sounds
