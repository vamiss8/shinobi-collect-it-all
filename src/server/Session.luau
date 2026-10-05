--!strict
-- Per-player state that lives only while they are connected and is never saved.

local Session = {}

export type Session = {
	training: string?, -- "meditate" | "focus" while training with that tool
	held: string?, -- id of the unit being carried
	throwChakra: number, -- Chakra the player chose to throw with, 0 for all of it
	boost: number, -- training multiplier from the last popped bubble
	boostUntil: number, -- os.clock() time the boost runs out
	-- Ryo the dojo earned while the player was away before this visit. Already paid out;
	-- kept so that an offer to multiply it can be honored later in the session.
	offline: number,
}

local sessions: { [Player]: Session } = {}

function Session.of(player: Player): Session
	local session = sessions[player]
	if not session then
		session = { boost = 1, boostUntil = 0, throwChakra = 0, offline = 0 }
		sessions[player] = session
	end
	return session
end

-- Training multiplier in effect right now, 1 if no bubble boost is running.
function Session.boost(player: Player): number
	local session = sessions[player]
	if session and os.clock() < session.boostUntil then
		return session.boost
	end
	return 1
end

function Session.clear(player: Player)
	sessions[player] = nil
end

return Session
