--!strict
-- What the owner gives without Robux, by Roblox user id: legendary shinobi (Services/Legends)
-- and passes (Services/Purchases). A player listed here is given each named for them when
-- their save loads, if the save has it not yet, just as a player who bought it is: so the gift
-- reaches them the next time they join, on any server running a build that has their line.
-- Like a purchase it is for good: the save is what says it is owned, and taking a line out
-- later takes nothing back.

-- Roblox user ids, the number in the address of a profile page: roblox.com/users/<id>/profile.
-- The shinobi by their ids in Config/Legends (tsunade, tobirama, hagoromo); the passes by their
-- keys in Config/Products (Vip, DoubleRyo, DoubleChakra, DoubleLuck, DoubleMutationLuck,
-- ExtraPads).
local Gifts: { [number]: { string } } = {
	-- dixtyne: Tsunade on 2026-10-17, +4 Pads on 2026-10-18
	[3736221745] = { "tsunade", "ExtraPads" },
	-- whydalmjun: Tsunade and +4 Pads on 2026-10-18
	[9144243296] = { "tsunade", "ExtraPads" },
}

return Gifts
