--!strict
-- The twin of the shinobi in the player's hands, glowing on its pad (owner, 2026-10-17: "when
-- you run home with such a shinobi, let there be something to tell it by too"). While the
-- player carries a unit whose twin stands on a pad of their dojo (Store.twins, sent with the
-- inventory), that twin is outlined in gold, its outline seen through the dojo's walls and
-- floors and its fill breathing, so that the pad to merge on is found at once among thirty:
-- on coming home from a throw with such a catch, or with one taken out of the inventory.
-- Only this player sees it. The arrival's message says the same (client Hud, RunMerge).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Store = require("./Store")
local Ui = require("./Ui")

local MergeGlow = {}

-- How often the twin is looked for again (a pad's figure is built anew when anything on that
-- pad changes), and how long a breath of the glow is.
local LOOK = 0.25
local BREATH = 1.6

-- The dojo assigned to this player (World/Plots marks it).
local function dojoOf(userId: number): Instance?
	for _, child in Workspace:GetChildren() do
		if child:GetAttribute(Net.DOJO_OWNER_ATTRIBUTE) == userId then
			return child
		end
	end
	return nil
end

-- The shinobi standing on a pad of that dojo (Services/Dojo marks it with the pad's number).
local function figureOn(dojo: Instance, index: number): Model?
	for _, child in dojo:GetChildren() do
		if child:IsA("Model") and child:GetAttribute(Net.PAD_ATTRIBUTE) == index then
			return child
		end
	end
	return nil
end

-- The figure that should glow now, if any.
local function target(userId: number): Model?
	local state = Store.get()
	local held = if state then state.held else nil
	local index = if held then Store.twins()[held] else nil
	if not index then
		return nil
	end
	local dojo = dojoOf(userId)
	return if dojo then figureOn(dojo, index) else nil
end

function MergeGlow.start()
	local me = Players.LocalPlayer
	local glow: Highlight? = nil

	local function look()
		local figure = target(me.UserId)
		local current = glow
		if current and current.Parent == figure and figure ~= nil then
			return
		end
		if current then
			current:Destroy()
			glow = nil
		end
		if figure then
			-- Made here, so it is this client's alone; it goes with the figure if that is
			-- built anew, and is put on the new one at the next look.
			local made = Instance.new("Highlight")
			made.Name = "MergeGlow"
			made.FillColor = Ui.GOLD
			made.OutlineColor = Ui.GOLD
			made.OutlineTransparency = 0
			made.FillTransparency = 0.7
			made.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			made.Parent = figure
			glow = made
		end
	end

	Store.onInventory(function()
		look()
	end)
	Store.onChange(function()
		look()
	end)
	task.spawn(function()
		while true do
			task.wait(LOOK)
			look()
		end
	end)

	-- The fill breathes between faint and fainter; the outline stays.
	RunService.Heartbeat:Connect(function()
		local current = glow
		if current then
			local phase = (math.cos(os.clock() * 2 * math.pi / BREATH) + 1) / 2
			current.FillTransparency = 0.55 + 0.35 * phase
		end
	end)
end

return MergeGlow
