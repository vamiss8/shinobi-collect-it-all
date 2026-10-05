--!strict
-- The game's icons. Each function fills the given square holder. An icon is drawn from plain
-- frames, sized in fractions of its holder so it scales with whatever it is put in; if Art
-- lists an uploaded picture for it, the picture takes the drawing's place once it has loaded.
-- So the game works with no images at all, takes them one at a time, and never shows an empty
-- square for one that is still in moderation.

local Art = require("./Art")
local Ui = require("./Ui")

local Icons = {}

local PARCHMENT = Color3.fromRGB(236, 220, 188)
local INK = Color3.fromRGB(70, 52, 40)
local WOOD = Color3.fromRGB(141, 98, 72)
local DARK_WOOD = Color3.fromRGB(93, 64, 55)
local SEAL_RED = Color3.fromRGB(198, 40, 40)
local DEEP_RED = Color3.fromRGB(140, 24, 24)
local COVER = Color3.fromRGB(69, 39, 30)
local SPINE = Color3.fromRGB(46, 26, 20)
local GOLD = Color3.fromRGB(255, 202, 40)
local DARK_GOLD = Color3.fromRGB(204, 142, 20)
local PALE_GOLD = Color3.fromRGB(255, 226, 120)
local BLUE = Color3.fromRGB(79, 195, 247)
local PALE_BLUE = Color3.fromRGB(190, 232, 255)
local DEEP_BLUE = Color3.fromRGB(30, 120, 190)
local SKIN = Color3.fromRGB(255, 219, 172)
local STEEL = Color3.fromRGB(176, 190, 197)
-- The color of the panels icons sit on; a shape in it reads as a hole.
local NIGHT = Ui.PANEL

-- A filled shape: position and size as fractions of the holder, corners as a fraction of the
-- shape's shorter side (0.5 makes a pill or a circle).
local function shape(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	height: number,
	color: Color3,
	rounding: number
): Frame
	local frame = Ui.make("Frame", {
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(width, height),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, parent)
	if rounding > 0 then
		Ui.make("UICorner", { CornerRadius = UDim.new(rounding, 0) }, frame)
	end
	return frame
end

-- How long a picture is waited for before the drawing is left in place for good, seconds.
local PATIENCE = 60

-- Lays the uploaded picture of that asset id over what has been drawn in the holder, and takes
-- the drawing away once the picture has really loaded. An image that is still in moderation,
-- or was turned down, loads as nothing; the drawing then simply stays. Call it last, after the
-- icon is drawn. Does nothing when there is no picture (the id is 0 or missing).
local function overlay(holder: Instance, assetId: number?)
	if not assetId or assetId == 0 then
		return
	end
	local drawn = holder:GetChildren()
	local image: ImageLabel = Ui.make("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Image = `rbxassetid://{assetId}`,
		ZIndex = 5,
	}, holder)
	task.spawn(function()
		for _ = 1, PATIENCE * 2 do
			if not image.Parent then
				return
			end
			if image.IsLoaded then
				for _, piece in drawn do
					if piece:IsA("GuiObject") then
						piece.Visible = false
					end
				end
				return
			end
			task.wait(0.5)
		end
	end)
end

-- A storage scroll: written parchment between two wooden rollers, closed with a red seal. In
-- the world of shinobi this is what things are kept in, which makes it the inventory.
function Icons.scroll(holder: Instance)
	shape(holder, 0.14, 0.26, 0.72, 0.48, PARCHMENT, 0.06)
	for _, x in { 0.25, 0.65 } do
		shape(holder, x, 0.36, 0.10, 0.04, INK, 0.5)
		shape(holder, x, 0.60, 0.10, 0.04, INK, 0.5)
	end
	for _, x in { 0.05, 0.80 } do
		shape(holder, x, 0.14, 0.15, 0.72, DARK_WOOD, 0.5)
		shape(holder, x + 0.04, 0.22, 0.04, 0.56, WOOD, 0.5)
	end
	shape(holder, 0.38, 0.38, 0.24, 0.24, SEAL_RED, 0.5)
	shape(holder, 0.455, 0.455, 0.09, 0.09, DEEP_RED, 0.5)
	overlay(holder, Art.icons.scroll)
end

-- A book with a name plate, a wanted mark on its cover and a red ribbon: the Bingo Book.
function Icons.book(holder: Instance)
	shape(holder, 0.20, 0.14, 0.68, 0.76, PARCHMENT, 0.06) -- the pages, showing past the cover
	shape(holder, 0.14, 0.10, 0.68, 0.76, COVER, 0.08)
	shape(holder, 0.14, 0.10, 0.13, 0.76, SPINE, 0.2)
	shape(holder, 0.34, 0.22, 0.40, 0.17, PARCHMENT, 0.15)
	shape(holder, 0.40, 0.29, 0.28, 0.03, INK, 0.5)
	shape(holder, 0.42, 0.50, 0.24, 0.24, SEAL_RED, 0.5)
	shape(holder, 0.48, 0.56, 0.12, 0.12, COVER, 0.5)
	shape(holder, 0.70, 0.06, 0.08, 0.34, SEAL_RED, 0)
	overlay(holder, Art.icons.book)
end

-- A Ryo coin: gold, with a rim and a square hole to string it by.
function Icons.coin(holder: Instance)
	shape(holder, 0.08, 0.08, 0.84, 0.84, DARK_GOLD, 0.5)
	shape(holder, 0.13, 0.13, 0.74, 0.74, GOLD, 0.5)
	shape(holder, 0.24, 0.24, 0.52, 0.52, DARK_GOLD, 0.5)
	shape(holder, 0.28, 0.28, 0.44, 0.44, PALE_GOLD, 0.5)
	shape(holder, 0.41, 0.41, 0.18, 0.18, NIGHT, 0.12)
	overlay(holder, Art.icons.coin)
end

-- Chakra: a blue flame, a round body under a pointed tip, with a paler heart.
function Icons.chakra(holder: Instance)
	shape(holder, 0.36, 0.10, 0.28, 0.28, BLUE, 0.1).Rotation = 45
	shape(holder, 0.18, 0.28, 0.64, 0.64, BLUE, 0.5)
	shape(holder, 0.43, 0.36, 0.14, 0.14, PALE_BLUE, 0.1).Rotation = 45
	shape(holder, 0.34, 0.50, 0.32, 0.32, PALE_BLUE, 0.5)
	overlay(holder, Art.icons.chakra)
end

-- Meditation: a figure sitting cross-legged, hands on its knees, inside a glow.
function Icons.meditate(holder: Instance)
	shape(holder, 0.10, 0.12, 0.80, 0.80, DEEP_BLUE, 0.5).BackgroundTransparency = 0.55
	shape(holder, 0.16, 0.66, 0.68, 0.20, BLUE, 0.5)
	shape(holder, 0.36, 0.38, 0.28, 0.36, BLUE, 0.3)
	shape(holder, 0.39, 0.14, 0.22, 0.22, SKIN, 0.5)
	shape(holder, 0.20, 0.62, 0.10, 0.10, SKIN, 0.5)
	shape(holder, 0.70, 0.62, 0.10, 0.10, SKIN, 0.5)
	overlay(holder, Art.icons.meditate)
end

-- Chakra control: the closing ring around its golden target, as in the exercise itself.
function Icons.focus(holder: Instance)
	shape(holder, 0.08, 0.08, 0.84, 0.84, PARCHMENT, 0.5)
	shape(holder, 0.15, 0.15, 0.70, 0.70, NIGHT, 0.5)
	shape(holder, 0.26, 0.26, 0.48, 0.48, GOLD, 0.5)
	shape(holder, 0.33, 0.33, 0.34, 0.34, NIGHT, 0.5)
	shape(holder, 0.43, 0.43, 0.14, 0.14, BLUE, 0.5)
	overlay(holder, Art.icons.focus)
end

-- The portrait of a character: a small shinobi in the given color with a forehead protector,
-- or the character's picture if Art has one.
function Icons.shinobi(holder: Instance, characterId: string, color: Color3)
	shape(holder, 0.26, 0.46, 0.48, 0.48, color, 0.18)
	shape(holder, 0.31, 0.08, 0.38, 0.38, SKIN, 0.5)
	shape(holder, 0.31, 0.18, 0.38, 0.08, NIGHT, 0)
	shape(holder, 0.43, 0.17, 0.14, 0.10, STEEL, 0.2)
	overlay(holder, Art.portraits[characterId])
end

return Icons
