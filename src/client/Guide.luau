--!strict
-- Iruka, the guide (Config/Guide; owner, 2026-10-19: "cover literally everything: a base
-- tutorial at the very start, and mini tutorials when something is first met; mutations are
-- mentioned in passing in the base one, and when a player first catches a shinobi with a
-- mutation Iruka explains it in more detail; so with every mechanic"). He speaks on a scroll
-- at the top of the screen, his face in a red frame beside his words (the keepers' way,
-- client Speech), with words in color as the FAQ has them (Ui.paint), and arrows point at what
-- he speaks of: a red arrow and a ring at a part of the interface, a red arrow over a place in
-- the world.
--
-- THE BASE TUTORIAL runs at the first visit and cannot be skipped then; a step either waits
-- for the player to do something (gather Chakra, step onto the strip, throw, bring a catch
-- home, set it on a pad) or has a button. The steps done are saved (Services/Guide), so one who
-- leaves half way goes on where they stopped. Replayed from the settings it can be skipped
-- and saves nothing. A TIP is said once, the first time what it is about is met, and waits
-- for its turn: never during the base tutorial, a throw (Cinematic.staging) or with a window
-- open. Everything waits so; nothing Iruka says stops the game.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Cinematic = require("./Cinematic")
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local GuideConfig = require(ReplicatedStorage.Shared.Config.Guide)
local Index = require(ReplicatedStorage.Shared.Logic.Index)
local Net = require(ReplicatedStorage.Shared.Net)
local Portrait = require("./Portrait")
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Remotes = require("./Remotes")
local Store = require("./Store")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local Guide = {}

-- The scroll: its width, where its top is, the face, the room the words have, their sizes
-- (the largest that keeps them to four lines), how tall a line is for its size, and the
-- button. The words were 18 to 22 px (owner, 2026-10-19: "Iruka's text is too small too";
-- "the menu itself is good"): 24 to 28 now, on a wider scroll.
local CARD_WIDE = 880
local CARD_TOP = 96
local FACE = 124
local WORDS_LEFT = 30 + FACE + 22
local WORDS_WIDE = CARD_WIDE - WORDS_LEFT - 36
local WORD_SIZES = { 28, 27, 26, 25, 24 }
local LINE_SHARE = 1.22
local BUTTON = Vector2.new(190, 48)
local MOST_LINES = 4
-- Chakra a "gather Chakra" step asks for.
local CHAKRA_TO_GATHER = 10
-- The arrows: their size, how far off what they point at, how far they bob.
local ARROW = Vector2.new(46, 56)
local ARROW_OFF = 38
-- The arrow at the screen's edge for a place out of sight: how much larger, how far in.
local EDGE_GROW = 1.4
local EDGE_MARGIN = 70
-- The trail on the ground from the player towards a place: chevrons, how many, how far apart,
-- where the first is, an arm's length and thickness, how far an arm leans back, how fast the
-- light runs along them, and how near the place they stop being laid.
local TRAIL_COUNT = 6
local TRAIL_STEP = 3.6
local TRAIL_FIRST = 3
local TRAIL_ARM = 2.4
local TRAIL_THICK = 0.5
local TRAIL_LEAN = math.rad(38)
local TRAIL_RUN = 7
local TRAIL_NEAR = 7
local BOB = 7

type Arrow = { frame: Frame, ring: Frame?, target: GuiObject?, cleanup: () -> () }

local state = {
	-- The base tutorial: running, and whether it is a replay (skippable, saves nothing).
	running = false,
	replay = false,
	step = 0, -- the step being said
	waiting = nil :: string?,
	chakraFrom = 0,
	-- The tip being said, and those waiting their turn.
	tip = nil :: string?,
	queue = {} :: { string },
	said = {} :: { [string]: boolean },
	-- Whether the scroll is meant to be up (it hides while the game is busy).
	speaking = false,
}

local paper: Ui.Parchment
local words: TextLabel
local button: TextButton
local skip: TextButton
local onButton: (() -> ())? = nil
local arrows: { Arrow } = {}
local arrowLayer: Frame

-- A red arrow pointing down, drawn of frames in `holder`: a shaft and a head of stacked bars
-- on an ink shadow. Turned by the holder's Rotation.
local function drawArrow(holder: Frame)
	local function paint(color: Color3, grow: number, offset: number)
		Ui.make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, offset, 0, offset),
			Size = UDim2.new(0.34, grow, 0.46, grow),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, holder)
		local steps = 12
		for step = 0, steps - 1 do
			local share = 1 - step / steps
			Ui.make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, offset, 0.44 + 0.56 * step / steps, offset),
				Size = UDim2.new(share, grow, 0.56 / steps, 1),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
			}, holder)
		end
	end
	paint(Ui.INK, 4, 2)
	paint(Ui.SEAL, 0, 0)
end

local function clearArrows()
	for _, arrow in arrows do
		arrow.cleanup()
	end
	table.clear(arrows)
end

-- The part of the world a name stands for (Config/Guide `point`), or nil.
local function placeOf(name: string): BasePart?
	if name == "strip" then
		local strip = Workspace:FindFirstChild("ThrowStrip", true)
		return if strip and strip:IsA("BasePart") then strip else nil
	elseif name == "gift" then
		local box = Workspace:FindFirstChild("GiftBox", true)
		return if box and box:IsA("BasePart") then box else nil
	elseif name == "board" then
		for _, prompt in CollectionService:GetTagged(Net.INFO_TAG) do
			local parent = prompt.Parent
			if parent and parent:IsA("BasePart") then
				return parent
			end
		end
		return nil
	elseif name == "dojo" then
		local userId = Players.LocalPlayer.UserId
		for _, model in Workspace:GetDescendants() do
			if model:IsA("Model") and model:GetAttribute(Net.DOJO_OWNER_ATTRIBUTE) == userId then
				local home = model:FindFirstChild(Net.HOME_PART)
				return if home and home:IsA("BasePart") then home else nil
			end
		end
		return nil
	end
	-- A shop, by its id.
	local market = Workspace:FindFirstChild(Net.MARKET_FOLDER)
	if market then
		for _, prompt in market:GetDescendants() do
			if
				prompt:IsA("ProximityPrompt")
				and prompt:GetAttribute(Net.SHOP_ATTRIBUTE) == name
			then
				local parent = prompt.Parent
				return if parent and parent:IsA("BasePart") then parent else nil
			end
		end
	end
	return nil
end

-- An arrow over a place in the world, for this player alone, the same size on the screen near
-- and far; and, while that place is out of sight (behind the camera, or off the screen's
-- edges), a larger arrow at the edge of the screen turned towards it, so that "follow the
-- arrow" can be followed from anywhere (owner, 2026-10-19: "Iruka told me to follow the arrow,
-- but there are no arrows": the arrow over the strip was there, out of sight behind him).
local function pointAtPlace(part: BasePart, above: number, withTrail: boolean)
	local board: BillboardGui = Ui.make("BillboardGui", {
		Name = "GuideArrow",
		Adornee = part,
		AlwaysOnTop = true,
		LightInfluence = 0,
		Size = UDim2.fromOffset(ARROW.X * Ui.scale(), (ARROW.Y + BOB * 2) * Ui.scale()),
		StudsOffsetWorldSpace = Vector3.new(0, part.Size.Y / 2 + above, 0),
	})
	local holder: Frame = Ui.make("Frame", {
		Size = UDim2.new(1, 0, 1, -BOB * 2 * Ui.scale()),
		BackgroundTransparency = 1,
	}, board)
	drawArrow(holder)
	board.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- A trail of chevrons on the ground, out of the player towards the place, the light running
	-- along it away from them (owner, 2026-10-19: "a blinking arrow coming out of the character
	-- to the object"). Parts of this client alone, touched by nothing.
	local trail = Instance.new("Folder")
	trail.Name = "GuideTrail"
	local arms: { { Part } } = {}
	for _ = 1, TRAIL_COUNT do
		local pair: { Part } = {}
		for _ = 1, 2 do
			local arm = Instance.new("Part")
			arm.Anchored = true
			arm.CanCollide = false
			arm.CanQuery = false
			arm.CanTouch = false
			arm.CastShadow = false
			arm.Material = Enum.Material.Neon
			arm.Color = Ui.SEAL
			arm.Size = Vector3.new(TRAIL_THICK, 0.12, TRAIL_ARM)
			arm.Parent = trail
			table.insert(pair, arm)
		end
		table.insert(arms, pair)
	end
	trail.Parent = Workspace

	local edge: Frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(ARROW.X * EDGE_GROW, ARROW.Y * EDGE_GROW),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Visible = false,
	}, arrowLayer)
	drawArrow(edge)

	local beat = RunService.RenderStepped:Connect(function()
		local scale = Ui.scale()
		local bob = (math.sin(os.clock() * 5) + 1) * BOB
		holder.Position = UDim2.fromOffset(0, bob * scale)

		-- The trail: laid from the player's feet along the ground towards the place.
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local towards = if root and root:IsA("BasePart")
			then (part.Position - root.Position) * Vector3.new(1, 0, 1)
			else Vector3.zero
		local laid = withTrail
			and root ~= nil
			and root:IsA("BasePart")
			and holder.Visible
			and towards.Magnitude > TRAIL_NEAR
		for index, pair in arms do
			local reach = TRAIL_FIRST + (index - 1) * TRAIL_STEP
			local shown = laid and reach < towards.Magnitude - TRAIL_NEAR / 2
			for _, arm in pair do
				arm.Transparency = 1
			end
			if shown and root and root:IsA("BasePart") then
				local way = towards.Unit
				local feet = root.Position.Y
					- root.Size.Y / 2
					- (if humanoid then humanoid.HipHeight else 2)
					+ 0.12
				local tip = Vector3.new(root.Position.X, feet, root.Position.Z) + way * reach
				local frame = CFrame.lookAt(tip, tip + way)
				-- Light runs out along the chevrons, from the player towards the place.
				local wave = (math.sin(os.clock() * TRAIL_RUN - index * 0.9) + 1) / 2
				for side, arm in pair do
					local lean = if side == 1 then TRAIL_LEAN else -TRAIL_LEAN
					arm.CFrame = frame * CFrame.Angles(0, lean, 0) * CFrame.new(0, 0, TRAIL_ARM / 2)
					arm.Transparency = 0.1 + 0.75 * (1 - wave)
				end
			end
		end

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local over = part.Position + Vector3.new(0, part.Size.Y / 2 + above, 0)
		local seen = camera:WorldToViewportPoint(over)
		local inset = GuiService:GetGuiInset()
		local room = Ui.room()
		-- Where the place is on the screen, in layout pixels, as the layers count them.
		local x = seen.X / scale
		local y = (seen.Y - inset.Y) / scale
		local inSight = seen.Z > 0
			and x > EDGE_MARGIN
			and x < room.X - EDGE_MARGIN
			and y > EDGE_MARGIN
			and y < room.Y - EDGE_MARGIN
		edge.Visible = not inSight and holder.Visible
		if inSight then
			return
		end
		local middleX, middleY = room.X / 2, room.Y / 2
		local dx, dy = x - middleX, y - middleY
		-- Behind the camera the point comes out mirrored through the middle of the screen.
		if seen.Z <= 0 then
			dx, dy = -dx, -dy
		end
		if math.abs(dx) < 1e-3 and math.abs(dy) < 1e-3 then
			dy = 1
		end
		local reach = math.min(
			(middleX - EDGE_MARGIN) / math.max(math.abs(dx), 1e-3),
			(middleY - EDGE_MARGIN) / math.max(math.abs(dy), 1e-3)
		)
		local length = math.sqrt(dx * dx + dy * dy)
		local back = bob / length
		edge.Position =
			UDim2.fromOffset(middleX + dx * reach - dx * back, middleY + dy * reach - dy * back)
		-- The arrow is drawn pointing down, which is 90 degrees on the screen.
		edge.Rotation = math.deg(math.atan2(dy, dx)) - 90
	end)
	table.insert(arrows, {
		frame = holder,
		cleanup = function()
			beat:Disconnect()
			board:Destroy()
			edge:Destroy()
			trail:Destroy()
		end,
	})
end

-- An arrow and a ring at a part of the interface, following it wherever it goes.
local function pointAtGui(target: GuiObject)
	local holder: Frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(ARROW.X, ARROW.Y),
		BackgroundTransparency = 1,
		ZIndex = 20,
	}, arrowLayer)
	drawArrow(holder)
	local ring: Frame = Ui.make("Frame", {
		BackgroundTransparency = 1,
		ZIndex = 19,
	}, arrowLayer)
	Ui.corner(ring, 12)
	local stroke = Ui.stroke(ring, Ui.SEAL, 3)
	local beat = RunService.RenderStepped:Connect(function()
		local scale = Ui.scale()
		local at = target.AbsolutePosition / scale
		local size = target.AbsoluteSize / scale
		local shown = target.Visible and size.X > 1
		holder.Visible = shown
		ring.Visible = shown
		if not shown then
			return
		end
		local room = Ui.room()
		local middle = at + size / 2
		local bob = (math.sin(os.clock() * 5) + 1) * BOB
		ring.Position = UDim2.fromOffset(at.X - 6, at.Y - 6)
		ring.Size = UDim2.fromOffset(size.X + 12, size.Y + 12)
		stroke.Transparency = 0.25 + 0.35 * (math.sin(os.clock() * 4) + 1) / 2
		if middle.Y > room.Y * 0.62 then
			holder.Rotation = 0
			holder.Position = UDim2.fromOffset(middle.X, at.Y - ARROW_OFF - bob)
		elseif middle.X < room.X * 0.35 then
			holder.Rotation = 90
			holder.Position = UDim2.fromOffset(at.X + size.X + ARROW_OFF + bob, middle.Y)
		elseif middle.X > room.X * 0.65 then
			holder.Rotation = -90
			holder.Position = UDim2.fromOffset(at.X - ARROW_OFF - bob, middle.Y)
		else
			holder.Rotation = 180
			holder.Position = UDim2.fromOffset(middle.X, at.Y + size.Y + ARROW_OFF + bob)
		end
	end)
	table.insert(arrows, {
		frame = holder,
		ring = ring,
		target = target,
		cleanup = function()
			beat:Disconnect()
			holder:Destroy()
			ring:Destroy()
		end,
	})
end

-- Points at everything a step or a tip names: the interface first, else the world.
local function point(names: { string }?)
	clearArrows()
	if not names then
		return
	end
	-- A trail on the ground goes to the first place named only: one way to walk at a time.
	local trailed = false
	for _, name in names do
		local gui = Ui.targetOf(name)
		if gui then
			pointAtGui(gui)
		else
			local part = placeOf(name)
			if part then
				pointAtPlace(part, if name == "dojo" then 18 else 5, not trailed)
				trailed = true
			end
		end
	end
end

-- Whether the game leaves room for Iruka now.
local function quiet(): boolean
	return not Cinematic.staging() and not Ui.windowOpen()
end

-- Puts Iruka's words on the scroll, with the button saying `label` (none: the step waits for
-- the player), and brings it up.
local function say(text: string, label: string?, pressed: (() -> ())?)
	local size, painted = WORD_SIZES[#WORD_SIZES], ""
	for _, try in WORD_SIZES do
		painted = Ui.paint(text, try, WORDS_WIDE)
		size = try
		if #string.split(painted, "\n") <= MOST_LINES then
			break
		end
	end
	local lines = #string.split(painted, "\n")
	local tall = math.max(
		FACE + 36,
		50 + lines * math.ceil(size * LINE_SHARE) + (if label then BUTTON.Y + 22 else 16)
	)
	local function write()
		paper.frame.Size = UDim2.fromOffset(CARD_WIDE, tall)
		words.TextSize = size
		words.Text = painted
		button.Visible = label ~= nil
		button.Text = if label then Strings.get(label) else ""
		skip.Visible = state.replay and state.running
	end
	onButton = pressed
	state.speaking = true
	if quiet() then
		Ui.rewrite(paper, write)
	else
		write()
	end
end

local function hush()
	state.speaking = false
	onButton = nil
	clearArrows()
	Ui.rollUp(paper)
end

-- Iruka's words for a step: the group's line names the community server once there is one.
local function stepWords(id: string): string
	local text = Strings.get(`Guide_{id}`)
	if id == "group" and Tuning.Social.server then
		text ..= " " .. Strings.get("Guide_groupServer")
	end
	return text
end

local beginStep: (index: number) -> ()

local function finishTutorial()
	state.running = false
	state.replay = false
	state.waiting = nil
	hush()
end

local function finishStep()
	local index = state.step
	state.waiting = nil
	clearArrows()
	if not state.replay then
		Remotes.Guide:FireServer("step", index)
	end
	if index >= #GuideConfig.steps then
		finishTutorial()
	else
		beginStep(index + 1)
	end
end

beginStep = function(index: number)
	local step = GuideConfig.steps[index]
	state.step = index
	state.waiting = step.wait
	if step.wait == "chakra" then
		local snapshot = Store.get()
		state.chakraFrom = if snapshot then snapshot.chakra else 0
	end
	local label = if step.wait
		then nil
		elseif index == #GuideConfig.steps then "GuideFinish"
		else "GuideNext"
	say(stepWords(step.id), label, finishStep)
	point(step.point)
end

-- The step of the base tutorial a player who comes back starts at: one that waits on a throw
-- in flight starts again from the strip.
local function resumeAt(done: number): number
	local index = math.clamp(done + 1, 1, #GuideConfig.steps)
	local id = GuideConfig.steps[index].id
	if id == "bar" or id == "run" then
		for place, step in GuideConfig.steps do
			if step.id == "strip" then
				return place
			end
		end
	end
	return index
end

-- A step that waits on `what` is done.
local function happened(what: string)
	if state.running and state.waiting == what then
		finishStep()
	end
end

-- Asks for a tip to be said in its turn, unless it has been.
local function want(id: string)
	if state.said[id] or table.find(state.queue, id) then
		return
	end
	local snapshot = Store.get()
	if snapshot and snapshot.tips[id] then
		return
	end
	table.insert(state.queue, id)
end

local tipById: { [string]: GuideConfig.Tip } = {}
for _, tip in GuideConfig.tips do
	tipById[tip.id] = tip
end

local function sayTip(id: string)
	local tip = tipById[id]
	if not tip then
		return
	end
	state.tip = id
	state.said[id] = true
	Remotes.Guide:FireServer("tip", id)
	say(Strings.get(`Tip_{id}`), "GuideOk", function()
		state.tip = nil
		hush()
	end)
	point(tip.point)
end

-- Asks for a tip from outside (client DailyPanel).
function Guide.tip(id: string)
	want(id)
end

-- Whether the base tutorial is running, first time or replay.
function Guide.running(): boolean
	return state.running
end

-- The base tutorial again, from the settings: it can be skipped and saves nothing.
function Guide.replay()
	if state.running then
		return
	end
	if state.tip then
		state.tip = nil
		hush()
	end
	state.running = true
	state.replay = true
	beginStep(1)
end

function Guide.start()
	local layer = Ui.screen("Guide", 22)
	arrowLayer = Ui.screen("GuideArrows", 23)
	paper = Ui.parchment(layer, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, CARD_TOP),
		Size = UDim2.fromOffset(CARD_WIDE, 150),
		Visible = false,
	}, 0)
	paper.seal.Visible = false
	paper.edge.Color = Ui.SEAL

	-- His face in a red frame, as the keepers' are (client Speech).
	local frame: Frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 30, 0.5, 0),
		Size = UDim2.fromOffset(FACE, FACE),
		BackgroundColor3 = Ui.SEAL,
		BorderSizePixel = 0,
	}, paper.page)
	Ui.corner(frame, 12)
	local window: Frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundColor3 = Ui.PANEL,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, frame)
	Ui.corner(window, 9)
	if not Portrait.show(window, "iruka", false, true) then
		Ui.text(window, {
			Size = UDim2.fromScale(1, 1),
			TextScaled = true,
			TextColor3 = Ui.PARCHMENT,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "I",
		})
	end
	Ui.text(paper.page, {
		Position = UDim2.fromOffset(WORDS_LEFT, 10),
		Size = UDim2.fromOffset(WORDS_WIDE, 28),
		TextSize = 24,
		TextColor3 = Ui.SEAL,
		Text = Strings.get("GuideName"),
	})
	words = Ui.text(paper.page, {
		Position = UDim2.fromOffset(WORDS_LEFT, 44),
		Size = UDim2.new(0, WORDS_WIDE, 1, -50),
		TextSize = 26,
		TextColor3 = Ui.INK,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
	})
	button = Ui.button(paper.page, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -34, 1, -12),
		Size = UDim2.fromOffset(BUTTON.X, BUTTON.Y),
		BackgroundColor3 = Ui.SEAL,
		TextColor3 = Ui.PARCHMENT,
		TextSize = 26,
	})
	button.Activated:Connect(function()
		local pressed = onButton
		if pressed then
			pressed()
		end
	end)
	skip = Ui.button(paper.page, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -34, 0, 8),
		Size = UDim2.fromOffset(130, 36),
		BackgroundColor3 = Ui.CARD,
		TextColor3 = Ui.PARCHMENT,
		TextSize = 22,
		Text = Strings.get("GuideSkip"),
		Visible = false,
	})
	skip.Activated:Connect(finishTutorial)

	-- The scroll and the arrows step aside while the game is busy, and come back.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local up = paper.frame.Visible
			if state.speaking and not quiet() and up then
				Ui.rollUp(paper)
				arrowLayer.Visible = false
				for _, arrow in arrows do
					arrow.frame.Visible = false
				end
			elseif state.speaking and quiet() and not up then
				Ui.unroll(paper)
				arrowLayer.Visible = true
				for _, arrow in arrows do
					arrow.frame.Visible = true
				end
			end
			-- A tip in its turn.
			if not state.running and not state.tip and quiet() and #state.queue > 0 then
				local id = table.remove(state.queue, 1)
				if id then
					sayTip(id)
				end
			end
		end
	end)

	-- What a step waits on.
	Store.onChange(function(snapshot: Net.Snapshot)
		if state.waiting == "chakra" and snapshot.chakra >= state.chakraFrom + CHAKRA_TO_GATHER then
			happened("chakra")
		end
	end)
	Remotes.KickStart.OnClientEvent:Connect(function()
		happened("aim")
	end)
	Remotes.KickResult.OnClientEvent:Connect(function(result: Net.KickResult?)
		if not result then
			return
		end
		happened("throw")
		if result.luck > 1 then
			want("lucky")
		end
	end)
	Remotes.RunEnd.OnClientEvent:Connect(function(result: Net.RunEnd)
		if state.running and state.waiting == "home" and not result.escaped then
			-- Caught on the first throws: said here, and the tip is not said again later.
			state.said.caught = true
			if not state.replay then
				Remotes.Guide:FireServer("tip", "caught")
			end
			say(Strings.get("Guide_caught"), "GuideNext", function()
				beginStep(resumeAt(state.step - 1))
			end)
			state.waiting = nil
			return
		end
		if result.escaped then
			happened("home")
		else
			want("caught")
		end
	end)
	Remotes.Placed.OnClientEvent:Connect(function(kind: string)
		if kind == "place" then
			happened("place")
		end
	end)
	Remotes.Notify.OnClientEvent:Connect(function(key: string)
		if key == "Merged" then
			happened("place")
			want("merged")
		elseif key == "FloorBuilt" then
			want("floor")
		end
	end)

	-- What a tip is about, met for the first time.
	Remotes.Bubble.OnClientEvent:Connect(function()
		want("seal")
	end)
	Remotes.Reveal.OnClientEvent:Connect(function(reveal: Net.Reveal)
		if reveal.mutation ~= Catalog.NONE then
			want("mutation")
		end
		local zone = Catalog.zoneById[reveal.zone]
		local rank = Catalog.rankOf(reveal.character)
		if zone and rank and rank.id ~= zone.rank then
			want("nextRank")
		end
	end)
	Remotes.RunStart.OnClientEvent:Connect(function(start: Net.RunStart)
		if start.twin then
			want("twin")
		end
	end)
	Remotes.Achievement.OnClientEvent:Connect(function()
		want("awards")
	end)
	Store.onInventory(function()
		if next(Store.twins()) ~= nil then
			want("twin")
		end
	end)
	Store.onIndex(function(found: Net.Found)
		for _, page in Index.pages do
			if Index.isPageComplete(found, page) then
				want("page")
				return
			end
		end
	end)
	local herbsBefore: number? = nil
	Store.onChange(function(snapshot: Net.Snapshot)
		if herbsBefore and snapshot.herbs > herbsBefore then
			want("herbs")
		end
		herbsBefore = snapshot.herbs
		local nextKunai = Catalog.kunai[snapshot.kunai + 1]
		if nextKunai and snapshot.ryo >= nextKunai.price then
			want("kunai")
		end
		if
			snapshot.speedLevel < Tuning.Speed.maxLevel
			and snapshot.ryo >= Economy.speedPrice(snapshot.speedLevel)
		then
			want("speed")
		end
		if
			snapshot.padsBought < Tuning.Dojo.buyablePads
			and snapshot.ryo >= Economy.padPrice(snapshot.padsBought)
		then
			want("pads")
		end
		if snapshot.income > 0 and snapshot.ryo >= snapshot.income * 5 then
			want("upgrade")
		end
		if next(snapshot.stock) ~= nil or next(snapshot.premium) ~= nil then
			want("potion")
		end
		if snapshot.streak >= Tuning.Kick.sageStreak then
			want("sage")
		end
		if Rebirth.ready(snapshot.chakra, snapshot.rebirths) then
			want("rebirth")
		end
	end)
	task.spawn(function()
		local hub = Workspace:WaitForChild(Net.HUB_FOLDER)
		local function changed()
			local id = hub:GetAttribute(Net.EVENT_ATTRIBUTE)
			if typeof(id) == "string" and id ~= "" then
				want("event")
			end
		end
		hub:GetAttributeChangedSignal(Net.EVENT_ATTRIBUTE):Connect(changed)
		changed()
	end)

	-- The base tutorial, for one who has not done it, from where they stopped.
	task.spawn(function()
		local snapshot = Store.get()
		while not snapshot do
			task.wait(0.2)
			snapshot = Store.get()
		end
		if snapshot and snapshot.guide < GuideConfig.DONE then
			state.running = true
			beginStep(resumeAt(snapshot.guide))
		end
	end)
end

return Guide
