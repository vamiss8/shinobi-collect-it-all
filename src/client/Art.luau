--!strict
-- Uploaded pictures that take the place of the icons drawn from frames (see Icons). Every
-- entry is the asset id of an image on Roblox; while it is 0 the drawn icon is used, so
-- pictures can be added one at a time.
--
-- The pictures themselves are kept in assets/icons, cropped and sized for upload. To add one:
-- upload its PNG in the Creator Hub under Development Items > Images from the account that
-- owns the game, and put its asset id here. The id has to be the image's own, not a decal's:
-- an id copied from the Images list is right. An id may go in before the image has passed
-- moderation: until it loads, the drawn icon stays.

local Art = {}

Art.icons = {
	coin = 116508526878923, -- the Ryo readout; assets/icons/coin.png
	chakra = 112681131536613, -- the Chakra readout; assets/icons/chakra.png
	scroll = 112573281784616, -- the Inventory tile; assets/icons/scroll.png
	book = 134344077361427, -- the Bingo Book tile; assets/icons/book.png
	meditate = 123433743975781, -- slot 1; assets/icons/meditate.png
	focus = 74944362570117, -- slot 2, Chakra Control; assets/icons/focus.png
	rebirth = 78996990936807, -- the Rebirth tile; assets/icons/rebirth.png
}

-- The emblems of the ranks players hold for their rebirths, by how many rebirths the rank
-- takes (Config/Rebirths; 0 is Academy Student), and of the stages of run speed, by the
-- stage's place in Config/SpeedStages (1 is Beginner, 5 the first Gate, 12 the last). Each is
-- a whole round badge, its own ground included, and takes the place of the seal drawn from
-- frames (Icons.rank, Icons.stage). The pictures are kept in assets/icons as rank_<n>.png and
-- stage_<n>.png.
Art.ranks = {
	[0] = 90964076211156, -- Academy Student
	[1] = 108510148876957, -- Genin
	[2] = 74231858107005, -- Chunin
	[3] = 96262673939127, -- Special Jonin
	[4] = 116383352351205, -- Jonin
	[5] = 105009275133134, -- ANBU
	[6] = 139778893959986, -- ANBU Captain
	[7] = 73491911753299, -- Sannin
	[8] = 110692031362276, -- Kage
	[9] = 106605286429250, -- Sage
	[10] = 130745525133572, -- Sage of Six Paths
} :: { [number]: number }
Art.stages = {
	[1] = 103899649154186, -- Beginner
	[2] = 133230073728037, -- Morning Laps
	[3] = 136424728514446, -- Training Weights
	[4] = 74685852013618, -- Heavy Weights
	[5] = 129118547272015, -- Gate of Opening
	[6] = 133458288556065, -- Gate of Healing
	[7] = 112941852624431, -- Gate of Life
	[8] = 118098574893622, -- Gate of Pain
	[9] = 131720257347679, -- Gate of Limit
	[10] = 106608979424319, -- Gate of View
	[11] = 107539491901641, -- Gate of Wonder
	[12] = 87883693169818, -- Gate of Death
} :: { [number]: number }

-- Portraits of shinobi by character id (Config/Characters), for cards and quick slots. A
-- character without one gets the drawn stand-in in its rank's color.
Art.portraits = {} :: { [string]: number }

-- Pictures of kunai by kunai id (Config/Kunai), for Tenten's shop window and the marker of the
-- power bar. A picture shows the kunai standing upright, tip up, and is turned as needed when
-- shown. A kunai without one is drawn from frames in its own colors. The pictures are kept in
-- assets/kunai, cut out of their backgrounds and stood upright; assets/kunai/reference has the
-- same on white, larger, for making the 3D models from.
Art.kunai = {
	training = 136133937132579, -- assets/kunai/training.png
	iron = 92943922851969,
	steel = 71731138947205,
	wire = 116163771185322,
	explosive_tag = 126500229998995,
	poison = 111566715173196,
	chakra_blade = 86272247369001,
	earth = 113044773720860,
	water = 118493751269313,
	wind = 93788270333169,
	fire = 94012698652192,
	lightning = 97029922626007,
	wood = 134093751621369,
	magnet = 124493209658626,
	scorch = 109589501483250,
	dust = 90259483784504,
	black_flame = 71173881958233,
	thunder_god = 136259121531337,
	truth_seeking = 98861102875126,
} :: { [string]: number }

return Art
