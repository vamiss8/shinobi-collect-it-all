--!strict
-- The marks a few players wear by their name, given by the owner, by Roblox user id: a pill in
-- the list of players in place of the VIP's gold, their name lettered over the head, and a tip
-- under the pointer saying what it is (client PlayerList, Services/Titles). Each is a key of
-- Config/Lettering `badges`. Who may use the developer console is server/Developers, not this.

local Badges: { [number]: string } = {
	[2893192350] = "founder", -- vamiss8: FOUNDER, violet with a band of light
	-- dixtyne: WHITE REAPER, white with a black band, exclusive (owner, 2026-10-18)
	[3736221745] = "reaper",
	[9144243296] = "dev", -- whydalmjun: DEV, red with a black band (owner, 2026-10-18)
	[11097160881] = "designer", -- miarmori8: DESIGNER, pink with a white band (owner, 2026-10-18)
}

return Badges
