--!strict
-- The hour on the village's clock, as this client reckons it: from the moment the server says
-- the day began (an attribute of the Hub folder) and the clock every client shares with the
-- server. So all players see the same hour without a word being sent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Daylight = require(ReplicatedStorage.Shared.Logic.Daylight)
local Looks = require(ReplicatedStorage.Shared.Config.ZoneArt)
local Net = require(ReplicatedStorage.Shared.Net)

local Daytime = {}

-- The hour, 0..24. Until the server's world is there it is the hour a day begins at.
function Daytime.clock(): number
	local hub = Workspace:FindFirstChild(Net.HUB_FOLDER)
	if not hub then
		return Looks.daytime.begins
	end
	-- An hour put on the folder by hand, in a Studio test, stops the clock there.
	local stopped = hub:GetAttribute(Net.HOUR_ATTRIBUTE)
	if typeof(stopped) == "number" then
		return stopped % 24
	end
	local began = hub:GetAttribute(Net.DAY_ATTRIBUTE)
	if typeof(began) ~= "number" then
		return Looks.daytime.begins
	end
	return Daylight.clock(math.max(Workspace:GetServerTimeNow() - began, 0))
end

return Daytime
