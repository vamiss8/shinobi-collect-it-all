--!strict
-- Iruka, the guide (Config/Guide; owner, 2026-10-19: "cover literally everything: a base
-- tutorial at the very start, and mini tutorials when something is first met; mutations are
-- mentioned in passing in the base one, and when a player first catches a shinobi with a
-- mutation Iruka explains it in more detail; so with every mechanic"). He speaks on a scroll
-- at the top of the screen, his face in a red frame beside his words (the keepers' way,
-- client Speech), with words in color as the FAQ has them (Ui.paint).
--
-- WHAT HE SPEAKS OF IS SHOWN, one thing at a time (the owner, after going through the first
-- tutorial: "three arrows on the screen at once say nothing"; "when one has to go somewhere,
-- leave only the arrow under the feet, but long, all the way to the object"; "the arrows at
-- Ryo, Chakra and so on are hard to see: zoom in, or make them plainer, or light the buttons
-- up, or tell the player to press them, in as much detail as can be"):
--   a place in the world: a trail of blinking chevrons from the player's feet in a straight
--     line all the way to it, through whatever stands between (it was laid along the way a
--     character walks, looked for again as the player moved, and lagged: "do not work its way
--     out each time; let it just be there, not going round things, no matter"); and where the
--     player is to stand, a glowing ring on the ground, or the thing itself lit (a pad, the
--     strip);
--   a part of the interface: the rest of the screen dimmed round it, a ring about it and a
--     large arrow at it.
--
-- THE BASE TUTORIAL runs at the first visit and cannot be skipped then; a step either waits
-- for the player to do something (Config/Guide lists what) or has a button. The steps done are
-- saved (Services/Guide), so one who leaves half way goes on where they stopped. Replayed from
-- the settings it can be skipped and saves nothing. A TIP is said once, the first time what it
-- is about is met, and waits for its turn: never during the base tutorial, a throw
-- (Cinematic.staging) or with a window open. Nothing Iruka says stops the game: while the
-- game is busy (a throw, a window) the scroll steps aside and comes back after.

local CollectionService = game:GetService("CollectionService")
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
local ThrowPower = require("./ThrowPower")
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
-- The arrow at a part of the interface: its size, how far off what it points at, how far it
-- bobs; the ring round the part, how far out; how dark the dimmed screen is.
local ARROW = Vector2.new(70, 86)
local ARROW_OFF = 56
-- How much larger the arrow is when it points at several parts at once.
local GROUP_ARROW = 1.35
local BOB = 10
local RING_OUT = 9
local DIM = 0.5
-- The trail on the ground: how far apart the chevrons are, where the first is, an arm's length
-- and thickness, how far an arm leans back, how fast the light runs along them, and the most
-- there are.
local TRAIL_STEP = 3.2
local TRAIL_FIRST = 2.6
local TRAIL_ARM = 2.4
local TRAIL_THICK = 0.5
local TRAIL_LEAN = math.rad(38)
local TRAIL_RUN = 6
local TRAIL_MOST = 90
-- The ring where a player is to stand: how wide for a place, and for a shop (its prompt
-- reaches 8 studs from the counter, World/ShopHouse REACH).
local ZONE_REACH: { [string]: number } = { board = 10, gift = 9 }
local SHOP_REACH = 7.5

type Shown = { cleanup: () -> () }

local state = {
	-- The base tutorial: running, and whether it is a replay (skippable, saves nothing).
	running = false,
	replay = false,
	step = 0, -- the step being said
	waiting = nil :: string?,
	chakraFrom = 0,
	opened = false, -- for a step that waits on a window: seen open
	-- The tip being said, and those waiting their turn.
	tip = nil :: string?,
	queue = {} :: { string },
	said = {} :: { [string]: boolean },
	-- Whether the scroll is meant to be up (it hides while the game is busy), and whether it
	-- is up now: what has been asked of it, not what its frame says while it rolls.
	speaking = false,
	up = false,
}

local paper: Ui.Parchment
local words: TextLabel
local button: TextButton
local skip: TextButton
local onButton: (() -> ())? = nil
local shown: { Shown } = {}
local arrowLayer: Frame
local dimLayer: Frame
-- The place the current step waits for the player to stand at, and how near.
local goal: { at: Vector3, reach: number }? = nil

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
		local steps = 14
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
	paint(Ui.INK, 5, 3)
	paint(Ui.SEAL, 0, 0)
end

local function clearShown()
	for _, thing in shown do
		thing.cleanup()
	end
	table.clear(shown)
	goal = nil
end

-- The player's own dojo, a Model its client can find by its owner.
local function myDojo(): Model?
	local userId = Players.LocalPlayer.UserId
	for _, model in Workspace:GetDescendants() do
		if model:IsA("Model") and model:GetAttribute(Net.DOJO_OWNER_ATTRIBUTE) == userId then
			return model
		end
	end
	return nil
end

-- The pad to set a catch on: the free pad of the lowest number (on the first floor, which a
-- new player has alone), else, all being taken, the first pad (to swap with). The second
-- answer says whether it is free.
local function padToUse(): (BasePart?, boolean)
	local dojo = myDojo()
	if not dojo then
		return nil, false
	end
	local free: BasePart?, freeAt = nil, math.huge
	local first: BasePart?, firstAt = nil, math.huge
	for _, part in dojo:GetDescendants() do
		if part:IsA("BasePart") then
			local number = tonumber(string.match(part.Name, "^Pad(%d+)$"))
			local padState = part:GetAttribute(Net.PAD_STATE_ATTRIBUTE)
			if number and padState == "empty" and number < freeAt then
				free, freeAt = part, number
			elseif number and padState == "taken" and number < firstAt then
				first, firstAt = part, number
			end
		end
	end
	if free then
		return free, true
	end
	return first, false
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
	elseif name == "pad" then
		return (padToUse())
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

-- The ground under a point, found by a ray straight down past `ignore`.
local function groundUnder(at: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = Players.LocalPlayer.Character
	local skipped = table.clone(ignore)
	if character then
		table.insert(skipped, character)
	end
	params.FilterDescendantsInstances = skipped
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(at + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position.Y else at.Y
end

-- A part of this client alone that nothing touches, for the trail and the rings.
local function lonePart(parent: Instance, color: Color3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 1
	part.Parent = parent
	return part
end

-- A trail of blinking chevrons from the player's feet straight to `target`, laid anew every
-- frame from where the player stands, the light running along it away from them (owner,
-- 2026-10-19: "a blinking arrow coming out of the character to the object"; then "long, all the
-- way"; then "do not work its way out each time, it lags").
local function trailTo(target: BasePart)
	local folder = Instance.new("Folder")
	folder.Name = "GuideTrail"
	folder.Parent = Workspace
	local chevrons: { { Part } } = {}
	local function chevron(index: number): { Part }
		local pair = chevrons[index]
		if pair then
			return pair
		end
		local made: { Part } = {}
		for _ = 1, 2 do
			local arm = lonePart(folder, Ui.SEAL)
			arm.Size = Vector3.new(TRAIL_THICK, 0.12, TRAIL_ARM)
			table.insert(made, arm)
		end
		chevrons[index] = made
		return made
	end

	local beat = RunService.RenderStepped:Connect(function()
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		local laid = 0
		if state.up and root and root:IsA("BasePart") then
			local lift = root.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 2)
			local feet = root.Position - Vector3.new(0, lift, 0)
			-- From the feet straight to the foot of the place.
			local base = target.Position.Y - target.Size.Y / 2
			local line: { Vector3 } = {
				feet,
				Vector3.new(target.Position.X, math.min(base, feet.Y + 2), target.Position.Z),
			}
			local walked, along = 0, TRAIL_FIRST
			for index = 1, #line - 1 do
				local a, b = line[index], line[index + 1]
				local span = (b - a).Magnitude
				local flat = (b - a) * Vector3.new(1, 0, 1)
				while along <= walked + span and laid < TRAIL_MOST do
					if flat.Magnitude > 0.05 then
						local tip = a:Lerp(b, (along - walked) / span) + Vector3.new(0, 0.14, 0)
						local frame = CFrame.lookAt(tip, tip + flat.Unit)
						laid += 1
						local wave = (math.sin(os.clock() * TRAIL_RUN - laid * 0.55) + 1) / 2
						for side, arm in chevron(laid) do
							local lean = if side == 1 then TRAIL_LEAN else -TRAIL_LEAN
							arm.CFrame = frame
								* CFrame.Angles(0, lean, 0)
								* CFrame.new(0, 0, TRAIL_ARM / 2)
							arm.Transparency = 0.1 + 0.7 * (1 - wave)
						end
					end
					along += TRAIL_STEP
				end
				walked += span
			end
		end
		for index = laid + 1, #chevrons do
			for _, arm in chevrons[index] do
				arm.Transparency = 1
			end
		end
	end)
	table.insert(shown, {
		cleanup = function()
			beat:Disconnect()
			folder:Destroy()
		end,
	})
end

-- A glowing ring on the ground where the player is to stand, breathing; the step waits until
-- they are in it.
local function ringAt(center: Vector3, reach: number, ignore: { Instance })
	local ground = groundUnder(center, ignore)
	local folder = Instance.new("Folder")
	folder.Name = "GuideRing"
	folder.Parent = Workspace
	local disc = lonePart(folder, Ui.GOLD)
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.1, reach * 2, reach * 2)
	disc.CFrame = CFrame.new(center.X, ground + 0.08, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	local rim = lonePart(folder, Ui.SEAL)
	rim.Shape = Enum.PartType.Cylinder
	rim.Size = Vector3.new(0.08, reach * 2 + 0.8, reach * 2 + 0.8)
	rim.CFrame = CFrame.new(center.X, ground + 0.06, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	goal = { at = Vector3.new(center.X, ground, center.Z), reach = reach }
	local beat = RunService.RenderStepped:Connect(function()
		local breath = (math.sin(os.clock() * 4) + 1) / 2
		disc.Transparency = if state.up then 0.78 - 0.2 * breath else 1
		rim.Transparency = if state.up then 0.35 - 0.25 * breath else 1
	end)
	table.insert(shown, {
		cleanup = function()
			beat:Disconnect()
			folder:Destroy()
		end,
	})
end

-- A part lit through walls, its outline breathing: the pad to set a catch on, the strip.
local function light(part: BasePart)
	local glow: Highlight = Ui.make("Highlight", {
		Adornee = part,
		FillColor = Ui.GOLD,
		OutlineColor = Ui.SEAL,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
	local beat = RunService.RenderStepped:Connect(function()
		local breath = (math.sin(os.clock() * 4) + 1) / 2
		glow.Enabled = state.up
		glow.FillTransparency = 0.75 - 0.35 * breath
		glow.OutlineTransparency = 0.1 * breath
	end)
	table.insert(shown, {
		cleanup = function()
			beat:Disconnect()
			glow:Destroy()
		end,
	})
end

-- Leads the player to a place: a trail to it, and where they are to stand.
local function showPlace(name: string, part: BasePart)
	trailTo(part)
	if name == "pad" or name == "strip" then
		light(part)
	elseif ZONE_REACH[name] then
		ringAt(part.Position, ZONE_REACH[name], { part })
	else
		ringAt(part.Position, SHOP_REACH, { part })
	end
end

-- The interface's parts being shown: the screen is dimmed round all of them together, and each
-- has a ring and an arrow.
local spotlit: { GuiObject } = {}
local dimFrames: { Frame } = {}

-- Everything of the interface a step names is shown together: one ring round all of it and one
-- arrow, larger for more than one (owner, 2026-10-19, a screenshot of the two training slots
-- with an arrow and a ring each, the rings running into each other: "better one larger arrow,
-- and both outlined in yellow at once").
local function showGui(targets: { GuiObject }, dim: boolean)
	local grow = if #targets > 1 then GROUP_ARROW else 1
	local holder: Frame = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(ARROW.X * grow, ARROW.Y * grow),
		BackgroundTransparency = 1,
		ZIndex = 20,
	}, arrowLayer)
	drawArrow(holder)
	local ring: Frame = Ui.make("Frame", {
		BackgroundTransparency = 1,
		ZIndex = 19,
	}, arrowLayer)
	Ui.corner(ring, 14)
	local gold = Ui.stroke(ring, Ui.GOLD, 5)
	local outer: Frame = Ui.make("Frame", {
		BackgroundTransparency = 1,
		ZIndex = 19,
	}, arrowLayer)
	Ui.corner(outer, 18)
	local red = Ui.stroke(outer, Ui.SEAL, 4)
	if dim then
		for _, target in targets do
			table.insert(spotlit, target)
		end
	end
	local beat = RunService.RenderStepped:Connect(function()
		local scale = Ui.scale()
		-- The box round everything shown that is on the screen.
		local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
		for _, target in targets do
			if target.Visible and target.AbsoluteSize.X > 1 then
				local corner = target.AbsolutePosition / scale
				local far = corner + target.AbsoluteSize / scale
				left, top = math.min(left, corner.X), math.min(top, corner.Y)
				right, bottom = math.max(right, far.X), math.max(bottom, far.Y)
			end
		end
		local visible = left < right
		local at = Vector2.new(left, top)
		local size = Vector2.new(right - left, bottom - top)
		holder.Visible = visible
		ring.Visible = visible
		outer.Visible = visible
		if not visible then
			return
		end
		local room = Ui.room()
		local middle = at + size / 2
		local pulse = (math.sin(os.clock() * 5) + 1) / 2
		local bob = pulse * BOB
		local off = ARROW_OFF * grow
		local swell = RING_OUT + pulse * 4
		ring.Position = UDim2.fromOffset(at.X - swell, at.Y - swell)
		ring.Size = UDim2.fromOffset(size.X + swell * 2, size.Y + swell * 2)
		outer.Position = UDim2.fromOffset(at.X - swell - 6, at.Y - swell - 6)
		outer.Size = UDim2.fromOffset(size.X + swell * 2 + 12, size.Y + swell * 2 + 12)
		gold.Transparency = 0.1 * pulse
		red.Transparency = 0.2 + 0.4 * (1 - pulse)
		if middle.Y > room.Y * 0.62 then
			holder.Rotation = 0
			holder.Position = UDim2.fromOffset(middle.X, at.Y - off - bob)
		elseif middle.X < room.X * 0.35 then
			holder.Rotation = 90
			holder.Position = UDim2.fromOffset(at.X + size.X + off + bob, middle.Y)
		elseif middle.X > room.X * 0.65 then
			holder.Rotation = -90
			holder.Position = UDim2.fromOffset(at.X - off - bob, middle.Y)
		else
			holder.Rotation = 180
			holder.Position = UDim2.fromOffset(middle.X, at.Y + size.Y + off + bob)
		end
	end)
	table.insert(shown, {
		cleanup = function()
			beat:Disconnect()
			holder:Destroy()
			ring:Destroy()
			outer:Destroy()
			for _, target in targets do
				local place = table.find(spotlit, target)
				if place then
					table.remove(spotlit, place)
				end
			end
		end,
	})
end

-- The dimmed screen round what is spotlit: four dark sheets about the one hole that takes in
-- every part shown. They catch no press.
local function dimRound()
	local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
	local scale = Ui.scale()
	for _, target in spotlit do
		if target.Visible and target.AbsoluteSize.X > 1 then
			local at = target.AbsolutePosition / scale
			local size = target.AbsoluteSize / scale
			left = math.min(left, at.X - RING_OUT - 10)
			top = math.min(top, at.Y - RING_OUT - 10)
			right = math.max(right, at.X + size.X + RING_OUT + 10)
			bottom = math.max(bottom, at.Y + size.Y + RING_OUT + 10)
		end
	end
	local any = state.up and left < right
	for _, sheet in dimFrames do
		sheet.Visible = any
	end
	if not any then
		return
	end
	local room = Ui.room()
	local sheets = {
		{ 0, 0, room.X, top },
		{ 0, bottom, room.X, room.Y - bottom },
		{ 0, top, left, bottom - top },
		{ right, top, room.X - right, bottom - top },
	}
	for index, sheet in sheets do
		local frame = dimFrames[index]
		frame.Position = UDim2.fromOffset(sheet[1], sheet[2])
		frame.Size = UDim2.fromOffset(math.max(sheet[3], 0), math.max(sheet[4], 0))
	end
end

-- Shows what a step or a tip names: the interface (dimmed round, in the base tutorial), else
-- the world; only the first place gets a trail, one way to walk at a time.
local function point(names: { string }?, dim: boolean)
	clearShown()
	if not names then
		return
	end
	local walked = false
	local guis: { GuiObject } = {}
	for _, name in names do
		local gui = Ui.targetOf(name)
		if gui then
			table.insert(guis, gui)
		elseif not walked then
			local part = placeOf(name)
			if part then
				showPlace(name, part)
				walked = true
			end
		end
	end
	if #guis > 0 then
		showGui(guis, dim)
	end
end

-- Whether the game leaves room for Iruka now.
local function quiet(): boolean
	return not Cinematic.staging() and not Ui.windowOpen()
end

local function bringUp()
	if not state.up then
		state.up = true
		Ui.unroll(paper)
		arrowLayer.Visible = true
	end
end

local function putDown()
	if state.up then
		state.up = false
		Ui.rollUp(paper)
		arrowLayer.Visible = false
	end
end

-- Puts Iruka's words on the scroll, with the button saying `label` (none: the step waits for
-- the player), and brings it up when the game leaves room.
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
	if state.up then
		Ui.rewrite(paper, write)
	else
		write()
		if quiet() then
			bringUp()
		end
	end
end

local function hush()
	state.speaking = false
	onButton = nil
	clearShown()
	putDown()
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
	clearShown()
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
	state.opened = false
	if step.wait == "chakra" then
		local snapshot = Store.get()
		state.chakraFrom = if snapshot then snapshot.chakra else 0
	end
	-- The run home says nothing: the game tells it, and the scroll would only flash between
	-- the throw's pictures.
	if step.silent then
		state.speaking = false
		onButton = nil
		clearShown()
		putDown()
		return
	end
	local text = stepWords(step.id)
	-- A pad to set the catch on: a free one, else (all taken, in a replay) one to swap with.
	if step.id == "place" then
		local _, free = padToUse()
		if not free then
			text = Strings.get("Guide_placeFull")
		end
	end
	-- A place that is not there (the gift, once taken): then the step has a button.
	local first = if step.point then step.point[1] else nil
	if step.wait == "near" and not (first and placeOf(first)) then
		state.waiting = nil
	end
	local waits = state.waiting
	local label = if waits
		then nil
		elseif index == #GuideConfig.steps then "GuideFinish"
		else "GuideNext"
	say(text, label, finishStep)
	if waits or step.wait ~= "near" then
		point(step.point, true)
	end
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

-- What some steps wait on, looked at in the guide's round.
local function checkWaits()
	if not state.running then
		return
	end
	local step = GuideConfig.steps[state.step]
	local waiting = state.waiting
	if not step or not waiting then
		return
	end
	if waiting == "slider" then
		if ThrowPower.isOpen() then
			happened("slider")
		end
	elseif waiting == "sliderShut" then
		if not ThrowPower.isOpen() then
			happened("sliderShut")
		end
	elseif waiting == "window" then
		local window = if step.window then Ui.windowNamed(step.window) else nil
		if window and window.isOpen() then
			state.opened = true
		elseif state.opened then
			happened("window")
		end
	elseif waiting == "near" then
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local target = goal
		if target and root and root:IsA("BasePart") then
			local away = (root.Position - target.at) * Vector3.new(1, 0, 1)
			if away.Magnitude <= target.reach then
				happened("near")
			end
		end
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
	point(tip.point, false)
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

-- Whether the player stands within `reach` of any part `find` gives.
local function near(find: () -> { BasePart }, reach: number): boolean
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return false
	end
	for _, part in find() do
		if (part.Position - root.Position).Magnitude <= reach then
			return true
		end
	end
	return false
end

-- The top stones of the legendary shinobi's pedestals, which carry their buy prompts.
local function legendStones(): { BasePart }
	local found: { BasePart } = {}
	local folder = Workspace:FindFirstChild(Net.LEGENDS_FOLDER)
	if folder then
		for _, item in folder:GetDescendants() do
			if item:IsA("BasePart") and item:GetAttribute(Net.LEGEND_ATTRIBUTE) ~= nil then
				table.insert(found, item)
			end
		end
	end
	return found
end

-- The leaderboards' sheets (World/Plaza `leaderboard`), found once.
local sheets: { BasePart }? = nil
local function leaderSheets(): { BasePart }
	local known = sheets
	if known then
		return known
	end
	local found: { BasePart } = {}
	for _, item in Workspace:GetDescendants() do
		if item.Name == "LeaderSheet" and item:IsA("BasePart") then
			table.insert(found, item)
		end
	end
	if #found > 0 then
		sheets = found
	end
	return found
end

function Guide.start()
	local layer = Ui.screen("Guide", 22)
	arrowLayer = Ui.screen("GuideArrows", 23)
	dimLayer = Ui.screen("GuideDim", 21)
	for _ = 1, 4 do
		local sheet: Frame = Ui.make("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = DIM,
			BorderSizePixel = 0,
			Active = false,
			Visible = false,
		}, dimLayer)
		table.insert(dimFrames, sheet)
	end
	RunService.RenderStepped:Connect(dimRound)

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

	-- The guide's round: the scroll steps aside while the game is busy and comes back after,
	-- once each way (it used to be rolled up again every round while it was rolling, slowly
	-- and in jerks: the owner saw "Run home" close like that); what some steps wait on; a tip
	-- in its turn; the places a tip is said at.
	task.spawn(function()
		while true do
			task.wait(0.2)
			if state.speaking and quiet() then
				bringUp()
			elseif state.up and not quiet() then
				putDown()
			end
			checkWaits()
			if not state.running and not state.tip and quiet() and #state.queue > 0 then
				local id = table.remove(state.queue, 1)
				if id then
					sayTip(id)
				end
			end
			if near(legendStones, 26) then
				want("legend")
			end
			if near(leaderSheets, 30) then
				want("leaders")
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
			state.waiting = nil
			say(Strings.get("Guide_caught"), "GuideNext", function()
				beginStep(resumeAt(state.step - 1))
			end)
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
	Remotes.Ring.OnClientEvent:Connect(function()
		want("ring")
	end)
	Remotes.Offline.OnClientEvent:Connect(function()
		want("offline")
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
	local rebirthsBefore: number? = nil
	Store.onChange(function(snapshot: Net.Snapshot)
		if herbsBefore and snapshot.herbs > herbsBefore then
			want("herbs")
		end
		herbsBefore = snapshot.herbs
		if rebirthsBefore and snapshot.rebirths > rebirthsBefore then
			want("reborn")
		end
		rebirthsBefore = snapshot.rebirths
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
