--!strict
-- The face words are written in, on this client. Everything is written in the brush
-- (PermanentMarker), on the screen and on boards in the world alike; where the brush has not
-- the letters of the player's language (Config/Languages `font`), or the player chose the plain
-- face in the settings (Languages.PLAIN), every word in the brush is given that face instead,
-- as it appears. A face set on the client is the client's own, so each player reads the world
-- in theirs.
--
-- Also here: no text of the game is translated by Roblox's machine translation (AutoLocalize
-- off on every interface and prompt). The game carries its own words (client/Lang); the
-- machine's mangled their sense and lost their face (owner, 2026-10-15).
--
-- AND WORDS NEVER RUN OUT OF THEIR BOX. The interface was laid out for English in the brush;
-- another face is wider (the plain one ran out of windows: owner, 2026-10-15), and another
-- language longer. A label written at a size of its own whose words do not fit it (Roblox's
-- TextFits) is given leave to shrink to fit, never past the size it was given: where the
-- words fit nothing changes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Languages = require(ReplicatedStorage.Shared.Config.Languages)
local Ui = require("./Ui")

local Fonts = {}

local BRUSH = Font.fromEnum(Enum.Font.PermanentMarker)
-- Marks a label that was written in the brush, so it can be given it back; and one that keeps
-- the face it was given (Fonts.keep).
local WAS_BRUSH = "WasBrush"
local KEEP = "KeepFace"
-- Marks a label given leave to shrink, and how far it may: a share of the size it was given.
local FITTED = "Fitted"
local SHRINK_TO = 0.55
local SMALLEST = 9

local language = Languages.DEFAULT
local face = "brush"
local target: Font? = nil
local roots: { Instance } = {}

local function weight(value: number?): Enum.FontWeight
	local best = Enum.FontWeight.Regular
	for _, item in Enum.FontWeight:GetEnumItems() do
		if value and math.abs(item.Value - value) < math.abs(best.Value - value) then
			best = item :: Enum.FontWeight
		end
	end
	return best
end

-- The face the brush's words are given with that choice of the settings; nil to keep the brush.
local function faceFor(choice: string): Font?
	if choice == "plain" then
		return Font.new(Languages.PLAIN.font, weight(Languages.PLAIN.weight))
	end
	local entry = Languages.byCode[language]
	if entry and entry.font then
		return Font.new(entry.font, weight(entry.weight))
	end
	return nil
end

local function wanted(): Font?
	return faceFor(face)
end

local function dress(object: Instance)
	if object:IsA("LayerCollector") or object:IsA("ProximityPrompt") then
		(object :: any).AutoLocalize = false
		return
	end
	if not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
		return
	end
	local text = object :: TextLabel
	if text:GetAttribute(KEEP) then
		return
	end
	local brush = text:GetAttribute(WAS_BRUSH) == true or text.FontFace.Family == BRUSH.Family
	if not brush then
		return
	end
	if target then
		text:SetAttribute(WAS_BRUSH, true)
		text.FontFace = target
	elseif text:GetAttribute(WAS_BRUSH) then
		text.FontFace = BRUSH
	end
end

-- Lets a label of the interface shrink its words to fit it, once they do not.
local function fit(object: Instance)
	if not (object:IsA("TextLabel") or object:IsA("TextButton")) then
		return
	end
	local text = object :: TextLabel
	if text.TextScaled or text:GetAttribute(FITTED) then
		return
	end
	local function check()
		if text.TextFits or text.TextScaled or text.Text == "" or text:GetAttribute(FITTED) then
			return
		end
		text:SetAttribute(FITTED, true)
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = math.max(math.floor(text.TextSize), 1)
		limit.MinTextSize =
			math.min(math.max(math.floor(text.TextSize * SHRINK_TO), SMALLEST), limit.MaxTextSize)
		limit.Parent = text
		text.TextScaled = true
	end
	text:GetPropertyChangedSignal("TextFits"):Connect(check)
	task.defer(check)
end

local function dressAll()
	for _, root in roots do
		for _, object in root:GetDescendants() do
			dress(object)
		end
	end
end

-- Call once the language is chosen (client Language), before the interface is built.
function Fonts.start(code: string, choice: string?)
	language = code
	face = if choice == "plain" then "plain" else "brush"
	target = wanted()
	Ui.measureWith(target)
	local player = Players.LocalPlayer
	local screen = player:WaitForChild("PlayerGui")
	roots = { screen, Workspace }
	for _, root in roots do
		root.DescendantAdded:Connect(dress)
	end
	dressAll()
	-- The world's writing is scaled to its boards already; the interface's is fitted.
	screen.DescendantAdded:Connect(fit)
	for _, object in screen:GetDescendants() do
		fit(object)
	end
end

-- Writes a label in the face a choice of the settings would give ("brush" or "plain"), and
-- keeps it so whatever is chosen: the settings show each choice in itself.
function Fonts.keep(label: TextButton, choice: string)
	label:SetAttribute(KEEP, true)
	label.FontFace = faceFor(choice) or BRUSH
end

-- The face chosen in the settings: "brush" or "plain". Every word on the screen and in the
-- world takes it at once.
function Fonts.set(choice: string)
	face = if choice == "plain" then "plain" else "brush"
	target = wanted()
	Ui.measureWith(target)
	dressAll()
end

return Fonts
