--!strict
local Economy = require("../src/shared/Logic/Economy")
local Saves = require("../src/shared/Logic/Saves")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

return {
	["a save from before the rules were numbered keeps the run speed it paid for"] = function()
		-- A level was two studs a second then, and there were twenty of them.
		for _, level in { 0, 1, 7, 20 } do
			local save = { version = 0, speedLevel = level }
			T.eq(Saves.bring(save), true)
			T.eq(save.version, Saves.VERSION)
			T.eq(Economy.walkSpeed(save.speedLevel), Tuning.Speed.base + 2 * level, `level {level}`)
			T.ok(save.speedLevel <= Tuning.Speed.maxLevel, "more levels than there are")
		end
	end,

	["a new save is left as it was but for the number"] = function()
		local save = { version = 0, speedLevel = 0 }
		Saves.bring(save)
		T.eq(save.speedLevel, 0)
		T.eq(save.version, Saves.VERSION)
	end,

	["a save in step is not touched, however often it is loaded"] = function()
		local save = { version = 0, speedLevel = 6 }
		Saves.bring(save)
		T.eq(save.speedLevel, 12)
		T.eq(Saves.bring(save), false)
		T.eq(Saves.bring(save), false)
		T.eq(save.speedLevel, 12)
	end,
}
