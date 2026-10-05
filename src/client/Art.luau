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
	coin = 0, -- the Ryo readout; assets/icons/coin.png
	chakra = 0, -- the Chakra readout; assets/icons/chakra.png
	scroll = 0, -- the Inventory tile; assets/icons/scroll.png
	book = 0, -- the Bingo Book tile; assets/icons/book.png
	meditate = 0, -- slot 1; assets/icons/meditate.png
	focus = 0, -- slot 2, Chakra Control; assets/icons/focus.png
}

-- Portraits of shinobi by character id (Config/Characters), for cards and quick slots. A
-- character without one gets the drawn stand-in in its rank's color.
Art.portraits = {} :: { [string]: number }

return Art
