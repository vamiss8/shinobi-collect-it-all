--!strict
-- A player's settings (client SettingsPanel): what they are when nothing is chosen, which
-- language a player is given, and what of a change a client sends is kept. Saved with the
-- player's progress, so that they follow the player to any device.

local Languages = require("../Config/Languages")

local Settings = {}

export type Settings = {
	language: string, -- Languages.AUTO, or a language's code
	font: string, -- "brush", or "plain" for the readable face (Languages.PLAIN)
	music: number, -- 0..1
	effects: number, -- 0..1
}

Settings.FONTS = { "brush", "plain" }
-- Volumes go in tenths.
Settings.STEP = 0.1

function Settings.defaults(): Settings
	return { language = Languages.AUTO, font = "brush", music = 0.6, effects = 0.8 }
end

-- The language a player is given: the one they chose, or else that of their Roblox (its locale,
-- as "pt-br"), or else, when that is English or not one of ours, the one of their country (as
-- "BR"), or else English.
function Settings.language(choice: string?, locale: string?, country: string?): string
	if choice and Languages.byCode[choice] then
		return choice
	end
	local spoken = string.lower(string.match(locale or "", "^%a+") or "")
	for _, language in Languages.list do
		if language.code ~= Languages.DEFAULT and table.find(language.locales, spoken) then
			return language.code
		end
	end
	local from = string.upper(country or "")
	for _, language in Languages.list do
		if table.find(language.countries, from) then
			return language.code
		end
	end
	return Languages.DEFAULT
end

local function volume(value: unknown, otherwise: number): number
	if typeof(value) ~= "number" or value ~= value then
		return otherwise
	end
	local steps = math.floor(math.clamp(value, 0, 1) / Settings.STEP + 0.5)
	return steps * Settings.STEP
end

-- What is kept of settings a client sent: anything it may not be is left as it was.
function Settings.clean(wanted: unknown, current: Settings): Settings
	local given: { [string]: unknown } = if typeof(wanted) == "table" then wanted :: any else {}
	local language = given.language
	local font = given.font
	return {
		language = if typeof(language) == "string"
				and (language == Languages.AUTO or Languages.byCode[language] ~= nil)
			then language
			else current.language,
		font = if typeof(font) == "string" and table.find(Settings.FONTS, font)
			then font
			else current.font,
		music = volume(given.music, current.music),
		effects = volume(given.effects, current.effects),
	}
end

return Settings
