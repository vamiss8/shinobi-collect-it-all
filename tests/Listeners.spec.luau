--!strict
-- A message the server sends the moment a save loads comes to the client before anyone there
-- listens (the client starts its modules after the save has loaded: client Language waits for
-- it), and Roblox delivers a message kept that way to the handler that connects first. Such a
-- message must have one handler on the client, or the others never hear of it: the welcome-back
-- window stayed shut while client Guide had the offline message (client WelcomeBack).
local fs = require("@lune/fs")

local T = require("./harness")

-- The messages the server sends at load, for a client that is not listening yet.
local AT_LOAD = { "Offline" }

local function sources(path: string, into: { string })
	for _, name in fs.readDir(path) do
		local full = `{path}/{name}`
		if fs.isDir(full) then
			sources(full, into)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(into, fs.readFile(full))
		end
	end
end

return {
	["a message sent at load has one handler on the client"] = function()
		local files = {}
		sources("src/client", files)
		for _, event in AT_LOAD do
			local count = 0
			for _, source in files do
				for _ in string.gmatch(source, `Remotes%.{event}%.OnClientEvent:Connect`) do
					count += 1
				end
			end
			T.eq(count, 1, `Remotes.{event} has {count} handlers on the client`)
		end
	end,
}
