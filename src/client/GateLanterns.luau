--!strict
-- Lights the lanterns on the gate of the Youth Training Ground (World/TrainingGround) for this
-- player: one for every one of the Eight Gates they have opened (Config/SpeedStages), green and
-- glowing a little; the rest hang pale gray, as the server hung them. What a client does to
-- them only that client sees, so every player sees their own way to the Gate of Death.
--
-- They first glowed each in its Gate's color, green, blue and red; the owner asked for one
-- plain reading instead: gray for what is not yet opened, green for what is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Net)
local SpeedStages = require(ReplicatedStorage.Shared.Config.SpeedStages)
local Store = require("./Store")

local GateLanterns = {}

-- How long to wait for the server's market to appear, seconds.
local WAIT = 60

-- An opened Gate's lantern: a green that glows without glaring, and the faint light it gives.
local OPENED = Color3.fromRGB(104, 196, 118)
local GLOW = { range = 9, brightness = 0.5 }

function GateLanterns.start()
	-- The server builds the market at startup, but this script may run first.
	task.spawn(function()
		local market = Workspace:WaitForChild(Net.MARKET_FOLDER, WAIT)
		local ground = if market then market:WaitForChild("TrainingGround", WAIT) else nil
		if not ground then
			return
		end

		-- The lanterns by their Gate, each with how it looks unlit.
		local lanterns: { [number]: { part: BasePart, color: Color3, material: Enum.Material } } =
			{}
		for _, item in ground:GetDescendants() do
			local gate = item:GetAttribute(Net.GATE_ATTRIBUTE)
			if
				item.Name == Net.GATE_LANTERN
				and item:IsA("BasePart")
				and typeof(gate) == "number"
			then
				lanterns[gate] = { part = item, color = item.Color, material = item.Material }
			end
		end

		local shown = -1
		Store.onChange(function(state)
			local stage = SpeedStages.at(state.speedLevel)
			if stage.gate == shown then
				return
			end
			shown = stage.gate
			for gate, lantern in lanterns do
				local lit = gate <= stage.gate
				local part = lantern.part
				part.Color = if lit then OPENED else lantern.color
				part.Material = if lit then Enum.Material.Neon else lantern.material
				local light = part:FindFirstChildOfClass("PointLight")
				if light then
					light.Color = OPENED
					light.Range = GLOW.range
					light.Brightness = GLOW.brightness
					light.Enabled = lit
				end
			end
		end)
	end)
end

return GateLanterns
