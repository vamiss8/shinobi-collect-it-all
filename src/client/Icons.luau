--!strict
-- Icons drawn from plain frames, so the game needs no uploaded images. Each function fills the
-- given square holder; everything inside is sized in fractions of it, so an icon scales with
-- whatever it is put in.

local Ui = require("./Ui")

local Icons = {}

local PARCHMENT = Color3.fromRGB(236, 220, 188)
local DARK_WOOD = Color3.fromRGB(93, 64, 55)
local SEAL_RED = Color3.fromRGB(198, 40, 40)
local COVER = Color3.fromRGB(69, 39, 30)
local SPINE = Color3.fromRGB(46, 26, 20)

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

-- A storage scroll: parchment between two wooden rollers, closed with a red seal. In the world
-- of shinobi this is what things are kept in, which makes it the inventory.
function Icons.scroll(holder: Instance)
	shape(holder, 0.16, 0.27, 0.68, 0.46, PARCHMENT, 0.08)
	shape(holder, 0.05, 0.16, 0.15, 0.68, DARK_WOOD, 0.5)
	shape(holder, 0.80, 0.16, 0.15, 0.68, DARK_WOOD, 0.5)
	shape(holder, 0.40, 0.40, 0.20, 0.20, SEAL_RED, 0.5)
end

-- A book with a name plate and a red ribbon: the Bingo Book.
function Icons.book(holder: Instance)
	shape(holder, 0.16, 0.12, 0.70, 0.76, COVER, 0.08)
	shape(holder, 0.16, 0.12, 0.13, 0.76, SPINE, 0.2)
	shape(holder, 0.38, 0.26, 0.38, 0.20, PARCHMENT, 0.15)
	shape(holder, 0.66, 0.12, 0.09, 0.34, SEAL_RED, 0)
end

return Icons
