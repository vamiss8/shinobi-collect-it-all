--!strict
-- Icons drawn from plain frames, so the game needs no uploaded images. Each function fills the
-- given square holder; everything inside is sized in fractions of it, so an icon scales with
-- whatever it is put in.

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
end

-- A Ryo coin: gold, with a rim and a square hole to string it by.
function Icons.coin(holder: Instance)
	shape(holder, 0.08, 0.08, 0.84, 0.84, DARK_GOLD, 0.5)
	shape(holder, 0.13, 0.13, 0.74, 0.74, GOLD, 0.5)
	shape(holder, 0.24, 0.24, 0.52, 0.52, DARK_GOLD, 0.5)
	shape(holder, 0.28, 0.28, 0.44, 0.44, PALE_GOLD, 0.5)
	shape(holder, 0.41, 0.41, 0.18, 0.18, NIGHT, 0.12)
end

-- Chakra: a blue flame, a round body under a pointed tip, with a paler heart.
function Icons.chakra(holder: Instance)
	shape(holder, 0.36, 0.10, 0.28, 0.28, BLUE, 0.1).Rotation = 45
	shape(holder, 0.18, 0.28, 0.64, 0.64, BLUE, 0.5)
	shape(holder, 0.43, 0.36, 0.14, 0.14, PALE_BLUE, 0.1).Rotation = 45
	shape(holder, 0.34, 0.50, 0.32, 0.32, PALE_BLUE, 0.5)
end

-- Meditation: a figure sitting cross-legged, hands on its knees, inside a glow.
function Icons.meditate(holder: Instance)
	shape(holder, 0.10, 0.12, 0.80, 0.80, DEEP_BLUE, 0.5).BackgroundTransparency = 0.55
	shape(holder, 0.16, 0.66, 0.68, 0.20, BLUE, 0.5)
	shape(holder, 0.36, 0.38, 0.28, 0.36, BLUE, 0.3)
	shape(holder, 0.39, 0.14, 0.22, 0.22, SKIN, 0.5)
	shape(holder, 0.20, 0.62, 0.10, 0.10, SKIN, 0.5)
	shape(holder, 0.70, 0.62, 0.10, 0.10, SKIN, 0.5)
end

-- Chakra control: the closing ring around its golden target, as in the exercise itself.
function Icons.focus(holder: Instance)
	shape(holder, 0.08, 0.08, 0.84, 0.84, PARCHMENT, 0.5)
	shape(holder, 0.15, 0.15, 0.70, 0.70, NIGHT, 0.5)
	shape(holder, 0.26, 0.26, 0.48, 0.48, GOLD, 0.5)
	shape(holder, 0.33, 0.33, 0.34, 0.34, NIGHT, 0.5)
	shape(holder, 0.43, 0.43, 0.14, 0.14, BLUE, 0.5)
end

-- A shinobi in the given color, with a forehead protector: the stand-in for a portrait until
-- the characters have pictures of their own.
function Icons.shinobi(holder: Instance, color: Color3)
	shape(holder, 0.26, 0.46, 0.48, 0.48, color, 0.18)
	shape(holder, 0.31, 0.08, 0.38, 0.38, SKIN, 0.5)
	shape(holder, 0.31, 0.18, 0.38, 0.08, NIGHT, 0)
	shape(holder, 0.43, 0.17, 0.14, 0.10, STEEL, 0.2)
end

return Icons
