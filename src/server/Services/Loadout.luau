--!strict
-- Fills the hotbar on every spawn. Roblox empties the backpack when a character respawns, so
-- each service that owns tools registers a giver here; givers run in registration order, which
-- is also the order of the hotbar slots.

local Data = require("../Data")
local Util = require("../Util")

local Loadout = {}

export type Giver = (
	player: Player,
	character: Model,
	backpack: Instance,
	humanoid: Humanoid
) -> ()

local givers: { Giver } = {}

function Loadout.register(giver: Giver)
	table.insert(givers, giver)
end

function Loadout.start()
	Data.onLoaded(function(player)
		Util.onCharacter(player, function(character)
			local backpack = player:WaitForChild("Backpack", 10)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if not backpack or not humanoid or not humanoid:IsA("Humanoid") then
				return
			end
			-- The waits above yield; the player may have left meanwhile.
			if not Data.get(player) then
				return
			end
			for _, give in givers do
				give(player, character, backpack, humanoid)
			end
		end)
	end)
end

return Loadout
