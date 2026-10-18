--!strict
-- The gift for joining the game's group (owner, 2026-10-18: "a reminder to join the group and a
-- starter pack for joining; only joining can be checked, a like cannot; what is in the pack,
-- decide yourself; put it on the spawn, and once the gift is taken take it away, the spawn is
-- cluttered enough"). A red lacquered box tied with gold cord stands behind the fountain
-- (World/Plaza, Logic/PlazaPlan `GIFT`), a tag over it asking to join sad mansion studios and
-- to like the game; whoever has taken it no longer sees it (client GroupGift), and the
-- client reminds a player now and then that it waits. ONCE A PLAYER, for good
-- (Data.groupGift): one of every potion into the pouch, of the kind bought for Herbs, and
-- Herbs (Tuning.Group). A like is asked for and never checked: nothing tells a game of one.
--
-- Joining is checked here, on the server, by the list of the player's groups
-- (GroupService:GetGroupsAsync): Player:IsInGroupAsync keeps its first answer on the server
-- for the whole visit, so a player who joins from the prompt in the game would still be told
-- no. One who is not in the group is shown Roblox's own prompt to join (client GroupGift),
-- and asks again once it is closed.

local GroupService = game:GetService("GroupService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Analytics = require("./Analytics")
local Data = require("../Data")
local Hub = require("../World/Hub")
local Plaza = require("../World/Plaza")
local Pouch = require(ReplicatedStorage.Shared.Logic.Pouch)
local Remotes = require("../Remotes")
local State = require("./State")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local GroupGift = {}

local GROUP = Tuning.Group
-- The tag over the box, in studs, how high its middle is over the ground, how far it is read.
local TAG = Vector2.new(8, 3.1)
local TAG_HEIGHT = 6.4
local TAG_FAR = 150
-- The prompt is offered from this far, studs.
local REACH = 10
local PARCHMENT = Color3.fromRGB(236, 220, 188)
local INK = Color3.fromRGB(58, 40, 30)
local SEAL = Color3.fromRGB(198, 40, 40)
local GILT = Color3.fromRGB(255, 202, 40)

-- Whether the player is in the group now, asked of Roblox afresh; nil when it cannot be told.
local function member(player: Player): boolean?
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(player.UserId)
	end)
	if ok and typeof(groups) == "table" then
		for _, group in groups :: { any } do
			if group.Id == GROUP.id then
				return true
			end
		end
		return false
	end
	local asked, inside = pcall(function()
		return (player :: any):IsInGroupAsync(GROUP.id)
	end)
	if asked and typeof(inside) == "boolean" then
		return inside
	end
	return nil
end

-- Gives the gift, if the player has not had it and is in the group; else asks them to join.
local function claim(player: Player)
	local data = Data.get(player)
	if not data or data.groupGift then
		return
	end
	local inside = member(player)
	if inside == nil then
		State.notify(player, "GroupGiftUnknown")
		return
	end
	if not inside then
		Remotes.GroupGift:FireClient(player, "join")
		return
	end
	-- Asked again after the wait: a second press could have come in meanwhile.
	if data.groupGift then
		return
	end
	data.groupGift = true
	for _, potion in Catalog.potions do
		Pouch.add(data.stock, potion.id, GROUP.potions)
	end
	data.herbs += GROUP.herbs
	Analytics.economy(
		player,
		true,
		"Herbs",
		GROUP.herbs,
		data.herbs,
		Enum.AnalyticsEconomyTransactionType.Onboarding,
		"GroupGift"
	)
	Analytics.event(player, "GroupGift")
	State.push(player)
	State.notify(player, "GroupGiftClaimed", GROUP.herbs)
end

local function words(parent: Instance, top: number, height: number, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromScale(0.28, top)
	label.Size = UDim2.fromScale(0.68, height)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.PermanentMarker
	label.TextScaled = true
	label.TextColor3 = INK
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = parent
	return label
end

-- The tag over the box: parchment in a gilt outline with a round red seal, like the game's
-- other signs.
local function tag(box: BasePart)
	local board = Instance.new("BillboardGui")
	board.Name = "GiftTag"
	board.Adornee = box
	board.Size = UDim2.fromScale(TAG.X, TAG.Y)
	local ground = Hub.at(0, 0, 0).Y
	board.StudsOffsetWorldSpace = Vector3.yAxis * (ground + TAG_HEIGHT - box.Position.Y)
	board.MaxDistance = TAG_FAR
	board.LightInfluence = 0

	local paper = Instance.new("Frame")
	paper.AnchorPoint = Vector2.new(0.5, 0.5)
	paper.Position = UDim2.fromScale(0.5, 0.5)
	paper.Size = UDim2.fromScale(0.96, 0.9)
	paper.BackgroundColor3 = PARCHMENT
	paper.BorderSizePixel = 0
	paper.Parent = board
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.16, 0)
	corner.Parent = paper
	local edge = Instance.new("UIStroke")
	edge.Color = GILT
	edge.Thickness = 3
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = paper

	local seal = Instance.new("TextLabel")
	seal.AnchorPoint = Vector2.new(0, 0.5)
	seal.Position = UDim2.fromScale(0.04, 0.5)
	seal.Size = UDim2.fromScale(0.2, 0.74)
	seal.BackgroundColor3 = SEAL
	seal.BorderSizePixel = 0
	seal.Font = Enum.Font.PermanentMarker
	seal.TextScaled = true
	seal.TextColor3 = PARCHMENT
	seal.Text = "贈"
	seal.Parent = paper
	local square = Instance.new("UIAspectRatioConstraint")
	square.AspectRatio = 1
	square.Parent = seal
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = seal

	words(paper, 0.06, 0.4, "GROUP GIFT")
	words(paper, 0.48, 0.24, "Join sad mansion studios and like the game")
	-- Roblox can be slow to tell a game of a group just joined (owner, 2026-10-19: "write
	-- that to check, the game has to be rejoined").
	words(paper, 0.74, 0.18, "Joined but not counted? Rejoin the game")
	board.Parent = box
end

function GroupGift.start()
	local gift = Plaza.gift
	local box = if gift then gift:FindFirstChild("GiftBox") else nil
	if box and box:IsA("BasePart") then
		tag(box)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Claim"
		prompt.ObjectText = "GROUP GIFT"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = REACH
		prompt.RequiresLineOfSight = false
		prompt.Parent = box
		prompt.Triggered:Connect(claim)
	end
	-- The client asks again once Roblox's prompt to join is closed.
	Remotes.GroupGift.OnServerEvent:Connect(function(player, what)
		if what == "claim" then
			claim(player)
		end
	end)
end

return GroupGift
