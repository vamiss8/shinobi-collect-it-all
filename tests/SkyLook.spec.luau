--!strict
-- The camera's look at the sky when an event begins (Logic/SkyLook): its timing and its way
-- round the player.
local SkyLook = require("../src/shared/Logic/SkyLook")
local T = require("./harness")

local FRAME = 1 / 60

local function stand(radius: number, height: number, angle: number): SkyLook.Stand
	return { radius = radius, height = height, angle = angle }
end

return {
	["the look begins and ends at the player's shoulder, with the eyes on the player"] = function()
		local fly, gaze = SkyLook.at(0)
		T.eq(fly, 0)
		T.eq(gaze, 0)
		fly, gaze = SkyLook.at(SkyLook.length())
		T.near(fly, 0, 1e-9)
		T.near(gaze, 0, 1e-9)
		T.ok(SkyLook.length() >= 5 and SkyLook.length() <= 7.5, `{SkyLook.length()} s long`)
	end,

	-- The owner's complaint was a camera that seemed to be teleported into the sky and back:
	-- nothing may jump from one frame to the next.
	["neither the flight nor the eyes ever jump"] = function()
		local lastFly, lastGaze = SkyLook.at(0)
		local time = FRAME
		while time <= SkyLook.length() do
			local fly, gaze = SkyLook.at(time)
			T.ok(math.abs(fly - lastFly) < 0.03, `the flight jumps at {time}`)
			T.ok(math.abs(gaze - lastGaze) < 0.03, `the eyes jump at {time}`)
			T.ok(fly >= 0 and fly <= 1 and gaze >= 0 and gaze <= 1, `out of range at {time}`)
			lastFly, lastGaze = fly, gaze
			time += FRAME
		end
	end,

	["the camera has left the player before its eyes leave them, and finds them again first"] = function()
		-- When the eyes begin to lift the camera is well on its way out.
		local fly = SkyLook.at(SkyLook.LIFT_AT)
		T.ok(fly > 0.5, `only {fly} of the way out when the eyes lift`)
		-- The eyes are still lifting when the flight out ends: no stop between the two.
		local _, gaze = SkyLook.at(SkyLook.OUT)
		T.ok(gaze > 0 and gaze < 1, `the eyes are at {gaze} when the climb ends`)
		-- At the top the eyes rest on the sky.
		fly, gaze = SkyLook.at(SkyLook.LIFT_AT + SkyLook.LIFT + SkyLook.REST / 2)
		T.eq(fly, 1)
		T.eq(gaze, 1)
		-- And on the way home they are back on the player before the camera is.
		local seen = false
		local time = 0
		while time <= SkyLook.length() do
			local flown, lifted = SkyLook.at(time)
			if time > SkyLook.OUT and lifted == 0 and flown > 0.2 then
				seen = true
			end
			time += FRAME
		end
		T.ok(seen, "the camera is home before its eyes are back on the player")
	end,

	["the flight goes from where the camera was to its peak and back the same way"] = function()
		local from = stand(11, 4, 0.4)
		local to = SkyLook.peak(from, 2.1, 1)
		local out = SkyLook.orbit(from, to, 0)
		T.near(out.radius, from.radius, 1e-9)
		T.near(out.height, from.height, 1e-9)
		T.near(out.angle, from.angle, 1e-9)
		out = SkyLook.orbit(from, to, 1)
		T.near(out.radius, SkyLook.AWAY, 1e-9)
		T.near(out.height, SkyLook.UP, 1e-9)
		T.near(out.angle, 2.1, 1e-9)
	end,

	-- A carried shinobi rides over the player's head.
	["the camera goes round the player and never over them"] = function()
		for _, radius in { 0.5, 6, 12.5, 40 } do
			for _, turn in { -3, -1.2, 0, 0.7, 3.1 } do
				local from = stand(radius, 3, 1)
				local to = SkyLook.peak(from, 1 + turn, 1)
				local last = from.radius
				for step = 0, 100 do
					local at = SkyLook.orbit(from, to, step / 100)
					T.ok(at.radius >= last - 1e-9, `the camera comes nearer at {step}`)
					T.ok(at.radius >= radius - 1e-9, "nearer than it set out")
					last = at.radius
				end
				T.ok(to.radius >= radius + SkyLook.LEAST - 1e-9, `{radius}: it hardly draws back`)
				T.ok(math.abs(to.angle - from.angle) <= math.pi + 1e-9, "the long way round")
			end
		end
	end,

	["it draws away before it climbs"] = function()
		local from = stand(12, 4, 0)
		local to = SkyLook.peak(from, 0, 1)
		local half = SkyLook.orbit(from, to, 0.5)
		local out = (half.radius - from.radius) / (to.radius - from.radius)
		local up = (half.height - from.height) / (to.height - from.height)
		T.ok(out > 0.55 and up < 0.4, `half way: {out} of the way out, {up} of the way up`)
	end,

	["in a narrow place it goes only as far as there is room"] = function()
		local from = stand(10, 3, 0)
		local to = SkyLook.peak(from, 0, 0.5)
		T.near(to.radius, 10 + (SkyLook.AWAY - 10) * 0.5, 1e-9)
		T.near(to.height, 3 + (SkyLook.UP - 3) * 0.5, 1e-9)
		local none = SkyLook.peak(from, 0, 0)
		T.near(none.radius, 10, 1e-9)
	end,
}
