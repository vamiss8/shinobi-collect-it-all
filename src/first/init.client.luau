--!strict
-- THE LOADING SCREEN (owner, 2026-10-21: "make the loading screen beautiful, as in the cool
-- games", with the game's thumbnail picture for it). It is the first thing of the game a player
-- sees: Roblox's own screen is taken away at once, and this one stands over everything until the
-- game is ready to be played.
--
--   the picture   the game's thumbnail (Sakura and Sasuke running from the Ten-Tails), filling
--                 the screen and slowly drifting nearer, under a shade that darkens its foot
--   petals        cherry petals drifting down over it
--   the title     SHINOBI in parchment and ink with a red shadow and a glint passing over it,
--                 COLLECT IT ALL! in gold under it, on the dark floor at the picture's foot
--   the bar       a parchment scroll between two rollers: what is being done in ink, how far in
--                 red, and a bar of red ink with the explosive tag kunai flying at its head
--   the tips      a tip of the game under it, a new one every few seconds
--   Skip          comes after a while, for a load that takes too long
--
-- WHEN IT GOES: once the game has loaded, the client has built the interface and the save has
-- come (client init.client: the attribute below, 1 and 2), and the queue of downloads has
-- settled or a few seconds have passed; never before it has stood a moment, and never after
-- the longest wait. It then fills its bar, says Ready! and fades away as the picture comes on.
--
-- It lives in ReplicatedFirst, which reaches the player before anything else of the game: so it
-- requires nothing of the rest, and its words are its own (Words, six languages).

local ContentProvider = game:GetService("ContentProvider")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Words = require(script.Words)

ReplicatedFirst:RemoveDefaultLoadingScreen()

-- What the client says as it gets ready (Net.LOADING_ATTRIBUTE: 1 the interface is built, 2 the
-- save has come) and the language it has chosen (Net.LOADING_LANGUAGE_ATTRIBUTE), on its own
-- Player. Written here as words: the game's Net is not here yet when this runs.
local LOADING_ATTRIBUTE = "ShinobiLoading"
local LANGUAGE_ATTRIBUTE = "ShinobiLanguage"

-- The pictures: the game's thumbnail, and the explosive tag kunai (client Art.kunai).
local BANNER = "rbxassetid://88374606536959"
local KUNAI = "rbxassetid://126500229998995"

-- How long it stands at the least and at the most, when Skip comes, how long the downloads are
-- waited for once the save has come and how few left in the queue is settled enough, seconds.
local SHORTEST = 3.5
local LONGEST = 45
local SKIP_AFTER = 10
local SETTLE_MOST = 5
local SETTLED_QUEUE = 8
-- How far the bar has come at each step (entering, the world, the interface, the save, ready).
local STEPS = { 0.08, 0.32, 0.58, 0.82, 1 }
-- A tip's turn, seconds; how many petals drift down.
local TIP_SECONDS = 5.5
local PETALS = 16

local INK = Color3.fromRGB(20, 14, 11)
local PARCHMENT = Color3.fromRGB(236, 220, 188)
local PAPER = Color3.fromRGB(246, 233, 205)
local WRITING = Color3.fromRGB(58, 40, 30)
local SEAL = Color3.fromRGB(198, 40, 40)
local DEEP_RED = Color3.fromRGB(120, 18, 18)
local GOLD = Color3.fromRGB(255, 202, 40)
local ROLLER = Color3.fromRGB(93, 64, 55)
local ROLLER_END = Color3.fromRGB(141, 98, 72)
local PETAL_COLORS = {
	Color3.fromRGB(255, 192, 213),
	Color3.fromRGB(255, 170, 200),
	Color3.fromRGB(250, 220, 230),
}
-- What a tip's marked words are colored, on the dark foot of the picture.
local MARKS: { [string]: string } = {
	r = "#FF7A6B",
	y = "#FFD54F",
	b = "#8FD3FF",
	g = "#A5E3A9",
}

local BRUSH = Font.fromEnum(Enum.Font.PermanentMarker)
-- Russian has no letters in the brush: it is written in Caveat, as in the game (Config/Languages).
local CAVEAT = Font.new("rbxassetid://12187369802", Enum.FontWeight.Bold)

local player = Players.LocalPlayer

-- The language: the one the client chose once it says so, until then the player's own, by the
-- rule the game goes by (Logic/Settings.language): their account's, Roblox's or their device's
-- language, the first that is one of ours.
local function detected(): string
	for _, locale in
		{ player.LocaleId, LocalizationService.RobloxLocaleId, LocalizationService.SystemLocaleId }
	do
		local spoken = string.lower(string.match(locale or "", "^%a+") or "")
		if Words[spoken] then
			return spoken
		end
	end
	return "en"
end

local language = detected()

local function make(class: string, properties: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(class)
	for name, value in properties do
		(instance :: any)[name] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- A label of the screen: the client's font swapping is to leave it alone (client Fonts KEEP).
local function label(parent: Instance, properties: { [string]: any }): TextLabel
	local made: TextLabel = make("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = BRUSH,
		TextScaled = true,
		TextColor3 = WRITING,
	}, parent)
	for name, value in properties do
		(made :: any)[name] = value
	end
	made:SetAttribute("KeepFace", true)
	return made
end

local function corner(parent: Instance, scale: number, offset: number?)
	make("UICorner", { CornerRadius = UDim.new(scale, offset or 0) }, parent)
end

local function tween(
	target: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	TweenService:Create(
		target,
		TweenInfo.new(
			seconds,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out
		),
		goal
	):Play()
end

-- Words with marks ({r|...}) as rich text in the colors above.
local function paint(text: string): string
	local safe = string.gsub(text, "&", "&amp;")
	safe = string.gsub(safe, "<", "&lt;")
	safe = string.gsub(safe, ">", "&gt;")
	return (
		string.gsub(safe, "{(%a)|([^}]*)}", function(mark: string, words: string): string
			local color = MARKS[mark]
			return if color then `<font color="{color}">{words}</font>` else words
		end)
	)
end

local gui: ScreenGui = make("ScreenGui", {
	Name = "LoadingScreen",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ScreenInsets = Enum.ScreenInsets.None,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	AutoLocalize = false,
})

-- The ground under everything, which also takes the presses meant for what is under it.
local ground: Frame = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = INK,
	BorderSizePixel = 0,
	Active = true,
}, gui)

-- The picture, larger than the screen so that it can drift; it comes in once it has loaded.
local banner: ImageLabel = make("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1.08, 1.08),
	BackgroundTransparency = 1,
	Image = BANNER,
	ImageTransparency = 1,
	ScaleType = Enum.ScaleType.Crop,
	ZIndex = 1,
}, ground)

-- The shade: dark at the foot, where the words are, and a little at the top, under Roblox's
-- buttons.
local function shade(stops: { { number } })
	local frame: Frame = make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		ZIndex = 2,
	}, ground)
	local keys = {}
	for _, stop in stops do
		table.insert(keys, NumberSequenceKeypoint.new(stop[1], stop[2]))
	end
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(keys) }, frame)
end
shade({ { 0, 1 }, { 0.42, 1 }, { 0.7, 0.4 }, { 1, 0.08 } })
shade({ { 0, 0.5 }, { 0.16, 1 }, { 1, 1 } })

-- Petals drifting down over the picture.
type Petal = {
	frame: Frame,
	x: number,
	speed: number,
	sway: number,
	phase: number,
	spin: number,
	size: number,
	offset: number,
}
local petalLayer: Frame = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	ZIndex = 3,
}, ground)
local petals: { Petal } = {}
local random = Random.new()
for index = 1, PETALS do
	local frame: Frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PETAL_COLORS[(index - 1) % #PETAL_COLORS + 1],
		BackgroundTransparency = random:NextNumber(0.05, 0.35),
		BorderSizePixel = 0,
	}, petalLayer)
	corner(frame, 0.5)
	table.insert(petals, {
		frame = frame,
		x = random:NextNumber(-0.05, 1.05),
		speed = random:NextNumber(0.045, 0.085),
		sway = random:NextNumber(0.015, 0.045),
		phase = random:NextNumber(0, math.pi * 2),
		spin = random:NextNumber(40, 110) * (if random:NextInteger(0, 1) == 0 then -1 else 1),
		size = random:NextNumber(0.011, 0.021),
		offset = random:NextNumber(0, 1.3),
	})
end

-- Everything written stands in the middle of the screen's foot; on a narrow screen it is wider.
local narrow = false
local content: Frame = make("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 4,
}, ground)

-- The title: SHINOBI over its red shadow, with a glint passing over it, and COLLECT IT ALL!
local title: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.fromScale(0.5, 0.79),
	Size = UDim2.fromScale(0.9, 0.19),
	BackgroundTransparency = 1,
}, content)
local titleScale: UIScale = make("UIScale", { Scale = 0.86 }, title)
local shadow = label(title, {
	Position = UDim2.new(0, 0, 0, 0),
	Size = UDim2.fromScale(1, 0.66),
	Text = "SHINOBI",
	TextColor3 = DEEP_RED,
	TextTransparency = 1,
})
local name = label(title, {
	Size = UDim2.fromScale(1, 0.66),
	Text = "SHINOBI",
	TextColor3 = Color3.new(1, 1, 1),
	TextTransparency = 1,
})
local nameEdge: UIStroke = make("UIStroke", { Color = INK, Transparency = 1 }, name)
local glint: UIGradient = make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PAPER),
		ColorSequenceKeypoint.new(0.42, PAPER),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.58, PAPER),
		ColorSequenceKeypoint.new(1, PAPER),
	}),
	Rotation = 20,
	Offset = Vector2.new(-1, 0),
}, name)
local subtitle = label(title, {
	Position = UDim2.fromScale(0, 0.64),
	Size = UDim2.fromScale(1, 0.34),
	Text = "COLLECT IT ALL!",
	TextColor3 = GOLD,
	TextTransparency = 1,
})
local subtitleEdge: UIStroke = make("UIStroke", { Color = INK, Transparency = 1 }, subtitle)

-- The scroll the bar is on: parchment between two rollers, which unrolls from its middle.
local scroll: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.808),
	Size = UDim2.fromScale(0.5, 0.075),
	BackgroundTransparency = 1,
}, content)
make("UISizeConstraint", {
	MinSize = Vector2.new(300, 38),
	MaxSize = Vector2.new(1100, 96),
}, scroll)
local sheet: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.04, 1),
	BackgroundColor3 = PARCHMENT,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, scroll)
corner(sheet, 0, 6)
make("UIStroke", { Color = WRITING, Thickness = 2 }, sheet)
-- The page keeps the whole scroll's size while the sheet over it is unrolled.
local page: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(25, 1),
	BackgroundTransparency = 1,
}, sheet)
local rollers: { Frame } = {}
for _, side in { 0, 1 } do
	local roller: Frame = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.022, 1.3),
		BackgroundColor3 = ROLLER,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, scroll)
	corner(roller, 0, 4)
	for _, tip in { 0, 1 } do
		local knob: Frame = make("Frame", {
			AnchorPoint = Vector2.new(0.5, tip),
			Position = UDim2.fromScale(0.5, tip),
			Size = UDim2.fromScale(1.5, 0.14),
			BackgroundColor3 = ROLLER_END,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, roller)
		corner(knob, 0, 3)
	end
	rollers[side + 1] = roller
end
local stageWords = label(page, {
	Position = UDim2.fromScale(0.045, 0.1),
	Size = UDim2.fromScale(0.68, 0.44),
	TextXAlignment = Enum.TextXAlignment.Left,
})
local percent = label(page, {
	Position = UDim2.fromScale(0.73, 0.1),
	Size = UDim2.fromScale(0.225, 0.44),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = SEAL,
	Text = "0%",
})
local track: Frame = make("Frame", {
	Position = UDim2.fromScale(0.045, 0.62),
	Size = UDim2.fromScale(0.91, 0.2),
	BackgroundColor3 = WRITING,
	BackgroundTransparency = 0.8,
	BorderSizePixel = 0,
}, page)
corner(track, 0.5)
local fill: Frame = make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
}, track)
corner(fill, 0.5)
make("UIGradient", {
	Color = ColorSequence.new(DEEP_RED, SEAL),
}, fill)
-- The kunai at the bar's head, tip forward: the picture stands upright, so it is turned. Until it
-- has loaded a small gold diamond stands there.
local diamond: Frame = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromScale(1.6, 1.6),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	Rotation = 45,
	BackgroundColor3 = GOLD,
	BorderSizePixel = 0,
	ZIndex = 2,
}, track)
local kunai: ImageLabel = make("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0, 0.5),
	Size = UDim2.fromScale(4.2, 4.2),
	SizeConstraint = Enum.SizeConstraint.RelativeYY,
	Rotation = 90,
	BackgroundTransparency = 1,
	Image = KUNAI,
	ImageTransparency = 1,
	ZIndex = 3,
}, track)

-- The tip under the scroll.
-- Two lines of it at the most, so that a long tip is not written small on a phone.
local tipLine = label(content, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.905),
	Size = UDim2.fromScale(0.78, 0.075),
	TextColor3 = PAPER,
	TextWrapped = true,
	RichText = true,
	TextTransparency = 1,
})
local tipSize: UITextSizeConstraint = make("UITextSizeConstraint", {}, tipLine)
local tipEdge: UIStroke =
	make("UIStroke", { Color = INK, Thickness = 1.5, Transparency = 1 }, tipLine)

-- Skip, for a load that takes too long.
local skip: TextButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -20),
	Size = UDim2.fromScale(0.11, 0.05),
	BackgroundColor3 = PARCHMENT,
	BorderSizePixel = 0,
	FontFace = BRUSH,
	TextScaled = true,
	TextColor3 = WRITING,
	AutoButtonColor = true,
	Visible = false,
}, content)
skip:SetAttribute("KeepFace", true)
corner(skip, 0, 8)
make(
	"UIStroke",
	{ Color = WRITING, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
	skip
)
make("UISizeConstraint", { MinSize = Vector2.new(96, 32), MaxSize = Vector2.new(220, 64) }, skip)
make("UIPadding", {
	PaddingTop = UDim.new(0.16, 0),
	PaddingBottom = UDim.new(0.16, 0),
	PaddingLeft = UDim.new(0.08, 0),
	PaddingRight = UDim.new(0.08, 0),
}, skip)

gui.Parent = player:WaitForChild("PlayerGui")

-- The words in the language: the stage being said, the tip, Skip.
local step = 1
local tipIndex = random:NextInteger(1, #Words.en.tips)
local function words(): Words.Pack
	return Words[language] or Words.en
end
local function face(): Font
	return if language == "ru" then CAVEAT else BRUSH
end
local function writeTip()
	local pack = words()
	local tips = pack.tips
	local index = (tipIndex - 1) % #tips + 1
	tipLine.Text = `<font color="#FFCA28">{pack.tip}</font>   {paint(tips[index])}`
end
local function writeAll()
	local pack = words()
	stageWords.Text = pack.stages[step] or ""
	skip.Text = pack.skip
	for _, written in { stageWords, tipLine, skip } do
		written.FontFace = face()
	end
	writeTip()
end
writeAll()

-- How thick the writing's edges are and how the title sits, for this screen.
local function resized()
	local size = gui.AbsoluteSize
	local tall = math.max(size.Y, 1)
	narrow = size.X / tall < 1.3
	nameEdge.Thickness = math.max(2, tall * 0.005)
	subtitleEdge.Thickness = math.max(1.5, tall * 0.0035)
	shadow.Position = UDim2.fromOffset(math.max(2, tall * 0.004), math.max(3, tall * 0.007))
	title.Size = UDim2.fromScale(if narrow then 0.96 else 0.9, if narrow then 0.15 else 0.19)
	scroll.Size = UDim2.fromScale(if narrow then 0.86 else 0.5, 0.075)
	tipLine.Size = UDim2.fromScale(if narrow then 0.94 else 0.78, 0.075)
	tipSize.MaxTextSize = math.max(14, math.floor(tall * 0.032))
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(resized)
resized()

-- It comes in: the title springs up, the scroll unrolls, the tip appears.
tween(titleScale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
for _, written in { name, shadow, subtitle } do
	tween(written, 0.5, { TextTransparency = 0 })
end
tween(nameEdge, 0.5, { Transparency = 0 })
tween(subtitleEdge, 0.5, { Transparency = 0 })
local unrolled = Instance.new("NumberValue")
unrolled.Value = 0.04
local function spread()
	local wide = math.clamp(unrolled.Value, 0.04, 1)
	sheet.Size = UDim2.fromScale(wide, 1)
	page.Size = UDim2.fromScale(1 / wide, 1)
	rollers[1].Position = UDim2.fromScale(0.5 - wide / 2, 0.5)
	rollers[2].Position = UDim2.fromScale(0.5 + wide / 2, 0.5)
end
unrolled.Changed:Connect(spread)
spread()
task.delay(0.25, function()
	tween(unrolled, 0.6, { Value = 1 }, Enum.EasingStyle.Quart)
end)
task.delay(0.6, function()
	tween(tipLine, 0.5, { TextTransparency = 0 })
	tween(tipEdge, 0.5, { Transparency = 0.2 })
end)

-- The pictures are fetched first of all; each comes in once it is here.
task.spawn(function()
	ContentProvider:PreloadAsync(
		{ banner, kunai },
		function(asset: string, status: Enum.AssetFetchStatus)
			if status ~= Enum.AssetFetchStatus.Success then
				return
			end
			if asset == BANNER then
				tween(banner, 0.9, { ImageTransparency = 0 })
			elseif asset == KUNAI then
				tween(kunai, 0.3, { ImageTransparency = 0 })
				tween(diamond, 0.3, { BackgroundTransparency = 1 })
			end
		end
	)
end)

-- The tips take turns.
task.spawn(function()
	while gui.Parent do
		task.wait(TIP_SECONDS)
		if not gui.Parent then
			return
		end
		tween(tipLine, 0.3, { TextTransparency = 1 })
		tween(tipEdge, 0.3, { Transparency = 1 })
		task.wait(0.32)
		tipIndex += 1
		writeTip()
		tween(tipLine, 0.4, { TextTransparency = 0 })
		tween(tipEdge, 0.4, { Transparency = 0.2 })
	end
end)

-- What the bar shows, and where it is going: a step's share at once, and towards the next one
-- slowly, never quite to it, while that step is waited for.
local began = os.clock()
local stepBegan = began
local shown = 0
local leaving = false
local function reach(index: number)
	if index <= step or leaving then
		return
	end
	step = index
	stepBegan = os.clock()
	stageWords.Text = words().stages[step] or ""
end

local ticking: RBXScriptConnection
ticking = RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()
	local since = now - began
	-- The picture drifts slowly nearer and back.
	local drift = (1 - math.cos(since * 2 * math.pi / 26)) / 2
	banner.Size = UDim2.fromScale(1.08 + 0.06 * drift, 1.08 + 0.06 * drift)
	banner.Position = UDim2.fromScale(0.5 + 0.012 * math.sin(since * 0.21), 0.5 - 0.01 * drift)
	-- The glint crosses the title every four seconds.
	local sweep = (since % 4) / 1.4
	glint.Offset = Vector2.new(if sweep < 1 then -1 + 2 * sweep else 1, 0)
	-- The petals.
	local tall = gui.AbsoluteSize.Y
	for _, petal in petals do
		local y = (since * petal.speed + petal.offset) % 1.3 - 0.15
		local x = petal.x + petal.sway * math.sin(since * 0.9 + petal.phase) + y * 0.08
		petal.frame.Position = UDim2.fromScale(x, y)
		petal.frame.Rotation = since * petal.spin + petal.phase * 57
		petal.frame.Size = UDim2.fromOffset(petal.size * tall, petal.size * tall * 0.62)
	end
	-- The bar.
	local floor = STEPS[step]
	local ceiling = STEPS[step + 1] or 1
	local wanted = if step >= #STEPS
		then 1
		else floor + (ceiling - floor) * 0.92 * (1 - math.exp(-(now - stepBegan) / 3))
	shown += (wanted - shown) * math.min(1, dt * (if step >= #STEPS then 9 else 5))
	fill.Size = UDim2.fromScale(shown, 1)
	kunai.Position = UDim2.fromScale(shown, 0.5)
	diamond.Position = UDim2.fromScale(shown, 0.5)
	percent.Text = `{math.floor(shown * 100 + 0.5)}%`
end)

-- Fades everything away as the picture comes nearer, and is gone.
local function leave()
	if leaving then
		return
	end
	reach(#STEPS)
	leaving = true
	task.wait(0.55)
	local seconds = 0.7
	for _, item in gui:GetDescendants() do
		if item:IsA("TextLabel") or item:IsA("TextButton") then
			tween(item, seconds, { TextTransparency = 1, BackgroundTransparency = 1 })
		elseif item:IsA("ImageLabel") then
			tween(item, seconds, { ImageTransparency = 1, BackgroundTransparency = 1 })
		elseif item:IsA("Frame") then
			tween(item, seconds, { BackgroundTransparency = 1 })
		elseif item:IsA("UIStroke") then
			tween(item, seconds, { Transparency = 1 })
		end
	end
	tween(ground, seconds, { BackgroundTransparency = 1 })
	tween(titleScale, seconds, { Scale = 1.08 })
	task.wait(seconds + 0.05)
	ticking:Disconnect()
	gui:Destroy()
end

skip.Activated:Connect(function()
	task.spawn(leave)
end)
task.delay(SKIP_AFTER, function()
	if gui.Parent and not leaving then
		skip.Visible = true
		skip.BackgroundTransparency = 1
		skip.TextTransparency = 1
		tween(skip, 0.4, { BackgroundTransparency = 0.05, TextTransparency = 0 })
	end
end)

-- The language the client chose, once it says.
local function heard()
	local chosen = player:GetAttribute(LANGUAGE_ATTRIBUTE)
	if typeof(chosen) == "string" and Words[chosen] and chosen ~= language then
		language = chosen
		writeAll()
	end
end
player:GetAttributeChangedSignal(LANGUAGE_ATTRIBUTE):Connect(heard)
heard()

-- The steps, in turn.
if not game:IsLoaded() then
	game.Loaded:Wait()
end
reach(2)
local function ready(): number
	local value = player:GetAttribute(LOADING_ATTRIBUTE)
	return if typeof(value) == "number" then value else 0
end
while ready() < 2 and os.clock() - began < LONGEST and not leaving do
	if ready() >= 1 then
		reach(3)
	end
	task.wait(0.1)
end
if not leaving then
	reach(3)
	reach(4)
	local settling = os.clock()
	while
		os.clock() - settling < SETTLE_MOST
		and ContentProvider.RequestQueueSize > SETTLED_QUEUE
		and os.clock() - began < LONGEST
		and not leaving
	do
		task.wait(0.1)
	end
	local rest = SHORTEST - (os.clock() - began)
	if rest > 0 then
		task.wait(rest)
	end
	leave()
end
