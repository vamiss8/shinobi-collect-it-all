--!strict
-- Smooth R15 meditation drafts for Shinobi: Collect It All! The co-author's (2026-10-15),
-- reworked the same day at the owner's word: "it rises into the pose in pieces, not smoothly,
-- though the moves themselves are not bad; and in the loop it levitates quite still, not even
-- swaying".
--
-- Run from Roblox Studio's Command Bar while Play/Run is stopped. It makes a NEW R15 rig,
-- MeditationSmoothRig, with MeditateStart, MeditateLoop and MeditateEnd in its AnimSaves, and
-- touches nothing else. Publish each from the Animation Editor and put its id into
-- src/shared/Config/Animations.luau.
--
-- WHY IT ROSE IN PIECES: a pose's easing is how it moves on to the NEXT key, and every pose
-- eased in and out (Cubic InOut), so the body came to a stop at each of the seven keys on its
-- way up. Now the way up is one curve that eases at its two ends only, keyed often and drawn
-- straight (Linear) from key to key.
--
-- The game lifts the character as well (Humanoid.HipHeight, Services/Training), over
-- Animations.MEDITATE_RISE seconds, which is RISE_SECONDS here: change the two together.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

assert(not RunService:IsRunning(), "Stop Play/Run before creating meditation drafts")

-- The way up: how long, and how many straight pieces it is drawn in.
local RISE_SECONDS = 2.05
local RISE_STEPS = 12
-- The way down, when the player walks off or jumps: short, since it plays over the walk.
local END_SECONDS = 0.5
local END_STEPS = 4
-- One breath of the loop, in and out, and how far the body rises on the breath in, studs.
local BREATH_SECONDS = 3.6
local BOB = 0.18

local hierarchy = {
	{ "HumanoidRootPart", "" },
	{ "LowerTorso", "HumanoidRootPart" },
	{ "UpperTorso", "LowerTorso" },
	{ "Head", "UpperTorso" },
	{ "RightUpperArm", "UpperTorso" },
	{ "RightLowerArm", "RightUpperArm" },
	{ "RightHand", "RightLowerArm" },
	{ "LeftUpperArm", "UpperTorso" },
	{ "LeftLowerArm", "LeftUpperArm" },
	{ "LeftHand", "LeftLowerArm" },
	{ "RightUpperLeg", "LowerTorso" },
	{ "RightLowerLeg", "RightUpperLeg" },
	{ "RightFoot", "RightLowerLeg" },
	{ "LeftUpperLeg", "LowerTorso" },
	{ "LeftLowerLeg", "LeftUpperLeg" },
	{ "LeftFoot", "LeftLowerLeg" },
}

-- One leg folds under the other; the second foot comes across the thigh.
-- This is deliberately asymmetric (half-lotus, not a mirror-image full lotus).
-- Angles are DEGREES and intended for a standard R15 body.
local halfLotus: { [string]: { number } } = {
	LowerTorso = { 0, 0, 0 },
	UpperTorso = { -3, 0, 0 },
	Head = { 3, 0, 0 },
	RightUpperLeg = { 77, 26, -37 },
	RightLowerLeg = { -118, -4, 5 },
	RightFoot = { 21, -13, 3 },
	LeftUpperLeg = { 83, -29, 41 },
	LeftLowerLeg = { -125, 4, -4 },
	LeftFoot = { 11, 17, -3 },
	RightUpperArm = { 25, 0, -14 },
	RightLowerArm = { 73, 0, 0 },
	RightHand = { -8, 22, -8 },
	LeftUpperArm = { 25, 0, 14 },
	LeftLowerArm = { 73, 0, 0 },
	LeftHand = { -8, -22, 8 },
}

-- What a breath in adds to the lotus at its top: the chest straightens a little, the head
-- stays level with it, the elbows drift out. A positive turn about X tips an upright part back.
local breathIn: { [string]: { number } } = {
	UpperTorso = { 3, 0, 0 },
	Head = { -3, 0, 0 },
	RightUpperArm = { 0, 0, 3 },
	LeftUpperArm = { 0, 0, -3 },
}

-- rise: the torso's offset in studs; fold: the share of the lotus; breath: the share of a
-- breath in; easing: how the pose moves on to the next key.
type Frame = {
	time: number,
	rise: number,
	fold: number,
	breath: number,
	easing: Enum.PoseEasingStyle,
}

-- 0 at rest, 1 at the end, slow at both ends and nowhere else.
local function ease(share: number): number
	return (1 - math.cos(math.pi * share)) / 2
end

-- From one depth of the pose to another along `ease`, in `steps` straight pieces.
local function glide(seconds: number, steps: number, from: number, to: number): { Frame }
	local frames: { Frame } = {}
	for step = 0, steps do
		local amount = from + (to - from) * ease(step / steps)
		table.insert(frames, {
			time = seconds * step / steps,
			rise = amount,
			fold = amount,
			breath = 0,
			easing = Enum.PoseEasingStyle.Linear,
		})
	end
	return frames
end

-- The way up ends at rest in the full pose, which is where the loop begins, also at rest.
local startFrames = glide(RISE_SECONDS, RISE_STEPS, 0, 1)
local endFrames = glide(END_SECONDS, END_STEPS, 1, 0)
-- A breath in and out. Its keys are only where the motion turns, so easing in and out between
-- them is what a sway is.
local loopFrames: { Frame } = {
	{ time = 0, rise = 1, fold = 1, breath = 0, easing = Enum.PoseEasingStyle.Cubic },
	{
		time = BREATH_SECONDS / 2,
		rise = 1 + BOB,
		fold = 1,
		breath = 1,
		easing = Enum.PoseEasingStyle.Cubic,
	},
	{ time = BREATH_SECONDS, rise = 1, fold = 1, breath = 0, easing = Enum.PoseEasingStyle.Cubic },
}

local function makeSequence(name: string, frames: { Frame }, looped: boolean): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Loop = looped
	seq.Priority = Enum.AnimationPriority.Action
	seq:SetAttribute("ShinobiSmoothMeditation", true)

	for _, frame in frames do
		local key = Instance.new("Keyframe")
		key.Name = "Pose"
		key.Time = frame.time
		key.Parent = seq
		local poses: { [string]: Pose } = {}

		for _, entry in hierarchy do
			local partName, parentName = entry[1], entry[2]
			local pose = Instance.new("Pose")
			pose.Name = partName
			local lotus = halfLotus[partName] or { 0, 0, 0 }
			local breath = breathIn[partName] or { 0, 0, 0 }
			local function turn(axis: number): number
				return math.rad(lotus[axis] * frame.fold + breath[axis] * frame.breath)
			end
			local displacement = if partName == "LowerTorso" then frame.rise else 0
			pose.CFrame = CFrame.new(0, displacement, 0) * CFrame.Angles(turn(1), turn(2), turn(3))
			pose.Weight = if partName == "HumanoidRootPart" then 0 else 1
			pose.EasingStyle = frame.easing
			pose.EasingDirection = Enum.PoseEasingDirection.InOut
			pose.Parent = if parentName == "" then key else poses[parentName]
			poses[partName] = pose
		end
	end
	return seq
end

local sequences = {
	makeSequence("MeditateStart", startFrames, false),
	makeSequence("MeditateLoop", loopFrames, true),
	makeSequence("MeditateEnd", endFrames, false),
}

-- Create a fresh rig. No existing published draft is overwritten.
local rig: Model? = nil
local success, result = pcall(function(): Model
	return Players:CreateHumanoidModelFromDescriptionAsync(
		Instance.new("HumanoidDescription"),
		Enum.HumanoidRigType.R15
	)
end)
if success and typeof(result) == "Instance" and result:IsA("Model") then
	rig = result
else
	local fallbackOk, fallback = pcall(function(): Model
		return (Players :: any):CreateHumanoidModelFromDescription(
			Instance.new("HumanoidDescription"),
			Enum.HumanoidRigType.R15
		)
	end)
	if fallbackOk and typeof(fallback) == "Instance" and fallback:IsA("Model") then
		rig = fallback
	else
		error("Could not make a new R15 rig. Check Studio network/access, then retry.")
	end
end

local newRig = rig :: Model
local index = 1
local name = "MeditationSmoothRig"
while workspace:FindFirstChild(name) do
	index += 1
	name = "MeditationSmoothRig" .. index
end
newRig.Name = name
local camera = workspace.CurrentCamera
newRig:PivotTo(
	CFrame.new(
		if camera then camera.Focus.Position + Vector3.new(6, 0, 0) else Vector3.new(0, 5, 0)
	)
)

local root = newRig:FindFirstChild("HumanoidRootPart")
if root and root:IsA("BasePart") then
	root.Anchored = true
end

local saved = Instance.new("Model")
saved.Name = "AnimSaves"
saved.Parent = newRig
for _, sequence in sequences do
	sequence.Parent = saved
end

ChangeHistoryService:SetWaypoint("Before smooth meditation drafts")
newRig.Parent = workspace
Selection:Set({ newRig })
ChangeHistoryService:SetWaypoint("Create smooth meditation drafts")

print("Created " .. newRig:GetFullName() .. " with MeditateStart / MeditateLoop / MeditateEnd")
print("Animation Editor -> select this R15 rig -> Load each sequence -> Publish to Roblox")
print("Then replace the 3 Meditate* asset IDs in src/shared/Config/Animations.luau")
