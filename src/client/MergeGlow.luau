--!strict
-- The twins of the shinobi in the player's hands, glowing on their pads (owner, 2026-10-17:
-- "when you run home with such a shinobi, let there be something to tell it by too"). While
-- the player carries a unit with twins standing on pads of their dojo (Store.twins, sent with
-- the inventory), every one of them is outlined in violet, the outline seen through the dojo's
-- walls and floors and the fill breathing, so that a pad to merge on is found at once among
-- thirty: on coming home from a throw with such a catch, or with one taken out of the
-- inventory. Only this player sees it. The arrival's message says the same (client Hud,
-- RunMerge). It glowed on the lowest pad alone, and in gold, at first (owner, the same day:
-- "with three Sasukes standing and one in the inventory only one lights up; and make it
-- violet").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Store = require("./Store")

local MergeGlow = {}

local VIOLET = Color3.fromRGB(178, 112, 255)
-- How often the twins are looked for again (a pad's figure is built anew when anything on
-- that pad changes), and how long a breath of the glow is.
local LOOK = 0.25
local BREATH = 1.6
-- Roblox draws at most 31 highlights at once; a dojo has 30 pads, and the dojo's own outline
-- is one more (client HomeMark).
local MOST = 29

-- The dojo assigned to this player (World/Plots marks it).
local function dojoOf(userId: number): Instance?
	for _, child in Workspace:GetChildren() do
		if child:GetAttribute(Net.DOJO_OWNER_ATTRIBUTE) == userId then
			return child
		end
	end
	return nil
end

-- The figures that should glow now: the twins of the shinobi carried, on their pads.
local function targets(userId: number): { [Model]: boolean }
	local found: { [Model]: boolean } = {}
	local state = Store.get()
	local held = if state then state.held else nil
	local pads = if held then Store.twins()[held] else nil
	local dojo = if pads then dojoOf(userId) else nil
	if not pads or not dojo then
		return found
	end
	local wanted: { [number]: boolean } = {}
	for _, index in pads do
		wanted[index] = true
	end
	local count = 0
	for _, child in dojo:GetChildren() do
		local index = child:GetAttribute(Net.PAD_ATTRIBUTE)
		if child:IsA("Model") and typeof(index) == "number" and wanted[index] and count < MOST then
			found[child] = true
			count += 1
		end
	end
	return found
end

function MergeGlow.start()
	local me = Players.LocalPlayer
	-- The glow on each figure lit now.
	local glows: { [Model]: Highlight } = {}

	local function look()
		local wanted = targets(me.UserId)
		for figure, glow in glows do
			if not wanted[figure] or glow.Parent ~= figure then
				glow:Destroy()
				glows[figure] = nil
			end
		end
		for figure in wanted do
			if not glows[figure] then
				-- Made here, so it is this client's alone; it goes with the figure if that is
				-- built anew, and the new one is lit at the next look.
				local made = Instance.new("Highlight")
				made.Name = "MergeGlow"
				made.FillColor = VIOLET
				made.OutlineColor = VIOLET
				made.OutlineTransparency = 0
				made.FillTransparency = 0.7
				made.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				made.Parent = figure
				glows[figure] = made
			end
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
		local phase = (math.cos(os.clock() * 2 * math.pi / BREATH) + 1) / 2
		for _, glow in glows do
			glow.FillTransparency = 0.55 + 0.35 * phase
		end
	end)
end

return MergeGlow
