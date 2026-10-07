--!strict
-- The papers on the plaza's notice board: where each is pinned, what it says, and how it is
-- drawn on the face of the part that is the paper. There are no pictures to put there, so a
-- paper is drawn the way the interface's icons are, from frames and writing: wanted posters
-- for the enemies of some zones, missions under a seal with their rank, and notes, some of
-- which tell a newcomer something true about the game.
--
-- World/Plaza builds the board and the papers themselves and calls write() for each.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local Notices = {}

export type Notice = {
	kind: "wanted" | "mission" | "note",
	title: string,
	body: string,
	place: string?, -- a wanted poster: where its subject is met
	tint: Color3?, -- and the color behind the portrait
	rank: string?, -- a mission: the letter on its seal
	red: boolean?, -- a note: whether its title is in red
	bowl: boolean?, -- whether a bowl of ramen is drawn on it
	stamp: boolean?, -- whether it carries a red stamp
}

-- A paper on the board: its middle, right and up from the middle of the board's face as one
-- looks at it, its size, and how far it hangs askew, degrees. All in studs.
export type Sheet = {
	x: number,
	y: number,
	width: number,
	height: number,
	roll: number,
	notice: Notice,
}

-- The face of the board the papers are laid out on: how wide and how tall.
Notices.BOARD = Vector2.new(9.6, 4.8)

-- How finely a paper is drawn, pixels to a stud.
local PIXELS = 120

local INK = Color3.fromRGB(46, 36, 30)
local FADED = Color3.fromRGB(118, 100, 84)
local RED = Color3.fromRGB(176, 38, 30)
local STEEL = Color3.fromRGB(158, 164, 172)

local sageStreak = Tuning.Kick.sageStreak
local sageMultiplier = Tuning.Kick.sageMultiplier

-- A wanted poster for the enemy of a zone, as the game's own list names it.
local function wanted(zoneId: string): Notice
	local zone = Catalog.zoneById[zoneId]
	-- "Itachi (Amaterasu)" is wanted as plain Itachi.
	local name = string.gsub(zone.enemy.name, "%s*%(.*%)", "")
	return {
		kind = "wanted",
		title = string.upper(name),
		body = "IF SEEN: RUN HOME!",
		place = string.upper(zone.name),
		tint = Color3.fromHex(zone.enemy.color),
	}
end

local function mission(rank: string, body: string): Notice
	return { kind = "mission", title = "MISSION", body = body, rank = rank }
end

local function zoneName(zoneId: string): string
	return Catalog.zoneById[zoneId].name
end

-- Where the eight papers of a side hang: two tall ones at the ends for the wanted posters,
-- and room between and under them for the rest.
local SLOTS = {
	{ x = -3.6, y = 0.8, width = 1.9, height = 2.8, roll = -2 },
	{ x = -1.25, y = 1.2, width = 2.3, height = 1.8, roll = 1.5 },
	{ x = 1.2, y = 0.9, width = 2.1, height = 2.4, roll = -1 },
	{ x = 3.6, y = 0.8, width = 1.9, height = 2.8, roll = 2.5 },
	{ x = -3.6, y = -1.5, width = 1.9, height = 1.2, roll = 2 },
	{ x = -1.25, y = -1.1, width = 2.3, height = 2, roll = -2.5 },
	{ x = 1.2, y = -1.35, width = 2.1, height = 1.4, roll = 1.5 },
	{ x = 3.6, y = -1.5, width = 1.9, height = 1.2, roll = -1.5 },
}

local function pinned(notices: { Notice }): { Sheet }
	local sheets: { Sheet } = {}
	for index, slot in SLOTS do
		table.insert(sheets, {
			x = slot.x,
			y = slot.y,
			width = slot.width,
			height = slot.height,
			roll = slot.roll,
			notice = notices[index],
		})
	end
	return sheets
end

-- The side that looks at the plaza's middle path.
Notices.front = pinned({
	wanted("academy"),
	mission("D", "Catch Tora, the runaway cat. Again."),
	{
		kind = "note",
		title = "ICHIRAKU RAMEN",
		body = "The best bowl in the village. Open till the last customer.",
		red = true,
		bowl = true,
	},
	wanted("land_of_waves"),
	{
		kind = "note",
		title = "LOST",
		body = "A green frog wallet, nearly empty. Return to Naruto.",
	},
	{
		kind = "note",
		title = "RULE ONE",
		body = "Train your Chakra every day. The more you have, the farther your kunai flies.",
		stamp = true,
	},
	mission("C", `Escort the bridge builder to the {zoneName("land_of_waves")}.`),
	{
		kind = "note",
		title = "NOTICE",
		body = "Do not feed the giant snakes.",
		red = true,
	},
})

-- The side that looks at the dojos.
Notices.back = pinned({
	wanted("akatsuki_lair"),
	mission("S", `Scout the {zoneName("akatsuki_lair")}. Come back in one piece.`),
	{
		kind = "note",
		title = "CHUNIN EXAMS",
		body = "Sign up at the Academy. Bring your own kunai. Finals at the arena.",
		stamp = true,
	},
	wanted("hidden_rain"),
	{
		kind = "note",
		title = "DOJO RULES",
		body = "Shoes off. No ramen on the pads.",
	},
	{
		kind = "note",
		title = "SAGE THROW",
		body = `{sageStreak} Perfect throws in a row charge it: x{sageMultiplier} power.`,
		red = true,
		stamp = true,
	},
	{
		kind = "note",
		title = "BINGO BOOK",
		body = "Fill a page for an income bonus that stays.",
	},
	{
		kind = "note",
		title = "TOO SLOW?",
		body = "Might Duy trains runners by the fountain.",
	},
})

-- A piece of writing in a box given in pixels: in the game's brush, as large as fits.
local function write(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	height: number,
	words: string,
	color: Color3
): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(width, height)
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = Enum.Font.PermanentMarker
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color
	label.Text = words
	label.Parent = parent
	return label
end

-- A patch of flat color in a box given in pixels. `round` is how round its corners are, as a
-- share of its shorter side: half makes a disc of a square and a pill of anything longer.
local function patch(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	height: number,
	color: Color3,
	round: number?
): Frame
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(width, height)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = frame
	end
	frame.Parent = parent
	return frame
end

-- A wanted poster: the word, a portrait, the name, where its subject is met, and what to do.
-- Nobody's likeness is to hand, so the portrait is the same dark figure for all of them, a
-- head and shoulders under a forehead plate with a scratch through it, on the enemy's color.
local function drawWanted(
	gui: SurfaceGui,
	wide: number,
	tall: number,
	notice: Notice,
	paper: Color3
)
	local border = patch(gui, wide * 0.04, tall * 0.027, wide * 0.92, tall * 0.946, paper)
	border.BackgroundTransparency = 1
	local line = Instance.new("UIStroke")
	line.Color = INK
	line.Thickness = 3
	line.Parent = border

	write(gui, wide * 0.08, tall * 0.045, wide * 0.84, tall * 0.16, "WANTED", RED)

	local width, height = wide * 0.72, tall * 0.42
	local tint = notice.tint or FADED
	local backdrop = Color3.new(
		tint.R + (paper.R - tint.R) * 0.45,
		tint.G + (paper.G - tint.G) * 0.45,
		tint.B + (paper.B - tint.B) * 0.45
	)
	local portrait = patch(gui, wide * 0.14, tall * 0.23, width, height, backdrop)
	portrait.ClipsDescendants = true
	local head = math.min(width * 0.42, height * 0.5)
	local top = height * 0.12
	-- The shoulders run out under the portrait's lower edge, which cuts them off.
	patch(portrait, width * 0.11, height * 0.6, width * 0.78, height * 0.7, INK, 0.5)
	patch(portrait, (width - head) / 2, top, head, head, INK, 0.5)
	patch(portrait, (width - head * 1.04) / 2, top + head * 0.24, head * 1.04, head * 0.2, STEEL)
	patch(portrait, (width - head * 0.7) / 2, top + head * 0.325, head * 0.7, 3, INK)

	write(gui, wide * 0.06, tall * 0.67, wide * 0.88, tall * 0.13, notice.title, INK)
	write(gui, wide * 0.06, tall * 0.8, wide * 0.88, tall * 0.075, notice.place or "", FADED)
	write(gui, wide * 0.06, tall * 0.88, wide * 0.88, tall * 0.08, notice.body, RED)
end

-- A mission: a red seal with its rank, the word and the rank beside it, and under a line
-- what is asked.
local function drawMission(
	gui: SurfaceGui,
	wide: number,
	tall: number,
	notice: Notice,
	paper: Color3
)
	local margin = wide * 0.06
	local seal = math.floor(tall * 0.36)
	local rank = notice.rank or "D"
	patch(gui, margin, tall * 0.08, seal, seal, RED, 0.5)
	write(gui, margin, tall * 0.08 + seal * 0.12, seal, seal * 0.76, rank, paper)

	local beside = margin + seal + wide * 0.04
	local room = wide - margin - beside
	local word = write(gui, beside, tall * 0.07, room, tall * 0.24, notice.title, INK)
	word.TextXAlignment = Enum.TextXAlignment.Left
	local under = write(gui, beside, tall * 0.31, room, tall * 0.13, `RANK {rank}`, FADED)
	under.TextXAlignment = Enum.TextXAlignment.Left

	patch(gui, margin, tall * 0.5, wide - 2 * margin, 3, INK)
	write(gui, margin, tall * 0.55, wide - 2 * margin, tall * 0.38, notice.body, INK)
end

-- A note: a title over a line, the words under it, and on some a bowl of ramen or a stamp.
local function drawNote(gui: SurfaceGui, wide: number, tall: number, notice: Notice)
	local margin = wide * 0.07
	local room = wide - 2 * margin
	if notice.stamp then
		-- Under the writing, as a stamp that was there first.
		local across = wide * 0.22
		local stamp =
			patch(gui, wide - margin - across, tall - margin - across, across, across, RED, 0.5)
		stamp.BackgroundTransparency = 0.45
	end

	local title = math.min(tall * 0.34, wide * 0.2)
	local y = tall * 0.07
	write(gui, margin, y, room, title, notice.title, if notice.red then RED else INK)
	y += title + tall * 0.03
	patch(gui, margin, y, room, 3, INK)
	y += tall * 0.04

	if notice.bowl then
		-- Steam over a bowl: the lower half of a disc under a rim, on a foot.
		local across = wide * 0.5
		local deep = across / 2
		local left = (wide - across) / 2
		for i = -1, 1 do
			patch(gui, wide / 2 + i * across * 0.2 - 2, y, 4, tall * 0.06, FADED, 0.5)
		end
		local bowl = y + tall * 0.08
		local half = patch(gui, left, bowl, across, deep, RED)
		half.BackgroundTransparency = 1
		half.ClipsDescendants = true
		patch(half, 0, -deep, across, across, RED, 0.5)
		patch(gui, left - across * 0.05, bowl - 3, across * 1.1, 7, INK, 0.5)
		patch(gui, wide / 2 - across * 0.18, bowl + deep - 1, across * 0.36, 6, INK)
		y = bowl + deep + tall * 0.05
	end

	write(gui, margin, y, room, tall * 0.94 - y, notice.body, INK)
end

-- Draws a notice on one face of the part that is its paper. The part's own color is the paper.
function Notices.write(paper: BasePart, face: Enum.NormalId, notice: Notice): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Writing"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PIXELS
	-- Paper is lit as the world is; and what is drawn later lies over what is drawn first.
	gui.LightInfluence = 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = paper

	local wide, tall = paper.Size.X * PIXELS, paper.Size.Y * PIXELS
	if notice.kind == "wanted" then
		drawWanted(gui, wide, tall, notice, paper.Color)
	elseif notice.kind == "mission" then
		drawMission(gui, wide, tall, notice, paper.Color)
	else
		drawNote(gui, wide, tall, notice)
	end
	return gui
end

return Notices
