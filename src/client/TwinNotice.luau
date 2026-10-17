--!strict
-- A catch that is ready to merge, told beside it on the run home (owner, 2026-10-17: "when you
-- have just rolled a character and run with it, let an animated notice come up that it can be
-- merged if you bring it home; not a scroll across the screen, over the character"). When a
-- twin of the catch stands on a pad of the runner's dojo (Net.RunStart `twin`), a slip of
-- parchment springs up at the right hand of the shinobi riding over their head, once the look
-- at the enemy is over: a violet seal stamped "!" that beats, and "Bring it home to merge!" in
-- ink, outlined in violet, the color the twins glow in at home (client MergeGlow). After a few
-- seconds the words go and the seal alone rides on beside the catch; at the end of the run
-- it is all gone. Only the runner sees it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("./Remotes")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local TwinNotice = {}

local VIOLET = Color3.fromRGB(178, 112, 255)
-- The slip at full length and folded to its seal, in layout pixels.
local SIZE = Vector2.new(250, 56)
local SEAL = 44
-- Where it stands from the catch's feet: to the right on the screen, at its middle, studs.
local BESIDE = Vector3.new(4.4, 2.4, 0)
-- When it comes up after the run starts (as the camera swings back from the enemy), and how
-- long its words stay.
local AFTER = Tuning.Chase.introSeconds * 0.75
local WORDS_FOR = 5
local BOB = 0.25
local BOB_SECONDS = 1.8
local BEAT_SECONDS = 0.7

-- The unseen piece at the feet of the shinobi riding over this player's head (View/Figure
-- `attach`), once it is there.
local function carriedHandle(me: Player): BasePart?
	local character = me.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root then
		return nil
	end
	for _, joint in CollectionService:GetTagged(Net.CARRY_TAG) do
		if joint:IsA("Weld") and joint.Part0 == root and joint.Part1 then
			return joint.Part1
		end
	end
	return nil
end

function TwinNotice.start()
	local me = Players.LocalPlayer
	local shown: BillboardGui? = nil
	local token = 0

	local function clear()
		token += 1
		local board = shown
		shown = nil
		if board then
			local root = board:FindFirstChild("Root")
			local fit = if root then root:FindFirstChildOfClass("UIScale") else nil
			if fit then
				TweenService:Create(
					fit,
					TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.In),
					{ Scale = 0 }
				):Play()
			end
			task.delay(0.2, function()
				board:Destroy()
			end)
		end
	end

	local function show(handle: BasePart, mine: number)
		local scale = Ui.scale()
		local board = Instance.new("BillboardGui")
		board.Name = "TwinNotice"
		board.Adornee = handle
		board.AlwaysOnTop = true
		board.LightInfluence = 0
		board.MaxDistance = 150
		board.ResetOnSpawn = false
		board.Size = UDim2.fromOffset(SIZE.X * scale, SIZE.Y * scale)
		board.StudsOffset = BESIDE

		-- Laid out at its size in layout pixels and scaled as the interface is; it springs up.
		local root = Ui.make("Frame", {
			Name = "Root",
			Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
			BackgroundTransparency = 1,
		}, board)
		local fit: UIScale = Ui.make("UIScale", { Scale = 0 }, root)
		local slip = Ui.make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Ui.PARCHMENT,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, root)
		Ui.make("UICorner", { CornerRadius = UDim.new(0, SIZE.Y / 2) }, slip)
		local outline = Ui.stroke(slip, VIOLET, 3)
		local words = Ui.text(slip, {
			Position = UDim2.fromOffset(SEAL + 14, 6),
			Size = UDim2.new(1, -(SEAL + 24), 1, -12),
			TextScaled = true,
			TextColor3 = Ui.INK,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = Strings.get("RunTwin"),
		})
		Ui.make("UITextSizeConstraint", { MaxTextSize = 24 }, words)
		local seal = Ui.text(root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 6 + SEAL / 2, 0.5, 0),
			Size = UDim2.fromOffset(SEAL, SEAL),
			BackgroundColor3 = VIOLET,
			BackgroundTransparency = 0,
			TextColor3 = Ui.PARCHMENT,
			TextSize = 30,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "!",
			ZIndex = 2,
		})
		Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, seal)
		Ui.stroke(seal, Ui.INK, 2)
		local beat: UIScale = Ui.make("UIScale", {}, seal)
		board.Parent = me:WaitForChild("PlayerGui")
		shown = board

		TweenService
			:Create(fit, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			})
			:Play()
		TweenService:Create(
			beat,
			TweenInfo.new(
				BEAT_SECONDS / 2,
				Enum.EasingStyle.Sine,
				Enum.EasingDirection.InOut,
				-1,
				true
			),
			{ Scale = 1.15 }
		):Play()

		-- The words go after a while; the slip folds up behind its seal.
		task.delay(WORDS_FOR, function()
			if token ~= mine then
				return
			end
			local fold = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			TweenService:Create(words, fold, { TextTransparency = 1 }):Play()
			TweenService:Create(slip, fold, {
				Size = UDim2.fromOffset(SEAL + 12, SIZE.Y),
				BackgroundTransparency = 1,
			}):Play()
			TweenService:Create(outline, fold, { Transparency = 1 }):Play()
		end)

		-- It rises and falls a little beside the catch.
		task.spawn(function()
			while token == mine and board.Parent do
				local rise = BOB * math.sin(os.clock() * 2 * math.pi / BOB_SECONDS)
				board.StudsOffset = BESIDE + Vector3.new(0, rise, 0)
				RunService.Heartbeat:Wait()
			end
		end)
	end

	Remotes.RunStart.OnClientEvent:Connect(function(run: Net.RunStart)
		clear()
		if not run.twin then
			return
		end
		local mine = token
		task.delay(AFTER, function()
			-- The catch rides over the runner by now; it may take a moment to arrive.
			for _ = 1, 20 do
				if token ~= mine then
					return
				end
				local handle = carriedHandle(me)
				if handle then
					show(handle, mine)
					return
				end
				task.wait(0.1)
			end
		end)
	end)
	Remotes.RunEnd.OnClientEvent:Connect(clear)
end

return TwinNotice
