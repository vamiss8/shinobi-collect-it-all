--!strict
-- A shinobi's merge stars as a row of drawn stars (owner, 2026-10-19: "one gold, two gold, a
-- platinum, more worked and beautiful, two platinum, a Six Paths star, very beautiful, two Six
-- Paths, three Six Paths, the most"; Catalog.starParts says which). The greatest on the left.
--
--   gold      a gold star edged in black
--   platinum  a pale silver star a glint passes over (lettered: Config/Lettering `stars`) on a
--             dark engraved rim a size larger, and a four-pointed sparkle that twinkles at its
--             shoulder
--   Six Paths gold and violet with a dark flame rising off it (lettered), on a shadow of
--             deep violet that breathes, before six rays of gold and violet that turn slowly,
--             with six black orbs going round it (the Sage's Truth-Seeking Orbs) and a gold
--             sparkle
--
-- What is built here is the same on the server (the tag over a figure, View/Figure) and on the
-- client (cards, slots); what moves is moved by every client: the lettering by client
-- Lettering, the rest by client StarShine, which finds a star's core by its tag
-- (Net.STAR_TAG) and its kind (attribute "Kind").
--
-- A star stands in a holder of its own, wider than tall for the greater ones so that their
-- rays and orbs have room, and a square core in its middle that everything is laid in: the
-- lettering's aura copies a label into the label's parent, and in the row's list layout
-- those copies would be laid out as stars.

local CollectionService = game:GetService("CollectionService")

local Catalog = require("../Config/Catalog")
local Lettering = require("../Config/Lettering")
local Net = require("../Net")

local Stars = {}

-- The attribute on a star's core that says what kind it is, for client StarShine.
Stars.KIND_ATTRIBUTE = "Kind"

local GLYPH = "★"
local GOLD = Color3.fromRGB(255, 213, 79)
local BLACK = Color3.new(0, 0, 0)
-- How wide a holder is for its height, by kind.
local WIDE: { [string]: number } = { gold = 1, platinum = 1.15, sixpaths = 1.3 }

-- A label of the star's shape filling its parent `scale` times over, around its middle.
local function glyph(parent: Instance, scale: number, z: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Glyph"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(scale, scale)
	label.BackgroundTransparency = 1
	label.ZIndex = z
	label.Font = Enum.Font.PermanentMarker
	label.TextScaled = true
	label.Text = GLYPH
	label.TextColor3 = GOLD
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = BLACK
	-- A star is not a word for a client to translate (client WorldWords).
	label:SetAttribute(Net.VERBATIM_ATTRIBUTE, true)
	label.Parent = parent
	return label
end

-- A frame of `color` filling `size` of its parent around `at`, square.
local function piece(
	parent: Instance,
	name: string,
	at: Vector2,
	size: number,
	color: Color3,
	z: number
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(at.X, at.Y)
	frame.Size = UDim2.fromScale(size, size)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	frame.Parent = parent
	return frame
end

-- A thin bar across its parent, fading out towards both ends; `turn` degrees about the middle.
local function ray(parent: Instance, thick: number, colors: ColorSequence, turn: number, z: number)
	local bar = Instance.new("Frame")
	bar.Name = "Ray"
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.Size = UDim2.fromScale(1, thick)
	bar.Rotation = turn
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BorderSizePixel = 0
	bar.ZIndex = z
	local fade = Instance.new("UIGradient")
	fade.Color = colors
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(0.7, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = bar
	bar.Parent = parent
end

-- A four-pointed sparkle at `at` of its parent, `size` of it across, of `color`. It is drawn
-- at nothing; client StarShine makes it twinkle (its UIScale "Twinkle").
local function sparkle(parent: Instance, at: Vector2, size: number, color: Color3, z: number)
	local holder = piece(parent, "Glint", at, size, color, z)
	holder.BackgroundTransparency = 1
	local twinkle = Instance.new("UIScale")
	twinkle.Name = "Twinkle"
	twinkle.Scale = 0
	twinkle.Parent = holder
	local colors = ColorSequence.new(color)
	for _, turn in { 0, 90 } do
		ray(holder, 0.16, colors, turn, z)
	end
end

local function round(frame: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
end

-- What goes round a platinum star.
local function platinum(core: Frame, z: number)
	-- The engraved rim: a dark star a size larger behind the bright one, edged in light.
	local rim = glyph(core, 1.3, z)
	rim.Name = "Rim"
	rim.TextColor3 = Color3.fromRGB(55, 71, 79)
	rim.TextStrokeColor3 = Color3.fromRGB(236, 239, 241)
	rim.TextStrokeTransparency = 0.25
	sparkle(core, Vector2.new(0.84, 0.16), 0.62, Color3.new(1, 1, 1), z + 2)
end

-- What goes round a Six Paths star.
local function sixPaths(core: Frame, z: number)
	-- Six rays, three bars through the middle, before which the star stands.
	local rays = piece(core, "Rays", Vector2.new(0.5, 0.5), 2.1, BLACK, z)
	rays.BackgroundTransparency = 1
	local colors = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(179, 136, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 213, 79)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(179, 136, 255)),
	})
	for _, turn in { 0, 60, 120 } do
		ray(rays, 0.09, colors, turn, z)
	end
	-- The dark flame under the star, breathing (its UIScale "Breath").
	local shadow = glyph(core, 1.4, z)
	shadow.Name = "Shadow"
	shadow.TextColor3 = Color3.fromRGB(27, 0, 51)
	shadow.TextStrokeColor3 = Color3.fromRGB(126, 87, 194)
	shadow.TextStrokeTransparency = 0.35
	local breath = Instance.new("UIScale")
	breath.Name = "Breath"
	breath.Parent = shadow
	-- The six Truth-Seeking Orbs, laid round it; client StarShine sends them round.
	for index = 1, 6 do
		local angle = (index - 1) * math.pi / 3
		local orb = piece(
			core,
			"Orb",
			Vector2.new(0.5 + 0.6 * math.cos(angle), 0.5 + 0.25 * math.sin(angle)),
			0.2,
			Color3.fromRGB(14, 10, 20),
			z
		)
		round(orb)
		local edge = Instance.new("UIStroke")
		edge.Color = Color3.fromRGB(179, 136, 255)
		edge.Thickness = 1
		edge.Parent = orb
	end
	sparkle(core, Vector2.new(0.86, 0.12), 0.7, Color3.fromRGB(255, 243, 196), z + 2)
end

-- Fills `row` (a GuiObject sized by its caller) with the stars of a unit at merge `level`,
-- each as tall as the row; what was in it before is taken out. `alignment` lays them from the
-- left (the default), the middle or the right. `z` is the ZIndex the stars stand at, the row's
-- own if none is given (over a portrait, which client Portrait draws at 4, more): what is
-- behind a star is drawn at it, the star at one more, its sparkle at two more. Returns how many
-- it drew.
function Stars.fill(
	row: GuiObject,
	level: number,
	alignment: Enum.HorizontalAlignment?,
	z: number?
): number
	for _, child in row:GetChildren() do
		if child.Name == "Star" or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = alignment or Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local base = z or row.ZIndex
	local parts = Catalog.starParts(level)
	local kinds: { { count: number, kind: string } } = {
		{ count = parts.sixPaths, kind = "sixpaths" },
		{ count = parts.platinum, kind = "platinum" },
		{ count = parts.gold, kind = "gold" },
	}
	local order = 0
	for _, entry in kinds do
		for _ = 1, entry.count do
			order += 1
			local holder = Instance.new("Frame")
			holder.Name = "Star"
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromScale(1, 1)
			holder.LayoutOrder = order
			holder.ZIndex = base
			local shape = Instance.new("UIAspectRatioConstraint")
			shape.AspectRatio = WIDE[entry.kind]
			shape.DominantAxis = Enum.DominantAxis.Height
			shape.Parent = holder

			local core = Instance.new("Frame")
			core.Name = "Core"
			core.AnchorPoint = Vector2.new(0.5, 0.5)
			core.Position = UDim2.fromScale(0.5, 0.5)
			core.Size = UDim2.fromScale(1, 1)
			core.BackgroundTransparency = 1
			core.ZIndex = base
			local square = Instance.new("UIAspectRatioConstraint")
			square.AspectRatio = 1
			square.DominantAxis = Enum.DominantAxis.Height
			square.Parent = core
			core.Parent = holder

			if entry.kind == "platinum" then
				platinum(core, base)
			elseif entry.kind == "sixpaths" then
				sixPaths(core, base)
			end
			local star = glyph(core, if entry.kind == "gold" then 1 else 0.95, base + 1)
			local key = if entry.kind == "gold" then nil else Lettering.key("star", entry.kind)
			if key then
				star:SetAttribute(Net.LETTERING_ATTRIBUTE, key)
				CollectionService:AddTag(star, Net.LETTERING_TAG)
				core:SetAttribute(Stars.KIND_ATTRIBUTE, entry.kind)
				CollectionService:AddTag(core, Net.STAR_TAG)
			end
			holder.Parent = row
		end
	end
	return order
end

-- How many stars a unit at merge `level` shows drawn: for a caller that sizes the row by them.
function Stars.count(level: number): number
	local parts = Catalog.starParts(level)
	return parts.gold + parts.platinum + parts.sixPaths
end

return Stars
