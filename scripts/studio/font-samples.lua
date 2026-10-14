-- Shows the faces that can write Russian in this game side by side, in Studio, so that one can
-- be chosen for Config/Languages (`font` of "ru"). Paste into Studio's command bar (View >
-- Command Bar) and press Enter: a sheet appears over the viewport, in edit mode, no test run
-- needed. Paste it again to take the sheet away.
--
-- The brush the game is written in (Permanent Marker) has no Cyrillic, so Russian needs another
-- face. The candidates: Marhey and Caveat from the Creator Store, by their font ids, and the
-- ones shipped with Roblox. Each line is written in its face; the last is the brush with Latin
-- for comparison. The game writes Russian in Caveat (Config/Languages), the owner's choice.

local StarterGui = game:GetService("StarterGui")

local old = StarterGui:FindFirstChild("FontSamples")
if old then
	old:Destroy()
	print("[FontSamples] the sheet is gone")
	return
end

local SAMPLE = "Лавка Тентен  +1.2K Рё/с  ВРАТА ОТКРЫТИЯ"
local FACES = {
	{
		"Marhey (Creator Store 12187364648)",
		Font.new("rbxassetid://12187364648", Enum.FontWeight.Bold),
	},
	{
		"Caveat (Creator Store 12187369802)",
		Font.new("rbxassetid://12187369802", Enum.FontWeight.Bold),
	},
	{ "Amatic SC Bold", Font.new("rbxasset://fonts/families/AmaticSC.json", Enum.FontWeight.Bold) },
	{ "Oswald Bold", Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold) },
	{
		"Montserrat Bold (the plain face)",
		Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold),
	},
	{ "Permanent Marker (the brush, Latin)", Font.fromEnum(Enum.Font.PermanentMarker) },
}

local gui = Instance.new("ScreenGui")
gui.Name = "FontSamples"
gui.IgnoreGuiInset = true

local sheet = Instance.new("Frame")
sheet.AnchorPoint = Vector2.new(0.5, 0.5)
sheet.Position = UDim2.fromScale(0.5, 0.5)
sheet.Size = UDim2.fromOffset(900, 90 * #FACES + 20)
sheet.BackgroundColor3 = Color3.fromRGB(236, 220, 188)
sheet.Parent = gui

for index, entry in FACES do
	local name, face = entry[1], entry[2]
	local line = Instance.new("TextLabel")
	line.Position = UDim2.fromOffset(20, 10 + (index - 1) * 90)
	line.Size = UDim2.fromOffset(860, 56)
	line.BackgroundTransparency = 1
	line.FontFace = face
	line.TextSize = 40
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextColor3 = Color3.fromRGB(58, 40, 30)
	line.Text = if index == #FACES
		then "Tenten's Ninja Tools  +1.2K Ryo/s  GATE OF OPENING"
		else SAMPLE
	line.Parent = sheet
	local caption = Instance.new("TextLabel")
	caption.Position = UDim2.fromOffset(20, 64 + (index - 1) * 90)
	caption.Size = UDim2.fromOffset(860, 20)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.SourceSans
	caption.TextSize = 18
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.TextColor3 = Color3.fromRGB(120, 90, 70)
	caption.Text = `{index}. {name}`
	caption.Parent = sheet
end

gui.Parent = StarterGui
print("[FontSamples] the sheet is over the viewport; paste the script again to take it away")
