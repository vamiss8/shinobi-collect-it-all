--!strict
-- The leaderboards on the plaza (Services/Leaderboards): how a player's Ryo or Chakra is kept
-- in a Roblox OrderedDataStore, and which of what it gives back are shown.
--
-- An OrderedDataStore keeps whole numbers of 64 bits only, and Ryo runs past 1e18 in the last
-- zones. So what is kept is the number's logarithm, scaled to a whole number: it orders the
-- same way, and the board shows it again to more places than Format.short writes.

local Leaders = {}

-- log10(1 + value) is kept times this. A value of 1e30 is kept as about 3e13, well inside
-- what a double holds exactly (2^53) and what the store takes (2^63).
Leaders.SCALE = 1e12
-- Past this a value is kept as this: an infinity would not be a number to the store.
Leaders.LARGEST = 1e300
-- How many players a board names.
Leaders.SHOWN = 10

export type Entry = { userId: number, value: number }

-- What is kept for a value: a whole number that orders as the value does, 0 for nothing.
function Leaders.encode(value: number): number
	if value ~= value or value <= 0 then
		return 0
	end
	return math.floor(math.log10(1 + math.min(value, Leaders.LARGEST)) * Leaders.SCALE)
end

-- The value a kept number stands for.
function Leaders.decode(kept: number): number
	if kept ~= kept or kept <= 0 then
		return 0
	end
	return 10 ^ (kept / Leaders.SCALE) - 1
end

-- The board's lines from the store's best first, as { key = user id as text, value = kept }:
-- the players to be left off left off (the owner: "me, of course, not on them"), nothing that
-- is not a player's id or that is worth nothing, at most `count` of them.
function Leaders.ranked(
	entries: { { key: string, value: number } },
	left: { [number]: boolean },
	count: number
): { Entry }
	local shown: { Entry } = {}
	for _, entry in entries do
		local userId = tonumber(entry.key)
		if userId and userId > 0 and not left[userId] and entry.value > 0 then
			table.insert(shown, { userId = userId, value = Leaders.decode(entry.value) })
			if #shown >= count then
				break
			end
		end
	end
	return shown
end

return Leaders
