--!strict
-- Celebrates a new speed stage (Config/SpeedStages): the screen flashes in the stage's color and
-- a scroll in the middle names it, as when a Gate bursts open. Only a purchase sets it off; the
-- stage the save loads with does not. Whatever else is to be celebrated the same way, a
-- rebirth for one, asks for the scroll with StageFlash.show.
--
-- The scroll is the game's own: parchment, the name in ink, and the stage's color on the
-- outline and the seal, which is stamped with the Gate's number. Words are never put on the
-- screen as bare colored lettering (see Ui.parchment).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Icons = require("./Icons")
local SpeedStages = require(ReplicatedStorage.Shared.Config.SpeedStages)
local Store = require("./Store")
local Strings = require("./Strings")
local Ui = require("./Ui")

local StageFlash = {}

local FLASH_SECONDS = 0.9 -- for the flash to fade
-- The screen flashes no oftener than this, seconds: a player buying levels in a row goes
-- through stages faster than a flash fades, and the screen stood in color all the while.
local FLASH_APART = 1.5
local HOLD_SECONDS = 2.4 -- the scroll stays this long

-- What a scroll's seal is stamped with: a word or two, or an emblem drawn into the square it
-- is given (see Icons).
export type Stamp = string | (holder: Instance) -> ()

-- Set by start(): flashes the screen and puts up the scroll.
local present: ((color: Color3, stamp: Stamp, title: string, words: string) -> ())? = nil

-- Flashes the screen in `color` and names something on the scroll for a moment: `stamp` on its
-- seal, `title` large, `words` under it. Nothing happens before start() has run.
function StageFlash.show(color: Color3, stamp: Stamp, title: string, words: string)
	if present then
		present(color, stamp, title, words)
	end
end

function StageFlash.start()
	local layer = Ui.screen("StageFlash", 20)
	local flash: Frame = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	}, layer)

	local paper = Ui.parchment(layer, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.34),
		Size = UDim2.fromOffset(820, 150),
		Visible = false,
	}, 84)
	paper.edge.Thickness = 4
	local mark = Ui.text(paper.seal, {
		Size = UDim2.fromScale(1, 1),
		TextScaled = true,
		TextColor3 = Ui.PARCHMENT,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	-- An emblem, when the seal is stamped with one, lies over the seal.
	local emblem: Frame = Ui.make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, paper.seal)
	local name = Ui.text(paper.page, {
		Position = UDim2.fromOffset(130, 6),
		Size = UDim2.new(1, -168, 0, 88),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 72 }, name)
	-- A drawn line between the name and what is said of it.
	Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 46, 0, 96),
		Size = UDim2.new(1, -230, 0, 3),
		BackgroundColor3 = Ui.INK,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, paper.page)
	local line = Ui.text(paper.page, {
		Position = UDim2.fromOffset(130, 100),
		Size = UDim2.new(1, -168, 0, 44),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextTransparency = 0.2,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 32 }, line)

	local token = 0
	local flashedAt = -FLASH_APART
	present = function(color: Color3, stamp: Stamp, title: string, words: string)
		token += 1
		local mine = token
		if os.clock() - flashedAt >= FLASH_APART then
			flashedAt = os.clock()
			flash.BackgroundColor3 = color
			flash.BackgroundTransparency = 0.45
			flash.Visible = true
			TweenService:Create(flash, TweenInfo.new(FLASH_SECONDS), { BackgroundTransparency = 1 })
				:Play()
		end

		Ui.rewrite(paper, function()
			name.Text = title
			emblem:ClearAllChildren()
			if typeof(stamp) == "string" then
				mark.Text = stamp
			else
				mark.Text = ""
				stamp(emblem)
			end
			line.Text = words
			paper.edge.Color = color
			paper.seal.BackgroundColor3 = color
		end)
		task.delay(HOLD_SECONDS, function()
			if token == mine then
				Ui.rollUp(paper)
			end
		end)
	end

	local shownLevel: number? = nil
	Store.onChange(function(state)
		local level = state.speedLevel
		local before = shownLevel
		shownLevel = level
		if before == nil or level <= before then
			return
		end
		local _, from = SpeedStages.at(before)
		local stage, to = SpeedStages.at(level)
		if to <= from then
			return
		end
		local speed = Economy.walkSpeed(level)
		local color = Color3.fromHex(stage.color)
		local words = if stage.gate > 0
			then Strings.get("StageGateOpened", stage.gate, SpeedStages.GATES, speed)
			else Strings.get("StageReached", speed)
		StageFlash.show(color, function(holder)
			Icons.stage(holder, stage)
		end, string.upper(stage.name), words)
	end)
end

return StageFlash
