--!strict
local Daylight = require("../src/shared/Logic/Daylight")
local T = require("./harness")
local ZoneArt = require("../src/shared/Config/ZoneArt")

local EPS = 1e-9
local TIME = ZoneArt.daytime
local WHOLE = TIME.daylight + TIME.night

return {
	["a server's first day begins in the morning"] = function()
		T.near(Daylight.clock(0), TIME.begins, EPS)
		T.ok(TIME.begins > Daylight.SUNRISE and TIME.begins < 12, "not a morning hour")
		T.near(Daylight.clock(WHOLE), TIME.begins, EPS, "a day and a night later")
		T.near(Daylight.clock(7 * WHOLE), TIME.begins, 1e-6, "a week of them later")
	end,

	["the clock only goes forward, and never jumps"] = function()
		local previous = Daylight.clock(0)
		for second = 1, 2 * WHOLE do
			local now = Daylight.clock(second)
			T.ok(now >= 0 and now < 24, `the clock shows {now}`)
			local step = Daylight.onward(previous, now)
			T.ok(step > 0, `the clock ran back at {second} s`)
			T.ok(step < 0.06, `the clock jumped {step} hours at {second} s`)
			previous = now
		end
	end,

	["the sun is up for as long as the day is, and down for as long as the night"] = function()
		local up = 0
		for second = 0, WHOLE - 1 do
			local now = Daylight.clock(second + 0.5)
			if now >= Daylight.SUNRISE and now < Daylight.SUNSET then
				up += 1
			end
		end
		T.eq(up, TIME.daylight)
		T.ok(TIME.daylight > TIME.night, "the night is as long as the day")
		T.ok(TIME.night >= 120, "the night is over before it has been looked at")
	end,

	["the hours the light is known at come round the clock in order"] = function()
		local hours = ZoneArt.day
		T.eq(hours[1].clock, 0)
		T.eq(hours[#hours].clock, 24)
		T.ok(hours[1].light == hours[#hours].light, "midnight is two lights")
		for index = 2, #hours do
			T.ok(hours[index].clock > hours[index - 1].clock, `hour {index} is out of order`)
		end
		local morning = false
		for _, hour in hours do
			if hour.light == ZoneArt.home then
				morning = true
				T.near(
					hour.clock,
					TIME.begins,
					0.5,
					"the day does not begin by the morning's light"
				)
			end
		end
		T.ok(morning, "the village's morning is not among the hours")
	end,

	["at any hour the light is the mix of the two hours it stands between"] = function()
		local hours = ZoneArt.day
		for step = 0, 24 * 20 - 1 do
			local clock = step / 20
			local from, to, share = Daylight.mix(clock)
			T.ok(hours[from] ~= nil and hours[to] ~= nil, `no hours for {clock}`)
			T.eq(to, from + 1)
			T.ok(share >= 0 and share < 1, `share {share} at {clock}`)
			local mixed = hours[from].clock + (hours[to].clock - hours[from].clock) * share
			T.near(mixed, clock, 1e-9)
		end
		-- A clock past midnight is the same clock.
		local from, to, share = Daylight.mix(25.5)
		local again, also, same = Daylight.mix(1.5)
		T.eq(from, again)
		T.eq(to, also)
		T.near(share, same, EPS)
	end,

	["two hours are mixed the shorter way round the clock"] = function()
		T.near(Daylight.onward(23.5, 6.5), 7, EPS)
		T.near(Daylight.onward(6.5, 23.5), -7, EPS)
		T.near(Daylight.onward(8, 14), 6, EPS)
		T.near(Daylight.toward(23, 1, 0.5), 0, EPS, "through midnight, not through noon")
		T.near(Daylight.toward(1, 23, 0.5), 0, EPS)
		T.near(Daylight.toward(22, 2, 0.75), 1, EPS)
		T.near(Daylight.toward(8, 14, 0.5), 11, EPS)
		for _, pair in { { 3, 21 }, { 21, 3 }, { 0, 12 }, { 17.2, 5.6 } } do
			T.near(Daylight.toward(pair[1], pair[2], 0), pair[1], EPS)
			T.near(Daylight.toward(pair[1], pair[2], 1), pair[2], EPS)
		end
	end,

	["lanterns burn low by day and bright by night, and are never out"] = function()
		local low = ZoneArt.lanterns.low
		T.ok(low >= 0.2 and low <= 0.6, `by day a lantern burns at {low}`)
		T.near(Daylight.glow(12), low, EPS, "at noon")
		T.near(Daylight.glow(9), low, EPS, "in the morning, once it has died down")
		T.near(Daylight.glow(0), 1, EPS, "at midnight")
		T.near(Daylight.glow(22), 1, EPS)
		T.near(Daylight.glow(4), 1, EPS)
		local previous = Daylight.glow(0)
		for step = 1, 24 * 60 do
			local glow = Daylight.glow(step / 60)
			T.ok(glow >= low - EPS and glow <= 1 + EPS, `a lantern burns at {glow}`)
			T.ok(math.abs(glow - previous) < 0.02, `the lanterns jump at {step / 60}`)
			previous = glow
		end
	end,

	["lanterns are well alight by sunset and still burning at sunrise"] = function()
		local low = ZoneArt.lanterns.low
		local half = (1 + low) / 2
		T.ok(Daylight.glow(Daylight.SUNSET) >= half, "it is dark before the lanterns are lit")
		T.ok(Daylight.glow(Daylight.SUNRISE) >= half, "the lanterns are out before it is light")
		-- They come up through the evening and go down through the morning, and only then.
		local up, down = ZoneArt.lanterns.lightUp, ZoneArt.lanterns.dieDown
		T.ok(up[1] < Daylight.SUNSET and up[2] > Daylight.SUNSET, "the evening is not at sunset")
		T.ok(
			down[1] < Daylight.SUNRISE and down[2] > Daylight.SUNRISE,
			"the morning is not at sunrise"
		)
		for step = 0, 20 do
			local evening = up[1] + (up[2] - up[1]) * step / 20
			local morning = down[1] + (down[2] - down[1]) * step / 20
			T.ok(
				Daylight.glow(evening + 0.01) >= Daylight.glow(evening) - EPS,
				"dims in the evening"
			)
			T.ok(
				Daylight.glow(morning + 0.01) <= Daylight.glow(morning) + EPS,
				"flares in the morning"
			)
		end
	end,

	["a lantern's shade is at its darkest by day and its own color by night"] = function()
		T.near(Daylight.shade(ZoneArt.lanterns.low), 0, EPS)
		T.near(Daylight.shade(1), 1, EPS)
		T.ok(
			ZoneArt.lanterns.shade >= 0.3 and ZoneArt.lanterns.shade < 1,
			"a shade as dark as that is out"
		)
	end,
}
