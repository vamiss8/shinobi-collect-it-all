--!strict
-- The game's icons. Each function fills the given square holder. An icon is drawn from plain
-- frames, sized in fractions of its holder so it scales with whatever it is put in; if Art
-- lists an uploaded picture for it, the picture takes the drawing's place once it has loaded.
-- So the game works with no images at all, takes them one at a time, and never shows an empty
-- square for one that is still in moderation.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = require("./Art")
local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
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
local HANDLE = Color3.fromRGB(58, 44, 36)
local OUTLINE = Color3.fromRGB(30, 22, 18)
local WHITE = Color3.new(1, 1, 1)
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

-- A filled bar centered on a point of the holder and turned about it, in degrees clockwise.
-- Sizes are fractions of the holder, corners a fraction of the bar's shorter side. A square
-- one turned 45 degrees is a diamond.
local function bar(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	height: number,
	turn: number,
	color: Color3,
	rounding: number
): Frame
	local frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(width, height),
		Rotation = turn,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, parent)
	if rounding > 0 then
		Ui.make("UICorner", { CornerRadius = UDim.new(rounding, 0) }, frame)
	end
	return frame
end

-- A picture that would not load is asked for again this often, this many times: one that is
-- still in moderation usually comes through within the hour.
local RETRY_SECONDS = 30
local RETRIES = 120

-- Lays the uploaded picture of that asset id over what has been drawn in the holder: the
-- picture is fetched in the background and, once it is there, shown in place of the drawing.
-- An image that is still in moderation, or was turned down, cannot be fetched; the drawing
-- then simply stays. Call it last, after the icon is drawn. Does nothing when there is no
-- picture (the id is 0 or missing). `turn` turns the picture, in degrees clockwise, and `zoom`
-- draws it that many times larger about the holder's middle.
--
-- The picture is fetched through ContentProvider and not left to the label, because a label
-- inside a hidden window does not load its image: the power bar and the store are hidden when
-- they are built, and their drawings would stay under the pictures for good.
local function overlay(holder: Instance, assetId: number?, turn: number?, zoom: number?)
	if not assetId or assetId == 0 then
		return
	end
	local drawn = holder:GetChildren()
	local size = zoom or 1
	local image: ImageLabel = Ui.make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(size, size),
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Image = `rbxassetid://{assetId}`,
		Rotation = turn or 0,
		ZIndex = 5,
		Visible = false,
	}, holder)
	task.spawn(function()
		for _ = 1, RETRIES do
			local fetched = false
			pcall(function()
				ContentProvider:PreloadAsync({ image }, function(_, status)
					fetched = status == Enum.AssetFetchStatus.Success
				end)
			end)
			if not image.Parent then
				return
			end
			if fetched then
				image.Visible = true
				for _, piece in drawn do
					if piece:IsA("GuiObject") then
						piece.Visible = false
					end
				end
				return
			end
			task.wait(RETRY_SECONDS)
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

local kunaiById: { [string]: Catalog.Kunai } = {}
for _, kunai in Catalog.kunai do
	kunaiById[kunai.id] = kunai
end

-- Which way a kunai's tip points when nothing else is asked for, in degrees clockwise from
-- straight up: to the upper right.
local KUNAI_TILT = 45
-- A kunai lying across the holder has the diagonal to itself, which is longer than a side, so
-- it is shown this much larger than one standing upright; in between, in proportion.
local KUNAI_DIAGONAL_ZOOM = 0.3
-- The blade of a drawn kunai, in fractions of the holder: how far under the top edge its two
-- sides meet, how long and wide each side is, how many degrees it leans away from the middle,
-- and how much larger the inked copy under it is.
local BLADE_TOP = 0.09
local BLADE_LENGTH = 0.42
local BLADE_WIDTH = 0.12
local BLADE_LEAN = 13
local BLADE_INK = 0.05

-- A kunai in its own colors (Config/Kunai): a leaf of a blade inked around the edge, a wrapped
-- handle and a ring. `backing` is the color the icon sits on, which fills the ring's hole.
-- `turn` is where the tip points, in degrees clockwise from straight up. A picture from Art
-- shows the kunai standing upright, tip up, and is turned the same way.
function Icons.kunai(holder: Instance, kunaiId: string, backing: Color3, turn: number?)
	local look = kunaiById[kunaiId]
	local blade = if look then Color3.fromHex(look.color) else STEEL
	local wrap = if look then Color3.fromHex(look.trail) else PARCHMENT
	local angle = turn or KUNAI_TILT

	local zoom = 1 + KUNAI_DIAGONAL_ZOOM * math.abs(math.sin(math.rad(2 * angle)))

	-- Drawn standing upright, tip up, in a square that is then turned as a whole. Everything
	-- stays inside the circle that fits the square, so no turn pushes a part out of the holder.
	local canvas = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(zoom, zoom),
		BackgroundTransparency = 1,
		Rotation = angle,
	}, holder)
	bar(canvas, 0.5, 0.865, 0.22, 0.22, 0, OUTLINE, 0.5)
	bar(canvas, 0.5, 0.865, 0.18, 0.18, 0, blade:Lerp(WHITE, 0.3), 0.5)
	bar(canvas, 0.5, 0.865, 0.09, 0.09, 0, backing, 0.5)
	bar(canvas, 0.5, 0.70, 0.14, 0.24, 0, OUTLINE, 0.2)
	bar(canvas, 0.5, 0.70, 0.10, 0.22, 0, HANDLE, 0.2)
	bar(canvas, 0.5, 0.68, 0.10, 0.03, 0, wrap, 0)
	bar(canvas, 0.5, 0.74, 0.10, 0.03, 0, wrap, 0)

	-- The blade is a leaf: two bars leaning apart from the tip, a diamond that closes the wide
	-- end and a small one that sharpens the tip. Inked first, a little larger, then filled.
	local sin, cos = math.sin(math.rad(BLADE_LEAN)), math.cos(math.rad(BLADE_LEAN))
	for _, pass in { { grow = BLADE_INK, color = OUTLINE }, { grow = 0, color = blade } } do
		for _, side in { -1, 1 } do
			bar(
				canvas,
				0.5 + side * BLADE_LENGTH / 2 * sin,
				BLADE_TOP + BLADE_LENGTH / 2 * cos,
				BLADE_WIDTH + pass.grow,
				BLADE_LENGTH + pass.grow,
				-side * BLADE_LEAN,
				pass.color,
				0
			)
		end
		bar(canvas, 0.5, BLADE_TOP + 0.40, 0.24 + pass.grow, 0.24 + pass.grow, 45, pass.color, 0.08)
		bar(canvas, 0.5, BLADE_TOP + 0.02, 0.10 + pass.grow, 0.10 + pass.grow, 45, pass.color, 0.08)
	end
	bar(canvas, 0.5, BLADE_TOP + 0.25, 0.035, 0.50, 0, blade:Lerp(WHITE, 0.45), 0.5)
	overlay(holder, Art.kunai[kunaiId], angle, zoom)
end

return Icons
