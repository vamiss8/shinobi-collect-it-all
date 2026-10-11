--!strict
-- Draft animations for Shinobi: Collect It All!: the throw, meditation and chakra control.
-- Rough blocking poses to start from, not finished animation: fix them by eye in the Animation
-- Editor before publishing. This is a Studio Command Bar script, not game code, and it uploads
-- nothing.
--
-- 1. Stop Play. A rig to pose: leave it to this script (it makes a plain R15 body itself, in
--    colors a pose can be read off, stands it where the camera looks and selects it), or
--    insert one (Avatar or Home tab -> Character -> R15; older Studios call it Rig Builder)
--    and select its Model.
-- 2. View -> Command Bar. Paste this whole script into it and run it.
-- 3. Avatar tab -> Animation Editor, click the rig. Asked about saved animations in an old
--    format, choose Migrate, and do not press Ctrl+Z after it. Then ... -> Load and pick one.
-- 4. Fix the poses. Keep the throw's "Release" marker at 0.75 s, where the kunai leaves the
--    hand, or set Animations.THROW_RELEASE to its new time.
-- 5. ... -> Publish to Roblox, as whoever owns the game (see the note on permissions in
--    src/shared/Config/Animations.luau), and put the six ids into that file under the same
--    names.
--
-- Saves that exist are never written over. A selected rig that already has any of the six
-- names is left alone and a new rig is made beside it, so running this again always gives a
-- fresh set of drafts and takes nothing away.
--
-- R15 looks toward -Z; its right side is +X. A positive turn about X swings a hanging limb
-- forward. All angles below are DEGREES; only LowerTorso is moved, so the root stays where it
-- is and the float of the meditation and the jump of the throw are for the eye alone.

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Selection = game:GetService("Selection")
local ServerStorage = game:GetService("ServerStorage")

type Rotation = { number }
type PoseFrame = {
	time: number,
	position: Vector3?,
	rotations: { [string]: Rotation },
	release: boolean?,
}
type Draft = {
	name: string,
	priority: Enum.AnimationPriority,
	looped: boolean,
	frames: { PoseFrame },
}

-- In this order a parent's pose exists before its child's is made. Every part is keyed on
-- every frame, so that the plain sit or run cannot show through a limb left out.
local skeleton = {
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
local names = { "Throw", "MeditateStart", "MeditateLoop", "MeditateEnd", "ChakraLoop", "ChakraHit" }
-- Where the Animation Editor keeps a rig's saves once it has taken them over.
local MIGRATED = "RBX_ANIMSAVES"
local RIG_NAME = "AnimationRig"

assert(not RunService:IsRunning(), "Stop Play/Run mode before creating animation drafts.")

-- Whether a model is a whole R15 body: every part there, and a joint from each to its parent.
local function isRig(model: Instance): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not model:IsA("Model") or not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return false
	end
	local parts: { [string]: BasePart } = {}
	for _, node in skeleton do
		local part = model:FindFirstChild(node[1])
		if not part or not part:IsA("BasePart") then
			return false
		end
		parts[node[1]] = part
	end
	for _, node in skeleton do
		if node[2] ~= "" then
			local connected = false
			for _, joint in model:GetDescendants() do
				if
					joint:IsA("Motor6D")
					and joint.Part0 == parts[node[2]]
					and joint.Part1 == parts[node[1]]
				then
					connected = true
					break
				end
			end
			if not connected then
				return false
			end
		end
	end
	return true
end

-- Where a rig's saved animations are: a Model or Folder named AnimSaves inside it (the old
-- way), or what its AnimSaves points at once the Animation Editor has taken them over. Nil
-- when it has none yet.
local function savesOf(model: Instance): Instance?
	local saves = model:FindFirstChild("AnimSaves")
	if saves and saves:IsA("ObjectValue") then
		return saves.Value
	end
	return saves
end

-- Whether a rig can take the drafts: none of the six names is taken on it.
local function free(model: Instance): boolean
	local saves = savesOf(model)
	if saves then
		for _, name in names do
			if saves:FindFirstChild(name) then
				return false
			end
		end
	end
	return true
end

-- A name no rig has yet, here or among the saves the editor keeps by a rig's name.
local function freeName(): (string, number)
	local kept = ServerStorage:FindFirstChild(MIGRATED)
	local count = 1
	local name = RIG_NAME
	while
		workspace:FindFirstChild(name)
		or ServerStorage:FindFirstChild(name)
		or (kept and kept:FindFirstChild(name))
	do
		count += 1
		name = RIG_NAME .. count
	end
	return name, count
end

-- A plain R15 body. One left at the default is black all over, and a pose cannot be read off
-- a black shape: skin for the head and the arms, green for the torso and brown for the legs,
-- so that an arm held before the chest is seen.
local function makeRig(): Model
	local look = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(234, 184, 146)
	local legs = Color3.fromRGB(196, 112, 60)
	look.HeadColor, look.LeftArmColor, look.RightArmColor = skin, skin, skin
	look.TorsoColor = Color3.fromRGB(40, 127, 71)
	look.LeftLegColor, look.RightLegColor = legs, legs
	local ok, made = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(look, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		-- The name this call had before; a Studio that has not the new one has this.
		ok, made = pcall(function()
			return (Players :: any):CreateHumanoidModelFromDescription(
				look,
				Enum.HumanoidRigType.R15
			)
		end)
	end
	assert(
		ok and made and isRig(made),
		"Could not make a rig: insert one with Avatar tab -> Character -> R15, select it and run this again"
	)
	local name, count = freeName()
	made.Name = name
	-- Beside the rigs made before it, not inside them.
	local at = workspace.CurrentCamera.Focus.Position + Vector3.new(6 * (count - 1), 0, 0)
	made:PivotTo(CFrame.new(at))
	return made
end

local selected = Selection:Get()
local chosen: Model? = if #selected == 1 and isRig(selected[1]) then selected[1] :: Model else nil
local taken = chosen ~= nil and not free(chosen)
local rig: Model = if chosen and not taken then chosen else makeRig()
local fresh = rig ~= chosen

local function poseTransform(rotation: Rotation?, position: Vector3?): CFrame
	local angles = rotation or { 0, 0, 0 }
	local offset = position or Vector3.zero
	return CFrame.new(offset.X, offset.Y, offset.Z)
		* CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
end

-- Reusable poses are copied before adding per-frame adjustments. A single frame's arm
-- or head edit must not silently modify every other keyframe sharing the base stance.
local function stance(
	base: { [string]: Rotation },
	changes: { [string]: Rotation }?
): { [string]: Rotation }
	local result = table.clone(base)
	if changes then
		for part, rotation in changes do
			result[part] = rotation
		end
	end
	return result
end

-- Half-lotus blocking: one shin is tucked more tightly across the opposite thigh.
-- The editor should refine this on the actual avatar proportions to avoid intersections.
local lotus = {
	LowerTorso = { 0, 0, 0 },
	UpperTorso = { -4, 0, 0 },
	Head = { 4, 0, 0 },
	RightUpperLeg = { 72, 25, -38 },
	RightLowerLeg = { -118, 0, 0 },
	RightFoot = { 20, -15, 0 },
	LeftUpperLeg = { 86, -30, 42 },
	LeftLowerLeg = { -132, 0, 0 },
	LeftFoot = { 25, 20, 0 },
	RightUpperArm = { 30, 0, -18 },
	RightLowerArm = { 85, 0, 0 },
	RightHand = { -10, 30, -15 },
	LeftUpperArm = { 30, 0, 18 },
	LeftLowerArm = { 85, 0, 0 },
	LeftHand = { -10, -30, 15 },
}

-- Positive Z at the right hip and negative Z at the left hip widen the stance.
-- Shoulder Z rotates inward so the bent forearms meet in front of the chest.
local chakra = {
	LowerTorso = { 0, 0, 0 },
	UpperTorso = { 2, 0, 0 },
	Head = { -2, 0, 0 },
	RightUpperLeg = { 6, 0, 13 },
	RightLowerLeg = { -12, 0, 0 },
	RightFoot = { 6, -10, -6 },
	LeftUpperLeg = { 6, 0, -13 },
	LeftLowerLeg = { -12, 0, 0 },
	LeftFoot = { 6, 10, 6 },
	RightUpperArm = { 42, 0, -23 },
	RightLowerArm = { 95, 0, 0 },
	RightHand = { -10, 35, -15 },
	LeftUpperArm = { 42, 0, 23 },
	LeftLowerArm = { 95, 0, 0 },
	LeftHand = { -10, -35, 15 },
}

local drafts: { Draft } = {
	{
		name = "Throw",
		priority = Enum.AnimationPriority.Action4,
		looped = false,
		frames = {
			{ time = 0, rotations = {} },
			{
				time = 0.12,
				rotations = {
					UpperTorso = { 12, -10, 0 },
					RightUpperArm = { -35, 0, -10 },
					RightLowerArm = { 50, 0, 0 },
					LeftUpperArm = { 45, 0, 10 },
					LeftLowerArm = { 70, 0, 0 },
					RightUpperLeg = { 40, 0, 0 },
					RightLowerLeg = { -35, 0, 0 },
					LeftUpperLeg = { -30, 0, 0 },
					LeftLowerLeg = { -50, 0, 0 },
				},
			},
			{
				time = 0.25,
				rotations = {
					UpperTorso = { 15, 15, 0 },
					RightUpperArm = { 45, 0, -15 },
					RightLowerArm = { 75, 0, 0 },
					LeftUpperArm = { -40, 0, 10 },
					LeftLowerArm = { 60, 0, 0 },
					RightUpperLeg = { -25, 0, 0 },
					RightLowerLeg = { -55, 0, 0 },
					LeftUpperLeg = { 45, 0, 0 },
					LeftLowerLeg = { -40, 0, 0 },
				},
			},
			{
				time = 0.38,
				position = Vector3.new(0, -0.25, 0),
				rotations = {
					LowerTorso = { 8, 0, 0 },
					UpperTorso = { 20, -20, 0 },
					RightUpperArm = { -50, 0, -25 },
					RightLowerArm = { 70, 0, 0 },
					LeftUpperArm = { -25, 0, 15 },
					LeftLowerArm = { 55, 0, 0 },
					RightUpperLeg = { 45, 0, 0 },
					RightLowerLeg = { -70, 0, 0 },
					LeftUpperLeg = { 40, 0, 0 },
					LeftLowerLeg = { -65, 0, 0 },
				},
			},
			{
				time = 0.55,
				position = Vector3.new(0, 0.85, 0),
				rotations = {
					LowerTorso = { -5, -95, 0 },
					UpperTorso = { -8, -20, -10 },
					Head = { 0, 20, 0 },
					RightUpperArm = { 135, -25, -35 },
					RightLowerArm = { 100, 0, 0 },
					LeftUpperArm = { 70, 0, 25 },
					LeftLowerArm = { 45, 0, 0 },
					RightUpperLeg = { 65, 0, -5 },
					RightLowerLeg = { -100, 0, 0 },
					LeftUpperLeg = { 30, 0, 5 },
					LeftLowerLeg = { -75, 0, 0 },
				},
			},
			{
				time = 0.66,
				position = Vector3.new(0, 1.05, 0),
				rotations = {
					LowerTorso = { 0, -180, 0 },
					UpperTorso = { -8, -35, -8 },
					Head = { 5, 25, 0 },
					RightUpperArm = { 150, -35, -30 },
					RightLowerArm = { 105, 0, 0 },
					RightHand = { 0, 0, -15 },
					LeftUpperArm = { 80, 0, 30 },
					LeftLowerArm = { 35, 0, 0 },
					RightUpperLeg = { 55, 0, 0 },
					RightLowerLeg = { -80, 0, 0 },
					LeftUpperLeg = { -10, 0, 0 },
					LeftLowerLeg = { -55, 0, 0 },
				},
			},
			{
				time = 0.75,
				position = Vector3.new(0, 0.9, 0),
				release = true,
				rotations = {
					-- The half-turn is followed by a rapid unwind toward the target. The
					-- right arm is extended toward local -Z exactly at the Release marker.
					LowerTorso = { 8, -20, 0 },
					UpperTorso = { 15, 20, 8 },
					Head = { -8, 0, 0 },
					RightUpperArm = { 95, 0, -8 },
					RightLowerArm = { 5, 0, 0 },
					RightHand = { -10, 0, 0 },
					LeftUpperArm = { -30, 0, 25 },
					LeftLowerArm = { 45, 0, 0 },
					RightUpperLeg = { 35, 0, 0 },
					RightLowerLeg = { -60, 0, 0 },
					LeftUpperLeg = { -20, 0, 0 },
					LeftLowerLeg = { -45, 0, 0 },
				},
			},
			{
				time = 0.9,
				position = Vector3.new(0, 0.45, 0),
				rotations = {
					UpperTorso = { 20, 25, 8 },
					RightUpperArm = { 65, 20, 25 },
					RightLowerArm = { 20, 0, 0 },
					LeftUpperArm = { -20, 0, 15 },
					RightUpperLeg = { 30, 0, 0 },
					RightLowerLeg = { -45, 0, 0 },
					LeftUpperLeg = { 10, 0, 0 },
					LeftLowerLeg = { -25, 0, 0 },
				},
			},
			{
				time = 1.05,
				position = Vector3.new(0, -0.2, 0),
				rotations = {
					UpperTorso = { 18, 10, 0 },
					RightUpperArm = { 20, 0, -15 },
					LeftUpperArm = { 20, 0, 15 },
					RightUpperLeg = { 35, 0, 0 },
					RightLowerLeg = { -60, 0, 0 },
					LeftUpperLeg = { 35, 0, 0 },
					LeftLowerLeg = { -60, 0, 0 },
				},
			},
			{ time = 1.25, rotations = {} },
		},
	},
	{
		name = "MeditateStart",
		priority = Enum.AnimationPriority.Action,
		looped = false,
		frames = {
			{ time = 0, rotations = {} },
			{
				time = 0.25,
				position = Vector3.new(0, 0.25, 0),
				rotations = stance(lotus, {
					RightUpperLeg = { 42, 12, -20 },
					RightLowerLeg = { -70, 0, 0 },
					LeftUpperLeg = { 50, -18, 25 },
					LeftLowerLeg = { -80, 0, 0 },
				}),
			},
			{ time = 0.55, position = Vector3.new(0, 0.9, 0), rotations = stance(lotus) },
			{ time = 0.7, position = Vector3.new(0, 1, 0), rotations = stance(lotus) },
		},
	},
	{
		name = "MeditateLoop",
		priority = Enum.AnimationPriority.Action,
		looped = true,
		frames = {
			{ time = 0, position = Vector3.new(0, 1, 0), rotations = stance(lotus) },
			{
				time = 0.75,
				position = Vector3.new(0, 1.12, 0),
				rotations = stance(lotus, { UpperTorso = { -6, 0, 2 }, Head = { 6, 0, -2 } }),
			},
			{ time = 1.5, position = Vector3.new(0, 1, 0), rotations = stance(lotus) },
			{
				time = 2.25,
				position = Vector3.new(0, 0.9, 0),
				rotations = stance(lotus, { UpperTorso = { -2, 0, -2 }, Head = { 2, 0, 2 } }),
			},
			{ time = 3, position = Vector3.new(0, 1, 0), rotations = stance(lotus) },
		},
	},
	{
		name = "MeditateEnd",
		priority = Enum.AnimationPriority.Action,
		looped = false,
		frames = {
			{ time = 0, position = Vector3.new(0, 1, 0), rotations = stance(lotus) },
			{
				time = 0.25,
				position = Vector3.new(0, 0.3, 0),
				rotations = {
					RightUpperLeg = { 35, 10, -18 },
					RightLowerLeg = { -60, 0, 0 },
					LeftUpperLeg = { 40, -10, 20 },
					LeftLowerLeg = { -65, 0, 0 },
					RightUpperArm = { 20, 0, -10 },
					RightLowerArm = { 40, 0, 0 },
					LeftUpperArm = { 20, 0, 10 },
					LeftLowerArm = { 40, 0, 0 },
				},
			},
			{ time = 0.5, rotations = {} },
		},
	},
	{
		name = "ChakraLoop",
		priority = Enum.AnimationPriority.Action,
		looped = true,
		frames = {
			{ time = 0, rotations = stance(chakra) },
			{
				time = 1,
				rotations = stance(chakra, {
					UpperTorso = { 0, 0, 0 },
					Head = { 0, 0, 0 },
					RightUpperArm = { 44, 0, -23 },
					LeftUpperArm = { 44, 0, 23 },
				}),
			},
			{ time = 2, rotations = stance(chakra) },
		},
	},
	{
		name = "ChakraHit",
		priority = Enum.AnimationPriority.Action2,
		looped = false,
		frames = {
			{ time = 0, rotations = stance(chakra) },
			{
				time = 0.06,
				rotations = stance(chakra, {
					UpperTorso = { -5, 0, 0 },
					RightUpperArm = { 35, 0, -23 },
					LeftUpperArm = { 35, 0, 23 },
					RightLowerArm = { 110, 0, 0 },
					LeftLowerArm = { 110, 0, 0 },
				}),
			},
			{
				time = 0.14,
				rotations = stance(chakra, {
					UpperTorso = { 12, 0, 0 },
					Head = { -12, 0, 0 },
					RightUpperArm = { 86, 0, -13 },
					LeftUpperArm = { 86, 0, 13 },
					RightLowerArm = { 8, 0, 0 },
					LeftLowerArm = { 8, 0, 0 },
					RightHand = { -12, 15, -10 },
					LeftHand = { -12, -15, 10 },
				}),
			},
			{ time = 0.4, rotations = stance(chakra) },
		},
	},
}

local sequences: { KeyframeSequence } = {}
for _, draft in drafts do
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = draft.name
	sequence.Priority = draft.priority
	sequence.Loop = draft.looped
	sequence:SetAttribute("ShinobiAnimationDraft", true)
	for _, frame in draft.frames do
		local keyframe = Instance.new("Keyframe")
		keyframe.Name = if frame.release then "Release" else "Pose"
		keyframe.Time = frame.time
		keyframe.Parent = sequence
		local poses: { [string]: Pose } = {}
		for _, node in skeleton do
			local partName, parentName = node[1], node[2]
			local pose = Instance.new("Pose")
			pose.Name = partName
			pose.CFrame = poseTransform(
				frame.rotations[partName],
				if partName == "LowerTorso" then frame.position else nil
			)
			pose.Weight = if partName == "HumanoidRootPart" then 0 else 1
			pose.EasingStyle = Enum.PoseEasingStyle.Cubic
			pose.EasingDirection = Enum.PoseEasingDirection.InOut
			pose.Parent = if parentName == "" then keyframe else poses[parentName]
			poses[partName] = pose
		end
		if frame.release then
			local marker = Instance.new("KeyframeMarker")
			marker.Name = "Release"
			marker.Value = ""
			marker.Parent = keyframe
		end
	end
	table.insert(sequences, sequence)
end

-- Everything is built before the place is touched, so that a failure above leaves nothing
-- half made, and Studio has one step to undo.
ChangeHistoryService:SetWaypoint("Before Shinobi animation drafts")
if fresh then
	rig.Parent = workspace
end
local saves = savesOf(rig)
if not saves then
	-- The old way, which the Animation Editor offers to take over when the rig is clicked.
	local model = Instance.new("Model")
	model.Name = "AnimSaves"
	model.Parent = rig
	saves = model
end
for _, sequence in sequences do
	sequence.Parent = saves
end
Selection:Set({ rig })
ChangeHistoryService:SetWaypoint("Create Shinobi animation drafts")

if taken then
	print(
		"The selected rig already has saves under these names: they were left alone and a new rig was made, "
			.. rig.Name
	)
end
print(
	"Six drafts are on "
		.. rig:GetFullName()
		.. ". Open the Animation Editor, click the rig (Migrate if asked), then ... -> Load."
)
