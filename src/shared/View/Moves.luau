--!strict
-- Plays the animations of Config/Animations on a body: a player's character or an enemy's
-- model. An animation is loaded once per body and kept; one whose id is empty is never loaded,
-- and asking for it gives nil, so callers simply go without.
--
-- Shared because the server animates enemies and the client the player's own character (what
-- a client plays on its own character every other client sees as well).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)

local Moves = {}

-- Tracks already loaded, by animator and then by asset id. Weak keys: a body that is gone takes
-- its tracks with it.
local loaded: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

-- The body's Animator: the one under its Humanoid or AnimationController, made if missing.
-- A model with neither (an enemy imported without a Humanoid) gets an AnimationController,
-- which drives the bones of a skinned mesh or the Motor6D joints of a rig the same way.
function Moves.animator(model: Model): Animator
	local holder: Instance? = model:FindFirstChildWhichIsA("Humanoid", true)
		or model:FindFirstChildWhichIsA("AnimationController", true)
	if not holder then
		local controller = Instance.new("AnimationController")
		controller.Parent = model
		holder = controller
	end
	local found = (holder :: Instance):FindFirstChildOfClass("Animator")
	if found then
		return found
	end
	local animator = Instance.new("Animator")
	animator.Parent = holder
	return animator
end

-- The track of an animation on that animator, loaded the first time; nil when its id is empty
-- or it fails to load (a wrong id, or one the game's owner does not own).
function Moves.track(animator: Animator, id: string?): AnimationTrack?
	local asset = Animations.asset(id)
	if not asset then
		return nil
	end
	local tracks = loaded[animator]
	if not tracks then
		tracks = {}
		loaded[animator] = tracks
	end
	local track = tracks[asset]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = asset
		local ok, result = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not ok then
			warn(`Animation {asset} did not load: {result}`)
			return nil
		end
		track = result
		tracks[asset] = result
	end
	return track
end

-- Plays an animation on that animator; returns its track, or nil when there is none.
-- `fade` is how long it blends in, seconds.
function Moves.play(
	animator: Animator,
	id: string?,
	priority: Enum.AnimationPriority,
	looped: boolean,
	fade: number?
): AnimationTrack?
	local track = Moves.track(animator, id)
	if track then
		track.Priority = priority
		track.Looped = looped
		track:Play(fade or 0.15)
	end
	return track
end

-- Stops an animation if it is playing.
function Moves.stop(animator: Animator, id: string?, fade: number?)
	local asset = Animations.asset(id)
	local tracks = loaded[animator]
	local track = if asset and tracks then tracks[asset] else nil
	if track and track.IsPlaying then
		track:Stop(fade or 0.2)
	end
end

-- A rigged model's limbs must not be anchored for its joints to move them: frees every part a
-- Motor6D moves and keeps the rest (the root) anchored. A skinned mesh moves by its bones and
-- needs nothing.
function Moves.freeLimbs(model: Model)
	for _, joint in model:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part1 then
			joint.Part1.Anchored = false
		end
	end
end

return Moves
