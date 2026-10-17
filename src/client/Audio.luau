--!strict
-- The game's sounds and music (Config/Sounds). Audio.play(cue) makes the sound of a moment;
-- the music follows what is on: the village's calm track, the boss's while its enemy chases the
-- player, an event's over both. A cue or a track whose id is 0 is silence, so nothing here
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

-- The music: the track playing now, and its id.
local playing: Sound? = nil
local playingId = 0

-- Gives way from the track playing to the one with this id (0: none), over Sounds.music's
-- crossfade.
local function playMusic(id: number)
	if id == playingId then
		return
	end
	playingId = id
	local fade = TweenInfo.new(Sounds.music.crossfade, Enum.EasingStyle.Sine)
	local old = playing
	playing = nil
	if old then
		TweenService:Create(old, fade, { Volume = 0 }):Play()
		task.delay(Sounds.music.crossfade, function()
			old:Destroy()
		end)
	end
	if id == 0 then
		return
	end
	local track = Instance.new("Sound")
	track.Name = "Music"
	track.SoundId = asset(id)
	track.Looped = true
	track.Volume = 0
	track.SoundGroup = group("Music")
	track.Parent = SoundService
	track:Play()
	TweenService:Create(track, fade, { Volume = Sounds.music.volume }):Play()
	playing = track
end

-- What the music should be: an event's track while one runs, else the boss's while the player
-- runs from it, else the village's. A track not in yet falls to the village's.
local chasedIn: string? = nil
local eventOn: string? = nil

local function chooseMusic()
	local id = 0
	if eventOn then
		id = Sounds.music.events[eventOn] or 0
	elseif chasedIn then
		id = Sounds.music.bosses[chasedIn] or 0
	end
	if id == 0 then
		id = Sounds.music.village
	end
	playMusic(id)
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
		local had, has = total(before.stock), total(state.stock)
		if has > had then
			Audio.play("potion")
		elseif has < had then
			Audio.play("drink")
		end
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
