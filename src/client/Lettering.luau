--!strict
-- Draws the names that are written in more than a plain color (Config/Lettering) and keeps
-- them moving: colors running through the letters, a glint passing over them, lightning across
-- them, rings spreading from their middle, their own shapes rising off them like flame.
--
-- A label is lettered in one of two ways. Whatever builds a tag in the world (View/Figure, on
-- the server or here) marks the label with a tag and the key of its lettering, and this module
-- finds it; the interface's own labels are handed over with `dress`. Either way all of it is
-- done on this client: the server only says which lettering a label is in.
--
-- The colors of a label are a UIGradient, and a gradient runs across the whole label, which is
-- often far wider than the word in it. So the gradient is laid over the word alone: every color
-- is placed within the stretch of the label that the text covers.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Styles = require(ReplicatedStorage.Shared.Config.Lettering)

local Lettering = {}

-- How often the letters are redrawn, seconds.
local STEP = 1 / 24
-- How many colors along a word its gradient is drawn with.
local SAMPLES = 10
-- How wide a glint is, as a share of the word, and the share of its period it takes to cross.
local GLINT = 0.2
local GLINT_CROSSES = 0.3
-- A stroke of lightning: when its flickers are lit, seconds from its start, and how long it is.
local FLICKERS = { { 0, 0.07 }, { 0.12, 0.18 }, { 0.23, 0.26 } }
local STRIKE_SECONDS = 0.28
-- A bolt is this many straight pieces, and this thick as a share of the label's height.
local BOLT_PIECES = 4
local BOLT_THICK = 0.08
-- The shapes that rise off letters with an aura: how many, how far they rise as a share of the
-- label's height, how much they grow, and how see-through they are when they set off.
local GHOSTS = 2
local GHOST_RISE = 0.42
local GHOST_GROWS = 0.1
local GHOST_CLEAR = 0.45
-- The outline of lettered words in the interface, pixels.
local OUTLINE = 1.5
-- A word that is not on screen cannot be measured: it is taken to be this wide a letter, as a
-- share of its height, until it can be, and is tried again this often, seconds.
local GLYPH = 0.55
local MEASURE_AGAIN = 0.5

local WHITE = Color3.new(1, 1, 1)

type Record = {
	key: string,
	style: Styles.Style,
	fill: { Color3 },
	edge: Color3,
	flare: Color3,
	shade: Color3, -- what rises off the letters
	plate: boolean, -- a plate of color with dark writing on it, not colored writing
	world: boolean, -- on a tag in the world, not in the interface
	-- Seconds this lettering runs ahead of the clock. It comes of the lettering's key, not of
	-- chance: cards are built anew whenever the inventory changes, and a word that took up a
	-- new place in its motion every time would jump. So words in one lettering keep time.
	phase: number,
	gradient: UIGradient,
	stroke: UIStroke?,
	ghosts: { TextLabel },
	raised: boolean, -- the label was lifted a layer for its ghosts to lie under it
	bolts: { Frame },
	-- The stretch of the label the word covers, as shares of its width, and the text and size
	-- it was measured for.
	from: number,
	to: number,
	measured: string,
	measureAt: number, -- when to measure again a word that could not be; never, once it was
	still: boolean, -- drawn in its resting colors, with nothing to redraw until something moves
	-- The colors the label had before it was lettered, given back when the lettering comes off.
	was: { text: Color3, stroke: Color3, strokeClear: number, back: Color3 },
	strikeAt: number, -- when lightning next strikes, and when the stroke under way began
	struckAt: number,
	lit: boolean,
}

local records: { [TextLabel]: Record } = {}
local rng = Random.new()

-- The color `at` of the way along a row of colors, 0..1.
local function along(colors: { Color3 }, at: number): Color3
	local last = #colors
	if last == 1 then
		return colors[1]
	end
	local place = math.clamp(at, 0, 1) * (last - 1)
	local index = math.min(math.floor(place), last - 2)
	return colors[index + 1]:Lerp(colors[index + 2], place - index)
end

-- The same row of colors gone round in a ring: `at` may be any number, and 1 is 0 again.
local function round(colors: { Color3 }, at: number): Color3
	local count = #colors
	local place = (at % 1) * count
	local index = math.floor(place) % count
	return colors[index + 1]:Lerp(colors[(index + 1) % count + 1], place - math.floor(place))
end

-- Lays the colors `paint` gives for each share of the word over the stretch of the label the
-- word covers.
local function lay(record: Record, paint: (share: number) -> Color3)
	local from, to = record.from, record.to
	local points = {}
	local first, last = paint(0), paint(1)
	if from > 0.002 then
		table.insert(points, ColorSequenceKeypoint.new(0, first))
	end
	for i = 0, SAMPLES do
		local share = i / SAMPLES
		local color = if i == 0 then first elseif i == SAMPLES then last else paint(share)
		-- A gradient's first color is at 0 and its last at 1, exactly.
		local at = if i == 0 then from elseif i == SAMPLES then to else from + (to - from) * share
		table.insert(points, ColorSequenceKeypoint.new(at, color))
	end
	if to < 0.998 then
		table.insert(points, ColorSequenceKeypoint.new(1, last))
	end
	record.gradient.Color = ColorSequence.new(points)
end

-- Finds the stretch of the label its word covers. A label that is not on screen yet has no
-- size to measure: on a tag in the world its word is reckoned from its length until it has,
-- and elsewhere the label is taken to be filled.
local function measure(label: TextLabel, record: Record, now: number)
	record.measured = label.Text
	record.measureAt = math.huge
	record.from, record.to = 0, 1
	if record.plate then
		return
	end
	local width = label.AbsoluteSize.X
	local text = label.TextBounds.X
	local share = 1
	if width > 0 and text > 0 then
		share = text / width
	else
		record.measureAt = now + MEASURE_AGAIN
		local board = label:FindFirstAncestorWhichIsA("BillboardGui")
		local wide = if board then board.Size.X.Scale * label.Size.X.Scale else 0
		local tall = if board then board.Size.Y.Scale * label.Size.Y.Scale else 0
		if wide <= 0 or tall <= 0 then
			return
		end
		share = #label.Text * GLYPH * tall / wide
	end
	share = math.clamp(share, 0.05, 1)
	local from, to
	if label.TextXAlignment == Enum.TextXAlignment.Left then
		from, to = 0, share
	elseif label.TextXAlignment == Enum.TextXAlignment.Right then
		from, to = 1 - share, 1
	else
		from, to = (1 - share) / 2, (1 + share) / 2
	end
	-- An end that all but reaches the label's is the label's.
	record.from = if from <= 0.002 then 0 else from
	record.to = if to >= 0.998 then 1 else to
end

local function outline(label: TextLabel, record: Record, color: Color3)
	if record.stroke then
		record.stroke.Color = color
	elseif record.world then
		label.TextStrokeColor3 = color
	end
end

-- Draws a bolt of lightning across the word: a few straight pieces from one end of it to the
-- other, up and down as they go.
local function strike(label: TextLabel, record: Record)
	local size = label.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local x, y = record.from, rng:NextNumber(0.25, 0.75)
	local step = (record.to - record.from) / BOLT_PIECES
	for index, bolt in record.bolts do
		local nextX = record.from + step * index
		local nextY = if index % 2 == 0
			then rng:NextNumber(0.5, 0.92)
			else rng:NextNumber(0.08, 0.5)
		local dx, dy = (nextX - x) * size.X, (nextY - y) * size.Y
		bolt.Position = UDim2.fromScale((x + nextX) / 2, (y + nextY) / 2)
		bolt.Size =
			UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1, math.max(2, size.Y * BOLT_THICK))
		bolt.Rotation = math.deg(math.atan2(dy, dx))
		x, y = nextX, nextY
	end
end

local function redraw(label: TextLabel, record: Record, now: number)
	if record.measured ~= label.Text or now >= record.measureAt then
		measure(label, record, now)
		record.still = false
	end
	local style = record.style
	local time = now + record.phase
	local turn = time / style.period
	local fill, flare = record.fill, record.flare

	if style.motion == "flow" then
		-- The colors run through the word, a little under one round of them in sight.
		lay(record, function(share)
			return round(fill, share * 0.8 - turn)
		end)
	elseif style.motion == "ripple" then
		-- Rings go out from the middle of the word to both of its ends.
		lay(record, function(share)
			return round(fill, math.abs(share - 0.5) * 1.6 - turn)
		end)
	elseif style.motion == "storm" then
		if now >= record.strikeAt then
			record.struckAt = now
			record.strikeAt = now + style.period * rng:NextNumber(0.5, 1.7)
			strike(label, record)
		end
		local since = now - record.struckAt
		local lit = false
		if since < STRIKE_SECONDS then
			for _, flicker in FLICKERS do
				lit = lit or (since >= flicker[1] and since < flicker[2])
			end
		end
		if lit ~= record.lit or not record.still then
			record.lit = lit
			record.still = true
			lay(record, function(share)
				return if lit then flare else along(fill, share)
			end)
			outline(label, record, if lit then flare else record.edge)
			for _, bolt in record.bolts do
				bolt.Visible = lit
			end
		end
	else
		-- A glint crosses the word at the start of every period; "aura" has its shapes rise too.
		local passed = (turn % 1) / GLINT_CROSSES
		if passed < 1 then
			local middle = -GLINT + (1 + 2 * GLINT) * passed
			record.still = false
			lay(record, function(share)
				local weight = math.max(0, 1 - math.abs(share - middle) / GLINT)
				return along(fill, share):Lerp(flare, weight)
			end)
		elseif not record.still then
			record.still = true
			lay(record, function(share)
				return along(fill, share)
			end)
		end
	end

	for index, ghost in record.ghosts do
		if ghost.Text ~= label.Text then
			ghost.Text = label.Text
		end
		local risen = (turn + (index - 1) / #record.ghosts) % 1
		local place, size = label.Position, label.Size
		ghost.Size = size
		ghost.Position = UDim2.new(
			place.X.Scale,
			place.X.Offset,
			place.Y.Scale - size.Y.Scale * GHOST_RISE * risen,
			place.Y.Offset - size.Y.Offset * GHOST_RISE * risen
		)
		ghost.TextTransparency = GHOST_CLEAR + (1 - GHOST_CLEAR) * risen
		local scale = ghost:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = 1 + GHOST_GROWS * risen
		end
	end
end

-- Takes a label's lettering off it again and gives it back the colors it had.
local function undress(label: TextLabel)
	local record = records[label]
	if not record then
		return
	end
	records[label] = nil
	label.TextColor3 = record.was.text
	label.TextStrokeColor3 = record.was.stroke
	label.TextStrokeTransparency = record.was.strokeClear
	label.BackgroundColor3 = record.was.back
	record.gradient:Destroy()
	if record.stroke then
		record.stroke:Destroy()
	end
	for _, ghost in record.ghosts do
		ghost:Destroy()
	end
	if record.raised then
		label.ZIndex -= 1
	end
	for _, bolt in record.bolts do
		bolt:Destroy()
	end
end

-- Letters a label in the lettering `key` stands for (Config/Lettering.key), or takes its
-- lettering off when there is none. A `plate` is a label that is a plate of color with dark
-- writing on it: the plate is what takes the colors.
function Lettering.dress(label: TextLabel, key: string?, plate: boolean?)
	local had = records[label]
	if had and had.key == key and had.plate == (plate == true) then
		return
	end
	undress(label)
	local style = if key then Styles.style(key) else nil
	if not key or not style then
		return
	end

	local fill = {}
	for _, hex in style.fill do
		table.insert(fill, Color3.fromHex(hex))
	end
	local world = label:FindFirstAncestorWhichIsA("BillboardGui") ~= nil
	local edge, flare = Color3.fromHex(style.edge), Color3.fromHex(style.flare)
	local phase = 0
	for index = 1, #key do
		phase += string.byte(key, index) * 0.37
	end
	local record: Record = {
		key = key,
		style = style,
		fill = fill,
		edge = edge,
		flare = flare,
		shade = if style.shade then Color3.fromHex(style.shade) else flare,
		plate = plate == true,
		world = world,
		phase = phase % style.period,
		gradient = Instance.new("UIGradient"),
		stroke = nil,
		ghosts = {},
		raised = false,
		bolts = {},
		from = 0,
		to = 1,
		measured = "",
		measureAt = 0,
		still = false,
		was = {
			text = label.TextColor3,
			stroke = label.TextStrokeColor3,
			strokeClear = label.TextStrokeTransparency,
			back = label.BackgroundColor3,
		},
		strikeAt = os.clock() + rng:NextNumber(0.2, style.period),
		struckAt = -1,
		lit = false,
	}

	if record.plate then
		-- The gradient colors the plate; the dark writing on it stays dark under any of them.
		label.BackgroundColor3 = WHITE
	else
		-- Shapes of the word that rise off it, behind it: made before anything is hung on the
		-- label, so that a copy of it is a copy of the bare text. A layer's pieces are drawn in
		-- the order of their ZIndex whatever holds them, so the label is lifted one and its
		-- ghosts take the place it had: over the card or the board, under the word.
		if style.motion == "aura" and label.Parent then
			local under = label.ZIndex
			label.ZIndex = under + 1
			record.raised = true
			for _ = 1, GHOSTS do
				local ghost = label:Clone()
				ghost:ClearAllChildren()
				CollectionService:RemoveTag(ghost, Net.LETTERING_TAG)
				ghost:SetAttribute(Net.LETTERING_ATTRIBUTE, nil)
				ghost.Name = "Ghost"
				ghost.RichText = false
				ghost.TextColor3 = record.shade
				ghost.TextStrokeTransparency = 1
				ghost.BackgroundTransparency = 1
				ghost.ZIndex = under
				ghost.Active = false
				Instance.new("UIScale").Parent = ghost
				ghost.Parent = label.Parent
				table.insert(record.ghosts, ghost)
			end
		end
		-- The gradient multiplies the text's own color: white lets its colors through.
		label.TextColor3 = WHITE
		if world then
			label.TextStrokeColor3 = edge
			label.TextStrokeTransparency = 0
		else
			local stroke = Instance.new("UIStroke")
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			stroke.LineJoinMode = Enum.LineJoinMode.Round
			stroke.Thickness = OUTLINE
			stroke.Color = edge
			stroke.Parent = label
			record.stroke = stroke
		end
		if style.motion == "storm" then
			for _ = 1, BOLT_PIECES do
				local bolt = Instance.new("Frame")
				bolt.Name = "Bolt"
				bolt.AnchorPoint = Vector2.new(0.5, 0.5)
				bolt.BackgroundColor3 = WHITE
				bolt.BorderSizePixel = 0
				bolt.Visible = false
				bolt.ZIndex = label.ZIndex + 1
				bolt.Parent = label
				table.insert(record.bolts, bolt)
			end
		end
	end

	-- A glint crosses a word on a slant; everything else runs straight along it.
	local slanted = style.motion == "sheen" or style.motion == "aura"
	record.gradient.Rotation = if slanted and not record.plate then 12 else 0
	record.gradient.Parent = label
	records[label] = record
	redraw(label, record, os.clock())
end

function Lettering.start()
	local function adopt(instance: Instance)
		local key = instance:GetAttribute(Net.LETTERING_ATTRIBUTE)
		if instance:IsA("TextLabel") and typeof(key) == "string" then
			Lettering.dress(instance, key)
		end
	end
	CollectionService:GetInstanceAddedSignal(Net.LETTERING_TAG):Connect(adopt)
	for _, instance in CollectionService:GetTagged(Net.LETTERING_TAG) do
		adopt(instance)
	end

	local since = 0
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < STEP then
			return
		end
		since = 0
		local now = os.clock()
		for label, record in records do
			if not label.Parent then
				-- Whatever held the label is gone, and what was hung beside it with it.
				undress(label)
			else
				-- One label that cannot be drawn must not stop the rest, every frame: it
				-- goes back to the plain color it had and says why.
				-- (Cast, or the checker has it that a function returning nothing leaves
				-- pcall nothing to say when it fails.)
				local drawn, problem = pcall(redraw :: any, label, record, now)
				if not drawn then
					undress(label)
					warn(`[Lettering] {record.key} on {label:GetFullName()}: {problem}`)
				end
			end
		end
	end)
end

return Lettering
