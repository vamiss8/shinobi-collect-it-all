--!strict
-- How a zone's enemy moves by code while it has no animations of its own (Config/Animations).
-- An enemy's model is one rigid piece, so its whole body is moved about its feet: lifted on
-- every step, leant forward into the run, rocked from side to side, swung, and for the snake
-- swept from side to side as it winds forward. Its steps keep time with the ground it covers,
-- so a faster enemy steps faster, up to the fastest it can step (CADENCE).
--
-- Pure numbers, so the specs can check it; Services/EnemyMoves turns a pose into a CFrame.

local Animations = require("../Config/Animations")

export type Motion = Animations.Motion

-- An offset of the body from where it stands, in its own frame: `lift` up, `side` to its right
-- and `forward` ahead of it, in studs; `pitch` leans it forward, `roll` tips it onto its right
-- side and `yaw` turns it to its left, in radians. Measured on an enemy of standard height and
-- scaled with it.
export type Pose = {
	lift: number,
	side: number,
	forward: number,
	pitch: number,
	roll: number,
	yaw: number,
}

local EnemyMotion = {}

-- The height the amplitudes below are measured on, studs (View/Figure's enemy height).
EnemyMotion.HEIGHT = 9.3

-- Ground covered in one full cycle of each motion: two steps, or one wave of the snake, studs.
EnemyMotion.STRIDE = {
	walker = 6,
	snake = 10,
	giant = 12,
	crawler = 4,
	glider = 8,
} :: { [Motion]: number }

-- The fastest each of them steps, full cycles a second. The strides above were measured for
-- enemies that cover 15 to 50 studs a second; on the lane they cover 21 to 85 (Chase.onLane),
-- and a body nine studs tall that bounced once for every three studs of that would shake, not
-- run. Past this pace an enemy's stride grows with its speed instead, as a runner's does.
EnemyMotion.CADENCE = {
	walker = 2,
	snake = 1.4,
	giant = 1.2,
	crawler = 2.6,
	glider = 1,
} :: { [Motion]: number }

-- How long the lunge of a catch lasts, seconds.
EnemyMotion.CATCH_SECONDS = 0.6

local TAU = 2 * math.pi

local function still(): Pose
	return { lift = 0, side = 0, forward = 0, pitch = 0, roll = 0, yaw = 0 }
end

local function scaled(pose: Pose, scale: number): Pose
	pose.lift *= scale
	pose.side *= scale
	pose.forward *= scale
	return pose
end

-- The ground an enemy's steps count for when it has covered `distance` studs in `dt` seconds:
-- all of it at a pace it can step at, and no more than its fastest pace covers in that time.
-- What this adds up to is the `travelled` a pose is asked for.
function EnemyMotion.paced(motion: Motion, distance: number, dt: number): number
	local most = (EnemyMotion.STRIDE[motion] or 6) * (EnemyMotion.CADENCE[motion] or 2) * dt
	return math.min(distance, most)
end

-- The pose of an enemy that has covered `travelled` studs so far and has been about for `time`
-- seconds; `moving` says whether it is chasing or standing. `height` is the enemy's own.
function EnemyMotion.pose(
	motion: Motion,
	travelled: number,
	time: number,
	moving: boolean,
	height: number?
): Pose
	local pose = still()
	local stride = EnemyMotion.STRIDE[motion] or 6
	local phase = travelled / stride * TAU
	-- One bounce for each step: twice a cycle.
	local step = math.abs(math.sin(phase))

	if motion == "walker" then
		if moving then
			pose.lift = 0.35 * step
			pose.pitch = 0.14
			pose.roll = 0.05 * math.sin(phase)
			pose.yaw = 0.05 * math.sin(phase)
		else
			-- Breathing.
			pose.lift = 0.04 * math.sin(time * 2)
		end
	elseif motion == "snake" then
		if moving then
			-- Winds from side to side, its body turned along the way it is heading.
			pose.side = 1.1 * math.sin(phase)
			pose.yaw = -0.35 * math.cos(phase)
			pose.lift = 0.08 * step
		else
			-- Reared up, swaying and watching.
			pose.pitch = -0.06
			pose.yaw = 0.15 * math.sin(time * 1.5)
			pose.lift = 0.1 * math.sin(time * 3)
		end
	elseif motion == "giant" then
		if moving then
			-- Heavy steps: a high lift that comes down hard, and a waddle from foot to foot.
			pose.lift = 0.6 * math.sqrt(step)
			pose.roll = 0.1 * math.sin(phase)
			pose.yaw = 0.06 * math.sin(phase)
			pose.pitch = 0.06
		else
			pose.lift = 0.08 * math.sin(time * 1.2)
			pose.roll = 0.02 * math.sin(time * 0.6)
		end
	elseif motion == "crawler" then
		if moving then
			-- Low and jerky: hunched forward, scuttling with quick twitches.
			pose.lift = 0.15 * step
			pose.pitch = 0.18 + 0.06 * math.sin(2 * phase)
			pose.side = 0.15 * math.sin(2 * phase)
			pose.yaw = 0.08 * math.sin(phase)
		else
			pose.pitch = 0.1
			pose.lift = 0.03 * math.sin(time * 4)
		end
	elseif motion == "glider" then
		-- Never steps: it rides the air over a stud off the ground, rising and sinking as it
		-- breathes. In the chase it lies forward into its flight and banks from side to side;
		-- standing, it leans back a little and looks about. (It first hung half a stud up and
		-- moved a hand's breadth, which on a body nine studs tall was seen as nothing at all:
		-- the owner, "every enemy's animation works but Pain's".)
		local breath = math.sin(time * 2.4)
		if moving then
			local bank = math.sin(time * 1.7)
			pose.lift = 1.4 + 0.3 * breath
			pose.pitch = 0.3
			pose.roll = 0.1 * bank
			pose.side = 0.4 * bank
		else
			pose.lift = 1.2 + 0.3 * breath
			pose.pitch = -0.05
			pose.yaw = 0.08 * math.sin(time * 1.1)
		end
	end

	return scaled(pose, (height or EnemyMotion.HEIGHT) / EnemyMotion.HEIGHT)
end

-- The lunge of a catch, `since` seconds into it: the body throws itself forward and down.
function EnemyMotion.lunge(since: number, height: number?): Pose
	local pose = still()
	local t = math.clamp(since / EnemyMotion.CATCH_SECONDS, 0, 1)
	-- Fast out in the first third, held, then a little back.
	local out = if t < 1 / 3 then math.sin(t * 3 * math.pi / 2) else 1 - 0.2 * (t - 1 / 3) * 1.5
	pose.forward = 2.5 * out
	pose.pitch = 0.35 * out
	return scaled(pose, (height or EnemyMotion.HEIGHT) / EnemyMotion.HEIGHT)
end

return EnemyMotion
