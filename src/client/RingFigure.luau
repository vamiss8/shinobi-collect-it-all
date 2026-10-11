--!strict
-- The player's own character inside the rings of chakra control (client/FocusPanel), doing the
-- chakra-control animation. The window stays where it is, in the middle of the screen, and the
-- player still sees their character train: a copy of it stands in a little scene of its own
-- (a ViewportFrame) behind the rings, so the closing ring reads as its chakra gathering in.
--
-- The copy is made when the training starts, so it wears what the character wears then, and
-- is thrown away when it ends. Its animations play in the scene's WorldModel, which only this
-- client sees. Until the chakra-control animation is made (Config/Animations) the copy simply
-- stands there.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Moves = require(ReplicatedStorage.Shared.View.Moves)
local Ui = require("./Ui")

local RingFigure = {}

-- Where the scene is drawn among what shares its holder: over whatever is there at the default
-- 1, and under what the caller lifts past this. Not 0: a layer made in code draws by ZIndex
-- across the whole layer, and at 0 the figure would lie under the board it stands on.
RingFigure.Z = 2

export type Shown = {
	hit: () -> (),
	destroy: () -> (),
}

-- The camera's angle of view and how much of the body it takes in, studs: the whole figure
-- with a little room over the head.
local FIELD = 30
local SEEN = 6.4
-- How far below the root the middle of what the camera takes in is, studs (the root sits at
-- the hips of an R15 body, the feet about 3 studs below it).
local DROP = 0.3

-- Everything a copy of the character can do without: what runs, what floats over it and what
-- it carries (the shinobi over its head, a tool in its hand, the look of its speed stage).
local function strip(copy: Model)
	for _, item in copy:GetDescendants() do
		if
			item:IsA("LuaSourceContainer")
			or item:IsA("Tool")
			or item:IsA("BillboardGui")
			or item:IsA("ParticleEmitter")
			or item:IsA("Trail")
			or item:IsA("Sound")
			or item:IsA("ForceField")
			or (item:IsA("Model") and item.Parent == copy)
		then
			item:Destroy()
		end
	end
end

-- A copy of the player's character standing at the origin, facing -Z; nil without one.
local function copyCharacter(): Model?
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	local archivable = character.Archivable
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = archivable
	if not copy then
		return nil
	end
	strip(copy)
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local root = copy:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.Anchored = true
	end
	copy:PivotTo(CFrame.new())
	return copy
end

-- Shows the character in `holder`, filling it, at RingFigure.Z among what else is in it. Nil
-- when there is no character to copy.
function RingFigure.show(holder: GuiObject): Shown?
	local copy = copyCharacter()
	if not copy then
		return nil
	end
	local scene: ViewportFrame = Ui.make("ViewportFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.fromRGB(200, 230, 255),
		LightDirection = Vector3.new(0.4, -1, 0.8),
		ImageTransparency = 0.1,
		ZIndex = RingFigure.Z,
	}, holder)
	-- Animations only play in a WorldModel.
	local world = Instance.new("WorldModel")
	world.Parent = scene
	copy.Parent = world

	local focus = Vector3.new(0, -DROP, 0)
	local away = SEEN / 2 / math.tan(math.rad(FIELD / 2))
	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(away * 0.25, away * 0.1, -away), focus)
	camera.Parent = scene
	scene.CurrentCamera = camera

	local animator = Moves.animator(copy)
	Moves.play(animator, Animations.player.ChakraLoop, Enum.AnimationPriority.Action, true, 0)

	return {
		hit = function()
			Moves.play(
				animator,
				Animations.player.ChakraHit,
				Enum.AnimationPriority.Action2,
				false,
				0.05
			)
		end,
		destroy = function()
			scene:Destroy()
		end,
	}
end

return RingFigure
