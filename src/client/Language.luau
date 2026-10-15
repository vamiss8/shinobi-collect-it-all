--!strict
-- Chooses the language the game is written in for this player (Logic/Settings.language), before
-- anything is written: the one they chose in the settings, or else the language of their Roblox
-- account, of Roblox itself or of their device, whichever first is one of ours and not English.
-- Never by where they play from (an IP's country), which a VPN changes. Their choice is in
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

function Language.start(): string
	local player = Players.LocalPlayer
	local deadline = os.clock() + WAIT_FOR_SAVE
	while player:GetAttribute(Net.SETTING_LANGUAGE) == nil and os.clock() < deadline do
		task.wait(0.1)
	end
	local choice = player:GetAttribute(Net.SETTING_LANGUAGE)
	local saved = if typeof(choice) == "string" and Languages.byCode[choice] then choice else nil
	-- The account's language can be one Roblox's own interface is not written in, and then
	-- RobloxLocaleId is English while LocaleId is not (Roblox's docs).
	detected = Settings.language(nil, {
		player.LocaleId,
		LocalizationService.RobloxLocaleId,
		LocalizationService.SystemLocaleId,
	})
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
