--!strict
-- The game's sounds and music (Config/Sounds): a track for every zone's boss and every event,
-- nothing for what is not there, and ids that are asset ids or 0.
local fs = require("@lune/fs")

local Catalog = require("../src/shared/Config/Catalog")
local EventsConfig = require("../src/shared/Config/Events")
local Sounds = require("../src/shared/Config/Sounds")
local T = require("./harness")

local function isId(id: number): boolean
	return id >= 0 and id == math.floor(id)
end

return {
	["every effect has an id, a sane volume and speed"] = function()
		local count = 0
		for cue, effect in Sounds.effects do
			count += 1
			T.ok(isId(effect.id), `{cue} has no asset id`)
			local volume = effect.volume or 0.5
			T.ok(volume > 0 and volume <= 1, `{cue} is too loud or silent`)
			local speed = effect.speed or 1
			T.ok(speed > 0.25 and speed < 4, `{cue} plays at a strange speed`)
			local lead = effect.lead or 0
			T.ok(lead >= 0 and lead < 2, `{cue} is started at a strange time before its moment`)
		end
		T.ok(count >= 20, "the effects are missing")
	end,

	-- A cue is a plain word where it is played (client Audio.play): every word played is one of
	-- Config/Sounds, or that moment would stay silent for good.
	["every sound the client plays is one of the config's"] = function()
		local count = 0
		local function look(path: string)
			for _, name in fs.readDir(path) do
				local full = path .. "/" .. name
				if fs.isDir(full) then
					look(full)
				elseif string.match(name, "%.luau$") then
					for cue in string.gmatch(fs.readFile(full), 'Audio%.play%(%s*"(%w+)"%s*%)') do
						count += 1
						T.ok(
							(Sounds.effects :: any)[cue] ~= nil,
							`{full} plays "{cue}", no such cue`
						)
					end
				end
			end
		end
		look("src/client")
		T.ok(count >= 20, `only {count} plays were found: the search is broken`)
	end,

	["every zone's boss and every event has a place for its track, and nothing else"] = function()
		for _, zone in Catalog.zones do
			local id = Sounds.music.bosses[zone.id]
			T.ok(id ~= nil and isId(id), `no place for the boss track of {zone.id}`)
		end
		for zoneId in Sounds.music.bosses do
			T.ok(Catalog.zoneById[zoneId] ~= nil, `a boss track for a zone there is not: {zoneId}`)
		end
		local events: { [string]: boolean } = {}
		for _, event in EventsConfig.list do
			events[event.id] = true
			local id = Sounds.music.events[event.id]
			T.ok(id ~= nil and isId(id), `no place for the track of {event.id}`)
		end
		for eventId in Sounds.music.events do
			T.ok(events[eventId] == true, `a track for an event there is not: {eventId}`)
		end
		T.ok(isId(Sounds.music.village), "the village's track is not an id")
		T.ok(Sounds.music.crossfade > 0, "tracks would cut over")
	end,
}
