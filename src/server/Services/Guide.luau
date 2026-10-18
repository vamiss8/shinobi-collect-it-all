--!strict
-- The guide's progress (Config/Guide; client Guide says it): the steps of the base tutorial
-- done (Data.guide) and the tips said (Data.tips), kept in the save so that nothing is said
-- twice and a tutorial left half way goes on where it stopped. Each step reached goes to the
-- Onboarding chart of the analytics (Services/Analytics), each tip to a custom event.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Analytics = require("./Analytics")
local Data = require("../Data")
local GuideConfig = require(ReplicatedStorage.Shared.Config.Guide)
local Remotes = require("../Remotes")
local State = require("./State")

local Guide = {}

local tipIds: { [string]: boolean } = {}
for _, tip in GuideConfig.tips do
	tipIds[tip.id] = true
end

local function told(player: Player, what: unknown, which: unknown)
	local data = Data.get(player)
	if not data then
		return
	end
	if what == "step" and typeof(which) == "number" then
		local done = math.clamp(math.floor(which), 0, GuideConfig.DONE)
		-- Steps only go forward: a replay from the settings sends nothing back.
		if done > data.guide then
			for step = data.guide + 1, done do
				Analytics.onboarding(player, step, GuideConfig.steps[step].id)
			end
			data.guide = done
			State.push(player)
		end
	elseif what == "tip" and typeof(which) == "string" and tipIds[which] then
		if not data.tips[which] then
			data.tips[which] = true
			Analytics.event(player, "Tip", 1, which)
			State.push(player)
		end
	end
end

function Guide.start()
	Remotes.Guide.OnServerEvent:Connect(told)
end

return Guide
