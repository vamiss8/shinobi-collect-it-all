--!strict
-- The legendary shinobi on their pedestals (Services/Legends), as this player sees them: one
-- the player owns says so on its price tag, and its prompt no longer offers it. The server
-- builds the pedestals' tags and prompts for everyone alike; what is changed here is this
-- client's own copy of them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local Store = require("./Store")
local Strings = require("./Strings")

local LegendShow = {}

-- How long to wait for the server's pedestals to appear, seconds.
local WAIT = 60

function LegendShow.start()
	local owned: { [string]: boolean } = {}
	local labels: { [string]: TextLabel } = {}
	local prompts: { [string]: ProximityPrompt } = {}

	-- What the server last wrote on each tag: the price, which comes back when a shinobi is no
	-- longer owned (the developer console can take one away).
	local priced: { [string]: string } = {}

	local function mark(id: string)
		local label, prompt = labels[id], prompts[id]
		local yours = Strings.get("LegendYours")
		if label then
			if label.Text ~= yours then
				priced[id] = label.Text
			end
			local says = if owned[id] then yours else priced[id] or label.Text
			if label.Text ~= says then
				label.Text = says
			end
		end
		if prompt then
			prompt.Enabled = not owned[id]
		end
	end

	local function adopt(item: Instance)
		local id = item:GetAttribute(Net.LEGEND_ATTRIBUTE)
		if typeof(id) ~= "string" then
			return
		end
		if item:IsA("ProximityPrompt") then
			prompts[id] = item
		elseif item:IsA("BillboardGui") then
			local label = item:FindFirstChild(Net.LEGEND_PRICE, true)
			if label and label:IsA("TextLabel") then
				labels[id] = label
				-- The server writes the price there when Roblox tells it: for an owner the
				-- tag goes on saying whose it is.
				label:GetPropertyChangedSignal("Text"):Connect(function()
					mark(id)
				end)
			end
		end
		mark(id)
	end

	-- The server builds the plaza and the show at startup, but this script may run first.
	task.spawn(function()
		for _, name in { Net.LEGENDS_FOLDER, "Plaza" } do
			local folder = Workspace:WaitForChild(name, WAIT)
			if folder then
				folder.DescendantAdded:Connect(adopt)
				for _, item in folder:GetDescendants() do
					adopt(item)
				end
			end
		end
	end)

	Store.onChange(function(state)
		local now: { [string]: boolean } = {}
		for _, id in state.legends do
			now[id] = true
		end
		local changed = false
		for id in labels do
			changed = changed or (owned[id] == true) ~= (now[id] == true)
		end
		for id in prompts do
			changed = changed or (owned[id] == true) ~= (now[id] == true)
		end
		owned = now
		if changed then
			for id in prompts do
				mark(id)
			end
			for id in labels do
				mark(id)
			end
		end
	end)
end

return LegendShow
