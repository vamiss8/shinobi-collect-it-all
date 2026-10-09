--!strict
-- The events (Config/Events) and the clock they go by (Logic/Events).
local Catalog = require("../src/shared/Config/Catalog")
local Config = require("../src/shared/Config/Events")
local Events = require("../src/shared/Logic/Events")
local Roll = require("../src/shared/Logic/Roll")
local T = require("./harness")

-- A slot of about now, to count from.
local NOW = 1_790_000_000
local FIRST = math.floor(NOW / Events.slot())
local MANY = 30000

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
