--!strict
-- The player's own moves (Config/Animations), played on their character; what a client plays
-- on its own character every other player sees too.
--   The throw: when the server takes the press. The kunai leaves on the animation's "Release"
--     frame, because the server holds the flight back that long (Services/Kicking).
--   Meditation: sitting into the pose, then the pose in a loop for as long as it lasts, then
--     getting up. It plays over the plain sit the server puts the character in.
--   Chakra control: the loop for as long as the training lasts, and a jolt on every hit.
-- A move whose id is empty is skipped and the game looks as it did without it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Moves = require(ReplicatedStorage.Shared.View.Moves)
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Store = require("./Store")

local PlayerMoves = {}

local ids = Animations.player
local ACTION = Enum.AnimationPriority.Action
-- A hit plays over the chakra loop, so it sits a level higher.
local OVER = Enum.AnimationPriority.Action2

-- The animator of the player's current character, if it has one yet.
local function animator(): Animator?
	local character = Players.LocalPlayer.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return if humanoid then humanoid:FindFirstChildOfClass("Animator") else nil
end

-- Sits into the pose and holds it. The loop fades in over the last moment of the sitting down,
-- so the pose never drops back to the plain sit in between; without a sitting-down animation it
-- starts at once.
local LOOP_OVERLAP = 0.15

local function startMeditating(on: Animator)
	local start = Moves.play(on, ids.MeditateStart, ACTION, false, 0.2)
	if not start then
		Moves.play(on, ids.MeditateLoop, ACTION, true, 0.2)
		return
	end
	task.spawn(function()
		-- A track knows its length only once its animation has loaded.
		local waited = 0
		while start.Length <= 0 and waited < 2 do
			waited += task.wait()
		end
		task.wait(math.max(start.Length - LOOP_OVERLAP - waited, 0))
		local state = Store.get()
		if start.IsPlaying and state and state.training == "meditate" then
			Moves.play(on, ids.MeditateLoop, ACTION, true, LOOP_OVERLAP)
		end
	end)
end

local function stopMeditating(on: Animator)
	Moves.stop(on, ids.MeditateStart, 0.1)
	Moves.stop(on, ids.MeditateLoop, 0.15)
	Moves.play(on, ids.MeditateEnd, ACTION, false, 0.1)
end

function PlayerMoves.start()
	local training: string? = nil
	Store.onChange(function(state)
		if state.training == training then
			return
		end
		local before = training
		training = state.training
		local on = animator()
		if not on then
			return
		end
		if before == "meditate" then
			stopMeditating(on)
		elseif before == "focus" then
			Moves.stop(on, ids.ChakraLoop)
		end
		if training == "meditate" then
			startMeditating(on)
		elseif training == "focus" then
			Moves.play(on, ids.ChakraLoop, ACTION, true, 0.2)
		end
	end)

	Remotes.RingResult.OnClientEvent:Connect(function(hit: Net.RingResult)
		local on = animator()
		if on and hit.gain > 0 then
			Moves.play(on, ids.ChakraHit, OVER, false, 0.05)
		end
	end)

	-- The server has taken the press: the throw starts now and the kunai leaves the hand on its
	-- "Release" frame. A cancelled bar (nil) is no throw.
	Remotes.KickResult.OnClientEvent:Connect(function(result: Net.KickResult?)
		local on = animator()
		if on and result then
			Moves.play(on, ids.Throw, Enum.AnimationPriority.Action4, false, 0.05)
		end
	end)
end

return PlayerMoves
