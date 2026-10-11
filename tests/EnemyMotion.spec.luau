--!strict
local Animations = require("../src/shared/Config/Animations")
local EnemyMotion = require("../src/shared/Logic/EnemyMotion")
local T = require("./harness")
local Zones = require("../src/shared/Config/Zones")

local MOTIONS = { "walker", "snake", "giant", "crawler", "glider" }

return {
	["every zone's enemy has a way to move"] = function()
		for _, zone in Zones do
			local spec = Animations.enemies[zone.id]
			T.ok(spec ~= nil, `{zone.id} has an entry in Config/Animations`)
			T.ok(EnemyMotion.STRIDE[spec.motion] ~= nil, `{zone.id} moves in a known way`)
		end
	end,

	["no motion throws the body far from where it stands"] = function()
		for _, motion in MOTIONS do
			for i = 0, 200 do
				for _, moving in { true, false } do
					local pose = EnemyMotion.pose(motion :: any, i * 0.37, i * 0.05, moving)
					local where = `{motion} at step {i}`
					T.ok(pose.lift >= -0.2 and pose.lift <= 1, `{where} lift`)
					T.ok(math.abs(pose.side) <= 1.5, `{where} side`)
					T.ok(math.abs(pose.pitch) <= 0.4, `{where} pitch`)
					T.ok(math.abs(pose.roll) <= 0.2, `{where} roll`)
					T.ok(math.abs(pose.yaw) <= 0.4, `{where} yaw`)
				end
			end
		end
	end,

	["a runner's feet come back to the ground on every step"] = function()
		local stride = EnemyMotion.STRIDE.walker
		for step = 0, 6 do
			local pose = EnemyMotion.pose("walker", step * stride / 2, 0, true)
			T.near(pose.lift, 0, 1e-9, `step {step} lands`)
		end
		local mid = EnemyMotion.pose("walker", stride / 4, 0, true)
		T.ok(mid.lift > 0.2, "and is off it between steps")
	end,

	["a slow enemy steps with the ground, a fast one no faster than it can"] = function()
		for _, motion in MOTIONS do
			local stride = EnemyMotion.STRIDE[motion :: any]
			local cadence = EnemyMotion.CADENCE[motion :: any]
			T.ok(cadence ~= nil and cadence > 0 and cadence <= 3, `{motion} has a fastest pace`)
			-- The lane's fastest enemy for a second, a frame at a time.
			local counted = 0
			for _ = 1, 60 do
				counted += EnemyMotion.paced(motion :: any, 85 / 60, 1 / 60)
			end
			T.near(counted / stride, cadence, 1e-6, `{motion} at full speed`)
			T.near(EnemyMotion.paced(motion :: any, 0.01, 1 / 60), 0.01, 1e-12, `{motion} slow`)
		end
	end,

	["the snake winds from side to side as it goes"] = function()
		local stride = EnemyMotion.STRIDE.snake
		local left = EnemyMotion.pose("snake", stride / 4, 0, true)
		local right = EnemyMotion.pose("snake", stride * 3 / 4, 0, true)
		T.ok(left.side > 0.5 and right.side < -0.5, "swings both ways")
	end,

	["a bigger enemy moves in bigger steps"] = function()
		local small = EnemyMotion.pose("giant", 3, 0, true, EnemyMotion.HEIGHT)
		local big = EnemyMotion.pose("giant", 3, 0, true, EnemyMotion.HEIGHT * 2)
		T.near(big.lift, small.lift * 2, 1e-9)
		T.near(big.roll, small.roll, 1e-9, "angles stay the same")
	end,

	["a catch lunges forward and comes to rest"] = function()
		local early = EnemyMotion.lunge(0)
		local peak = EnemyMotion.lunge(EnemyMotion.CATCH_SECONDS / 3)
		local late = EnemyMotion.lunge(EnemyMotion.CATCH_SECONDS)
		T.near(early.forward, 0, 1e-9)
		T.ok(peak.forward > 2, "throws itself forward")
		T.ok(late.forward > 1 and late.forward < peak.forward, "and settles a little back")
	end,

	["an empty id is no animation, a bare number becomes an asset id"] = function()
		T.eq(Animations.asset(""), nil)
		T.eq(Animations.asset(nil), nil)
		T.eq(Animations.asset("123"), "rbxassetid://123")
		T.eq(Animations.asset("rbxassetid://9"), "rbxassetid://9")
	end,
}
