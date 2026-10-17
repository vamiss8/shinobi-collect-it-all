--!strict
-- A mark over the player's own dojo, for their eyes alone (owner, 2026-10-17: "show which dojo
-- is yours more plainly; one forgets, and has to look high up to make out one's dojo"). The
-- dojo's name is written on its roof and floats over it, which is where the eye does not go
-- from the plaza. So a slip of parchment hangs over the dojo's stairs, 12 studs up: the
-- player's own face on a red seal, "YOUR DOJO" in ink, and a point under it at the door. It
-- rises and falls a little, is seen through other dojos and from across the plaza at the same
-- size on the screen, and is taken down while its owner is inside.
-- The server marks the dojo given to the player and puts an unseen part as large as its floor
-- in it, with the point the mark hangs at (World/Plots, Net.HOME_PART).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Strings = require("./Strings")
local Ui = require("./Ui")

local HomeMark = {}

-- The slip's size on the screen, in layout pixels, and its face.
local SIZE = Vector2.new(250, 64)
local FACE = 52
-- How far it rises and falls, studs, and how long a rise and fall takes.
local BOB = 0.5
local BOB_SECONDS = 2.4
-- Inside the dojo's floor and this much round it, the mark is taken down.
local INSIDE_MARGIN = 3
local LOOK = 0.25
local FARTHEST = 700

-- The unseen floor of the dojo given to this player, once the server has given one.
local function homeOf(userId: number): BasePart?
	for _, child in Workspace:GetChildren() do
		if child:GetAttribute(Net.DOJO_OWNER_ATTRIBUTE) == userId then
			local part = child:FindFirstChild(Net.HOME_PART)
			return if part and part:IsA("BasePart") then part else nil
		end
	end
	return nil
end

function HomeMark.start()
	local me = Players.LocalPlayer

	local board = Instance.new("BillboardGui")
	board.Name = "HomeMark"
	board.AlwaysOnTop = true
	board.LightInfluence = 0
	board.MaxDistance = FARTHEST
	board.ResetOnSpawn = false
	board.Enabled = false

	-- Laid out at its size in layout pixels and scaled as the interface is.
	local root = Ui.make("Frame", {
		Size = UDim2.fromOffset(SIZE.X, SIZE.Y),
		BackgroundTransparency = 1,
	}, board)
	local fit: UIScale = Ui.make("UIScale", {}, root)

	local slip = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, 0, 1, -12),
		BackgroundColor3 = Ui.PARCHMENT,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, root)
	Ui.corner(slip, 10)
	Ui.stroke(slip, Ui.SEAL, 3)
	-- The point under it, at the door: a square turned on its corner, half behind the slip.
	local point = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(20, 20),
		Rotation = 45,
		BackgroundColor3 = Ui.PARCHMENT,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, root)
	Ui.stroke(point, Ui.SEAL, 3)

	-- The player's own face on a red seal.
	local seal = Ui.make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(FACE, FACE),
		BackgroundColor3 = Ui.SEAL,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, slip)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, seal)
	Ui.stroke(seal, Ui.INK, 2)
	local face = Ui.make("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.9),
		BackgroundTransparency = 1,
		Image = `rbxthumb://type=AvatarHeadShot&id={me.UserId}&w=150&h=150`,
		ZIndex = 4,
	}, seal)
	Ui.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, face)
	local words = Ui.text(slip, {
		Position = UDim2.fromOffset(FACE + 14, 6),
		Size = UDim2.new(1, -(FACE + 24), 1, -12),
		TextScaled = true,
		TextColor3 = Ui.INK,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Text = Strings.get("HomeMark"),
	})
	Ui.make("UITextSizeConstraint", { MaxTextSize = 30 }, words)

	-- Drawn as large on the screen as the rest of the interface, from near and far alike.
	Ui.onResize(function()
		local scale = Ui.scale()
		board.Size = UDim2.fromOffset(SIZE.X * scale, SIZE.Y * scale)
		fit.Scale = scale
	end)
	board.Parent = me:WaitForChild("PlayerGui")

	local home: BasePart? = nil
	local mark = Vector3.zero
	task.spawn(function()
		while true do
			if not home or not home.Parent then
				home = homeOf(me.UserId)
				if home then
					board.Adornee = home
					local at = home:GetAttribute(Net.HOME_MARK_ATTRIBUTE)
					mark = if typeof(at) == "Vector3" then at - home.Position else Vector3.zero
				end
			end
			-- Down while the player is inside it or about to step in.
			local part = home
			local character = me.Character
			local body = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local inside = false
			if part and body and body:IsA("BasePart") then
				local spot = part.CFrame:PointToObjectSpace(body.Position)
				inside = math.abs(spot.X) < part.Size.X / 2 + INSIDE_MARGIN
					and math.abs(spot.Z) < part.Size.Z / 2 + INSIDE_MARGIN
			end
			board.Enabled = part ~= nil and not inside
			task.wait(LOOK)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if board.Enabled then
			local rise = BOB * math.sin(os.clock() * 2 * math.pi / BOB_SECONDS)
			board.StudsOffsetWorldSpace = mark + Vector3.new(0, rise, 0)
		end
	end)
end

return HomeMark
