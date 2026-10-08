--!strict
-- What a shopkeeper says, as a scroll hung in the air over their counter: parchment, the words
-- in ink, a red outline and a round red seal, like every other message of the game. The words
-- are large first, what the shop is for, and under a drawn line small, something the keeper
-- adds.
--
-- It is a BillboardGui that is always drawn on top. The first greetings were Roblox's own chat
-- bubbles over the keeper's head, which is under a roof and behind a curtain: the owner could
-- not see them, "they run into the textures". Drawn on top, a scroll runs into nothing, and it
-- hangs before the shop's front, above the keeper and clear of their face.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Ui = require("./Ui")

local Speech = {}

-- The scroll's size in studs: it is a thing in the world and shrinks with distance. Seen from
-- where it is set off, it takes about a quarter of the screen's width, and its large words are
-- then about 26 px tall on a 900 px screen, the small ones about 17; both grow on the way to the
-- counter. Each takes two lines.
local SIZE = Vector2.new(20, 7.2)
-- The red sheet shows this far round the parchment, studs.
local EDGE = 0.24
-- It is not drawn for a player farther off than this, studs.
local FAR = 80

export type Scroll = {
	-- Shows the scroll with these words, springing up.
	say: (title: string, line: string) -> (),
	hide: () -> (),
}

-- A scroll hanging `lift` studs over the middle of `counter`, its seal stamped with `mark`.
function Speech.build(counter: BasePart, lift: number, mark: string): Scroll
	local board: BillboardGui = Ui.make("BillboardGui", {
		Name = "Speech",
		Adornee = counter,
		AlwaysOnTop = true,
		Enabled = false,
		LightInfluence = 0,
		MaxDistance = FAR,
		ResetOnSpawn = false,
		Size = UDim2.fromScale(SIZE.X, SIZE.Y),
		StudsOffsetWorldSpace = Vector3.new(0, lift, 0),
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))

	-- Everything inside is measured in shares of the board, not in pixels: the board is as
	-- many pixels as its distance makes it. The red sheet under the parchment is its outline.
	local edge: Frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.SEAL,
		BorderSizePixel = 0,
	}, board)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.16, 0) }, edge)
	local scale: UIScale = Ui.make("UIScale", {}, edge)
	local paper: Frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1 - 2 * EDGE / SIZE.X, 1 - 2 * EDGE / SIZE.Y),
		BackgroundColor3 = Ui.PARCHMENT,
		BorderSizePixel = 0,
	}, edge)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.14, 0) }, paper)

	local seal: Frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.03, 0.5),
		Size = UDim2.fromScale(0.16, 0.66),
		BackgroundColor3 = Ui.SEAL,
		BorderSizePixel = 0,
	}, paper)
	Ui.make("UIAspectRatioConstraint", { AspectRatio = 1 }, seal)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, seal)
	Ui.text(seal, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7),
		TextScaled = true,
		TextColor3 = Ui.PARCHMENT,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = mark,
	})

	local title = Ui.text(paper, {
		Position = UDim2.fromScale(0.2, 0.06),
		Size = UDim2.fromScale(0.77, 0.46),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	-- A drawn line between the two.
	Ui.make("Frame", {
		Position = UDim2.fromScale(0.26, 0.56),
		Size = UDim2.fromScale(0.65, 0.016),
		BackgroundColor3 = Ui.INK,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, paper)
	local line = Ui.text(paper, {
		Position = UDim2.fromScale(0.2, 0.6),
		Size = UDim2.fromScale(0.77, 0.34),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextTransparency = 0.15,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	return {
		say = function(words: string, more: string)
			title.Text = words
			line.Text = more
			board.Enabled = true
			scale.Scale = 0.6
			TweenService:Create(
				scale,
				TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()
		end,
		hide = function()
			board.Enabled = false
		end,
	}
end

return Speech
