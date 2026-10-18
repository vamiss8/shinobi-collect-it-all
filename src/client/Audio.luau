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

-- The group a sound of the game plays in ("Effects" or "Music"), for sounds made elsewhere
-- (client Footsteps).
function Audio.group(name: string): SoundGroup
	return group(name)
end

-- How an effect's pitch is varied (Config/Sounds `vary`).
local pitcher = Random.new()

-- How fast a sound cut short (Config/Sounds `cut`, `choke`) fades away, seconds.
local CUT_FADE = 0.12
-- How many times each sound has been started, so that a fade meant for one play leaves the
-- next alone, and the fade under way on each.
local plays: { [Sound]: number } = setmetatable({}, { __mode = "k" }) :: any
local cutting: { [Sound]: Tween } = setmetatable({}, { __mode = "k" }) :: any
-- The sounds of each choke (Config/Sounds `choke`) that have played.
local chokes: { [string]: { Sound } } = {}

-- Fades a sound away and stops it, then does `after` (a copy destroys itself), unless it has
-- been started again meanwhile.
local function hush(sound: Sound, after: (() -> ())?)
	local token = plays[sound]
	local tween = TweenService:Create(sound, TweenInfo.new(CUT_FADE), { Volume = 0 })
	cutting[sound] = tween
	tween.Completed:Once(function()
		if plays[sound] == token then
			cutting[sound] = nil
			sound:Stop()
			if after then
				after()
			end
		end
	end)
	tween:Play()
end

-- Starts a sound from its beginning at its effect's volume and at a pitch, and cuts it short
-- after the effect's `cut` if it has one.
local function launch(sound: Sound, effect: Sounds.Effect, pitch: number, after: (() -> ())?)
	local token = (plays[sound] or 0) + 1
	plays[sound] = token
	local tween = cutting[sound]
	if tween then
		cutting[sound] = nil
		tween:Cancel()
	end
	sound.Volume = effect.volume or 0.5
	sound.PlaybackSpeed = pitch
	sound.TimePosition = 0
	sound:Play()
	local cut = effect.cut
	if cut then
		task.delay(cut, function()
			if plays[sound] == token and sound.IsPlaying then
				hush(sound, after)
			end
		end)
	end
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

-- How fast a sustained sound (Audio.sustain) comes in and goes, seconds, and how long one
-- forgotten may ring at the most.
local SUSTAIN_FADE = 0.2
local SUSTAIN_LIFE = 30

-- Plays a cue looped until the function it hands back is called, which fades it away: the
-- kunai's whistle in flight.
function Audio.sustain(cue: string): () -> ()
	local base = effectSound(cue)
	if not base then
		return function() end
	end
	local effect = EFFECTS[cue]
	local sound = base:Clone()
	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = effect.speed or 1
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(SUSTAIN_FADE), { Volume = effect.volume or 0.5 })
		:Play()
	local stopped = false
	local function stop()
		if stopped then
			return
		end
		stopped = true
		local tween = TweenService:Create(sound, TweenInfo.new(SUSTAIN_FADE), { Volume = 0 })
		tween.Completed:Once(function()
			sound:Destroy()
		end)
		tween:Play()
	end
	task.delay(SUSTAIN_LIFE, stop)
	return stop
end

-- How long before its moment a cue's sound is to be started (Config/Sounds `lead`): the
-- moment comes that far into it.
function Audio.lead(cue: string): number
	local effect = EFFECTS[cue]
	return if effect then effect.lead or 0 else 0
end

-- Makes the sound of a moment, `speed` times as high as it is set to be if given (the roulette's
-- ticks climb). One that may overlap itself (ticks, presses) is played as a copy while the
-- last is still sounding; any other starts again. One of a choke fades the others away.
function Audio.play(cue: string, speed: number?)
	local sound = effectSound(cue)
	if not sound then
		return
	end
	local effect = EFFECTS[cue]
	local pitch = (effect.speed or 1) * (speed or 1)
	local vary = effect.vary
	if vary and vary > 0 then
		pitch *= 1 + pitcher:NextNumber(-vary, vary)
	end
	local choke = effect.choke
	if choke then
		local list = chokes[choke]
		if not list then
			list = {}
			chokes[choke] = list
		end
		for _, other in list do
			if other ~= sound and other.IsPlaying then
				hush(other)
			end
		end
		if not table.find(list, sound) then
			table.insert(list, sound)
		end
	end
	if sound.IsPlaying and effect.overlap then
		local copy = sound:Clone()
		copy.Parent = SoundService
		local function gone()
			if copy.Parent then
				copy:Destroy()
			end
		end
		copy.Ended:Once(gone)
		task.delay(COPY_LIFE, gone)
		launch(copy, effect, pitch, gone)
		return
	end
	launch(sound, effect, pitch)
end

-- The music (Config/Sounds `music`). Every track is a Sound of its own, made the first time it
-- is wanted and kept, so that it is loaded the next time. One is heard at a time: an event's
-- while one runs, else the zone's while its enemy chases the player, else the village's. The
-- village's tracks are a playlist that plays on by itself and that the player can step through,
-- repeat and shuffle (the player in client SettingsPanel); the one under way is paused when another takes over
-- and goes on from where it was when the village comes back. A zone's or an event's starts at
-- its chosen moment (`from`) every time, and loops back to it.
local MUSIC = Sounds.music
-- Past any track's end: a region whose far end lies beyond the track ends with the track.
local THE_END = 100000

local trackSounds: { [string]: Sound } = {}
-- How many fades each track has had: a fade that has been overtaken does not finish its work.
local fades: { [Sound]: number } = {}

local heard: string? = nil -- the key of the track heard now
-- The village's playlist: the track under way (by its place in MUSIC.village), playing or
-- paused, and how the next one is picked.
local villageAt: number? = nil
-- SHUFFLE IS A DECK (owner, 2026-10-18: "shuffle when the player comes in, and then none
-- repeats until all five have played"): every track once, in an order drawn when the visit
-- begins and drawn anew each time it has all been played, never so that the new round begins
-- with the track that ended the last. `orderAt` is the place in it of the track under way.
local shuffle = true
local order: { number } = {}
local orderAt = 0
local repeatOne = false
-- Paused by the player in the music player: the village's track stands where it is until
-- played again, through chases and events too.
local userPaused = false
-- How fast a pause or a play fades, seconds.
local PAUSE_FADE = 0.25
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
	local loopFrom = track.loopFrom or from
	if from > 0 or track.to or track.loopFrom then
		-- Played from the chosen moment, cut before a silent tail, and looped back to the
		-- moment (or further back, `loopFrom`), never to the track's start. The region has to
		-- take in where the loop goes back to; the start is set after Play (see start).
		sound.PlaybackRegionsEnabled = true
		local ends = track.to or THE_END
		sound.PlaybackRegion = NumberRange.new(math.min(from, loopFrom), ends)
		sound.LoopRegion = NumberRange.new(loopFrom, ends)
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

-- Starts a track at its chosen moment. The moment is set after Play: a region that begins before
-- it (a loop that goes further back) would start the track at the region's beginning.
local function start(sound: Sound, track: Sounds.Track)
	sound:Play()
	sound.TimePosition = track.from or 0
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

-- Draws a new order of every track, one that does not begin with `avoid`.
local function deal(avoid: number?)
	local count = #MUSIC.village
	order = {}
	for index = 1, count do
		table.insert(order, index)
	end
	for index = count, 2, -1 do
		local other = shuffler:NextInteger(1, index)
		order[index], order[other] = order[other], order[index]
	end
	if avoid and count > 1 and order[1] == avoid then
		local other = shuffler:NextInteger(2, count)
		order[1], order[other] = order[other], order[1]
	end
	orderAt = 0
end

-- The track of the playlist that comes after the one under way: the next of the deck with
-- shuffle on, the next in the list with it off.
local function following(): number?
	local count = #MUSIC.village
	if count == 0 then
		return nil
	end
	if not shuffle then
		return if villageAt then villageAt % count + 1 else 1
	end
	if orderAt >= #order then
		deal(villageAt)
	end
	orderAt += 1
	return order[orderAt]
end

-- The track before the one under way: the deck's with shuffle on, the list's with it off; the
-- first of a round is begun anew.
local function preceding(): number?
	local count = #MUSIC.village
	if count == 0 or not villageAt then
		return villageAt
	end
	if not shuffle then
		return (villageAt - 2) % count + 1
	end
	if orderAt > 1 then
		orderAt -= 1
		return order[orderAt]
	end
	return villageAt
end

-- Makes `index` the village's track under way. The one it takes over from is stopped (at once
-- if it is not heard, by the fade otherwise), so that it begins from its start if it comes
-- again; the same one is begun anew.
local function setVillage(index: number?)
	local old = villageAt
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
			if not sound.IsPlaying then
				sound:Play()
			end
			sound.TimePosition = if track then track.from or 0 else 0
		end
	end
	told()
end

skipVillage = function(step: number)
	userPaused = false
	setVillage(if step < 0 then preceding() else following())
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
		setVillage(following())
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
		if userPaused then
			-- Paused by the player: it stays where it is, silent, until played.
			fade(sound, 0, seconds, function()
				if sound.IsPlaying then
					sound:Pause()
				end
			end)
			return
		end
	end
	if sound.IsPaused then
		sound:Resume()
	elseif not sound.IsPlaying then
		start(sound, track)
	end
	fade(sound, MUSIC.volume * (track.volume or 1), seconds)
end

-- The village's playlist, for the music player (client SettingsPanel).
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

-- Shuffle plays the tracks as a deck, each once in a drawn order; off, they go in the list's
-- order. Turned on, it draws a deck whose first is the track under way.
function Audio.setShuffle(on: boolean)
	shuffle = on
	if on then
		deal(nil)
		local at = villageAt
		if at then
			local place = table.find(order, at)
			if place then
				order[1], order[place] = order[place], order[1]
			end
			orderAt = 1
		end
	end
	told()
end

function Audio.paused(): boolean
	return userPaused
end

-- Pause stops the village's music where it is; play goes on from there.
function Audio.setPaused(on: boolean)
	userPaused = on
	local at = villageAt
	if at and heard == villageKey(at) then
		local track = MUSIC.village[at]
		local sound = trackSound(villageKey(at), track)
		if on then
			fade(sound, 0, PAUSE_FADE, function()
				sound:Pause()
			end)
		else
			if sound.IsPaused then
				sound:Resume()
			elseif not sound.IsPlaying then
				start(sound, track)
			end
			fade(sound, MUSIC.volume * (track.volume or 1), PAUSE_FADE)
		end
	end
	told()
end

-- Moves the village's track under way to a share of its length (the player's bar pressed).
function Audio.seekVillage(share: number)
	local at = villageAt
	if not at then
		return
	end
	local sound = trackSounds[villageKey(at)]
	if not sound then
		return
	end
	local length = if sound.TimeLength > 0 then sound.TimeLength else MUSIC.village[at].length
	sound.TimePosition = math.clamp(share, 0, 0.99) * length
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
	HandsFull = "refuse",
	NothingHeld = "refuse",
	NotYourDojo = "refuse",
	Merged = "merge",
	FloorBuilt = "floor",
}

-- How long after coming home a shinobi put into the hands is the catch itself, seconds: that
-- one is the run home's sound, not a pickup's.
local HOME_HANDS = 1.5

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
	local homeAt = -math.huge
	Remotes.RunEnd.OnClientEvent:Connect(function(run: Net.RunEnd)
		homeAt = os.clock()
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
	-- Set on a pad (or swapped onto one), or taken off one into the inventory (owner,
	-- 2026-10-18: "setting a shinobi down makes no sound"; it was told from the snapshot by
	-- the hands emptying as the income rose, and was not heard).
	Remotes.Placed.OnClientEvent:Connect(function(kind: string)
		if kind == "place" then
			Audio.play("place")
		elseif kind == "take" then
			Audio.play("pickup")
		end
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
		-- A shinobi taken into the hands. Setting one on a pad, which the snapshot does not tell
		-- for sure, the server says (Placed below).
		if state.held and state.held ~= before.held then
			if os.clock() - homeAt > HOME_HANDS then
				Audio.play("pickup")
			end
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
