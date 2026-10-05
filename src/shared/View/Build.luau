--!strict
-- Small constructors for the placeholder world: anchored parts, prompts and labels.

local Build = {}

function Build.part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- An invisible wall. It stops characters but not raycasts, so the camera does not zoom in when
-- a wall ends up between it and the player.
function Build.wall(parent: Instance, name: string, size: Vector3, position: Vector3): Part
	local wall = Build.part(parent, name, size, position, Color3.new(1, 1, 1))
	wall.Transparency = 1
	wall.CanQuery = false
	wall.CastShadow = false
	return wall
end

-- An interaction prompt ("press E"). It works on keyboard, touch and gamepad out of the box.
function Build.prompt(parent: Instance, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

-- A text label floating `offsetY` studs above `parent`. `size` is in studs, so the label
-- shrinks with distance like a real sign.
function Build.label(parent: Instance, text: string, offsetY: number, size: Vector2): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size.X, size.Y)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 400
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.PermanentMarker
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.RichText = true
	label.Text = text
	label.Parent = gui
	return label
end

-- Text painted on one face of a part, filling it. Unlike a floating label it turns with the
-- part and is hidden from behind. Returns the label and the gui that holds it.
function Build.faceLabel(part: BasePart, face: Enum.NormalId, text: string): (TextLabel, SurfaceGui)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.9, 0.84)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.PermanentMarker
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	return label, gui
end

return Build
