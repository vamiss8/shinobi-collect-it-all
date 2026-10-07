--!strict
-- Keeps saves in step with the rules. A save carries the number of the rules it was written
-- under, and one written under older rules is brought up to today's when it is loaded, a step
-- at a time. (Characters that leave the roster are Logic/Roster's business.)

local Saves = {}

-- The rules a save is written under today.
Saves.VERSION = 1

-- The fields of a save that the steps below touch.
export type Save = {
	version: number, -- 0 for a save from before the rules were numbered, and for a new one
	speedLevel: number,
}

-- Brings a save up to today's rules, in place, and says whether anything had to be done.
function Saves.bring(save: Save): boolean
	local from = save.version
	-- 1: a level of run speed is one stud a second where it was two, and there are twice as
	-- many levels. A runner keeps the speed they paid for, at twice the level.
	if save.version < 1 then
		save.speedLevel *= 2
		save.version = 1
	end
	return save.version ~= from
end

return Saves
