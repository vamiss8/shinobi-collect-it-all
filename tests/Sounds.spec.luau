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
			local vary = effect.vary or 0
			T.ok(vary >= 0 and vary <= 0.3, `{cue} is varied out of tune`)
		end
		T.ok(count >= 20, "the effects are missing")
	end,

	-- Every material named stands for a surface there is, and every surface has steps enough
	-- to take turns.
	["footsteps have a surface for every material named"] = function()
		local steps = Sounds.steps
		T.ok(steps.surfaces[steps.fallback] ~= nil, "the fallback surface is not there")
		for material, surface in steps.materials do
			T.ok(steps.surfaces[surface] ~= nil, `{material} steps on {surface}, no such surface`)
		end
		for name, surface in steps.surfaces do
			T.ok(#surface.ids >= 2, `{name} has fewer than two steps to take turns`)
			for _, id in surface.ids do
				T.ok(isId(id), `{name} has a step that is no asset id`)
			end
			T.ok(surface.volume > 0 and surface.volume <= 1, `{name} steps are too loud or silent`)
		end
		T.ok(#steps.jump.ids >= 2, "the jump has fewer than two sounds to take turns")
		for _, id in steps.jump.ids do
			T.ok(isId(id), "the jump has a sound that is no asset id")
		end
		T.ok(steps.landing.volume >= 1 and steps.landing.speed > 0.5, "a landing is no landing")
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
					for cue in string.gmatch(fs.readFile(full), 'Audio%.play%(%s*"(%w+)"') do
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

	["every zone's track is a zone's and every event has one"] = function()
		for zoneId in Sounds.music.bosses do
			T.ok(Catalog.zoneById[zoneId] ~= nil, `a track for a zone there is not: {zoneId}`)
		end
		local events: { [string]: boolean } = {}
		for _, event in EventsConfig.list do
			events[event.id] = true
			T.ok(Sounds.music.events[event.id] ~= nil, `no track for {event.id}`)
		end
		for eventId in Sounds.music.events do
			T.ok(events[eventId] == true, `a track for an event there is not: {eventId}`)
		end
		-- The owner: one track alone would pall in the village; they take turns.
		T.ok(#Sounds.music.village >= 3, "the village has fewer than three tracks")
		T.ok(Sounds.music.crossfade > 0, "tracks would cut over")
		T.ok(
			Sounds.music.chase > 0 and Sounds.music.chase < Sounds.music.crossfade,
			"a chase's track comes in slower than a fade"
		)
	end,

	-- A track starts at the moment the owner chose in it: inside the track, with something left.
	["every track is an asset that starts inside itself, at a sane volume"] = function()
		local function look(where: string, track: Sounds.Track)
			T.ok(isId(track.id) and track.id > 0, `{where} has no asset id`)
			T.ok(track.name ~= "", `{where} has no name for the music window`)
			T.ok(track.length > 0, `{where} has no length`)
			local from = track.from or 0
			T.ok(
				from >= 0 and from <= track.length - 20,
				`{where} starts {from} s into a track of {track.length} s`
			)
			local cut = track.to or track.length
			T.ok(cut > from + 10 and cut <= track.length, `{where} is cut at {cut} s`)
			local loopFrom = track.loopFrom or from
			T.ok(
				loopFrom >= 0 and loopFrom <= from,
				`{where} loops back to {loopFrom} s, past its start`
			)
			local volume = track.volume or 1
			T.ok(volume > 0 and volume <= 2, `{where} plays at a strange volume`)
		end
		for index, track in Sounds.music.village do
			look(`village track {index}`, track)
		end
		for zoneId, track in Sounds.music.bosses do
			look(`the track of {zoneId}`, track)
		end
		for eventId, track in Sounds.music.events do
			look(`the track of {eventId}`, track)
		end
	end,
}
