--!strict
-- THE PROMO CODES (Logic/Codes for the rules, Services/Codes for the redeeming). They are kept
-- here, on the server, which no client can read: a code in ReplicatedStorage would be in the
-- hands of anybody who looked, and the codes are meant for those who join the community
-- server.
--
-- TO ADD A CODE: a line here, written in capitals (letters and digits), and publish. What it
-- may give, all of it optional:
--   herbs = 200                      Herbs
--   ryoMinutes = 15                  minutes of the dojo's income in Ryo (at least 50 a minute)
--   potions = { "gama_charm" }       potions of the kind bought for Herbs, 5 minutes each
--   premium = { "ichiraku_ramen" }   premium potions, 15 minutes each
--   ends = "2026-12-31"              its last day, UTC; none: it never ends
--   uses = 50                        how many players in all may redeem it, over every
--                                    server, the first to come (a giveaway); none: no limit
-- Potion ids: soldier_pill (x2 Chakra), ichiraku_ramen (x2 Ryo), gama_charm (x2 luck),
-- sage_oil (x2 mutation luck). A player redeems each code once. A code taken out of here
-- stops working; one that a player has had stays had (Data.codes), so a name is not to be
-- used again for a new code.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodeRules = require(ReplicatedStorage.Shared.Logic.Codes)

local Codes: { [string]: CodeRules.Code } = {
	-- For those who join the community server (owner, 2026-10-20). Mine as a start: the name
	-- and what it gives are the owner's to change.
	HIDDENLEAF = { herbs = 200, ryoMinutes = 15, premium = { "ichiraku_ramen" } },
}

return Codes
