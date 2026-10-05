--!strict

local Util = {}

-- Runs `fn` for the player's current character, if any, and for every one spawned later.
function Util.onCharacter(player: Player, fn: (character: Model) -> ())
	player.CharacterAdded:Connect(fn)
	local character = player.Character
	if character then
		task.spawn(fn, character)
	end
end

return Util
