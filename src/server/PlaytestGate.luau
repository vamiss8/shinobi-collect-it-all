--!strict
-- Closed playtest gate. While the game is published for testing, only the accounts listed here
-- may stay on a live server; anyone else is sent away as they join. An empty list switches the
-- gate off.
--
-- Roblox's own audience setting (Creator Hub > Configure > Settings > Audience) is the first
-- lock. This is the second one, for audiences that admit more people than the testers:
-- "Friends" lets in every friend of the owner, "Public" lets in everyone.
--
-- Before the real release the list has to be emptied, or nobody but the testers gets in.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlaytestGate = {}

-- Roblox user ids of the testers. An id is the number in the address of a profile page:
-- roblox.com/users/<id>/profile
local ALLOWED: { number } = {
	2893192350, -- owner
	9144243296, -- co-author
}

local function check(player: Player)
	if not table.find(ALLOWED, player.UserId) then
		player:Kick("This game is in closed testing. Come back soon!")
	end
end

function PlaytestGate.start()
	-- Test sessions in Studio run under made-up accounts, so the gate is for live servers only.
	if #ALLOWED == 0 or RunService:IsStudio() then
		return
	end
	Players.PlayerAdded:Connect(check)
	for _, player in Players:GetPlayers() do
		check(player)
	end
end

return PlaytestGate
