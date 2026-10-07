--!strict
-- A card describing one shinobi, used by the inventory, the Mission Desk and the Bingo Book. A
-- card for a unit the player has not found yet is a black silhouette that only gives away its
-- shape and its income. An upgraded unit's card also shows its base income, what it earned at level 1: that
-- is the number to compare two shinobi by, since a level can be bought for either.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Icons = require("./Icons")
local Strings = require("./Strings")
local Ui = require("./Ui")

local UnitCard = {}

UnitCard.SIZE = Vector2.new(224, 148)

local BLACK = Color3.new(0, 0, 0)

-- Builds a card. It is a button, so the caller can make it clickable. The bottom-right corner
-- shows the unit's income unless a `footer` is given to show there instead.
function UnitCard.build(
	parent: Instance,
	unit: Economy.Unit,
	known: boolean,
	footer: string?
): TextButton
	local character = Catalog.characterById[unit.character]
	local rank = if character then Catalog.ranks[Catalog.rankOrder[character.rank]] else nil
	local mutation = Catalog.mutationById[unit.mutation]
	local rankColor = if rank then Color3.fromHex(rank.color) else Ui.WHITE

	local card = Ui.button(parent, {
		Size = UDim2.fromOffset(UnitCard.SIZE.X, UnitCard.SIZE.Y),
		BackgroundColor3 = if known then Ui.CARD else BLACK,
		AutoButtonColor = known,
	})
	Ui.stroke(card, if known then rankColor else Ui.EDGE, 3)

	-- The character's portrait: a photograph of its model (a drawn stand-in while it has
	-- none), and only its black outline while unknown.
	local portrait = Ui.make("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = if known then Ui.PANEL else Color3.fromRGB(44, 40, 38),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, card)
	Ui.corner(portrait, 6)
	if known then
		Icons.shinobi(portrait, unit.character, rankColor)
	else
		Icons.shadow(portrait, unit.character)
	end

	-- The name takes two lines when it has to: "Rock Lee (Drunken Fist)" does not fit in one.
	local name = Ui.text(card, {
		Position = UDim2.fromOffset(76, 6),
		Size = UDim2.new(1, -84, 0, 36),
		TextScaled = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = if not known
			then Strings.get("CardUnknown")
			elseif character then character.name
			else unit.character,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 14 }, name)
	-- The rank on a plate of its own color: the first thing to read on a card.
	local plate = Ui.text(card, {
		Position = UDim2.fromOffset(76, 44),
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = if known then rankColor else Ui.GRAY,
		BackgroundTransparency = 0,
		TextSize = 19,
		TextColor3 = Ui.PANEL,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = if rank then rank.name else "",
		Visible = rank ~= nil,
	})
	Ui.corner(plate, 6)
	Ui.make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, plate)

	if mutation then
		Ui.text(card, {
			Position = UDim2.fromOffset(10, 72),
			Size = UDim2.new(1, -20, 0, 22),
			TextSize = 18,
			TextColor3 = if known then Color3.fromHex(mutation.color) else Ui.GRAY,
			Text = string.upper(mutation.name),
		})
	end

	local upgrades = unit.upgrade or 0
	if known and upgrades > 0 then
		Ui.text(card, {
			Position = UDim2.new(0, 10, 1, -56),
			Size = UDim2.new(1, -20, 0, 22),
			TextSize = 17,
			TextColor3 = Ui.MUTED,
			TextXAlignment = Enum.TextXAlignment.Right,
			Text = Strings.get("CardBase", Economy.baseIncome(unit)),
		})
	end

	-- Bottom line: level and merge stars on the left, income on the right.
	local level = Strings.get("CardLevel", upgrades + 1)
	if unit.level > 1 then
		level ..= " " .. Catalog.stars(unit.level)
	end
	-- Both shrink to fit: a long price or a row of stars must not run under the other.
	local levelLabel = Ui.text(card, {
		Position = UDim2.new(0, 10, 1, -32),
		Size = UDim2.new(0.44, -10, 0, 26),
		TextScaled = true,
		TextColor3 = if known then Ui.WHITE else Ui.GRAY,
		Text = if known then level else "",
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 20 }, levelLabel)
	local incomeLabel = Ui.text(card, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 1, -32),
		Size = UDim2.new(0.56, -10, 0, 26),
		TextScaled = true,
		TextColor3 = if known then Ui.GOLD else Ui.GRAY,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = footer or Strings.get("CardIncome", Economy.unitIncome(unit)),
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 20 }, incomeLabel)

	return card
end

return UnitCard
