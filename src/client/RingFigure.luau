--!strict
-- The player's own character at the Chakra Control board (client FocusPanel), doing the
-- chakra-control animation: a copy of it in a little scene of its own (a ViewportFrame), which
-- only this client sees. The board stands low in the middle of the screen, over where the
-- character is, so the copy is how the player sees themselves train.
--
-- IT STANDS BESIDE THE RINGS, NOT BEHIND THEM. It was first drawn on the target's own sheet,
-- inside the rings; the owner: "it looks cool, but it is in the way, being behind the very
-- actions of the mini-game; something else has to be thought of, the animation stays". So the
-- board has a small scroll of its own for it, and this module only fills the sheet it is
-- handed: the rings have the target to themselves.
--
-- The copy is made when the training starts, so it wears what the character wears then, and
-- is thrown away when it ends. With no chakra-control animation (Config/Animations) there is
-- no copy at all, and the scroll stays away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animations = require(ReplicatedStorage.Shared.Config.Animations)
local Moves = require(ReplicatedStorage.Shared.View.Moves)
local Ui = require("./Ui")

local RingFigure = {}

export type Controller = {
	-- The training has begun or ended: the copy is made, or thrown away.
	setOpen: (open: boolean) -> (),
	-- A press hit: the copy answers as the character does.
	hit: () -> (),
}

local R15_BODY: { string } = {
	"Head",
	"LowerTorso",
	"UpperTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}
local R6_BODY: { string } = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

-- A character may be there before the rest of its body is. A Humanoid and a root are not
-- enough for a portrait: wait for the whole body, hands and feet included.
local function bodyReady(character: Model, humanoid: Humanoid): boolean
	local names: { string } = if humanoid.RigType == Enum.HumanoidRigType.R15
		then R15_BODY
		else R6_BODY
	for _, name in names do
		local part = character:FindFirstChild(name)
		if not part or not part:IsA("BasePart") then
			return false
		end
	end
	return true
end

-- A player's character is not archivable as a rule. The flag is put back even if the copying
-- fails, so that this portrait never changes how anything else sees the player.
local function cloneCharacter(character: Model): Model?
	local archivable = character.Archivable
	character.Archivable = true
	local ok, result = pcall(function()
		return character:Clone()
	end)
	character.Archivable = archivable
	if not ok then
		warn("Cannot copy the player for the Chakra Control board: " .. tostring(result))
		return nil
	end
	return result :: Model?
end

-- Keeps the body, the clothes and the accessories, and nothing that runs, floats over the
-- character or comes off it. A Model right under the character is a shinobi carried, not a
-- part of the body.
local function strip(copy: Model)
	for _, child in copy:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	for _, item in copy:GetDescendants() do
		if
			item:IsA("LuaSourceContainer")
			or item:IsA("Tool")
			or item:IsA("BillboardGui")
			or item:IsA("ParticleEmitter")
			or item:IsA("Trail")
			or item:IsA("Sound")
			or item:IsA("ForceField")
		then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			-- A player in first person is unseen by their own camera: not so here.
			item.LocalTransparencyModifier = 0
		end
	end
end

-- Stands the camera so that every corner of the body's box is in the picture, whatever the
-- sheet's shape: a distance that fits the height alone would crop broad shoulders on a narrow
-- sheet. A little room is left for the hands going forward at a hit.
local function frameBody(camera: Camera, viewport: ViewportFrame, box: CFrame, size: Vector3)
	local pixels = viewport.AbsoluteSize
	local aspect = if pixels.Y > 0 then math.max(pixels.X / pixels.Y, 0.1) else 1
	local vertical = math.tan(math.rad(camera.FieldOfView / 2))
	local horizontal = vertical * aspect
	-- From in front of the body (its face is to -Z), a little to its side and from above.
	local direction = Vector3.new(0.22, 0.05, -1).Unit
	local center = box.Position
	local facing = CFrame.lookAt(center + direction, center)
	local half = size / 2
	local distance = 0.5
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner =
					box:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
				local offset = corner - center
				local depth = offset:Dot(direction)
				distance = math.max(
					distance,
					math.abs(offset:Dot(facing.RightVector)) / horizontal + depth,
					math.abs(offset:Dot(facing.UpVector)) / vertical + depth
				)
			end
		end
	end
	camera.CFrame = CFrame.lookAt(center + direction * distance * 1.2, center)
	camera.Focus = CFrame.new(center)
end

-- Keeps a copy of the player on `stage` while the training is open, filling it. `shown` is
-- told when a copy has come to stand there and when it is gone, so that whoever owns the
-- stage can bring it up and take it away.
function RingFigure.start(stage: Frame, shown: (there: boolean) -> ()): Controller
	local player = Players.LocalPlayer
	local opened = false
	local destroyed = false
	local source: Model? = nil
	local viewport: ViewportFrame? = nil
	local animator: Animator? = nil
	local connections: { RBXScriptConnection } = {}

	local function clearFigure()
		animator = nil
		local scene = viewport
		if scene then
			viewport = nil
			scene:Destroy()
			shown(false)
		end
	end

	local function unwatch()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		source = nil
		clearFigure()
	end

	local function configured(): boolean
		return Animations.asset(Animations.player.ChakraLoop) ~= nil
			or Animations.asset(Animations.player.ChakraHit) ~= nil
	end

	local function watch(character: Model?)
		unwatch()
		if not opened or not configured() or not character then
			return
		end
		source = character
		local attempted = false
		local humanoidWatching: Humanoid? = nil

		local function show()
			if attempted or not opened or destroyed or player.Character ~= character then
				return
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not root or not root:IsA("BasePart") or not humanoid then
				return
			end
			if humanoidWatching ~= humanoid then
				humanoidWatching = humanoid
				table.insert(connections, humanoid.Died:Connect(clearFigure))
			end
			if
				humanoid.Health <= 0
				or not character.Parent
				or not bodyReady(character, humanoid)
			then
				return
			end
			attempted = true
			local copy = cloneCharacter(character)
			if not copy then
				return
			end
			strip(copy)
			local copyRoot = copy:FindFirstChild("HumanoidRootPart")
			local copyHumanoid = copy:FindFirstChildOfClass("Humanoid")
			if not copyRoot or not copyRoot:IsA("BasePart") or not copyHumanoid then
				copy:Destroy()
				return
			end
			copyRoot.Anchored = true
			copyHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			copyHumanoid.AutoRotate = false
			copy.PrimaryPart = copyRoot
			copy:PivotTo(CFrame.new())

			local scene: ViewportFrame = Ui.make("ViewportFrame", {
				Name = "RingFigure",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Active = false,
				Selectable = false,
				Ambient = Color3.fromRGB(200, 200, 200),
				LightColor = Color3.new(1, 1, 1),
				LightDirection = Vector3.new(-1, -1, -1),
			}, stage)
			-- Animations only play in a WorldModel.
			local world: WorldModel = Ui.make("WorldModel", {}, scene)
			copy.Parent = world
			local camera: Camera = Ui.make("Camera", {
				CameraType = Enum.CameraType.Scriptable,
				FieldOfView = 35,
			}, scene)
			scene.CurrentCamera = camera
			local box, size = copy:GetBoundingBox()
			frameBody(camera, scene, box, size)
			table.insert(
				connections,
				scene:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
					frameBody(camera, scene, box, size)
				end)
			)
			viewport = scene
			local host = Moves.animator(copy)
			animator = host
			Moves.play(
				host,
				Animations.player.ChakraLoop,
				Enum.AnimationPriority.Action,
				true,
				0.15
			)
			shown(true)
		end

		-- Opened in the middle of a respawn, the character may be there before all of its
		-- body: wait for the body to come, rather than copy anew with every snapshot.
		table.insert(connections, character.ChildAdded:Connect(show))
		table.insert(
			connections,
			character.ChildRemoved:Connect(function(child: Instance)
				if child.Name == "HumanoidRootPart" or child == humanoidWatching then
					clearFigure()
				end
			end)
		)
		table.insert(
			connections,
			character.AncestryChanged:Connect(function()
				if character.Parent then
					show()
				else
					clearFigure()
				end
			end)
		)
		show()
	end

	local added = player.CharacterAdded:Connect(function(character: Model)
		watch(character)
	end)
	-- Hats and clothes can come after the body. The copy is made once more when Roblox has
	-- finished dressing the character, so one made during a respawn has the whole outfit.
	local appearance = player.CharacterAppearanceLoaded:Connect(function(character: Model)
		if source == character then
			watch(character)
		end
	end)
	local removing = player.CharacterRemoving:Connect(function(character: Model)
		if source == character then
			unwatch()
		end
	end)
	-- The board outlives respawns; should it ever be taken down, its listeners go with it.
	stage.Destroying:Connect(function()
		destroyed = true
		added:Disconnect()
		appearance:Disconnect()
		removing:Disconnect()
		unwatch()
	end)

	return {
		setOpen = function(open: boolean)
			if destroyed or opened == open then
				return
			end
			opened = open
			watch(if open then player.Character else nil)
		end,
		hit = function()
			if opened and animator then
				Moves.play(
					animator,
					Animations.player.ChakraHit,
					Enum.AnimationPriority.Action2,
					false,
					0.05
				)
			end
		end,
	}
end

return RingFigure
