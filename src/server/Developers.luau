--!strict
-- The accounts the developer console obeys (Services/DevConsole): whoever is listed here can
-- give themselves anything in the game, on a live server as well as in a test, so the list is
-- the owner's alone. It lives on the server: a client never sees it, and what a client says
-- about itself is never taken for it.

-- Roblox user ids. An id is the number in the address of a profile page:
-- roblox.com/users/<id>/profile
local Developers: { number } = {
	2893192350, -- owner
}

return Developers
