--!strict
-- Smooth R15 meditation drafts for Shinobi: Collect It All!
-- Run ONCE from Roblox Studio > View > Command Bar while Play/Run is stopped.
-- It creates a NEW independent R15 rig with MeditateStart, MeditateLoop and MeditateEnd.
-- Does not overwrite existing rigs, upload animations, touch DataStores or commit anything.
-- Publish each clip from Animation Editor and replace its ID in
-- src/shared/Config/Animations.luau for the actual game to play these new motions.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

assert(not RunService:IsRunning(), "Stop Play/Run before creating meditation drafts")

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

-- No two-pose snap: lift and folding happen together, across SEVEN keyframes.
-- rise: torso offset in studs; fold: fraction of final half-lotus pose.
-- Both finish gently. First and last loop keys EXACTLY match the start's last key.
local startFrames = {
	{ time = 0.00, rise = 0.00, fold = 0.00 },
	{ time = 0.30, rise = 0.06, fold = 0.07 },
	{ time = 0.65, rise = 0.22, fold = 0.23 },
	{ time = 1.00, rise = 0.46, fold = 0.47 },
	{ time = 1.35, rise = 0.73, fold = 0.73 },
	{ time = 1.70, rise = 0.93, fold = 0.92 },
	{ time = 2.05, rise = 1.00, fold = 1.00 },
}

local loopFrames = {
	{ time = 0.00, rise = 1.00, fold = 1.00 },
	{ time = 1.50, rise = 1.00, fold = 1.00 },
}

local endFrames = {
	{ time = 0.00, rise = 1.00, fold = 1.00 },
	{ time = 0.35, rise = 0.93, fold = 0.92 },
	{ time = 0.70, rise = 0.73, fold = 0.73 },
	{ time = 1.05, rise = 0.46, fold = 0.47 },
	{ time = 1.40, rise = 0.22, fold = 0.23 },
	{ time = 1.75, rise = 0.06, fold = 0.07 },
	{ time = 2.05, rise = 0.00, fold = 0.00 },
}

local function makeSequence(name: string, frames, looped: boolean): KeyframeSequence
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
			local angles = halfLotus[partName]
			local x = if angles then math.rad(angles[1] * frame.fold) else 0
			local y = if angles then math.rad(angles[2] * frame.fold) else 0
			local z = if angles then math.rad(angles[3] * frame.fold) else 0
			local displacement = if partName == "LowerTorso" then frame.rise else 0
			pose.CFrame = CFrame.new(0, displacement, 0) * CFrame.Angles(x, y, z)
			pose.Weight = if partName == "HumanoidRootPart" then 0 else 1
			pose.EasingStyle = Enum.PoseEasingStyle.Cubic
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
