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
-- The music is from the same licensed libraries (APM's): what plays where is under
-- Sounds.music below.

export type Effect = {
	id: number,
	volume: number?, -- 0.5 if not given; the player's Effects slider is over all of them
	speed: number?, -- PlaybackSpeed, 1 if not given
	overlap: boolean?, -- may play again while the last one still sounds (ticks, presses)
	-- How far into the sound its moment comes (the hit of an arrow that first flies in),
	-- seconds: it is started that much before the moment, where its caller can (Audio.lead).
	lead: number?,
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
	-- The arrow flies in for about half a second before it hits (owner, 2026-10-17: "the
	-- kunai's sound comes about half a second after it lands"), so it is started so early.
	land = { id = 9113161857, volume = 0.6, lead = 0.5 }, -- Arrow In And Hit 19
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

-- A piece of music: an asset of the Creator Store's licensed libraries (APM's, free in any
-- game), its name as the store gives it (the music window shows it), the moment it starts at,
-- how loud it is against the others, and how long the store says it is (the tests hold the
-- moment inside it).
export type Track = {
	id: number,
	name: string,
	from: number?, -- seconds into the track at which it starts, 0 if not given
	volume: number?, -- times Sounds.music.volume, 1 if not given
	length: number, -- seconds, as the Creator Store gives it
}

-- The music (owner, 2026-10-18). THE VILLAGE PLAYS A PLAYLIST: several calm, light tracks one
-- after another, never the same twice running ("one alone would pall; they must take turns"),
-- which the player can step through, repeat and shuffle in the settings' player (client SettingsPanel).
-- A RUNNER HEARS THEIR ZONE'S TRACK, from the moment the owner chose in it (`from`, where its
-- drop is), for the chase alone: at home the village's comes back and goes on from where it
-- was. He had first thought of letting a zone's track play out after the run and gave it up:
-- most are dark or heavy to hear whole, and the drop belongs to the chase. A zone's track that
-- runs out during a chase begins again from its moment. The Academy has none: it is the
-- village itself, and its chase lasts five seconds. An event's track plays over both while it
-- runs (owner, 2026-10-14: "no boss track during an event").
-- NO TRACK HAS WORDS (owner, the same day: "tracks without words everywhere"): the store does
-- not tag voices, so a track goes in only when its description names its instruments and no
-- voices. The zones' tracks are his choice from the Creator Store; the village's and the
-- events' are MY CANDIDATES, chosen by what the store says of them, since I cannot hear them.
-- To hear one outside the game: create.roblox.com/store/asset/<id>.
Sounds.music = {
	volume = 0.5,
	-- How long one track gives way to another, seconds.
	crossfade = 1.5,
	-- How fast a zone's track comes in when a chase begins, so that its drop is not faded under.
	chase = 0.4,
	village = {
		-- Cheerful, gentle shamisen and koto, no drums.
		{ id = 9047130875, name = "Kemari D", length = 121 },
		-- A light underscore, Japanese instruments only.
		{ id = 9047132342, name = "History Of Bushido D", length = 76 },
		-- A light Japanese rhythm without drums, with shakuhachi.
		{ id = 9047128762, name = "Motivational Incentive D", length = 123 },
		-- Koto, soft guitar, airy guitar, chimes.
		{ id = 1837591472, name = "Fudji Sunrise", length = 178 },
		-- "Unhurried scenes".
		{ id = 1839872620, name = "Japanese Life", length = 86 },
	} :: { Track },
	bosses = {
		land_of_waves = { id = 9043278318, name = "Kyoto", from = 7, volume = 0.6, length = 190 },
		forest_of_death = { id = 9043557976, name = "Uneasy Ticking (b)", from = 73, length = 100 },
		chunin_exam_finals = {
			id = 9043308431,
			name = "Training For Victory",
			from = 21,
			length = 134,
		},
		valley_of_the_end = {
			id = 9043605715,
			name = "The Tornado Approaches (b)",
			from = 18,
			length = 126,
		},
		hidden_sand = { id = 1839958713, name = "Desert Trap b", from = 58, length = 137 },
		akatsuki_lair = { id = 9039697342, name = "Much Fear", from = 121, length = 170 },
		hidden_rain = { id = 9042149619, name = "Piano Reflections (a)", from = 83, length = 246 },
		kamui_dimension = { id = 9040021529, name = "Subterranean World", from = 75, length = 102 },
		great_ninja_war = { id = 1835322993, name = "Purge the Darkness", from = 30, length = 190 },
	} :: { [string]: Track },
	events = {
		-- A shakuhachi tune leading to a festive beat with shamisen, "busy Tokyo street life";
		-- the owner liked Pleasure Days, which has a singer.
		leaf_festival = { id = 9047131010, name = "Tokyo Festival A", length = 173 },
		-- An ominous, strong opening and a steady, driving taiko beat; Among Blossom was too quiet.
		akatsuki_raid = { id = 9038213554, name = "Seifuku", length = 135 },
		-- Dark and bewitching over a slow beat, shamisen-like guitars.
		crimson_moon = { id = 9040307437, name = "Black Moon Temple", length = 159 },
	} :: { [string]: Track },
}

return Sounds
