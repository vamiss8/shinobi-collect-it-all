--!strict
-- The legendary shinobi on their pedestals (Services/Legends), as this player sees them: one
-- the player owns says so on its price tag, and its prompt no longer offers it; and a tag
-- says the price this player would pay. The server builds the pedestals' tags and prompts for
-- everyone alike; what is changed here is this client's own copy of them.
--
-- The price is asked for here as well as on the server because Roblox may price a pass by
-- region or try another price on some players, when the owner lets it (managed pricing): only
-- a client is told its own player's price, and that is the one the purchase window will show.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
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
	-- And what this client was told the price is for its own player, which goes before it.
	local mine: { [string]: string } = {}

	local function mark(id: string)
		local label, prompt = labels[id], prompts[id]
		local yours = Strings.get("LegendYours")
		if label then
			if label.Text ~= yours and label.Text ~= mine[id] then
				priced[id] = label.Text
			end
			local says = if owned[id] then yours else mine[id] or priced[id] or label.Text
			if label.Text ~= says then
				label.Text = says
			end
		end
		if prompt then
			-- The prompt is the way to buy: it names its price, and is gone for an owner.
			prompt.Enabled = not owned[id]
			local legend = Catalog.legendById[id]
			if legend and mine[id] then
				prompt.ObjectText = `{legend.name}  |  {mine[id]}`
			end
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

	-- This player's price of each pass. The call can fail, and is tried again a few times.
	for _, legend in Catalog.legends do
		local pass = Catalog.legendPass(legend.id)
		if pass > 0 then
			task.spawn(function()
				for _ = 1, 5 do
					local ok, info = pcall(function()
						return MarketplaceService:GetProductInfo(pass, Enum.InfoType.GamePass)
					end)
					local robux = if ok and typeof(info) == "table" then info.PriceInRobux else nil
					if typeof(robux) == "number" then
						mine[legend.id] = Strings.get("LegendPrice", tostring(robux))
						mark(legend.id)
						return
					end
					task.wait(20)
				end
			end)
		end
	end

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
