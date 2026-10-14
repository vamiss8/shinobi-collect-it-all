--!strict
-- Chooses the language the game is written in for this player (Logic/Settings.language), before
-- anything is written: the one they chose in the settings, or else that of their Roblox, or
-- else, when their Roblox is in English, that of the country they play from. Their choice is in
-- their save, which the server puts on their Player once it has loaded: it is waited for a
-- moment, and a save slow to come leaves the language worked out without it.

local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Languages = require(ReplicatedStorage.Shared.Config.Languages)
local Net = require(ReplicatedStorage.Shared.Net)
local Settings = require(ReplicatedStorage.Shared.Logic.Settings)
local Strings = require("./Strings")

local Language = {}

-- How long the saved choice is waited for, seconds.
local WAIT_FOR_SAVE = 4

-- The language the game would choose by itself, and the language it is written in now.
local detected = Languages.DEFAULT
local chosen = Languages.DEFAULT

local function country(player: Player): string?
	local ok, code = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)
	return if ok and typeof(code) == "string" then code else nil
end

function Language.start(): string
	local player = Players.LocalPlayer
	local deadline = os.clock() + WAIT_FOR_SAVE
	while player:GetAttribute(Net.SETTING_LANGUAGE) == nil and os.clock() < deadline do
		task.wait(0.1)
	end
	local choice = player:GetAttribute(Net.SETTING_LANGUAGE)
	local saved = if typeof(choice) == "string" and Languages.byCode[choice] then choice else nil
	local locale = LocalizationService.RobloxLocaleId
	-- The country is asked only when the locale does not settle it: it is a call that waits.
	local byLocale = Settings.language(nil, locale, nil)
	detected = if byLocale ~= Languages.DEFAULT
		then byLocale
		else Settings.language(nil, locale, country(player))
	chosen = saved or detected
	-- A Studio tester can have any language (Net.TEST_LANGUAGE_ATTRIBUTE).
	local models = ReplicatedStorage:FindFirstChild(Net.MODELS_FOLDER)
	local forced = if models and RunService:IsStudio()
		then models:GetAttribute(Net.TEST_LANGUAGE_ATTRIBUTE)
		else nil
	if typeof(forced) == "string" and Languages.byCode[string.lower(forced)] then
		chosen = string.lower(forced)
	end
	Strings.use(chosen)
	return chosen
end

-- The language written in now.
function Language.current(): string
	return chosen
end

-- The language the game would choose by itself for this player.
function Language.detected(): string
	return detected
end

return Language
