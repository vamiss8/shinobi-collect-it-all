--!strict
-- Legendary shinobi the owner gives without Robux, by Roblox user id (Services/Legends). A
-- player listed here is given each shinobi named for them when their save loads, if the save
-- has no such unit yet, just as the owner of the shinobi's pass is: so the gift reaches them
-- the next time they join, on any server running a build that has their line. Like a pass it
-- is for good: the unit in the save is what says it is owned, and taking a line out later
-- takes nothing back.

-- Roblox user ids, the number in the address of a profile page: roblox.com/users/<id>/profile.
-- The shinobi by their ids in Config/Legends: tsunade, tobirama, hagoromo.
local Gifts: { [number]: { string } } = {
	[3736221745] = { "tsunade" }, -- dixtyne, given by the owner on 2026-10-17
	[9144243296] = { "tsunade" }, -- whydalmjun, given by the owner on 2026-10-18
}

return Gifts
