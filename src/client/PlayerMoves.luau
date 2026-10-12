--!strict
-- Plays the local player's published animation clips in response to server-confirmed actions.
-- Only an Animator replicated inside the player's Humanoid is used: Roblox can then replicate
-- this owner's playback to other clients. These clips never move the root, change Humanoid.Sit,
-- alter training rewards, or own the camera; those remain with the existing gameplay modules.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Moves = require(ReplicatedStorage.Shared.View.Moves)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")

local PlayerMoves = {}

local FADE = 0.15
local THROW_FADE = 0.05
-- Length is zero while a clip loads, and can remain zero for an inaccessible asset. A missing
-- transition must not keep the usable meditation loop waiting forever.
local LENGTH_TIMEOUT = 2
local LENGTH_POLL = 0.05
local ANIMATOR_TIMEOUT = 2
local HUMANOID_TIMEOUT = 5

local started = false

function PlayerMoves.start()
	if started then
		return
	end
	started = true

	local clips = Animations.player
	local configured = false
	for _, id in clips do
		if id ~= "" then
			configured = true
			break
		end
	end
	-- Empty placeholders deliberately preserve today's player behavior, including avoiding
	-- unnecessary Animator lookup/creation, asset requests, and character event connections.
	if not configured then
		return
	end

	local player = Players.LocalPlayer
	local character: Model? = nil
	local humanoid: Humanoid? = nil
	local animator: Animator? = nil
	local training: string? = nil
	local characterGeneration = 0
	local modeGeneration = 0
	local characterConnections: { RBXScriptConnection } = {}

	local function currentAnimator(): Animator?
		local model = character
		local body = humanoid
		local host = animator
		if
			model
			and model == player.Character
			and model.Parent ~= nil
			and body
			and body.Parent == model
			and body.Health > 0
			and host
			and host.Parent == body
		then
			return host
		end
		return nil
	end

	local function stopTraining(host: Animator, fade: number)
		Moves.stop(host, clips.MeditateStart, fade)
		Moves.stop(host, clips.MeditateLoop, fade)
		Moves.stop(host, clips.MeditateEnd, fade)
		Moves.stop(host, clips.ChakraLoop, fade)
		Moves.stop(host, clips.ChakraHit, fade)
	end

	-- Invalidates both character-loading work and meditation transitions before stopping any
	-- tracks. A removed/dead character is never given an exit animation or a delayed new loop.
	local function clearCharacter()
		characterGeneration += 1
		modeGeneration += 1
		training = nil
		for _, connection in characterConnections do
			connection:Disconnect()
		end
		table.clear(characterConnections)
		local previous = animator
		character = nil
		humanoid = nil
		animator = nil
		if previous then
			stopTraining(previous, 0)
			Moves.stop(previous, clips.Throw, 0)
		end
	end

	local function beginMode(mode: string?, generation: number)
		local host = currentAnimator()
		if not host then
			return
		end
		if mode == "focus" then
			Moves.play(host, clips.ChakraLoop, Enum.AnimationPriority.Action, true, FADE)
		elseif mode == "meditate" then
			local transition =
				Moves.play(host, clips.MeditateStart, Enum.AnimationPriority.Action, false, FADE)

			local function stillMeditating(): boolean
				return modeGeneration == generation
					and training == "meditate"
					and currentAnimator() == host
			end

			local function beginLoop()
				if stillMeditating() then
					Moves.stop(host, clips.MeditateStart, FADE)
					Moves.play(host, clips.MeditateLoop, Enum.AnimationPriority.Action, true, FADE)
				end
			end

			if not transition then
				-- The start clip is optional. An empty or unloadable id uses the loop directly.
				beginLoop()
				return
			end

			task.spawn(function()
				local deadline = os.clock() + LENGTH_TIMEOUT
				while
					stillMeditating()
					and transition.Length <= 0
					and transition.IsPlaying
					and os.clock() < deadline
				do
					task.wait(LENGTH_POLL)
				end
				if not stillMeditating() then
					return
				end
				if transition.Length <= 0 or not transition.IsPlaying then
					beginLoop()
					return
				end
				-- Account for playback that elapsed during loading. The loop fades in for the
				-- last 0.15 seconds of the start clip, rather than adding a pause between them.
				local remaining = math.max(transition.Length - transition.TimePosition - FADE, 0)
				task.delay(remaining, beginLoop)
			end)
		end
	end

	local function setTraining(mode: string?)
		local nextMode = if mode == "meditate" or mode == "focus" then mode else nil
		if training == nextMode then
			return
		end
		local previous = training
		training = nextMode
		modeGeneration += 1
		local host = currentAnimator()
		if host then
			stopTraining(host, FADE)
			if previous == "meditate" then
				Moves.play(host, clips.MeditateEnd, Enum.AnimationPriority.Action, false, FADE)
			end
		end
		beginMode(nextMode, modeGeneration)
	end

	local function bindCharacter(model: Model)
		clearCharacter()
		character = model
		local generation = characterGeneration
		local function stillCurrent(): boolean
			return characterGeneration == generation
				and character == model
				and player.Character == model
				and model.Parent ~= nil
		end
		table.insert(
			characterConnections,
			model.AncestryChanged:Connect(function(_, parent)
				if parent == nil and character == model then
					clearCharacter()
				end
			end)
		)
		task.spawn(function()
			local body = model:FindFirstChildOfClass("Humanoid")
			if not body then
				local found = model:WaitForChild("Humanoid", HUMANOID_TIMEOUT)
				body = if found and found:IsA("Humanoid") then found else nil
			end
			if not stillCurrent() or not body or body.Health <= 0 then
				return
			end
			humanoid = body
			table.insert(characterConnections, body.Died:Connect(clearCharacter))
			-- A client-created Animator cannot replicate its tracks. Allow a short wait for
			-- the normal server-created player Animator instead of silently creating one here.
			local host = body:FindFirstChildOfClass("Animator")
			if not host then
				local found = body:WaitForChild("Animator", ANIMATOR_TIMEOUT)
				host = if found and found:IsA("Animator") then found else nil
			end
			if not stillCurrent() or body.Health <= 0 then
				return
			end
			if not host then
				warn("PlayerMoves: the player's server-created Humanoid.Animator is missing")
				return
			end
			animator = host
			-- Every clip is asked for now, so that the first sit or throw does not stand
			-- waiting for its clip to come.
			for _, id in clips do
				Moves.track(host, id :: string)
			end
			beginMode(training, modeGeneration)
		end)
	end

	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(model)
		if character == model then
			clearCharacter()
		end
	end)
	if player.Character then
		bindCharacter(player.Character)
	end

	-- State also arrives once per second with income. Only a changed training mode starts or
	-- stops a clip, so unchanged snapshots do not continually rewind the active loop.
	Store.onChange(function(snapshot)
		setTraining(snapshot.training)
	end)
	Remotes.KickResult.OnClientEvent:Connect(function(result: Net.KickResult?)
		local host = currentAnimator()
		if result and host then
			local throw =
				Moves.play(host, clips.Throw, Enum.AnimationPriority.Action4, false, THROW_FADE)
			-- Played slower than it was made (Animations.THROW_STRETCH): the server counts
			-- the kunai's leaving the hand by the same pace.
			if throw then
				throw:AdjustSpeed(Animations.throwSpeed())
			end
		end
	end)
	Remotes.RingResult.OnClientEvent:Connect(function(result: Net.RingResult)
		local host = currentAnimator()
		if training == "focus" and result.gain > 0 and host then
			Moves.play(host, clips.ChakraHit, Enum.AnimationPriority.Action2, false, FADE)
		end
	end)
end

return PlayerMoves
