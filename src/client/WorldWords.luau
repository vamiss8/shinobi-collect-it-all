--!strict
-- The words the server writes in the world, in English, said in this player's language: zone
-- signs, the tags over shinobi and over players, the pads' tags and the upgrade consoles, the
-- notice board, the shops' names and their prompts (Strings.world, Logic/Words). Each player's
-- client rewrites them for its own player, as it first sees them and whenever the server writes
-- them anew; nothing is rewritten for a player who plays in English.

local Workspace = game:GetService("Workspace")

local Strings = require("./Strings")

local WorldWords = {}

-- What this client last wrote into each, so that its own writing is not taken for the
-- server's.
local written: { [Instance]: { [string]: string } } = setmetatable({}, { __mode = "k" }) :: any

local function say(object: Instance, property: string)
	local text = (object :: any)[property]
	if typeof(text) ~= "string" or text == "" then
		return
	end
	local mine = written[object]
	if mine and mine[property] == text then
		return
	end
	local said = Strings.world(text)
	local record: { [string]: string } = mine or {}
	written[object] = record
	record[property] = said
	if said ~= text then
		(object :: any)[property] = said
	end
end

local function watch(object: Instance)
	local properties: { string }
	if object:IsA("TextLabel") or object:IsA("TextButton") then
		properties = { "Text" }
	elseif object:IsA("ProximityPrompt") then
		properties = { "ActionText", "ObjectText" }
	else
		return
	end
	for _, property in properties do
		say(object, property)
		object:GetPropertyChangedSignal(property):Connect(function()
			say(object, property)
		end)
	end
end

-- Call once the language is chosen (client Language).
function WorldWords.start()
	if Strings.language() == "en" then
		return
	end
	Workspace.DescendantAdded:Connect(watch)
	for _, object in Workspace:GetDescendants() do
		watch(object)
	end
end

return WorldWords
