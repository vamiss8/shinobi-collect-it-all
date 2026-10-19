--!strict
-- A shinobi's merge stars as a row of drawn stars (owner, 2026-10-19: "merges can be so many
-- that the stars do not fit: from the third star make a beautiful animated platinum star, and
-- three platinum ones the last, a super cool Six Paths star"). Counted in threes
-- (Catalog.starParts): the Six Paths stars first, then the platinum, then the gold, the
-- greatest on the left. Gold ones are plain gold letters edged in black; platinum and Six
-- Paths are lettered (Config/Lettering `stars`), which every client draws and keeps moving:
-- a label is marked for it, so a row built on the server (the tag over a figure, View/Figure)
-- moves on every client as one built on the client does (client Lettering adopts it).
--
-- Each star stands in a square holder of its own: the lettering's aura copies a label into
-- the label's parent, and in the row's list layout those copies would be laid out as stars.

local CollectionService = game:GetService("CollectionService")

local Catalog = require("../Config/Catalog")
local Lettering = require("../Config/Lettering")
local Net = require("../Net")

local Stars = {}

local GOLD = Color3.fromRGB(255, 213, 79)
local GLYPH = "★"

-- Fills `row` (a GuiObject sized by its caller) with the stars of a unit at merge `level`,
-- left to right, each as tall as the row; what was in it before is taken out. `alignment` lays
-- them from the left (the default), the middle or the right. `z` is the ZIndex they are drawn
-- at, the row's own if none is given: over a portrait (client Portrait draws at 4), more.
-- Returns how many it drew.
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
	layout.Padding = UDim.new(0, 0)
	layout.Parent = row

	local parts = Catalog.starParts(level)
	local kinds: { { count: number, key: string? } } = {
		{ count = parts.sixPaths, key = Lettering.key("star", "sixpaths") },
		{ count = parts.platinum, key = Lettering.key("star", "platinum") },
		{ count = parts.gold, key = nil },
	}
	local order = 0
	for _, kind in kinds do
		for _ = 1, kind.count do
			order += 1
			local holder = Instance.new("Frame")
			holder.Name = "Star"
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromScale(1, 1)
			holder.LayoutOrder = order
			holder.ZIndex = z or row.ZIndex
			local square = Instance.new("UIAspectRatioConstraint")
			square.AspectRatio = 1
			square.DominantAxis = Enum.DominantAxis.Height
			square.Parent = holder

			local label = Instance.new("TextLabel")
			label.Name = "Glyph"
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.ZIndex = z or row.ZIndex
			label.Font = Enum.Font.PermanentMarker
			label.TextScaled = true
			label.Text = GLYPH
			label.TextColor3 = GOLD
			label.TextStrokeTransparency = 0
			label.TextStrokeColor3 = Color3.new(0, 0, 0)
			-- A star is not a word for a client to translate (client WorldWords).
			label:SetAttribute(Net.VERBATIM_ATTRIBUTE, true)
			if kind.key then
				label:SetAttribute(Net.LETTERING_ATTRIBUTE, kind.key)
				CollectionService:AddTag(label, Net.LETTERING_TAG)
			end
			label.Parent = holder
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
