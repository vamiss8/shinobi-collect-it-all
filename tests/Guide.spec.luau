--!strict
-- The guide (Config/Guide) and the daily rewards (Config/Daily, Logic/Daily): every step and
-- tip has its words, points at something the guide can find, and the week of rewards goes
-- round as it should.
local Catalog = require("../src/shared/Config/Catalog")
local Daily = require("../src/shared/Logic/Daily")
local Days = require("../src/shared/Config/Daily")
local Guide = require("../src/shared/Config/Guide")
local Saves = require("../src/shared/Logic/Saves")
local T = require("./harness")

local English = require("../src/client/Lang/en")

-- What an arrow can point at: a part of the interface named by Ui.target, or a place.
local POINTABLE: { [string]: boolean } = {
	slot1 = true,
	slider = true,
	pad = true,
	slot2 = true,
	ryo = true,
	chakra = true,
	herbsChip = true,
	inventory = true,
	book = true,
	shop = true,
	awards = true,
	rebirth = true,
	settings = true,
	daily = true,
	strip = true,
	dojo = true,
	gift = true,
	board = true,
	tenten = true,
	sell = true,
	speed = true,
	herbs = true,
}

local WAITS: { [string]: boolean } = {
	chakra = true,
	aim = true,
	throw = true,
	home = true,
	place = true,
	slider = true,
	sliderShut = true,
	near = true,
	window = true,
}

local DAY = 86400

return {
	["every step and tip has words and points at what can be found"] = function()
		local seen: { [string]: boolean } = {}
		for _, step in Guide.steps do
			T.ok(not seen[step.id], `step {step.id} is twice`)
			seen[step.id] = true
			T.ok(English.text["Guide_" .. step.id] ~= nil, `no words for step {step.id}`)
			local wait = step.wait
			if wait then
				T.ok(WAITS[wait], `step {step.id} waits on {wait}, which nothing tells`)
			end
			if wait == "window" then
				T.ok(step.window ~= nil, `step {step.id} waits on a window it does not name`)
			end
			if wait == "near" then
				T.ok(step.point ~= nil and #step.point >= 1, `step {step.id} waits near nothing`)
			end
			for _, name in step.point or {} do
				T.ok(POINTABLE[name], `step {step.id} points at {name}`)
			end
		end
		T.eq(Guide.DONE, #Guide.steps)
		for _, key in { "GuideName", "GuideNext", "GuideOk", "GuideFinish", "GuideSkip" } do
			T.ok(English.text[key] ~= nil, `no {key}`)
		end
		T.ok(English.text.Guide_caught ~= nil and English.text.Guide_groupServer ~= nil)
		T.ok(English.text.Guide_placeFull ~= nil, "no words for a dojo with every pad taken")
		local tips: { [string]: boolean } = {}
		for _, tip in Guide.tips do
			T.ok(not tips[tip.id], `tip {tip.id} is twice`)
			tips[tip.id] = true
			T.ok(English.text["Tip_" .. tip.id] ~= nil, `no words for tip {tip.id}`)
			for _, name in tip.point or {} do
				T.ok(POINTABLE[name], `tip {tip.id} points at {name}`)
			end
		end
	end,

	["a week of daily rewards: each day in a row the next, a missed day the first again"] = function()
		local kept = { last = 0, streak = 0 }
		local now = 20000 * DAY + 3600
		T.ok(Daily.ready(kept, now))
		T.eq(Daily.due(kept, now), 1)
		T.eq(Daily.claim(kept, now), 1)
		T.eq(Daily.claim(kept, now + 60), nil, "claimed twice in a day")
		T.ok(not Daily.ready(kept, now))
		T.eq(Daily.wait(kept, now), DAY - 3600)
		for day = 2, #Days.days + 1 do
			now += DAY
			T.eq(Daily.claim(kept, now), (day - 1) % #Days.days + 1, `day {day}`)
		end
		T.eq(kept.streak, #Days.days + 1)
		now += 2 * DAY
		T.eq(Daily.due(kept, now), 1, "a missed day does not start the week over")
		T.eq(Daily.claim(kept, now), 1)
		T.eq(kept.streak, 1)
	end,

	["every daily reward gives something there is"] = function()
		for index, day in Days.days do
			local something = (day.herbs or 0) > 0
				or (day.ryoMinutes or 0) > 0
				or day.potion ~= nil
				or day.premium ~= nil
			T.ok(something, `day {index} gives nothing`)
			for _, potion in { day.potion, day.premium } do
				T.ok(potion == nil or Catalog.potionById[potion] ~= nil, `day {index}: {potion}`)
			end
		end
		T.eq(Daily.ryo(10, 0), 10 * Days.ryoFloor, "an empty dojo is not paid the floor")
		T.eq(Daily.ryo(10, 100), 60000)
	end,

	["a save that has thrown before the tutorial has it done"] = function()
		local played = { version = 4, speedLevel = 0, spins = 30, guide = 0, tips = {} }
		Saves.bring(played)
		T.eq(played.guide, Guide.DONE)
		T.ok(played.tips.mutation, "a tester is told what a mutation is")
		T.ok(not played.tips.daily, "a tester is not told of the daily rewards")
		local fresh = { version = 0, speedLevel = 0, spins = 0, guide = 0 }
		Saves.bring(fresh)
		T.eq(fresh.guide, 0, "a new player skips the tutorial")
		-- The tutorial was rebuilt: the first one done counts as the new one done, and one half
		-- way through the first starts the new one over.
		local first = { version = 5, speedLevel = 0, spins = 0, guide = Guide.FIRST_DONE }
		Saves.bring(first)
		T.eq(first.guide, Guide.DONE)
		local halfway = { version = 5, speedLevel = 0, spins = 0, guide = 6 }
		Saves.bring(halfway)
		T.eq(halfway.guide, 0)
	end,
}
