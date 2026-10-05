--!strict
-- Uploaded pictures that take the place of the icons drawn from frames (see Icons). Every
-- entry is the asset id of an image on Roblox; while it is 0 the drawn icon is used, so
-- pictures can be added one at a time.
--
-- To add one: upload a square PNG with a transparent background (512x512 is plenty) in the
-- Creator Hub under Development Items > Images, wait for it to pass moderation, and put its
-- asset id here. The id has to be the image's own, not a decal's: an id copied from the
-- Images list is right.

local Art = {}

Art.icons = {
	coin = 0, -- the Ryo readout
	chakra = 0, -- the Chakra readout
	scroll = 0, -- the Inventory tile
	book = 0, -- the Bingo Book tile
	meditate = 0, -- slot 1
	focus = 0, -- slot 2, Chakra Control
}

-- Portraits of shinobi by character id (Config/Characters), for cards and quick slots. A
-- character without one gets the drawn stand-in in its rank's color.
Art.portraits = {} :: { [string]: number }

return Art
