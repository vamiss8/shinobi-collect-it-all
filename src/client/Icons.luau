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
local Portrait = require("./Portrait")
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local SpeedStages = require(ReplicatedStorage.Shared.Config.SpeedStages)
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

-- Rebirth: the Rinnegan, the eye of the cycle of rebirth, its rings round a dark pupil.
function Icons.rebirth(holder: Instance)
	local iris = Color3.fromRGB(179, 157, 219)
	local ring = Color3.fromRGB(94, 53, 177)
	shape(holder, 0.04, 0.04, 0.92, 0.92, INK, 0.5)
	shape(holder, 0.09, 0.09, 0.82, 0.82, iris, 0.5)
	shape(holder, 0.19, 0.19, 0.62, 0.62, ring, 0.5)
	shape(holder, 0.23, 0.23, 0.54, 0.54, iris, 0.5)
	shape(holder, 0.31, 0.31, 0.38, 0.38, ring, 0.5)
	shape(holder, 0.35, 0.35, 0.30, 0.30, iris, 0.5)
	shape(holder, 0.43, 0.43, 0.14, 0.14, INK, 0.5)
	overlay(holder, Art.icons.rebirth)
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

-- The portrait of a character: a photograph of its own model when it has one (see Portrait),
-- and until then a small drawn shinobi in the given color with a forehead protector. The
-- character's picture takes the place of either if Art has one.
function Icons.shinobi(holder: Instance, characterId: string, color: Color3)
	if not Portrait.show(holder, characterId) then
		shape(holder, 0.26, 0.46, 0.48, 0.48, color, 0.18)
		shape(holder, 0.31, 0.08, 0.38, 0.38, SKIN, 0.5)
		shape(holder, 0.31, 0.18, 0.38, 0.08, NIGHT, 0)
		shape(holder, 0.43, 0.17, 0.14, 0.10, STEEL, 0.2)
	end
	overlay(holder, Art.portraits[characterId])
end

-- The outline of a character that has not been found yet: its model's shape in black. Draws
-- nothing for a character without a model.
function Icons.shadow(holder: Instance, characterId: string)
	Portrait.show(holder, characterId, true)
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

-- THE EMBLEMS. A rank, a speed stage and an event each have a mark of their own, drawn on a
-- round seal of their color: they were numbers and letters on colored discs, which the owner
-- would not have ("just digits from 1 to 10 in different colors"). The further along, the
-- more there is to a mark; the color still says which it is from across the screen.

-- The round seal an emblem is drawn on: a rim, gilt for the highest, round a face.
local function seal(holder: Instance, face: Color3, gilt: boolean?)
	shape(holder, 0, 0, 1, 1, if gilt then DARK_GOLD else OUTLINE, 0.5)
	if gilt then
		shape(holder, 0.035, 0.035, 0.93, 0.93, PALE_GOLD, 0.5)
	end
	shape(holder, 0.075, 0.075, 0.85, 0.85, face, 0.5)
end

-- A dot centered on a point of the holder.
local function dot(parent: Instance, x: number, y: number, size: number, color: Color3)
	bar(parent, x, y, size, size, 0, color, 0.5)
end

-- A chevron, point up, centered on a point of the holder: a stripe of rank.
local function chevron(parent: Instance, y: number, thick: number)
	bar(parent, 0.39, y, 0.30, thick, -38, OUTLINE, 0.3)
	bar(parent, 0.61, y, 0.30, thick, 38, OUTLINE, 0.3)
end

-- The mask of the ANBU: a pale face with slanted eyes and red marks on its cheeks.
local function mask(parent: Instance)
	shape(parent, 0.27, 0.21, 0.46, 0.58, OUTLINE, 0.5)
	shape(parent, 0.30, 0.24, 0.40, 0.52, PARCHMENT, 0.5)
	bar(parent, 0.41, 0.46, 0.13, 0.05, 20, OUTLINE, 0.5)
	bar(parent, 0.59, 0.46, 0.13, 0.05, -20, OUTLINE, 0.5)
	bar(parent, 0.38, 0.62, 0.045, 0.13, 12, SEAL_RED, 0.5)
	bar(parent, 0.62, 0.62, 0.045, 0.13, -12, SEAL_RED, 0.5)
end

-- What each rank's seal is marked with, by the rebirths it takes (Config/Rebirths).
local RANK_MARKS: { [number]: (parent: Instance, face: Color3) -> () } = {
	-- Academy Student: a forehead protector with nothing on its plate yet.
	[0] = function(parent)
		bar(parent, 0.5, 0.5, 0.62, 0.15, 0, OUTLINE, 0.3)
		bar(parent, 0.5, 0.5, 0.28, 0.21, 0, OUTLINE, 0.2)
		bar(parent, 0.5, 0.5, 0.22, 0.15, 0, STEEL, 0.2)
	end,
	-- Genin, Chunin, Special Jonin: one stripe, two, three.
	[1] = function(parent)
		chevron(parent, 0.52, 0.11)
	end,
	[2] = function(parent)
		chevron(parent, 0.43, 0.10)
		chevron(parent, 0.62, 0.10)
	end,
	[3] = function(parent)
		chevron(parent, 0.36, 0.085)
		chevron(parent, 0.52, 0.085)
		chevron(parent, 0.68, 0.085)
	end,
	-- Jonin: a diamond with a heart.
	[4] = function(parent, face)
		bar(parent, 0.5, 0.5, 0.42, 0.42, 45, OUTLINE, 0.08)
		bar(parent, 0.5, 0.5, 0.27, 0.27, 45, face, 0.08)
		dot(parent, 0.5, 0.5, 0.12, OUTLINE)
	end,
	-- ANBU: the mask.
	[5] = function(parent)
		mask(parent)
	end,
	-- ANBU Captain: the mask, crested in red.
	[6] = function(parent)
		mask(parent)
		bar(parent, 0.5, 0.30, 0.05, 0.13, 0, SEAL_RED, 0.5)
		bar(parent, 0.42, 0.32, 0.045, 0.10, -24, SEAL_RED, 0.5)
		bar(parent, 0.58, 0.32, 0.045, 0.10, 24, SEAL_RED, 0.5)
	end,
	-- Sannin: three marks on a ring, one for each of the three.
	[7] = function(parent, face)
		dot(parent, 0.5, 0.5, 0.50, OUTLINE)
		dot(parent, 0.5, 0.5, 0.40, face)
		dot(parent, 0.5, 0.27, 0.20, OUTLINE)
		dot(parent, 0.70, 0.61, 0.20, OUTLINE)
		dot(parent, 0.30, 0.61, 0.20, OUTLINE)
		dot(parent, 0.5, 0.5, 0.10, OUTLINE)
	end,
	-- Kage: the hat of a village's shadow, white with its red quarter.
	[8] = function(parent)
		bar(parent, 0.5, 0.52, 0.48, 0.48, 45, OUTLINE, 0.06)
		bar(parent, 0.5, 0.52, 0.41, 0.41, 45, PARCHMENT, 0.06)
		bar(parent, 0.5, 0.52, 0.21, 0.21, 45, SEAL_RED, 0.06)
		dot(parent, 0.5, 0.52, 0.07, PARCHMENT)
	end,
	-- Sage: the toad's eye, a bar for a pupil under an orange lid.
	[9] = function(parent)
		shape(parent, 0.17, 0.30, 0.66, 0.40, OUTLINE, 0.5)
		shape(parent, 0.20, 0.33, 0.60, 0.34, PALE_GOLD, 0.5)
		bar(parent, 0.5, 0.50, 0.36, 0.10, 0, OUTLINE, 0.4)
		bar(parent, 0.5, 0.25, 0.46, 0.06, 0, Color3.fromRGB(255, 112, 67), 0.5)
	end,
	-- Sage of Six Paths: the Rinnegan's rings, and the nine orbs round them.
	[10] = function(parent, face)
		for index = 0, 8 do
			local angle = math.rad(index * 40 - 90)
			dot(
				parent,
				0.5 + 0.345 * math.cos(angle),
				0.5 + 0.345 * math.sin(angle),
				0.085,
				OUTLINE
			)
		end
		local violet = Color3.fromRGB(149, 117, 205)
		dot(parent, 0.5, 0.5, 0.50, OUTLINE)
		dot(parent, 0.5, 0.5, 0.44, violet)
		dot(parent, 0.5, 0.5, 0.32, OUTLINE)
		dot(parent, 0.5, 0.5, 0.27, violet:Lerp(face, 0.4))
		dot(parent, 0.5, 0.5, 0.16, OUTLINE)
		dot(parent, 0.5, 0.5, 0.11, violet)
		dot(parent, 0.5, 0.5, 0.05, OUTLINE)
	end,
}

-- The seal of the rank a player holds after `count` rebirths: its mark on its color.
function Icons.rank(holder: Instance, count: number)
	local done = Rebirth.done(count)
	local face = Color3.fromHex(Rebirth.color(done))
	seal(holder, face, done >= 7)
	local mark = RANK_MARKS[done]
	if mark then
		mark(holder, face)
	end
end

-- The color of the seal of a speed stage the player has not reached: pale gray, like the
-- lanterns of the Gates not yet opened on the training ground's gate.
local UNREACHED = Color3.fromRGB(176, 178, 174)

-- One of the Eight Gates: a pair of doors that stand wider open with every Gate, the light
-- behind them showing through, and round them eight studs, as many gilt as Gates are open.
local function gate(parent: Instance, number: number, face: Color3)
	for index = 1, SpeedStages.GATES do
		local angle = math.rad((index - 1) * 360 / SpeedStages.GATES - 90)
		local lit = index <= number
		dot(parent, 0.5 + 0.36 * math.cos(angle), 0.5 + 0.36 * math.sin(angle), 0.11, OUTLINE)
		if lit then
			dot(parent, 0.5 + 0.36 * math.cos(angle), 0.5 + 0.36 * math.sin(angle), 0.07, GOLD)
		end
	end
	local wide, left, top = 0.40, 0.30, 0.30
	shape(parent, left - 0.03, top - 0.03, wide + 0.06, wide + 0.06, OUTLINE, 0.08)
	shape(parent, left, top, wide, wide, face:Lerp(WHITE, 0.75), 0.04)
	local gap = wide * (0.08 + 0.115 * (number - 1))
	local door = (wide - gap) / 2
	if door > 0.012 then
		shape(parent, left, top, door, wide, DARK_WOOD, 0)
		shape(parent, left + wide - door, top, door, wide, DARK_WOOD, 0)
	end
end

-- What the four stages before the Gates are marked with, by what a runner of the stage wears.
local function training(parent: Instance, stage: SpeedStages.Stage, face: Color3)
	local function wears(wear: SpeedStages.Wear): boolean
		return SpeedStages.wears(stage, wear)
	end
	if wears("heavy") then
		-- Heavy weights: two iron bands, one over the other, strapped.
		for _, y in { 0.38, 0.64 } do
			bar(parent, 0.5, y, 0.56, 0.24, 0, OUTLINE, 0.2)
			bar(parent, 0.5, y, 0.50, 0.18, 0, STEEL, 0.2)
		end
		bar(parent, 0.5, 0.51, 0.10, 0.52, 0, OUTLINE, 0.3)
	elseif wears("weights") then
		-- Training weights: one band.
		bar(parent, 0.5, 0.5, 0.58, 0.34, 0, OUTLINE, 0.2)
		bar(parent, 0.5, 0.5, 0.52, 0.28, 0, STEEL, 0.2)
		bar(parent, 0.5, 0.5, 0.10, 0.42, 0, OUTLINE, 0.3)
		dot(parent, 0.32, 0.5, 0.06, OUTLINE)
		dot(parent, 0.68, 0.5, 0.06, OUTLINE)
	elseif wears("dust") then
		-- Morning laps: the sun coming up over the road.
		dot(parent, 0.5, 0.60, 0.40, OUTLINE)
		dot(parent, 0.5, 0.60, 0.30, GOLD)
		shape(parent, 0.20, 0.62, 0.60, 0.24, face, 0)
		bar(parent, 0.5, 0.63, 0.68, 0.07, 0, OUTLINE, 0.5)
		bar(parent, 0.5, 0.26, 0.05, 0.11, 0, OUTLINE, 0.5)
		bar(parent, 0.29, 0.34, 0.05, 0.11, -45, OUTLINE, 0.5)
		bar(parent, 0.71, 0.34, 0.05, 0.11, 45, OUTLINE, 0.5)
	else
		-- A beginner: a bare footprint.
		shape(parent, 0.37, 0.36, 0.26, 0.42, OUTLINE, 0.5)
		dot(parent, 0.37, 0.30, 0.09, OUTLINE)
		dot(parent, 0.47, 0.24, 0.09, OUTLINE)
		dot(parent, 0.57, 0.25, 0.08, OUTLINE)
		dot(parent, 0.65, 0.31, 0.07, OUTLINE)
	end
end

-- The seal of a speed stage (Config/SpeedStages): its mark on its color, or on gray for one
-- the player has not reached.
function Icons.stage(holder: Instance, stage: SpeedStages.Stage, reached: boolean?)
	local face = if reached == false then UNREACHED else Color3.fromHex(stage.color)
	seal(holder, face, stage.gate >= SpeedStages.GATES)
	if stage.gate > 0 then
		gate(holder, stage.gate, face)
	else
		training(holder, stage, face)
	end
end

-- The seal of an event (Config/Events), by what the event hangs in the sky: a red moon, red
-- clouds, a leaf of gold.
function Icons.event(holder: Instance, shows: string)
	if shows == "moon" then
		seal(holder, Color3.fromRGB(40, 8, 16))
		dot(holder, 0.5, 0.5, 0.60, Color3.fromRGB(255, 82, 82))
		dot(holder, 0.5, 0.5, 0.52, Color3.fromRGB(213, 0, 0))
		dot(holder, 0.40, 0.42, 0.13, Color3.fromRGB(150, 0, 12))
		dot(holder, 0.60, 0.58, 0.10, Color3.fromRGB(150, 0, 12))
		dot(holder, 0.58, 0.38, 0.06, Color3.fromRGB(150, 0, 12))
	elseif shows == "clouds" then
		seal(holder, Color3.fromRGB(20, 14, 16))
		-- A red cloud edged in white, as on the cloak.
		for _, pass in { { grow = 0.06, color = WHITE }, { grow = 0, color = SEAL_RED } } do
			dot(holder, 0.36, 0.50, 0.26 + pass.grow, pass.color)
			dot(holder, 0.52, 0.42, 0.30 + pass.grow, pass.color)
			dot(holder, 0.66, 0.52, 0.24 + pass.grow, pass.color)
			bar(holder, 0.51, 0.59, 0.46 + pass.grow, 0.16 + pass.grow, 0, pass.color, 0.5)
		end
	else
		seal(holder, Color3.fromRGB(255, 213, 79), true)
		-- A leaf, its rib down the middle.
		bar(holder, 0.5, 0.5, 0.34, 0.62, 38, Color3.fromRGB(46, 125, 50), 0.5)
		bar(holder, 0.5, 0.5, 0.26, 0.54, 38, Color3.fromRGB(124, 179, 66), 0.5)
		bar(holder, 0.5, 0.5, 0.035, 0.56, 38, Color3.fromRGB(46, 125, 50), 0.5)
	end
end

return Icons
