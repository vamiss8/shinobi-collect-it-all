--!strict
-- The game's sounds and music (Config/Sounds). Audio.play(cue) makes the sound of a moment;
-- the music follows what is on: the village's playlist, the zone's track while its enemy chases
-- the player, an event's over both. A cue or a track whose id is 0 is silence, so nothing here
-- waits on a sound being chosen.
--
-- Effects play in the SoundGroup "Effects" and music in "Music", whose volumes the settings set
-- (client SettingsPanel); whichever of the two modules comes first makes them. Sounds are parts
-- of SoundService and so are heard the same wherever the camera is.
--
-- Who calls: what the player presses on the screen calls Audio.play where it is pressed (Ui's
-- buttons and windows, the reveal, the bonus seals, the consoles, an event's start); what the
-- server says is listened to here (a throw's grade, the ring, the run's end, messages), and so
-- is what the snapshot shows has changed (a kunai, run speed, a pad, a rebirth, Herbs, the
-- pouch).

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local SpeedStages = require(ReplicatedStorage.Shared.Config.SpeedStages)

local Audio = {}

-- The effects by cue, read by name: a cue is a plain word wherever Audio.play is called, and
-- tests/Sounds.spec holds every word the client plays to a cue of Config/Sounds.
local EFFECTS: { [string]: Sounds.Effect } = Sounds.effects :: any

-- How long a copy of an effect played over itself may live at the most, seconds: one that never
-- loaded never ends.
local COPY_LIFE = 12

-- The group a sound plays in, made if it is not there yet (the same as SettingsPanel's).
local function group(name: string): SoundGroup
	local found = SoundService:FindFirstChild(name)
	if found and found:IsA("SoundGroup") then
		return found
	end
	local made = Instance.new("SoundGroup")
	made.Name = name
	made.Parent = SoundService
	return made
end

local function asset(id: number): string
	return `rbxassetid://{id}`
end

-- One Sound for each cue, made the first time it is played.
local made: { [string]: Sound } = {}

local function effectSound(cue: string): Sound?
	local effect = EFFECTS[cue]
	if not effect or effect.id == 0 then
		return nil
	end
	local found = made[cue]
	if found then
		return found
	end
	local sound = Instance.new("Sound")
	sound.Name = `Effect_{cue}`
	sound.SoundId = asset(effect.id)
	sound.Volume = effect.volume or 0.5
	sound.PlaybackSpeed = effect.speed or 1
	sound.SoundGroup = group("Effects")
	sound.Parent = SoundService
	made[cue] = sound
	return sound
end

-- How long before its moment a cue's sound is to be started (Config/Sounds `lead`): the
-- moment comes that far into it.
function Audio.lead(cue: string): number
	local effect = EFFECTS[cue]
	return if effect then effect.lead or 0 else 0
end

-- Makes the sound of a moment. One that may overlap itself (ticks, presses) is played as a copy
-- while the last is still sounding; any other starts again.
function Audio.play(cue: string)
	local sound = effectSound(cue)
	if not sound then
		return
	end
	local effect = EFFECTS[cue]
	if sound.IsPlaying and effect.overlap then
		local copy = sound:Clone()
		copy.Parent = SoundService
		copy.Ended:Once(function()
			copy:Destroy()
		end)
		task.delay(COPY_LIFE, function()
			if copy.Parent then
				copy:Destroy()
			end
		end)
		copy:Play()
		return
	end
	sound.TimePosition = 0
	sound:Play()
end

-- The music (Config/Sounds `music`). Every track is a Sound of its own, made the first time it
-- is wanted and kept, so that it is loaded the next time. One is heard at a time: an event's
-- while one runs, else the zone's while its enemy chases the player, else the village's. The
-- village's tracks are a playlist that plays on by itself and that the player can step through,
-- repeat and shuffle (client MusicPanel); the one under way is paused when another takes over
-- and goes on from where it was when the village comes back. A zone's or an event's starts at
-- its chosen moment (`from`) every time, and loops back to it.
local MUSIC = Sounds.music
-- Past any track's end: a region whose far end lies beyond the track ends with the track.
local THE_END = 100000
-- How many tracks back "previous" can go.
local HISTORY = 50

local trackSounds: { [string]: Sound } = {}
-- How many fades each track has had: a fade that has been overtaken does not finish its work.
local fades: { [Sound]: number } = {}

local heard: string? = nil -- the key of the track heard now
-- The village's playlist: the track under way (by its place in MUSIC.village), playing or
-- paused; the ones played before it; and how the next one is picked.
local villageAt: number? = nil
local history: { number } = {}
local shuffle = true
local repeatOne = false
local shuffler = Random.new()
local playlistListeners: { () -> () } = {}

local chasedIn: string? = nil
local eventOn: string? = nil

local function isVillage(key: string): boolean
	return string.sub(key, 1, 8) == "village:"
end

local function villageKey(index: number): string
	return `village:{index}`
end

local function told()
	for _, listener in playlistListeners do
		task.spawn(listener)
	end
end

local chooseMusic: () -> ()
local skipVillage: (step: number) -> ()

local function trackSound(key: string, track: Sounds.Track): Sound
	local kept = trackSounds[key]
	if kept then
		return kept
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.SoundId = asset(track.id)
	sound.Volume = 0
	sound.Looped = not isVillage(key)
	sound.SoundGroup = group("Music")
	local from = track.from or 0
	if from > 0 then
		-- Played from the chosen moment, and looped back to it, never to the track's start.
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(from, THE_END)
		sound.LoopRegion = NumberRange.new(from, THE_END)
	end
	if isVillage(key) then
		-- A village track played out: the playlist goes on (one on repeat loops and never ends).
		sound.Ended:Connect(function()
			if villageAt and key == villageKey(villageAt) then
				skipVillage(1)
			end
		end)
	end
	sound.Parent = SoundService
	trackSounds[key] = sound
	return sound
end

-- Turns a track's volume to `volume` over `seconds`, then does `after`, unless another fade of
-- the same track has begun meanwhile.
local function fade(sound: Sound, volume: number, seconds: number, after: (() -> ())?)
	local mark = (fades[sound] or 0) + 1
	fades[sound] = mark
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine)
	TweenService:Create(sound, info, { Volume = volume }):Play()
	if after then
		task.delay(seconds, function()
			if fades[sound] == mark then
				after()
			end
		end)
	end
end

-- The track of the playlist that comes after the one under way: the next in order, or with
-- shuffle on any other at random, so that none comes twice running.
local function following(): number?
	local count = #MUSIC.village
	if count == 0 then
		return nil
	end
	if not villageAt then
		return if shuffle then shuffler:NextInteger(1, count) else 1
	end
	if count == 1 then
		return villageAt
	end
	if not shuffle then
		return villageAt % count + 1
	end
	local index = shuffler:NextInteger(1, count - 1)
	return if index >= villageAt then index + 1 else index
end

-- Makes `index` the village's track under way. The one it takes over from is stopped (at once
-- if it is not heard, by the fade otherwise), so that it begins from its start if it comes
-- again; the same one is begun anew.
local function setVillage(index: number?, remember: boolean)
	local old = villageAt
	if old and remember and old ~= index then
		table.insert(history, old)
		if #history > HISTORY then
			table.remove(history, 1)
		end
	end
	villageAt = index
	if old then
		local oldKey = villageKey(old)
		local sound = trackSounds[oldKey]
		if sound and (old ~= index or heard ~= oldKey) then
			if heard ~= oldKey then
				sound:Stop()
			end
		elseif sound and old == index then
			local track = MUSIC.village[old]
			sound.TimePosition = if track then track.from or 0 else 0
			if not sound.IsPlaying then
				sound:Play()
			end
		end
	end
	told()
end

skipVillage = function(step: number)
	if step < 0 then
		local back = table.remove(history)
		if not back and villageAt and not shuffle then
			back = (villageAt - 2) % #MUSIC.village + 1
		end
		setVillage(back or villageAt, false)
	else
		setVillage(following(), true)
	end
	chooseMusic()
end

-- What should be heard now: its key, its track, and whether it is a chase's.
local function wanted(): (string?, Sounds.Track?, boolean)
	if eventOn then
		local track = MUSIC.events[eventOn]
		if track and track.id > 0 then
			return `event:{eventOn}`, track, false
		end
	end
	if chasedIn then
		local track = MUSIC.bosses[chasedIn]
		if track and track.id > 0 then
			return `boss:{chasedIn}`, track, true
		end
	end
	if not villageAt then
		setVillage(following(), false)
	end
	if villageAt then
		return villageKey(villageAt), MUSIC.village[villageAt], false
	end
	return nil, nil, false
end

chooseMusic = function()
	local key, track, chase = wanted()
	if key == heard then
		return
	end
	-- A chase's track comes in at once, so that its drop is heard; the way home is gentler.
	local seconds = if chase then MUSIC.chase else MUSIC.crossfade
	local was = heard
	local old = if was then trackSounds[was] else nil
	if was and old then
		-- The village's track under way is paused, to go on later; any other is stopped.
		local keep = villageAt ~= nil and was == villageKey(villageAt)
		fade(old, 0, seconds, function()
			if keep then
				old:Pause()
			else
				old:Stop()
			end
		end)
	end
	heard = key
	told()
	if not key or not track then
		return
	end
	local sound = trackSound(key, track)
	if isVillage(key) then
		sound.Looped = repeatOne
	end
	if sound.IsPaused then
		sound:Resume()
	elseif not sound.IsPlaying then
		sound.TimePosition = track.from or 0
		sound:Play()
	end
	fade(sound, MUSIC.volume * (track.volume or 1), seconds)
end

-- The village's playlist, for the music window (client MusicPanel).
function Audio.playlist(): { Sounds.Track }
	return MUSIC.village
end

-- Which of the playlist's tracks is under way, and whether it is heard now: during a chase or
-- an event their own track is, and the village's waits.
function Audio.villageAt(): (number?, boolean)
	return villageAt, heard ~= nil and isVillage(heard)
end

-- How far the village's track under way has played, and how long it is, seconds.
function Audio.villageClock(): (number, number)
	if not villageAt then
		return 0, 0
	end
	local track = MUSIC.village[villageAt]
	local sound = trackSounds[villageKey(villageAt)]
	if not sound then
		return 0, track.length
	end
	return sound.TimePosition, if sound.TimeLength > 0 then sound.TimeLength else track.length
end

-- Plays a track of the playlist from its start.
function Audio.playVillage(index: number)
	if MUSIC.village[index] then
		setVillage(index, true)
		chooseMusic()
	end
end

-- The next track of the playlist (1), or the one before (-1).
function Audio.skipVillage(step: number)
	skipVillage(step)
end

function Audio.repeating(): boolean
	return repeatOne
end

-- Repeat plays the track under way over and over.
function Audio.setRepeat(on: boolean)
	repeatOne = on
	if villageAt then
		local sound = trackSounds[villageKey(villageAt)]
		if sound then
			sound.Looped = on
		end
	end
	told()
end

function Audio.shuffling(): boolean
	return shuffle
end

-- Shuffle picks the next track at random, never the same twice running; off, they go in order.
function Audio.setShuffle(on: boolean)
	shuffle = on
	told()
end

-- Calls `listener` whenever the playlist's track, what is heard, repeat or shuffle change.
function Audio.onPlaylist(listener: () -> ())
	table.insert(playlistListeners, listener)
end

-- What a message from the server (a key of client/Strings) sounds like.
local NOTIFY: { [string]: string } = {
	Sold = "sell",
	SoldMany = "sell",
	PassBought = "pass",
	LegendJoined = "pass",
	RyoPackBought = "coins",
	OfflineDoubled = "coins",
	NotEnoughHerbs = "refuse",
	NotEnoughRyo = "refuse",
}

-- The sum of a table of counts.
local function total(counts: { [string]: number }): number
	local sum = 0
	for _, count in counts do
		sum += count
	end
	return sum
end

function Audio.start()
	-- Required here and not at the top: Ui plays through this module, and these do not.
	local Remotes = require("./Remotes")
	local Store = require("./Store")

	-- Every effect is fetched ahead, in the background, so that the first press is heard.
	task.spawn(function()
		local list: { Instance } = {}
		for cue in EFFECTS do
			local sound = effectSound(cue)
			if sound then
				table.insert(list, sound)
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
	end)

	Remotes.KickResult.OnClientEvent:Connect(function(result: Net.KickResult?)
		if result then
			if result.grade == "Perfect" then
				Audio.play("perfect")
			else
				Audio.play("press")
			end
		end
	end)
	Remotes.RingResult.OnClientEvent:Connect(function(result: Net.RingResult)
		if result.grade == "Perfect" then
			Audio.play("ringPerfect")
		elseif result.gain > 0 then
			Audio.play("ring")
		else
			Audio.play("ringMiss")
		end
	end)
	Remotes.RunStart.OnClientEvent:Connect(function(run: Net.RunStart)
		chasedIn = run.zone
		chooseMusic()
	end)
	Remotes.RunEnd.OnClientEvent:Connect(function(run: Net.RunEnd)
		if run.escaped then
			Audio.play("home")
		else
			Audio.play("caught")
		end
		chasedIn = nil
		chooseMusic()
	end)
	Remotes.Notify.OnClientEvent:Connect(function(key: string)
		local cue = NOTIFY[key]
		if cue then
			Audio.play(cue)
		end
	end)
	Remotes.Announce.OnClientEvent:Connect(function()
		Audio.play("announce")
	end)

	-- What the snapshot shows has changed since the last one. The first one only sets the mark.
	local last: Net.Snapshot? = nil
	Store.onChange(function(state)
		local before = last
		last = table.clone(state)
		if not before then
			return
		end
		if state.rebirths > before.rebirths then
			Audio.play("rebirth")
		elseif state.kunai > before.kunai then
			Audio.play("kunai")
		elseif state.speedLevel > before.speedLevel then
			local _, was = SpeedStages.at(before.speedLevel)
			local _, now = SpeedStages.at(state.speedLevel)
			if now ~= was then
				Audio.play("stage")
			else
				Audio.play("speed")
			end
		elseif state.padsBought > before.padsBought then
			Audio.play("pad")
		end
		if state.herbs > before.herbs then
			Audio.play("herbs")
		end
		local had = total(before.stock) + total(before.premium)
		local has = total(state.stock) + total(state.premium)
		if has > had then
			Audio.play("potion")
		elseif has < had then
			Audio.play("drink")
		end
	end)

	-- The tracks are fetched in the background, the village's first and the chases' and events'
	-- after them, so that a chase's drop is not lost to loading the first time.
	task.spawn(function()
		local first: { Instance } = {}
		for index, track in MUSIC.village do
			if track.id > 0 then
				table.insert(first, trackSound(villageKey(index), track))
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(first)
		end)
		local rest: { Instance } = {}
		for zoneId, track in MUSIC.bosses do
			if track.id > 0 then
				table.insert(rest, trackSound(`boss:{zoneId}`, track))
			end
		end
		for eventId, track in MUSIC.events do
			if track.id > 0 then
				table.insert(rest, trackSound(`event:{eventId}`, track))
			end
		end
		pcall(function()
			ContentProvider:PreloadAsync(rest)
		end)
	end)

	-- The music: the village's from the start, an event's while one runs.
	task.spawn(function()
		local hub = Workspace:WaitForChild(Net.HUB_FOLDER, 60)
		if hub then
			local function changed()
				local id = hub:GetAttribute(Net.EVENT_ATTRIBUTE)
				eventOn = if typeof(id) == "string" and id ~= "" then id else nil
				chooseMusic()
			end
			hub:GetAttributeChangedSignal(Net.EVENT_ATTRIBUTE):Connect(changed)
			changed()
		else
			chooseMusic()
		end
	end)
end

return Audio
