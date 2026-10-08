--!strict
-- What a rank shows on its holder's character beyond the tag over their head: orbs of Chakra
-- that hang in a slow wheel behind their back, one more with every rank, as the Truth-Seeking
-- Orbs hang behind the Sage of Six Paths. Each client draws them for every player (client
-- RankOrbs); this says what there is to draw.
--
-- The higher the rank, the more there is: more orbs, larger, turning faster; from Sannin on
-- each leaves a tail of light; and the last rank's are the Sage's own, black.

local Rebirth = require("./Rebirth")

local RankLook = {}

-- The Sage of Six Paths has nine: no rank has more.
RankLook.MOST_ORBS = 9
-- From this many rebirths on an orb leaves a tail.
RankLook.TAILS_FROM = 7

export type Look = {
	orbs: number, -- how many
	size: number, -- how wide each is, studs
	color: string, -- the rank's own, hex: the orb's, or for a dark orb its tail's
	dark: boolean, -- black orbs, the last rank's
	tail: boolean,
	spin: number, -- how fast the wheel turns, degrees a second
}

-- The look of the rank a player holds after `count` rebirths; nil for one who has done none.
function RankLook.of(count: number?): Look?
	local done = Rebirth.done(count)
	if done <= 0 then
		return nil
	end
	return {
		orbs = math.min(done, RankLook.MOST_ORBS),
		size = 0.5 + 0.022 * done,
		color = Rebirth.color(done),
		dark = done >= Rebirth.count(),
		tail = done >= RankLook.TAILS_FROM,
		spin = 34 + 5 * done,
	}
end

return RankLook
