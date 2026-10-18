--!strict
-- Keeps saves in step with the rules. A save carries the number of the rules it was written
-- under, and one written under older rules is brought up to today's when it is loaded, a step
-- at a time. (Characters that leave the roster are Logic/Roster's business.)

local Guide = require("../Config/Guide")
local Rebirth = require("./Rebirth")

local Saves = {}

-- The rules a save is written under today.
Saves.VERSION = 6

-- The fields of a save that the steps below touch.
export type Save = {
	version: number, -- 0 for a save from before the rules were numbered, and for a new one
	speedLevel: number,
	rebirths: number?,
	stock: { [string]: number }?,
	premium: { [string]: number }?,
	spins: number?,
	guide: number?,
	tips: { [string]: boolean }?,
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
	-- 2: a rebirth takes shinobi, Ryo and run speed with the Chakra, where for its first day
	-- it took the Chakra alone. Rebirths done under the old rule cost next to nothing, so
	-- they are taken back: everyone starts the ladder from its foot.
	if save.version < 2 then
		save.rebirths = 0
		save.version = 2
	end
	-- 3: a rank starts with run speed of its own (Config/Rebirths `startSpeed`), which a
	-- rebirth leaves its player with from now on. Those who hold a rank already are given
	-- the same, so that nobody is slower than their rank starts.
	if save.version < 3 then
		save.speedLevel = math.max(save.speedLevel, Rebirth.startSpeed(save.rebirths))
		save.version = 3
	end
	-- 4: a potion bought for Robux is premium and runs 15 minutes, one bought for Herbs 5
	-- (Config/Potions). Every potion in a pouch before then was bought to run 15 minutes,
	-- whatever it was paid with, so all of them are premium.
	if save.version < 4 then
		local stock, premium = save.stock, save.premium
		if stock and premium then
			for potionId, count in stock do
				premium[potionId] = (premium[potionId] or 0) + count
			end
			table.clear(stock)
		end
		save.version = 4
	end
	-- 5: the base tutorial (Config/Guide) is for those who have not played; a save that has
	-- thrown before it existed has it done, and has heard the tips about what it knows: all
	-- but those about what is new to everyone (Config/Guide `everyone`), lest a tester be met
	-- by a string of them on coming in.
	if save.version < 5 then
		if (save.spins or 0) > 0 then
			save.guide = Guide.DONE
			local tips = save.tips or {}
			for _, tip in Guide.tips do
				if not tip.everyone then
					tips[tip.id] = true
				end
			end
			save.tips = tips
		end
		save.version = 5
	end
	-- 6: the base tutorial was rebuilt (21 steps where there were 14): one who had played,
	-- or had done the first, has the new one done and the tips about what they know heard
	-- (some tips are new); one half way through the first starts the new one from its first
	-- step, the places of the steps having changed.
	if save.version < 6 then
		if (save.spins or 0) > 0 or (save.guide or 0) >= Guide.FIRST_DONE then
			save.guide = Guide.DONE
			local tips = save.tips or {}
			for _, tip in Guide.tips do
				if not tip.everyone then
					tips[tip.id] = true
				end
			end
			save.tips = tips
		else
			save.guide = 0
		end
		save.version = 6
	end
	return save.version ~= from
end

return Saves
