--!strict
local Focus = require("../src/shared/Logic/Focus")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

local EPS = 1e-9
local training = Tuning.Training

return {
	["the ring closes over one period and starts over"] = function()
		T.near(Focus.phase(0, 2), 0, EPS)
		T.near(Focus.phase(1, 2), 0.5, EPS)
		T.near(Focus.phase(2, 2), 0, EPS, "a new ring begins")
		T.near(Focus.phase(3, 2), 0.5, EPS)
	end,

	["rounds stay inside the configured ranges"] = function()
		local slowest = Focus.round(0.999999, 0.999999)
		local fastest = Focus.round(0, 0)
		T.near(fastest.period, training.ringPeriodMin, EPS)
		T.near(fastest.target, training.ringTargetMin, EPS)
		T.ok(slowest.period < training.ringPeriodMax + EPS, "period above the maximum")
		T.ok(slowest.target < training.ringTargetMax + EPS, "target above the maximum")
	end,

	["no fixed beat scores twice in a row across different rounds"] = function()
		-- Pressing after the same number of seconds is Perfect in one round and a miss in
		-- another: that is what the randomness is for.
		local quick = Focus.round(0, 0)
		local slow = Focus.round(0.999999, 0.999999)
		local beat = quick.period * quick.target
		T.eq(Focus.grade(Focus.phase(beat, quick.period), quick.target).grade, "Perfect")
		T.eq(Focus.grade(Focus.phase(beat, slow.period), slow.target).grade, "Miss")
	end,

	["a press right on the target is Perfect"] = function()
		local hit = Focus.grade(0.7, 0.7)
		T.eq(hit.grade, "Perfect")
		T.eq(hit.reps, Focus.bestReps())
	end,

	["the farther off the press, the lower the grade"] = function()
		local target = 0.7
		local last = math.huge
		for _, grade in training.ringGrades do
			-- Just inside the window on either side of the target.
			local inside = grade.within * 0.99
			T.eq(Focus.grade(target - inside, target).grade, grade.id, "early")
			T.eq(Focus.grade(target + inside, target).grade, grade.id, "late")
			T.ok(grade.reps < last, `{grade.id} must pay less than the grade above it`)
			last = grade.reps
		end
	end,

	["a press outside every window is a miss and pays nothing"] = function()
		local widest = training.ringGrades[#training.ringGrades].within
		local hit = Focus.grade(0.7 - widest - 0.01, 0.7)
		T.eq(hit.grade, "Miss")
		T.eq(hit.reps, 0)
		T.eq(Focus.grade(0, 0.7).grade, "Miss", "pressing the moment the ring appears")
	end,

	["every window fits inside the period for any target"] = function()
		local widest = training.ringGrades[#training.ringGrades].within
		T.ok(training.ringTargetMax + widest < 1, "the late window runs past the end")
		T.ok(training.ringTargetMin - widest > 0, "the early window starts before the ring does")
	end,
}
