--!strict
-- The events (Config/Events) and the clock they go by (Logic/Events).
local Catalog = require("../src/shared/Config/Catalog")
local Config = require("../src/shared/Config/Events")
local Daylight = require("../src/shared/Logic/Daylight")
local Events = require("../src/shared/Logic/Events")
local Roll = require("../src/shared/Logic/Roll")
local T = require("./harness")
local ZoneArt = require("../src/shared/Config/ZoneArt")

-- A slot of about now, to count from.
local NOW = 1_790_000_000
local FIRST = math.floor(NOW / Events.slot())
local MANY = 30000

-- How bright a hex color is, 0 for black to 1 for white.
local function brightness(hex: string): number
	local red = tonumber(string.sub(hex, 2, 3), 16) :: number
	local green = tonumber(string.sub(hex, 4, 5), 16) :: number
	local blue = tonumber(string.sub(hex, 6, 7), 16) :: number
	return (0.299 * red + 0.587 * green + 0.114 * blue) / 255
end

return {
	["a slot's dice is its own, the same wherever it is thrown, and fair"] = function()
		T.eq(Events.dice(FIRST), Events.dice(FIRST))
		local bins = table.create(10, 0)
		for slot = FIRST, FIRST + MANY - 1 do
			local dice = Events.dice(slot)
			T.ok(dice >= 0 and dice < 1, `slot {slot} threw {dice}`)
			bins[math.floor(dice * 10) + 1] += 1
		end
		for index, count in bins do
			local share = count / MANY
			T.ok(share > 0.085 and share < 0.115, `a tenth of the dice fell {share} in bin {index}`)
		end
	end,

	["over many slots each event comes as often as its weight says"] = function()
		local total = Config.quiet
		for _, event in Config.list do
			total += event.weight
		end
		local came: { [string]: number } = {}
		local none = 0
		for slot = FIRST, FIRST + MANY - 1 do
			local event = Events.inSlot(slot)
			if event then
				came[event.id] = (came[event.id] or 0) + 1
			else
				none += 1
			end
		end
		for _, event in Config.list do
			local share = (came[event.id] or 0) / MANY
			T.near(share, event.weight / total, 0.012, `{event.name} came {share} of the time`)
		end
		T.near(none / MANY, Config.quiet / total, 0.012, "slots with no event")
	end,

	["an event begins with its slot, lasts its minutes, and is over before the next slot"] = function()
		local seen = 0
		for slot = FIRST, FIRST + 400 do
			local event = Events.inSlot(slot)
			local began = slot * Events.slot()
			if event then
				seen += 1
				local long = event.minutes * 60
				local running = Events.at(began)
				T.ok(running ~= nil and running.event == event, `slot {slot} does not open with it`)
				T.eq((running :: Events.Running).began, began)
				T.eq((running :: Events.Running).ends, began + long)
				T.ok(Events.at(began + long - 1) ~= nil, "over a second early")
				T.eq(Events.at(began + long), nil, "still running when its minutes are up")
				T.eq(Events.at(began + Events.slot() - 1), nil, "running into the next slot")
			else
				T.eq(Events.at(began), nil, `slot {slot} has an event after all`)
			end
		end
		T.ok(seen > 200, `only {seen} slots of 400 had an event`)
	end,

	["the next event is found from any moment"] = function()
		for step = 0, 200 do
			local time = NOW + step * 173
			local following = Events.after(time)
			T.ok(following ~= nil, "no event to come")
			T.ok((following :: Events.Running).began > time, "the next event has already begun")
			T.ok((following :: Events.Running).began - time <= 12 * Events.slot(), "hours to wait")
		end
	end,

	-- The owner's rule: three events of different rarity, with mutations to match.
	["the rarer the event, the better the mutation it brings and the harder that is to get"] = function()
		local events = table.clone(Config.list)
		table.sort(events, function(a, b)
			return a.weight > b.weight
		end)
		T.eq(#events, 3)
		for index, event in events do
			local mutation = Catalog.mutationById[event.mutation]
			T.ok(mutation ~= nil and mutation.event == event.id, `{event.name} brings nothing`)
			local commoner = events[index - 1]
			if commoner then
				local before = Catalog.mutationById[commoner.mutation]
				T.ok(event.weight < commoner.weight, `{event.name} is no rarer`)
				T.ok(
					mutation.multiplier > before.multiplier,
					`{event.name}'s mutation pays no more`
				)
				T.ok(mutation.chance > before.chance, `{event.name}'s mutation is no harder to get`)
			end
		end
	end,

	-- "Not 100%": an event gives a chance of its mutation, and no other event's.
	["an event's mutation drops only during it, and far from every time"] = function()
		for _, event in Config.list do
			local during = Roll.mutationTable(event.id)
			local found = false
			for _, entry in during do
				local mutation = Catalog.mutationById[entry.id]
				if mutation and mutation.event then
					T.eq(mutation.event, event.id, `{entry.id} drops during {event.name}`)
					T.ok(entry.weight > 0 and entry.weight <= 0.1, `{entry.id}: {entry.weight}`)
					found = true
				end
			end
			T.ok(found, `{event.name}'s mutation is not in its table`)
		end
		for _, entry in Roll.mutationTable(nil) do
			local mutation = Catalog.mutationById[entry.id]
			T.ok(not (mutation and mutation.event), `{entry.id} drops with no event running`)
		end
	end,

	-- The owner's numbers of 2026-10-09: the festival every 25 to 30 minutes, the raid every
	-- hour, the moon every two.
	["the events come as often as the owner asked"] = function()
		local total = Config.quiet
		for _, event in Config.list do
			total += event.weight
		end
		local function every(id: string): number
			return Config.slotMinutes * total / Events.byId[id].weight
		end
		T.ok(every("leaf_festival") >= 25 and every("leaf_festival") <= 30, "the festival")
		T.near(every("akatsuki_raid"), 60, 3, "the raid")
		T.near(every("crimson_moon"), 120, 6, "the moon")
		for _, event in Config.list do
			T.ok(
				event.minutes <= Config.slotMinutes / 2,
				`{event.name} leaves no quiet before the next slot`
			)
		end
	end,

	["no event has blood in its name"] = function()
		for _, event in Config.list do
			T.ok(not string.find(string.lower(event.name), "blood"), event.name)
			T.ok(not string.find(event.id, "blood"), event.id)
		end
	end,

	-- "Let the beauty of an event not depend on the time of day": each holds the village in a
	-- light of its own, at an hour of its own, and none of the three is a dark one.
	["every event has a light of its own for the village, and it is not a dark one"] = function()
		local hours: { [number]: string } = {}
		for _, event in Config.list do
			local light = event.light
			T.ok(hours[light.clock] == nil, `{event.name} is held at {hours[light.clock]}'s hour`)
			hours[light.clock] = event.name
			T.ok(light.clock >= 0 and light.clock < 24, `{event.name}: hour {light.clock}`)
			T.ok(brightness(light.outdoor) >= 0.26, `{event.name}: outdoor ambient {light.outdoor}`)
			T.ok(brightness(light.ambient) >= 0.26, `{event.name}: indoor ambient {light.ambient}`)
			T.ok(light.brightness >= 1.5 and light.brightness <= 4, `{event.name} brightness`)
			for key, value in ZoneArt.hours.noon :: any do
				T.ok(
					typeof((light :: any)[key]) == typeof(value),
					`{event.name}'s light has no {key}`
				)
			end
		end
		-- The festival's lanterns are lit, the red moon has a night for its moon to be up in,
		-- and the raid's cloud has daylight to darken.
		T.ok(Daylight.glow(Events.byId.leaf_festival.light.clock) > 0.95, "the festival's lanterns")
		local moon = Events.byId.crimson_moon.light.clock
		T.ok(moon >= 21 or moon <= 3, `the moon is held at {moon}`)
		local raid = Events.byId.akatsuki_raid.light.clock
		T.ok(raid > 9 and raid < 16, `the raid is held at {raid}`)
		-- A red night, not a blue one: a red tint on blue is a dark violet.
		local night = Events.byId.crimson_moon.light.outdoor
		T.ok(
			(tonumber(string.sub(night, 2, 3), 16) :: number)
				> (tonumber(string.sub(night, 6, 7), 16) :: number) * 1.3,
			`the moon's night is {night}`
		)
	end,

	["no two events look alike"] = function()
		local shows: { [string]: string } = {}
		local colors: { [string]: string } = {}
		for _, event in Config.list do
			T.ok(shows[event.shows] == nil, `{event.name} hangs what {shows[event.shows]} does`)
			shows[event.shows] = event.name
			T.ok(colors[event.color] == nil, `{event.name} has {colors[event.color]}'s color`)
			colors[event.color] = event.name
			T.ok(event.sky.tint ~= "#FFFFFF", `{event.name} leaves the picture as it is`)
			T.ok(event.weather.rate > 0, `nothing falls during {event.name}`)
		end
	end,
}
