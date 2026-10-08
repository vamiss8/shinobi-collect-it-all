--!strict
-- What a shopkeeper says, as a scroll hung in the air over their counter: parchment, the words
-- in ink, a red outline, and on its left the keeper's own face, so that it is plain who is
-- speaking. The words are large first, what the shop is for, and under a drawn line small,
-- something the keeper adds.
--
-- The face is a photograph of the keeper's model (client Portrait), in a frame like the one a
-- shinobi's portrait has in the inventory. A keeper without a model has a round red seal with
-- a letter there instead, as every keeper had at first: the owner could not tell from a "D" on
-- red who was talking.
--
-- It is a BillboardGui that is always drawn on top. The first greetings were Roblox's own chat
-- bubbles over the keeper's head, which is under a roof and behind a curtain: the owner could
-- not see them, "they run into the textures". Drawn on top, a scroll runs into nothing, and it
-- hangs before the shop's front, above the keeper and clear of their face.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Portrait = require("./Portrait")
local Ui = require("./Ui")

local Speech = {}

-- The scroll's size in studs: it is a thing in the world and shrinks with distance. Seen from
-- where it is set off, it takes about a quarter of the screen's width, and its large words are
-- then about 26 px tall on a 900 px screen, the small ones about 17; both grow on the way to the
-- counter. Each takes two lines.
local SIZE = Vector2.new(20, 7.2)
-- The red sheet shows this far round the parchment, studs.
local EDGE = 0.24
-- It is not drawn for a camera farther off than this, studs. Whoever shows it takes it down
-- sooner, by how far the player is (client Shops); this is for a camera zoomed a long way out.
local FAR = 60
-- How long it takes to shrink away when hidden, seconds.
local CLOSE_SECONDS = 0.14

export type Scroll = {
	-- Shows the scroll with these words, springing up.
	say: (title: string, line: string) -> (),
	hide: () -> (),
}

-- A scroll hanging `lift` studs over the middle of `counter`, with the face of the keeper whose
-- model is named `keeper` on it, or a seal stamped with `mark` when there is no such model.
function Speech.build(counter: BasePart, lift: number, mark: string, keeper: string): Scroll
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

	-- Who is speaking: a red frame with the keeper's face in it, a square as tall as most of
	-- the scroll.
	local seal: Frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.03, 0.5),
		Size = UDim2.fromScale(0.24, 0.8),
		BackgroundColor3 = Ui.SEAL,
		BorderSizePixel = 0,
	}, paper)
	Ui.make("UIAspectRatioConstraint", { AspectRatio = 1 }, seal)
	local rim: UICorner = Ui.make("UICorner", { CornerRadius = UDim.new(0.16, 0) }, seal)
	local window: Frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		BackgroundColor3 = Ui.PANEL,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, seal)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.13, 0) }, window)
	if not Portrait.show(window, keeper, false, true) then
		-- No model to photograph: the round seal with a letter, as before.
		rim.CornerRadius = UDim.new(0.5, 0)
		seal.Size = UDim2.fromScale(0.16, 0.66)
		window:Destroy()
		Ui.text(seal, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.7),
			TextScaled = true,
			TextColor3 = Ui.PARCHMENT,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = mark,
		})
	end

	local title = Ui.text(paper, {
		Position = UDim2.fromScale(0.26, 0.06),
		Size = UDim2.fromScale(0.71, 0.46),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	-- A drawn line between the two.
	Ui.make("Frame", {
		Position = UDim2.fromScale(0.3, 0.56),
		Size = UDim2.fromScale(0.63, 0.016),
		BackgroundColor3 = Ui.INK,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, paper)
	local line = Ui.text(paper, {
		Position = UDim2.fromScale(0.26, 0.6),
		Size = UDim2.fromScale(0.71, 0.34),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextTransparency = 0.15,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- Counts showings and hidings, so that a scroll shrinking away does not shut a newer one.
	local turn = 0
	return {
		say = function(words: string, more: string)
			turn += 1
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
			if not board.Enabled then
				return
			end
			turn += 1
			local mine = turn
			TweenService:Create(
				scale,
				TweenInfo.new(CLOSE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Scale = 0.5 }
			):Play()
			task.delay(CLOSE_SECONDS, function()
				if turn == mine then
					board.Enabled = false
				end
			end)
		end,
	}
end

return Speech
