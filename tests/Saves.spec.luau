--!strict
local Economy = require("../src/shared/Logic/Economy")
local Rebirth = require("../src/shared/Logic/Rebirth")
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
		local save = { version = 0, speedLevel = 0, rebirths = 0 }
		Saves.bring(save)
		T.eq(save.speedLevel, 0)
		T.eq(save.rebirths, 0)
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

	-- Rebirths done while a rebirth took only Chakra are taken back, once.
	["rebirths done under the first rule are taken back, and later ones are kept"] = function()
		local save = { version = 1, speedLevel = 9, rebirths = 4 }
		T.eq(Saves.bring(save), true)
		T.eq(save.rebirths, 0)
		T.eq(save.speedLevel, 9, "the run speed is not doubled a second time")
		save.rebirths = 2
		T.eq(Saves.bring(save), false)
		T.eq(save.rebirths, 2)
	end,

	-- A rank starts with run speed of its own; whoever held a rank before that is given it.
	["a save of a rank is given the run speed its rank starts with, once, and never less than it had"] = function()
		local rank = Rebirth.count()
		local starts = Rebirth.startSpeed(rank)
		T.ok(starts > 0, "the last rank starts with no run speed")
		local slow = { version = 2, speedLevel = 0, rebirths = rank }
		T.eq(Saves.bring(slow), true)
		T.eq(slow.speedLevel, starts)
		local fast = { version = 2, speedLevel = starts + 3, rebirths = rank }
		Saves.bring(fast)
		T.eq(fast.speedLevel, starts + 3, "run speed that was paid for went")
		-- Brought once: what the save holds after that is the player's doing.
		slow.speedLevel = 0
		T.eq(Saves.bring(slow), false)
		T.eq(slow.speedLevel, 0)
	end,
}
