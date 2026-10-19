--!strict
-- A word now and then that the game has a Discord server (owner, 2026-10-19: "mention the
-- Discord in the game itself, not only in the FAQ"). ROBLOX ALLOWS NO LINK INSIDE A GAME
-- (Tuning.Social): the words name the server and say that its link is on the game's page.
-- Only once there is one (Tuning.Social.server), at REMIND_AT seconds into a visit, on the
-- message scroll, never in the middle of a throw, over an open window or while Iruka teaches.
-- Iruka says it too, at the end of his tutorial (client Guide), and so does How to play.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cinematic = require("./Cinematic")
local Guide = require("./Guide")
local Hud = require("./Hud")
local Strings = require("./Strings")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)
local Ui = require("./Ui")

local Community = {}

local REMIND_AT = { 600, 2700 }
-- A reminder that finds the player busy looks again this many seconds later.
local RETRY = 20
-- Discord's own blue, on the scroll's seal and edge.
local DISCORD = Color3.fromRGB(88, 101, 242)

function Community.start()
	if not Tuning.Social.server then
		return
	end
	task.spawn(function()
		local started = os.clock()
		for _, at in REMIND_AT do
			task.wait(math.max(at - (os.clock() - started), 0))
			while Cinematic.staging() or Ui.windowOpen() or Guide.running() do
				task.wait(RETRY)
			end
			Hud.toast(Strings.get("CommunityRemind"), DISCORD)
		end
	end)
end

return Community
