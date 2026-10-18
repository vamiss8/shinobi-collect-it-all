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
	-- 0.5 if not given; the player's Effects slider is over all of them. Over 1 for a file that
	-- is quiet in itself (up to 2).
	volume: number?,
	speed: number?, -- PlaybackSpeed, 1 if not given
	overlap: boolean?, -- may play again while the last one still sounds (ticks, presses)
	-- How much its pitch is varied at random each time it plays, as a share (0.08 is up to 8%
	-- higher or lower), so that a sound heard over and over does not grate.
	vary: number?,
	-- How long it rings before it is faded away, seconds, for a long sound heard often: it is
	-- not let run out under the next.
	cut: number?,
	-- Cues of one choke (a word) cut one another: one that starts fades away any other of the
	-- same choke still ringing, so that they never sound on top of one another.
	choke: string?,
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
	| "flight" -- the kunai's whistle while it flies, from the kunai (Audio.sustain)
	| "land" -- the kunai strikes the ground
	| "tick" -- the roulette turns to the next shinobi
	| "stop" -- the blow as the roulette stops, under "reveal"
	| "reveal" -- the roulette stops on what was caught
	| "rareHit" -- the blow as it stops on something rare, under "rare"
	| "rare" -- it stopped on a mutation or on the rank above the zone's
	| "enemy" -- the look at the zone's enemy begins
	| "home" -- home safe with the catch
	| "caught" -- caught by the enemy: a taiko sting
	| "caughtHit" -- the blow under it
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
	| "floor" -- a new floor of the dojo goes up
	| "pickup" -- a shinobi taken into the hands
	| "place" -- a shinobi set on a pad
	| "merge" -- two shinobi merged into one
	| "sell" -- shinobi sent on their last mission
	| "potion" -- a potion into the pouch
	| "drink" -- a potion drunk
	| "pass" -- a game pass or a legendary shinobi bought
	| "rebirth" -- a rebirth
	| "event" -- an event begins

local Sounds = {}

Sounds.effects = {
	-- LOUDER THAN THEY WERE (owner, 2026-10-18: "with both sliders at the same level the steps
	-- and some other effects simply cannot be heard"): the quiet ones are turned up, and the
	-- music under them down (Sounds.music.volume). The kunai's hit and the run home were his
	-- examples of good effects, "do not touch them", and are as they were.
	click = { id = 15675032796, volume = 0.5, overlap = true }, -- Roblox_UI_Small_Click
	window = { id = 15675037413, volume = 0.55 }, -- Roblox_UI_Paper_Swipe
	refuse = { id = 9120888980, volume = 0.55 }, -- Wood Hits Board Impacts On Fence Post 7
	announce = { id = 9117231544, volume = 0.6 }, -- Paper Scroll Unroll Handle 3

	press = { id = 9120704978, volume = 0.55 }, -- Whooshes Fast Wipes Quick Airy Slices 3
	perfect = { id = 9126073001, volume = 0.6 }, -- Synth Sparkle Tone High Pitch Bell Tone Ding
	throw = { id = 9120972444, volume = 0.65 }, -- Wood Whoosh Slicing Air Quick Swings 1
	-- A faint whistle while the kunai flies (owner, 2026-10-18: "a barely heard whistle of the
	-- flight"), faded out as the hit's arrow comes in. It is a steady wind of 8 s, longer than
	-- any flight, sounding from the kunai itself. It was Arrow Out Whooshing Pass By 6, looped:
	-- "very strange, it does not go on through the flight, it plays at the start and at the
	-- end, and as if from left to right" (a pass-by swells, crosses and is gone, and the loop
	-- began it again).
	-- Then "on the contrary, very quiet, against the roulette's sounds; bring them into line":
	-- the file is a soft wind, so it is played at 1.6.
	flight = { id = 9113324429, volume = 1.6 }, -- Basement Wind Tubular Airy Swirling 16
	-- The arrow flies in for about half a second before it hits (owner, 2026-10-17: "the
	-- kunai's sound comes about half a second after it lands"), so it is started so early.
	land = { id = 9113161857, volume = 0.6, lead = 0.5 }, -- Arrow In And Hit 19
	-- THE ROULETTE IS HEARD (owner, the same day: "the spin is not so noticeable and epic"): a
	-- shinobi of it comes up in a short puff of smoke, higher and higher as it slows (client
	-- Cinematic), and as it stops a deep blow under the chime, a greater one under the burst
	-- for a rare catch. The stop he liked ("the sound at the end, when the shinobi itself comes
	-- down, is cool"); the airy whirl at the start and the temple block's clack for each turn
	-- he did not ("rubbish, change the spin"): the whirl is gone and the clack is a puff.
	-- Magic Poofs Short Breathy Bursts Punchy 2
	tick = { id = 9116405618, volume = 0.5, overlap = true, vary = 0.05, cut = 0.22 },
	stop = { id = 9126009571, volume = 0.65 }, -- Subwoofer Impact Deep Rumbling Pops Booming
	reveal = { id = 9116394545, volume = 0.65 }, -- Magic Glows Soft Clusters Of Chiming Hits 1
	rareHit = { id = 9125404320, volume = 0.75 }, -- Boom Impact Deep Distant Thumping Hits
	rare = { id = 9116384485, volume = 0.75 }, -- Magic Burst 1
	enemy = { id = 9046413546, volume = 0.7 }, -- APM taiko sting "Gekido"
	home = { id = 9046419161, volume = 0.6 }, -- APM taiko sting "Kyoso"
	-- CAUGHT IS A TAIKO STING OVER A LOW BLOW (owner, 2026-10-18: "there is no sound when the
	-- boss catches you, and it happens often, so it needs a cool one; in headphones there is a
	-- sharp loud click instead"): it was Body Hits 10, a short slap, which I take to be that
	-- click. Zengeance is of the APM taiko album the enemy's and the home's stings are of.
	caught = { id = 9046414649, volume = 0.7 }, -- APM taiko sting "Zengeance"
	caughtHit = { id = 9113535217, volume = 0.6 }, -- Body Slam Low End Thump 2
	herbs = { id = 9114515381, volume = 0.55 }, -- Foliage Crunchy Rustle 4

	-- CHAKRA CONTROL IS SOFT (owner, the same day: "choose less biting ones, these begin to
	-- annoy after a while"): they were high synth sparkles, heard every second or two. Now a
	-- drop of water for a hit, a small temple bell for a Perfect and a muted pat for a miss,
	-- each a little higher or lower every time. AND THEY NEVER RING ON TOP OF ONE ANOTHER
	-- (owner, next: "they glitch, they pile up, too long for chakra control perhaps"): the bell
	-- rings six seconds and a round is a second or so, and each was let overlap itself. Now
	-- the three are one choke, so the next one fades the last away, and each is cut short.
	-- Water Drip Cu Single Drips Constant 9 (Roblox's own)
	ring = { id = 9120510269, volume = 0.55, vary = 0.1, cut = 0.6, choke = "ring" },
	-- A cluster of soft chimes, struck at once. NOT OF THE CHOKE, and played over itself
	-- (owner, next: "six Perfects in a row, the sound played only on the sixth", and then
	-- "still glitchy, and late"). It was a small Buddhist temple bell, whose file, MEASURED
	-- (scratch onset.py: the bytes each tenth of a second takes in the Ogg file), is several
	-- strokes over six seconds, the first soft and the loudest one to three seconds in: cut
	-- short it was gone before its stroke, let ring it came late. This one is loudest in its
	-- first tenth and spent in half a second.
	-- Magic Glows Soft Clusters Of Chiming Hits 2
	ringPerfect = { id = 9116394876, volume = 0.45, vary = 0.04, overlap = true, cut = 0.9 },
	-- Body Pat Muted 1
	ringMiss = { id = 9113531800, volume = 0.45, vary = 0.08, cut = 0.45, choke = "ring" },
	bubble = { id = 17208204604, volume = 0.65, overlap = true }, -- Roblox GUI - Bubble

	coins = { id = 9113849651, volume = 0.6, overlap = true }, -- Coin Throws 3
	kunai = { id = 9119742466, volume = 0.6 }, -- Sword Draw Clang Unsheathing Two Sabers 1
	speed = { id = 9126229255, volume = 0.5 }, -- Whoosh By Fast Airy Swooshing Whipping Thuds
	stage = { id = 9046417006, volume = 0.6 }, -- APM taiko sting "Swing Shime"
	pad = { id = 9113728625, volume = 0.55 }, -- Cash Register 1
	floor = { id = 9114753510, volume = 0.6 }, -- Hammer Hits Wood 3
	pickup = { id = 9113818802, volume = 0.5, vary = 0.08 }, -- Cloth Flap 9
	place = { id = 9113481039, volume = 0.5, vary = 0.06 }, -- Body Fall Wood 1
	merge = { id = 9116421827, volume = 0.65 }, -- Magic Transformation 10
	sell = { id = 9113728049, volume = 0.55 }, -- Cash Register 2
	potion = { id = 9113849492, volume = 0.55 }, -- Coins Or Keys Jingle 6
	drink = { id = 9114171855, volume = 0.55 }, -- Drinking Cu Gulping 2
	pass = { id = 9047073049, volume = 0.6 }, -- APM "Japanese Tradition Sting 3"
	rebirth = { id = 9114630316, volume = 0.7 }, -- Gong Hit Resonant Trail 1
	event = { id = 9047072745, volume = 0.6 }, -- APM "Japanese Tradition Sting 2"
} :: { [Cue]: Effect }

-- FOOTSTEPS BY THE GROUND (owner, 2026-10-18: "the walking sounds are Roblox's stock ones,
-- rather quiet and unclear, and do not depend on the surface"): client Footsteps silences
-- Roblox's and plays these instead, for every character near the camera. The licensed
-- libraries have hardly any plain human steps (ProSoundEffects' "footsteps" are dinosaurs,
-- robots and spiders), so a step is a short blow on the ground it stands for: a stomp for
-- stone, a muted knock for wood, an object set down on grass, rock on earth, sand, snow, a
-- small puddle. MY CANDIDATES, not heard: a surface whose steps he dislikes takes other ids.
export type Surface = {
	ids: { number }, -- one step each, picked at random and never the same twice running
	volume: number, -- a step at a run; a walk is a little softer
	speed: number?, -- PlaybackSpeed, 1 if not given
}

Sounds.steps = {
	-- A jump is a soft flap of clothes, one of four (owner, 2026-10-18: "change the jump, spammed
	-- it is too annoying, and does not fit"; it was a loud swish, Jump Swish 1, and every plain
	-- jump also landed as a heavy thud). Cloth Flap 4, 7, 8, 13.
	jump = { ids = { 9113818515, 9113818671, 9113818686, 9113819701 }, volume = 0.3 },
	-- A landing is a step of the ground landed on: a plain jump's is an ordinary step, and only
	-- a real fall grows louder and lower, up to this many times.
	landing = { volume = 1.5, speed = 0.82 },
	-- The surface of any material not named below.
	fallback = "stone",
	surfaces = {
		-- A fifth softer than first put in (owner, the same day: "a tiny bit quieter", and
		-- again with the first version of client Footsteps brought back: "a little quieter
		-- than the old version").
		-- Tip Toe Of Object Onto Grass 1, 7, 14, 22
		grass = { ids = { 9120062559, 9120062862, 9120063311, 9120063929 }, volume = 0.68 },
		-- Rock Hit Dirt Impact 14, 15, 16, 20
		earth = { ids = { 9118598279, 9118598469, 9118598470, 9118598729 }, volume = 0.48 },
		-- Sand Impacts 4, 5, 7, 8
		sand = { ids = { 9118768256, 9118768193, 9118768545, 9118768535 }, volume = 0.56 },
		-- Wood Grab Muted Thuds 14, 15, 17, 23
		wood = { ids = { 9120880063, 9120880067, 9120880314, 9120880755 }, volume = 0.56 },
		-- Foot Stomp 1, 2, 3, 5
		stone = { ids = { 9114523161, 9114523351, 9114523345, 9114523636 }, volume = 0.4 },
		-- Snowball Hits Lands Semi-Deep Snow 3, 6, 8, 9
		snow = { ids = { 9119310368, 9119310649, 9119310905, 9119310903 }, volume = 0.48 },
		-- Puddle Impact Small Footsteps 1, 2, 3, 7
		water = { ids = { 9117942768, 9117943121, 9117943083, 9117943465 }, volume = 0.44 },
	} :: { [string]: Surface },
	-- The surface of a material, by the name of its Enum.Material.
	materials = {
		Grass = "grass",
		LeafyGrass = "grass",
		Fabric = "grass",
		Carpet = "grass",
		Ground = "earth",
		Mud = "earth",
		Pebble = "earth",
		Sand = "sand",
		Sandstone = "sand",
		Salt = "sand",
		Wood = "wood",
		WoodPlanks = "wood",
		Cardboard = "wood",
		Snow = "snow",
		Glacier = "snow",
		Water = "water",
	} :: { [string]: string },
}

-- A piece of music: an asset of the Creator Store's licensed libraries (APM's, free in any
-- game), its name as the store gives it (the music window shows it), the moment it starts at,
-- how loud it is against the others, and how long the store says it is (the tests hold the
-- moment inside it).
export type Track = {
	id: number,
	name: string,
	from: number?, -- seconds into the track at which it starts, 0 if not given
	-- Where the track is cut, seconds: before a silent tail it ends on, which a loop would
	-- otherwise play through. Its end if not given.
	to: number?,
	-- Where a loop goes back to, seconds, if not to `from`: further back, so that a short
	-- stretch after the chosen moment is not heard over and over.
	loopFrom: number?,
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
	-- 0.5 until the effects were found to be lost under it at the same slider (2026-10-18).
	volume = 0.4,
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
		-- After 1:15 the track has 27 s, and it ends in about 5 s of silence (owner, 2026-10-18:
		-- "it ends very soon, then silence for 5 seconds, then it begins again"): cut at 1:35,
		-- and looped back to 0:45, where the store says its tense part begins.
		kamui_dimension = {
			id = 9040021529,
			name = "Subterranean World",
			from = 75,
			to = 95,
			loopFrom = 45,
			length = 102,
		},
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
