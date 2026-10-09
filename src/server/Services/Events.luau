--!strict
-- Runs the events (Config/Events): keeps track of which one the clock has running
-- (Logic/Events), says so where every client can read it, and tells whoever asks, which is
-- the throw: a catch made during an event has a chance of the event's mutation.
--
-- What is running is two attributes of the Hub folder, the event's id and the moment it ends
-- by the clock all clients share with the server. A client draws everything else for itself
-- (client EventShow): the announcement, the sky, the timer.
--
-- A developer can start an event by hand (Services/DevConsole); it runs on this server alone
-- and the clock's own schedule takes over again when it ends.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Schedule = require(ReplicatedStorage.Shared.Logic.Events)

local Events = {}

-- How often the clock is looked at, seconds.
local CHECK_SECONDS = 1

local running: Schedule.Running? = nil
-- An event started by hand, which goes before the clock's until it ends.
local forced: Schedule.Running? = nil

-- The clock the events go by: seconds since 1970, the same on every server and, near enough,
-- on every client.
local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Puts what is running where the clients read it.
local function publish()
	local hub = Workspace:FindFirstChild(Net.HUB_FOLDER)
	if not hub then
		return
	end
	local current = running
	hub:SetAttribute(Net.EVENT_ATTRIBUTE, if current then current.event.id else nil)
	hub:SetAttribute(Net.EVENT_ENDS_ATTRIBUTE, if current then current.ends else nil)
end

local function check()
	local time = now()
	if forced and time >= forced.ends then
		forced = nil
	end
	local due = forced or Schedule.at(time)
	local was = running
	local same = (was == nil and due == nil)
		or (was ~= nil and due ~= nil and was.event == due.event and was.ends == due.ends)
	if not same then
		running = due
		publish()
	end
end

-- The id of the event running now, if one is: what a throw is rolled under.
function Events.current(): string?
	local current = running
	return if current and now() < current.ends then current.event.id else nil
end

-- Starts an event by hand for so many seconds, or with no id ends the one started by hand.
-- Says whether there is such an event.
function Events.force(id: string?, seconds: number?): boolean
	if not id then
		forced = nil
		check()
		return true
	end
	local event = Schedule.byId[id]
	if not event then
		return false
	end
	local began = now()
	forced = { event = event, began = began, ends = began + (seconds or event.minutes * 60) }
	check()
	return true
end

-- Call after Hub.start(): the Hub folder carries what is running.
function Events.start()
	check()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			check()
		end
	end)
end

return Events
