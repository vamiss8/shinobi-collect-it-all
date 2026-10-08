--!strict
-- Shows a player's rank, the one their rebirths have earned them (Logic/Rebirth), on their
-- character, for everyone to see: its name over their head in its color, above their own
-- name, and from the first rebirth on a round glow on the ground under them that is wider and
-- brighter with every rank. The four highest ranks are lettered (Config/Lettering `titles`):
-- the tag's line is marked for the clients, each of which draws the lettering.
--
-- The tag takes the place of Roblox's own name over the head, which is switched off: the two
-- would lie on each other. It sits low, between the head and where a carried shinobi's feet
-- are, so that the shinobi does not stand on it.
--
-- Like a runner's speed look, it is put on by the server, on every new character and again
-- when a rebirth changes the rank, and nothing of the avatar is changed or lit.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require("../Data")
local Lettering = require(ReplicatedStorage.Shared.Config.Lettering)
local Loadout = require("./Loadout")
local Net = require(ReplicatedStorage.Shared.Net)
local Rebirth = require(ReplicatedStorage.Shared.Logic.Rebirth)

local Titles = {}

-- Attribute on everything this module adds, so it can be found and taken off again.
local MARK = "RankLook"
-- The tag: how wide and tall it is and how far over the middle of the head its own middle
-- hangs, studs. The rank takes the larger share of its height, the name the rest.
local TAG = Vector2.new(9, 1.5)
local TAG_LIFT = 1.4
local RANK_SHARE = 0.56
-- It is not drawn for a camera farther off than this, studs.
local TAG_FAR = 110
-- The glow under a player: how wide it is after the first rebirth and how much wider with
-- every one after, studs; how see-through it starts and how much less so it gets.
local GLOW_WIDTH = 4.4
local GLOW_WIDER = 0.6
local GLOW_CLEAR = 0.72
local GLOW_SOLIDER = 0.035
local GLOW_THICK = 0.08
-- How far over the ground it lies, so as not to lie in it.
local GLOW_LIFT = 0.07

local function mark<T>(instance: T): T
	((instance :: any) :: Instance):SetAttribute(MARK, true)
	return instance
end

local function clear(character: Model)
	for _, item in character:GetDescendants() do
		if item:GetAttribute(MARK) then
			item:Destroy()
		end
	end
end

local function line(board: BillboardGui, from: number, share: number, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromScale(0, from)
	label.Size = UDim2.fromScale(1, share)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.PermanentMarker
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = board
	return label
end

-- Hangs the tag over the head: the rank, and the player's name under it.
local function tag(head: BasePart, name: string, count: number)
	local board = mark(Instance.new("BillboardGui"))
	board.Name = "RankTag"
	board.Size = UDim2.fromScale(TAG.X, TAG.Y)
	board.StudsOffsetWorldSpace = Vector3.new(0, TAG_LIFT, 0)
	board.MaxDistance = TAG_FAR
	board.LightInfluence = 0

	local rank = line(board, 0, RANK_SHARE, string.upper(Rebirth.title(count)))
	rank.TextColor3 = Color3.fromHex(Rebirth.color(count))
	local lettering = Lettering.key("title", tostring(count))
	if lettering then
		rank:SetAttribute(Net.LETTERING_ATTRIBUTE, lettering)
		CollectionService:AddTag(rank, Net.LETTERING_TAG)
	end
	line(board, RANK_SHARE, 1 - RANK_SHARE, name)
	board.Parent = head
end

-- Lays the glow on the ground under the player: a thin round plate of light fixed to their
-- root at the height of their soles. (A cylinder lies along its X side, hence the turn.)
local function glow(root: BasePart, humanoid: Humanoid, count: number)
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else humanoid.HipHeight
	local width = GLOW_WIDTH + GLOW_WIDER * (count - 1)
	local plate = mark(Instance.new("Part"))
	plate.Name = "RankGlow"
	plate.Shape = Enum.PartType.Cylinder
	plate.Size = Vector3.new(GLOW_THICK, width, width)
	plate.CFrame = root.CFrame
		* CFrame.new(0, GLOW_LIFT - root.Size.Y / 2 - legs, 0)
		* CFrame.Angles(0, 0, math.rad(90))
	plate.Color = Color3.fromHex(Rebirth.color(count))
	plate.Material = Enum.Material.Neon
	plate.Transparency = math.max(GLOW_CLEAR - GLOW_SOLIDER * (count - 1), 0.3)
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.CastShadow = false
	plate.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = plate
	weld.Parent = plate
	plate.Parent = root
end

-- Puts the player's rank on their character, taking off whatever rank it wore.
function Titles.dress(player: Player)
	local data = Data.get(player)
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not data or not character or not humanoid then
		return
	end
	clear(character)
	local count = Rebirth.done(data.rebirths)
	if head and head:IsA("BasePart") then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		tag(head, player.DisplayName, count)
	end
	if count > 0 and root and root:IsA("BasePart") then
		glow(root, humanoid, count)
	end
end

function Titles.start()
	Loadout.register(function(player, character)
		task.spawn(function()
			character:WaitForChild("Head", 5)
			if character.Parent then
				Titles.dress(player)
			end
		end)
	end)
end

return Titles
