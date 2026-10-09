--!strict
-- Which event runs at a given moment (Config/Events). The schedule is a matter of the clock
-- alone: time since 1970 is cut into slots, a slot's number is ground into a number between 0
-- and 1, and that number says whether the slot has an event and which, by the events' weights.
-- Nothing is remembered and nothing is sent between servers, and all of them agree.

local Config = require("../Config/Events")

local Events = {}

export type Event = Config.Event

-- An event that is running: which, and when it began and ends, in seconds since 1970.
export type Running = {
	event: Event,
	began: number,
	ends: number,
}

local SLOT = Config.slotMinutes * 60
-- The multiplier and modulus of the "minimal standard" generator: small enough for every
-- product to be exact in a number, so that all machines get the same answer.
local MULTIPLIER = 48271
local MODULUS = 2147483647

Events.list = Config.list
Events.byId = {} :: { [string]: Event }
for _, event in Config.list do
	Events.byId[event.id] = event
end

-- The length of a slot, seconds.
function Events.slot(): number
	return SLOT
end

-- A number in [0, 1) that is a slot's own: the same for that slot wherever it is asked for,
-- and as good as unrelated to its neighbors'.
function Events.dice(slot: number): number
	local x = slot % (MODULUS - 1) + 1
	for _ = 1, 3 do
		x = x * MULTIPLIER % MODULUS
	end
	return x / MODULUS
end

-- The event the slot of that number has, if it has one.
function Events.inSlot(slot: number): Event?
	local total = Config.quiet
	for _, event in Config.list do
		total += event.weight
	end
	local at = Events.dice(slot) * total
	for _, event in Config.list do
		if at < event.weight then
			return event
		end
		at -= event.weight
	end
	return nil
end

-- The event running at `time`, seconds since 1970; nil between events.
function Events.at(time: number): Running?
	local slot = math.floor(time / SLOT)
	local event = Events.inSlot(slot)
	local began = slot * SLOT
	if event and time < began + event.minutes * 60 then
		return { event = event, began = began, ends = began + event.minutes * 60 }
	end
	return nil
end

-- The next event to begin after `time`, however far off; nil only if none of the slots looked
-- at has one, which the weights make all but impossible.
function Events.after(time: number): Running?
	local slot = math.floor(time / SLOT)
	for ahead = 1, 500 do
		local event = Events.inSlot(slot + ahead)
		if event then
			local began = (slot + ahead) * SLOT
			return { event = event, began = began, ends = began + event.minutes * 60 }
		end
	end
	return nil
end

return Events
