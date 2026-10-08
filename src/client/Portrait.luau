--!strict
-- A character's portrait, taken from its own model: the model stands in a little scene of its
-- own inside the interface (a ViewportFrame) and a camera looks at its head and shoulders. So
-- every shinobi whose model has been supplied (see View/Figure) has its picture in the
-- inventory, the Bingo Book and the quick slots without anything being drawn or uploaded.
--
-- A scene like this is drawn once and kept until something in it changes, and nothing in it
-- ever does.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Figure = require(ReplicatedStorage.Shared.View.Figure)
local Ui = require("./Ui")

local Portrait = {}

-- The camera's angle of view, narrow so that a face is not bulged, and what it takes in: this
-- share of the figure's height, centered this far up it. A chibi is half head. A portrait of
-- the face alone takes in the head and no more.
local FIELD = 30
local SEEN = 0.8
local CENTER = 0.64
local FACE_SEEN = 0.52
local FACE_CENTER = 0.75

-- A model made ready once for each character and copied for every portrait of it.
local ready: { [string]: Model } = {}

local function modelOf(characterId: string): Model?
	local kept = ready[characterId]
	if not kept then
		local built = Figure.bare(characterId)
		if not built then
			return nil
		end
		ready[characterId] = built
		kept = built
	end
	return kept:Clone()
end

-- Fills `holder` with the portrait of that character and returns it, or returns nil when the
-- character has no model. `shadow` makes it a black outline of the character, for one that has
-- not been found yet; `face` moves in on the face. Whoever has a model under their id can be
-- photographed, a shopkeeper as well as a shinobi.
function Portrait.show(
	holder: Instance,
	characterId: string,
	shadow: boolean?,
	face: boolean?
): ViewportFrame?
	local model = modelOf(characterId)
	if not model then
		return nil
	end
	local scene: ViewportFrame = Ui.make("ViewportFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(190, 190, 190),
		LightColor = Color3.fromRGB(255, 244, 230),
		-- The light falls from over the camera's shoulder onto the face.
		LightDirection = Vector3.new(0.4, -1, 0.8),
		ImageColor3 = if shadow then Color3.new(0, 0, 0) else Ui.WHITE,
		ZIndex = 4,
	}, holder)
	model.Parent = scene

	-- A figure stands on the scene's origin with its face to -Z: the camera stands out that
	-- way, a little to one side and above, and looks back.
	local seen = if face then FACE_SEEN else SEEN
	local focus = Vector3.new(0, Figure.HEIGHT * (if face then FACE_CENTER else CENTER), 0)
	local away = Figure.HEIGHT * seen / 2 / math.tan(math.rad(FIELD / 2))
	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(away * 0.2, away * 0.08, -away), focus)
	camera.Parent = scene
	scene.CurrentCamera = camera
	return scene
end

return Portrait
