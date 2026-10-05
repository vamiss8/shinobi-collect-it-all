--!strict
-- Chakra control, the active way to train: a ring closes in on a fixed target ring and the
-- player presses as the two meet. The closer the press, the more reps it pays. How fast the
-- ring closes and where the target sits change every round.

local Tuning = require("../Config/Tuning")

local Focus = {}

-- One ring: how long it takes to close, and when in that time it meets the target.
export type Round = {
	period: number, -- seconds
	target: number, -- 0..1 of the period
}

export type Hit = {
	grade: string, -- "Perfect" | "Great" | "Good" | "Miss"
	reps: number, -- how many reps' worth of Chakra the press pays
}

-- Draws a round from two random numbers in [0, 1).
function Focus.round(speedRoll: number, targetRoll: number): Round
	local t = Tuning.Training
	return {
		period = t.ringPeriodMin + (t.ringPeriodMax - t.ringPeriodMin) * speedRoll,
		target = t.ringTargetMin + (t.ringTargetMax - t.ringTargetMin) * targetRoll,
	}
end

-- How far the ring has closed `elapsed` seconds after it started: 0 is wide open, 1 fully
-- closed. A ring nobody pressed starts over.
function Focus.phase(elapsed: number, period: number): number
	return (elapsed % period) / period
end

-- Grades a press made at the given phase by how far it is from the moment the rings meet.
function Focus.grade(phase: number, target: number): Hit
	local off = math.abs(phase - target)
	for _, grade in Tuning.Training.ringGrades do
		if off <= grade.within then
			return { grade = grade.id, reps = grade.reps }
		end
	end
	return { grade = "Miss", reps = 0 }
end

-- What a perfect press pays, in reps.
function Focus.bestReps(): number
	return Tuning.Training.ringGrades[1].reps
end

return Focus
