--!strict
-- A card describing one shinobi, used by the inventory, the sell stall and the Bingo Book. A
-- card for a unit the player has not found yet is a black silhouette that only gives away its
-- income. An upgraded unit's card also shows its base income, what it earned at level 1: that
-- is the number to compare two shinobi by, since a level can be bought for either.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Icons = require("./Icons")
local Strings = require("./Strings")
local Ui = require("./Ui")

local UnitCard = {}

UnitCard.SIZE = Vector2.new(164, 108)

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
	Ui.stroke(card, if known then rankColor else Ui.EDGE, 2)

	-- A portrait stand-in: a little shinobi in the rank's color, an empty square while unknown.
	local portrait = Ui.make("Frame", {
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = if known then Ui.PANEL else Color3.fromRGB(24, 24, 24),
		BorderSizePixel = 0,
	}, card)
	Ui.corner(portrait, 6)
	if known then
		Icons.shinobi(portrait, rankColor)
	end

	Ui.text(card, {
		Position = UDim2.fromOffset(56, 6),
		Size = UDim2.new(1, -62, 0, 24),
		Font = Ui.BRUSH,
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = if not known
			then Strings.get("CardUnknown")
			elseif character then character.name
			else unit.character,
	})
	Ui.text(card, {
		Position = UDim2.fromOffset(56, 28),
		Size = UDim2.new(1, -62, 0, 18),
		TextSize = 13,
		TextColor3 = if known then rankColor else Ui.GRAY,
		Text = if rank then rank.name else "",
	})

	if mutation then
		Ui.text(card, {
			Position = UDim2.fromOffset(8, 50),
			Size = UDim2.new(1, -16, 0, 16),
			TextSize = 13,
			TextColor3 = if known then Color3.fromHex(mutation.color) else Ui.GRAY,
			Text = string.upper(mutation.name),
		})
	end

	local upgrades = unit.upgrade or 0
	if known and upgrades > 0 then
		Ui.text(card, {
			Position = UDim2.new(0, 8, 1, -42),
			Size = UDim2.new(1, -16, 0, 16),
			TextSize = 13,
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
	Ui.text(card, {
		Position = UDim2.new(0, 8, 1, -24),
		Size = UDim2.new(0.5, -8, 0, 18),
		TextSize = 14,
		TextColor3 = if known then Ui.WHITE else Ui.GRAY,
		Text = if known then level else "",
	})
	Ui.text(card, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 1, -24),
		Size = UDim2.new(0.5, -8, 0, 18),
		TextSize = 14,
		TextColor3 = if known then Ui.GOLD else Ui.GRAY,
		TextXAlignment = Enum.TextXAlignment.Right,
		Text = footer or Strings.get("CardIncome", Economy.unitIncome(unit)),
	})

	return card
end

return UnitCard
