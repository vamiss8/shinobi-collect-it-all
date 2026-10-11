-- Draft animations for Shinobi: Collect It All!: the throw, meditation and chakra control.
-- Rough poses to start from; fix them by eye in the Animation Editor before publishing.
--
-- 1. A rig to pose. Either leave it to this script: with no rig selected it makes a plain R15
--    body itself and stands it where the camera looks. Or insert one: Avatar (or Home) tab ->
--    Character -> R15, any body (the tool is the Rig Generator; older Studios call it Rig
--    Builder), and select the new "Rig" in the Explorer.
-- 2. View -> Command Bar. Paste this whole script into it and press Enter.
-- 3. Avatar tab -> Animation Editor, click the rig. Asked about saved animations in an old
--    format, choose Migrate. Then ... -> Load and pick an animation.
-- 4. Fix the poses, then ... -> Publish to Roblox, as whoever owns the game (see the note on
--    permissions in src/shared/Config/Animations.luau). Copy the id into that file under the
--    same name.
-- The throw has a marker "Release" where the kunai leaves the hand; if you move that moment,
-- set Animations.THROW_RELEASE to its new time.
--
-- Each pose is { x, y, z, rx, ry, rz }: a move (only LowerTorso has one) and the joint's turn
-- in degrees, as CFrame.Angles takes them.

local Players = game:GetService("Players")
local Selection = game:GetService("Selection")

-- The rig the drafts go on: the R15 rig selected in the Explorer, or, with none selected, a
-- plain R15 body made here and stood where the camera looks.
local rig = Selection:Get()[1]
if not (rig and rig:FindFirstChild("LowerTorso")) then
	-- A body left at the default is black all over, and a pose cannot be read off a black
	-- shape: skin for the head and arms, green for the torso and brown for the legs, so that
	-- an arm held before the chest is seen.
	local look = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(234, 184, 146)
	look.HeadColor, look.LeftArmColor, look.RightArmColor = skin, skin, skin
	look.TorsoColor = Color3.fromRGB(40, 127, 71)
	look.LeftLegColor, look.RightLegColor =
		Color3.fromRGB(196, 112, 60), Color3.fromRGB(196, 112, 60)
	local ok, made = pcall(function()
		return Players:CreateHumanoidModelFromDescription(look, Enum.HumanoidRigType.R15)
	end)
	assert(
		ok and made and made:FindFirstChild("LowerTorso"),
		"Could not make a rig: insert one with Avatar tab -> Character -> R15, select it and run this again"
	)
	rig = made
	rig.Name = "AnimationRig"
	rig:PivotTo(CFrame.new(workspace.CurrentCamera.Focus.Position))
	rig.Parent = workspace
	Selection:Set({ rig })
end

local TREE = {
	HumanoidRootPart = { "LowerTorso" },
	LowerTorso = { "UpperTorso", "LeftUpperLeg", "RightUpperLeg" },
	UpperTorso = { "Head", "LeftUpperArm", "RightUpperArm" },
	LeftUpperArm = { "LeftLowerArm" },
	LeftLowerArm = { "LeftHand" },
	RightUpperArm = { "RightLowerArm" },
	RightLowerArm = { "RightHand" },
	LeftUpperLeg = { "LeftLowerLeg" },
	LeftLowerLeg = { "LeftFoot" },
	RightUpperLeg = { "RightLowerLeg" },
	RightLowerLeg = { "RightFoot" },
}

local ANIMATIONS = {
	Throw = {
		looped = false,
		priority = Enum.AnimationPriority.Action4,
		markers = { Release = 0.75 },
		keys = {
			{
				time = 0,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.2, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -8, -10, 0 },
					RightUpperArm = { 0, 0, 0, -35, 0, 25 },
					RightLowerArm = { 0, 0, 0, 40, 0, 0 },
					LeftUpperArm = { 0, 0, 0, 30, 0, -10 },
					LeftLowerArm = { 0, 0, 0, 30, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 10, 0, 0 },
					RightLowerLeg = { 0, 0, 0, -20, 0, 0 },
					LeftUpperLeg = { 0, 0, 0, 10, 0, 0 },
					LeftLowerLeg = { 0, 0, 0, -20, 0, 0 },
				},
			},
			{
				time = 0.18,
				easing = Enum.PoseEasingStyle.Linear,
				pose = {
					LowerTorso = { 0, -0.1, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -14, 0, 0 },
					LeftUpperLeg = { 0, 0, 0, 45, 0, 0 },
					LeftLowerLeg = { 0, 0, 0, -35, 0, 0 },
					LeftFoot = { 0, 0, 0, -10, 0, 0 },
					RightUpperLeg = { 0, 0, 0, -30, 0, 0 },
					RightLowerLeg = { 0, 0, 0, -50, 0, 0 },
					RightFoot = { 0, 0, 0, 20, 0, 0 },
					RightUpperArm = { 0, 0, 0, -45, 0, 15 },
					RightLowerArm = { 0, 0, 0, 50, 0, 0 },
					LeftUpperArm = { 0, 0, 0, -30, 0, 0 },
					LeftLowerArm = { 0, 0, 0, 40, 0, 0 },
				},
			},
			{
				time = 0.36,
				easing = Enum.PoseEasingStyle.Linear,
				pose = {
					LowerTorso = { 0, -0.1, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -14, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 45, 0, 0 },
					RightLowerLeg = { 0, 0, 0, -35, 0, 0 },
					RightFoot = { 0, 0, 0, -10, 0, 0 },
					LeftUpperLeg = { 0, 0, 0, -30, 0, 0 },
					LeftLowerLeg = { 0, 0, 0, -50, 0, 0 },
					LeftFoot = { 0, 0, 0, 20, 0, 0 },
					RightUpperArm = { 0, 0, 0, -20, 0, 15 },
					RightLowerArm = { 0, 0, 0, 50, 0, 0 },
					LeftUpperArm = { 0, 0, 0, 45, 0, 0 },
					LeftLowerArm = { 0, 0, 0, 40, 0, 0 },
				},
			},
			{
				time = 0.55,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, 0.5, 0, 0, -25, 0 },
					UpperTorso = { 0, 0, 0, 5, -30, 0 },
					Head = { 0, 0, 0, 0, 40, 0 },
					RightUpperArm = { 0, 0, 0, -150, 0, 20 },
					RightLowerArm = { 0, 0, 0, 70, 0, 0 },
					LeftUpperArm = { 0, 0, 0, 90, 20, -20 },
					LeftLowerArm = { 0, 0, 0, 5, 0, 0 },
					LeftUpperLeg = { 0, 0, 0, 60, 0, 0 },
					LeftLowerLeg = { 0, 0, 0, -70, 0, 0 },
					RightUpperLeg = { 0, 0, 0, -10, 0, 0 },
					RightLowerLeg = { 0, 0, 0, -60, 0, 0 },
				},
			},
			{
				time = 0.75,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, 0.15, 0, 0, 20, 0 },
					UpperTorso = { 0, 0, 0, -22, 25, 0 },
					Head = { 0, 0, 0, 10, -15, 0 },
					RightUpperArm = { 0, 0, 0, 105, 0, -10 },
					RightLowerArm = { 0, 0, 0, 5, 0, 0 },
					LeftUpperArm = { 0, 0, 0, -30, 0, -25 },
					LeftLowerArm = { 0, 0, 0, 40, 0, 0 },
					LeftUpperLeg = { 0, 0, 0, 40, 0, 0 },
					LeftLowerLeg = { 0, 0, 0, -30, 0, 0 },
					RightUpperLeg = { 0, 0, 0, -35, 0, 0 },
					RightLowerLeg = { 0, 0, 0, -40, 0, 0 },
				},
			},
			{
				time = 0.95,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.7, 0, 0, 15, 0 },
					UpperTorso = { 0, 0, 0, -25, 15, 0 },
					Head = { 0, 0, 0, 10, 0, 0 },
					RightUpperArm = { 0, 0, 0, 55, 0, -35 },
					RightLowerArm = { 0, 0, 0, 20, 0, 0 },
					LeftUpperArm = { 0, 0, 0, -25, 0, -20 },
					LeftLowerArm = { 0, 0, 0, 30, 0, 0 },
					LeftUpperLeg = { 0, 0, 0, 75, 0, 0 },
					LeftLowerLeg = { 0, 0, 0, -85, 0, 0 },
					LeftFoot = { 0, 0, 0, 10, 0, 0 },
					RightUpperLeg = { 0, 0, 0, -25, 0, 0 },
					RightLowerLeg = { 0, 0, 0, -95, 0, 0 },
					RightFoot = { 0, 0, 0, 30, 0, 0 },
				},
			},
			{ time = 1.25, easing = Enum.PoseEasingStyle.Cubic, pose = {} },
		},
	},
	MeditateStart = {
		looped = false,
		priority = Enum.AnimationPriority.Action,
		markers = {},
		keys = {
			{ time = 0, easing = Enum.PoseEasingStyle.Cubic, pose = {} },
			{
				time = 0.35,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.95, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -12, 0, 0 },
					Head = { 0, 0, 0, -8, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 90, 0, 45 },
					LeftUpperLeg = { 0, 0, 0, 90, 0, -45 },
					RightLowerLeg = { 0, 0, 0, 0, 0, -125 },
					LeftLowerLeg = { 0, 0, 0, 0, 0, 125 },
					RightUpperArm = { 0, 0, 0, 20, 0, -10 },
					LeftUpperArm = { 0, 0, 0, 20, 0, 10 },
					RightLowerArm = { 0, 0, 0, 70, 0, -35 },
					LeftLowerArm = { 0, 0, 0, 70, 0, 35 },
				},
			},
			{
				time = 0.7,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.6, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -2, 0, 0 },
					Head = { 0, 0, 0, -8, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 90, 0, 45 },
					LeftUpperLeg = { 0, 0, 0, 90, 0, -45 },
					RightLowerLeg = { 0, 0, 0, 0, 0, -125 },
					LeftLowerLeg = { 0, 0, 0, 0, 0, 125 },
					RightUpperArm = { 0, 0, 0, 20, 0, -10 },
					LeftUpperArm = { 0, 0, 0, 20, 0, 10 },
					RightLowerArm = { 0, 0, 0, 70, 0, -35 },
					LeftLowerArm = { 0, 0, 0, 70, 0, 35 },
				},
			},
		},
	},
	MeditateLoop = {
		looped = true,
		priority = Enum.AnimationPriority.Action,
		markers = {},
		keys = {
			{
				time = 0,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.6, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -2, 0, 0 },
					Head = { 0, 0, 0, -8, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 90, 0, 45 },
					LeftUpperLeg = { 0, 0, 0, 90, 0, -45 },
					RightLowerLeg = { 0, 0, 0, 0, 0, -125 },
					LeftLowerLeg = { 0, 0, 0, 0, 0, 125 },
					RightUpperArm = { 0, 0, 0, 20, 0, -10 },
					LeftUpperArm = { 0, 0, 0, 20, 0, 10 },
					RightLowerArm = { 0, 0, 0, 70, 0, -35 },
					LeftLowerArm = { 0, 0, 0, 70, 0, 35 },
				},
			},
			{
				time = 1.5,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.42, 0, 0, 0, 0 },
					Head = { 0, 0, 0, -8, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 90, 0, 45 },
					LeftUpperLeg = { 0, 0, 0, 90, 0, -45 },
					RightLowerLeg = { 0, 0, 0, 0, 0, -125 },
					LeftLowerLeg = { 0, 0, 0, 0, 0, 125 },
					RightUpperArm = { 0, 0, 0, 20, 0, -12 },
					LeftUpperArm = { 0, 0, 0, 20, 0, 12 },
					RightLowerArm = { 0, 0, 0, 70, 0, -35 },
					LeftLowerArm = { 0, 0, 0, 70, 0, 35 },
				},
			},
			{
				time = 3,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.6, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -2, 0, 0 },
					Head = { 0, 0, 0, -8, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 90, 0, 45 },
					LeftUpperLeg = { 0, 0, 0, 90, 0, -45 },
					RightLowerLeg = { 0, 0, 0, 0, 0, -125 },
					LeftLowerLeg = { 0, 0, 0, 0, 0, 125 },
					RightUpperArm = { 0, 0, 0, 20, 0, -10 },
					LeftUpperArm = { 0, 0, 0, 20, 0, 10 },
					RightLowerArm = { 0, 0, 0, 70, 0, -35 },
					LeftLowerArm = { 0, 0, 0, 70, 0, 35 },
				},
			},
		},
	},
	MeditateEnd = {
		looped = false,
		priority = Enum.AnimationPriority.Action,
		markers = {},
		keys = {
			{
				time = 0,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.6, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -2, 0, 0 },
					Head = { 0, 0, 0, -8, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 90, 0, 45 },
					LeftUpperLeg = { 0, 0, 0, 90, 0, -45 },
					RightLowerLeg = { 0, 0, 0, 0, 0, -125 },
					LeftLowerLeg = { 0, 0, 0, 0, 0, 125 },
					RightUpperArm = { 0, 0, 0, 20, 0, -10 },
					LeftUpperArm = { 0, 0, 0, 20, 0, 10 },
					RightLowerArm = { 0, 0, 0, 70, 0, -35 },
					LeftLowerArm = { 0, 0, 0, 70, 0, 35 },
				},
			},
			{
				time = 0.2,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.95, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -12, 0, 0 },
					Head = { 0, 0, 0, -8, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 90, 0, 45 },
					LeftUpperLeg = { 0, 0, 0, 90, 0, -45 },
					RightLowerLeg = { 0, 0, 0, 0, 0, -125 },
					LeftLowerLeg = { 0, 0, 0, 0, 0, 125 },
					RightUpperArm = { 0, 0, 0, 20, 0, -10 },
					LeftUpperArm = { 0, 0, 0, 20, 0, 10 },
					RightLowerArm = { 0, 0, 0, 70, 0, -35 },
					LeftLowerArm = { 0, 0, 0, 70, 0, 35 },
				},
			},
			{ time = 0.5, easing = Enum.PoseEasingStyle.Cubic, pose = {} },
		},
	},
	ChakraLoop = {
		looped = true,
		priority = Enum.AnimationPriority.Action,
		markers = {},
		keys = {
			{
				time = 0,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.25, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -6, 0, 0 },
					Head = { 0, 0, 0, 4, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 15, 0, 12 },
					LeftUpperLeg = { 0, 0, 0, 15, 0, -12 },
					RightLowerLeg = { 0, 0, 0, -30, 0, 0 },
					LeftLowerLeg = { 0, 0, 0, -30, 0, 0 },
					RightFoot = { 0, 0, 0, 15, 0, -10 },
					LeftFoot = { 0, 0, 0, 15, 0, 10 },
					RightUpperArm = { 0, 0, 0, 45, 0, -22 },
					LeftUpperArm = { 0, 0, 0, 45, 0, 22 },
					RightLowerArm = { 0, 0, 0, 95, 0, -40 },
					LeftLowerArm = { 0, 0, 0, 95, 0, 40 },
				},
			},
			{
				time = 1,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.3, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -8, 0, 0 },
					Head = { 0, 0, 0, 4, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 15, 0, 12 },
					LeftUpperLeg = { 0, 0, 0, 15, 0, -12 },
					RightLowerLeg = { 0, 0, 0, -30, 0, 0 },
					LeftLowerLeg = { 0, 0, 0, -30, 0, 0 },
					RightFoot = { 0, 0, 0, 15, 0, -10 },
					LeftFoot = { 0, 0, 0, 15, 0, 10 },
					RightUpperArm = { 0, 0, 0, 48, 0, -22 },
					LeftUpperArm = { 0, 0, 0, 48, 0, 22 },
					RightLowerArm = { 0, 0, 0, 95, 0, -40 },
					LeftLowerArm = { 0, 0, 0, 95, 0, 40 },
				},
			},
			{
				time = 2,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.25, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -6, 0, 0 },
					Head = { 0, 0, 0, 4, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 15, 0, 12 },
					LeftUpperLeg = { 0, 0, 0, 15, 0, -12 },
					RightLowerLeg = { 0, 0, 0, -30, 0, 0 },
					LeftLowerLeg = { 0, 0, 0, -30, 0, 0 },
					RightFoot = { 0, 0, 0, 15, 0, -10 },
					LeftFoot = { 0, 0, 0, 15, 0, 10 },
					RightUpperArm = { 0, 0, 0, 45, 0, -22 },
					LeftUpperArm = { 0, 0, 0, 45, 0, 22 },
					RightLowerArm = { 0, 0, 0, 95, 0, -40 },
					LeftLowerArm = { 0, 0, 0, 95, 0, 40 },
				},
			},
		},
	},
	ChakraHit = {
		looped = false,
		priority = Enum.AnimationPriority.Action2,
		markers = {},
		keys = {
			{
				time = 0,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.25, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -6, 0, 0 },
					Head = { 0, 0, 0, 4, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 15, 0, 12 },
					LeftUpperLeg = { 0, 0, 0, 15, 0, -12 },
					RightLowerLeg = { 0, 0, 0, -30, 0, 0 },
					LeftLowerLeg = { 0, 0, 0, -30, 0, 0 },
					RightFoot = { 0, 0, 0, 15, 0, -10 },
					LeftFoot = { 0, 0, 0, 15, 0, 10 },
					RightUpperArm = { 0, 0, 0, 45, 0, -22 },
					LeftUpperArm = { 0, 0, 0, 45, 0, 22 },
					RightLowerArm = { 0, 0, 0, 95, 0, -40 },
					LeftLowerArm = { 0, 0, 0, 95, 0, 40 },
				},
			},
			{
				time = 0.1,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.4, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -14, 0, 0 },
					Head = { 0, 0, 0, 4, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 15, 0, 12 },
					LeftUpperLeg = { 0, 0, 0, 15, 0, -12 },
					RightLowerLeg = { 0, 0, 0, -30, 0, 0 },
					LeftLowerLeg = { 0, 0, 0, -30, 0, 0 },
					RightFoot = { 0, 0, 0, 15, 0, -10 },
					LeftFoot = { 0, 0, 0, 15, 0, 10 },
					RightUpperArm = { 0, 0, 0, 88, 0, -12 },
					LeftUpperArm = { 0, 0, 0, 88, 0, 12 },
					RightLowerArm = { 0, 0, 0, 12, 0, -10 },
					LeftLowerArm = { 0, 0, 0, 12, 0, 10 },
				},
			},
			{
				time = 0.4,
				easing = Enum.PoseEasingStyle.Cubic,
				pose = {
					LowerTorso = { 0, -0.25, 0, 0, 0, 0 },
					UpperTorso = { 0, 0, 0, -6, 0, 0 },
					Head = { 0, 0, 0, 4, 0, 0 },
					RightUpperLeg = { 0, 0, 0, 15, 0, 12 },
					LeftUpperLeg = { 0, 0, 0, 15, 0, -12 },
					RightLowerLeg = { 0, 0, 0, -30, 0, 0 },
					LeftLowerLeg = { 0, 0, 0, -30, 0, 0 },
					RightFoot = { 0, 0, 0, 15, 0, -10 },
					LeftFoot = { 0, 0, 0, 15, 0, 10 },
					RightUpperArm = { 0, 0, 0, 45, 0, -22 },
					LeftUpperArm = { 0, 0, 0, 45, 0, 22 },
					RightLowerArm = { 0, 0, 0, 95, 0, -40 },
					LeftLowerArm = { 0, 0, 0, 95, 0, 40 },
				},
			},
		},
	},
}

local function turn(values)
	local x, y, z, rx, ry, rz = table.unpack(values or { 0, 0, 0, 0, 0, 0 })
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
end

local function addPose(parent, name, values, easing)
	local pose = Instance.new("Pose")
	pose.Name = name
	pose.CFrame = if name == "HumanoidRootPart" then CFrame.new() else turn(values[name])
	pose.EasingStyle = easing
	pose.EasingDirection = Enum.PoseEasingDirection.InOut
	pose.Parent = parent
	for _, child in TREE[name] or {} do
		addPose(pose, child, values, easing)
	end
end

local saves = rig:FindFirstChild("AnimSaves")
if not saves then
	saves = Instance.new("Model")
	saves.Name = "AnimSaves"
	saves.Parent = rig
end

for name, spec in ANIMATIONS do
	local old = saves:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = spec.looped
	sequence.Priority = spec.priority
	for _, key in spec.keys do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = key.time
		addPose(keyframe, "HumanoidRootPart", key.pose, key.easing)
		for marker, at in spec.markers do
			if math.abs(at - key.time) < 1e-6 then
				local mark = Instance.new("KeyframeMarker")
				mark.Name = marker
				keyframe:AddMarker(mark)
			end
		end
		keyframe.Parent = sequence
	end
	sequence.Parent = saves
end

print(
	"Draft animations are in " .. saves:GetFullName() .. ": open them with Animation Editor -> Load"
)
