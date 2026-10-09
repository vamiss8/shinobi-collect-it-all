--!strict
-- The camera's look at the sky when an event begins (client EventShow), as plain numbers: how
-- far along its flight the camera is at a moment, how far its eyes have lifted, and where on
-- its way round the player it then is.
--
-- The owner on the first one, which turned the camera up where it stood and back (2026-10-09):
-- "it looks as if we are simply teleported into the sky and then back. Let the camera really
-- fly off from the character, rise, and return. It needs a feeling of wholeness." So the
-- player stays in the picture while the camera leaves: it draws back from their shoulder
-- first and climbs after, watching them grow small, and only then lifts its eyes to the sky.
-- They rest there, come down on the player again, and the camera flies back in the way it
-- went. Nothing is cut and nothing stands still between: the eyes begin to lift before the
-- climb is over, and the flight home begins before they are all the way down.
--
-- The camera goes round the player, never over them: a shinobi they carry rides over their
-- head, and a camera's way must not cross it (client Cinematic learned that first).

local SkyLook = {}

-- Seconds. The flight out; when the eyes begin to lift, and how long that takes; how long
-- they rest on the sky; how long they take to come down; how long after they begin to that
-- the flight home begins, and how long it takes.
SkyLook.OUT = 1.9
SkyLook.LIFT_AT = 1.1
SkyLook.LIFT = 1.4
SkyLook.REST = 1.5
SkyLook.LOWER = 1.2
SkyLook.BACK_AFTER = 0.5
SkyLook.BACK = 1.7
-- Where the flight out ends: this far from the player, on the side away from what is looked
-- at, and this far over their middle, studs. A camera that was farther off or higher than
-- that to begin with still draws back and climbs by the least.
SkyLook.AWAY = 26
SkyLook.UP = 14
SkyLook.LEAST = 5
-- A look that is given up half way (the player has begun to aim) is flown home in this long.
SkyLook.HURRY = 0.6

-- Where the camera is about the player: studs out from them, studs over their middle, and the
-- compass angle it stands at, radians.
export type Stand = {
	radius: number,
	height: number,
	angle: number,
}

local LOWER_AT = SkyLook.LIFT_AT + SkyLook.LIFT + SkyLook.REST
local BACK_AT = LOWER_AT + SkyLook.BACK_AFTER

-- 0..1, slow at both ends.
function SkyLook.eased(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

-- How long the whole look takes, seconds.
function SkyLook.length(): number
	return math.max(BACK_AT + SkyLook.BACK, LOWER_AT + SkyLook.LOWER)
end

-- How far out along its flight the camera is `time` seconds into the look, and how far its
-- eyes have lifted from the player to the sky, each 0..1.
function SkyLook.at(time: number): (number, number)
	local fly: number
	if time < BACK_AT then
		fly = SkyLook.eased(time / SkyLook.OUT)
	else
		fly = 1 - SkyLook.eased((time - BACK_AT) / SkyLook.BACK)
	end
	local gaze: number
	if time < LOWER_AT then
		gaze = SkyLook.eased((time - SkyLook.LIFT_AT) / SkyLook.LIFT)
	else
		gaze = 1 - SkyLook.eased((time - LOWER_AT) / SkyLook.LOWER)
	end
	return fly, gaze
end

-- How far round one angle is from another, the shorter way: -pi..pi.
function SkyLook.turn(from: number, to: number): number
	return (to - from + math.pi) % (2 * math.pi) - math.pi
end

-- Where the flight out ends for a camera that sets out from `from`, on the side of the player
-- at `angle`. `room` is how much of the way there is free, 0..1: in a narrow place the camera
-- goes only so far.
function SkyLook.peak(from: Stand, angle: number, room: number): Stand
	local away = math.max(SkyLook.AWAY, from.radius + SkyLook.LEAST)
	local up = math.max(SkyLook.UP, from.height + SkyLook.LEAST)
	return {
		radius = from.radius + (away - from.radius) * room,
		height = from.height + (up - from.height) * room,
		angle = from.angle + SkyLook.turn(from.angle, angle),
	}
end

-- Where the camera is when it is `fly` of the way out from one stand to another. It draws
-- away first and climbs after, and swings round the player as it goes, the shorter way; it is
-- never nearer them than the nearer of the two stands.
function SkyLook.orbit(from: Stand, to: Stand, fly: number): Stand
	local share = math.clamp(fly, 0, 1)
	return {
		radius = from.radius + (to.radius - from.radius) * share ^ 0.7,
		height = from.height + (to.height - from.height) * share ^ 1.6,
		angle = from.angle + SkyLook.turn(from.angle, to.angle) * share,
	}
end

return SkyLook
