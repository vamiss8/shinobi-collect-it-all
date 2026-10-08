--!strict
-- Shows a player's rank, the one their rebirths have earned them (Logic/Rebirth), on their
-- character, for everyone to see: its name over their head in its color, above their own
-- name. The four highest ranks are lettered (Config/Lettering `titles`): the tag's line is
-- marked for the clients, each of which draws the lettering.
--
-- The tag takes the place of Roblox's own name over the head, which is switched off: the two
-- would lie on each other. It sits low, between the head and where a carried shinobi's feet
-- are, so that the shinobi does not stand on it.
--
-- Like a runner's speed look, it is put on by the server, on every new character and again
-- when a rebirth changes the rank, and nothing of the avatar is changed or lit. What a rank
-- adds beyond its tag, the orbs that hang behind its holder, every client draws for itself
-- (client RankOrbs). (It was a round plate of light fixed under the feet at first: the owner
-- found it artificial, deaf to the light and to how its player moved, and gone for a moment
-- at every landing.)

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

-- Puts the player's rank on their character, taking off whatever rank it wore.
function Titles.dress(player: Player)
	local data = Data.get(player)
	local character = player.Character
	local head = if character then character:FindFirstChild("Head") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not data or not character or not humanoid then
		return
	end
	clear(character)
	if head and head:IsA("BasePart") then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		tag(head, player.DisplayName, Rebirth.done(data.rebirths))
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
