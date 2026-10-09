--!strict
-- The hour on the village's clock, as this client reckons it: from the moment the server says
-- the day began (an attribute of the Hub folder) and the clock every client shares with the
-- server. So all players see the same hour without a word being sent.
--
-- The clock can be HELD at an hour (an event does it, through client Mood: the festival is an
-- evening and the red moon a night, whatever the village's own hour). It is not put there at a
-- stroke: the hands turn to the held hour over a few seconds, and turn back to the village's
-- own hour as slowly when they are let go. They turn forward, as time goes, so that night
-- falls and morning comes the way they do: the sun sets in the west. Only when that would be
-- most of a day round are they turned back instead. The sky, the light and the lanterns all
-- ask here, so they turn together.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Daylight = require(ReplicatedStorage.Shared.Logic.Daylight)
local Looks = require(ReplicatedStorage.Shared.Config.ZoneArt)
local Net = require(ReplicatedStorage.Shared.Net)

local Daytime = {}

-- How long the hands take to turn to an hour they are to be held at, and back, seconds, when
-- whoever holds them names no time of their own.
local TURN_SECONDS = 4
-- The hands are turned forward to an hour up to this many hours on; farther than that, back.
local FORWARD_MOST = 18

-- The hour the clock is held at, if it is; when it was last taken hold of or let go; the hour
-- and the grip that turn set out from; and how many hours it was to turn through, forward
-- when positive.
local heldAt: number? = nil
local turnedAt = -math.huge
local hourFrom = 0
local gripFrom = 0
local hoursRound = 0
-- How long the turn that is under way takes, seconds.
local turnSeconds = TURN_SECONDS

-- How far through the turn the hands are, eased, 0..1.
local function turned(): number
	local t = math.clamp((os.clock() - turnedAt) / turnSeconds, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The village's own hour, 0..24. Until the server's world is there it is the hour a day
-- begins at.
local function own(): number
	local hub = Workspace:FindFirstChild(Net.HUB_FOLDER)
	if not hub then
		return Looks.daytime.begins
	end
	-- An hour put on the folder by hand, in a Studio test, stops the clock there.
	local stopped = hub:GetAttribute(Net.HOUR_ATTRIBUTE)
	if typeof(stopped) == "number" then
		return stopped % 24
	end
	local began = hub:GetAttribute(Net.DAY_ATTRIBUTE)
	if typeof(began) ~= "number" then
		return Looks.daytime.begins
	end
	return Daylight.clock(math.max(Workspace:GetServerTimeNow() - began, 0))
end

-- The hour the village is seen at, 0..24: its own, or the one it is held at, or on the way
-- between the two.
function Daytime.clock(): number
	local goal = heldAt or own()
	local share = turned()
	if share >= 1 then
		return goal
	end
	-- The way round was chosen when the turn began; the village's own hour has moved on a
	-- little since, and the turn ends where it is now.
	local on = hoursRound + Daylight.onward((hourFrom + hoursRound) % 24, goal)
	return (hourFrom + on * share) % 24
end

-- How firmly the clock is held, 0..1: 1 once the hands have reached the held hour, 0 once they
-- are back at the village's own. Whatever else an hour is held with (its light: client Mood) is
-- mixed in by this.
function Daytime.grip(): number
	local goal = if heldAt then 1 else 0
	return gripFrom + (goal - gripFrom) * turned()
end

-- Whether the hands are on their way to a held hour or back from one.
function Daytime.turning(): boolean
	return os.clock() - turnedAt < turnSeconds
end

-- Holds the clock at `hour`, or with nil lets it go. The hands set out from where they are and
-- take `seconds` over the turn, or the usual time.
function Daytime.hold(hour: number?, seconds: number?)
	if hour == heldAt then
		return
	end
	hourFrom = Daytime.clock()
	gripFrom = Daytime.grip()
	heldAt = hour
	turnedAt = os.clock()
	turnSeconds = seconds or TURN_SECONDS
	local forward = ((hour or own()) - hourFrom) % 24
	hoursRound = if forward > FORWARD_MOST then forward - 24 else forward
end

return Daytime
