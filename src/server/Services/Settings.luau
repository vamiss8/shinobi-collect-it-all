--!strict
-- A player's settings (Logic/Settings): kept in their save, so they follow the player to any
-- device, and put on their Player as attributes for their client to read once the save has
-- loaded. The client sends the settings as they are whenever one is changed; what it may not
-- set is left as it was.
--
-- A new language takes when the player comes back into the game (every word on the screen is
-- written as it is built), so the client can ask to be sent back into this same server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Data = require("../Data")
local Net = require(ReplicatedStorage.Shared.Net)
local Remotes = require("../Remotes")
local SettingsLogic = require(ReplicatedStorage.Shared.Logic.Settings)
local State = require("./State")

local Settings = {}

local function post(player: Player, settings: SettingsLogic.Settings)
	player:SetAttribute(Net.SETTING_LANGUAGE, settings.language)
	player:SetAttribute(Net.SETTING_FONT, settings.font)
	player:SetAttribute(Net.SETTING_MUSIC, settings.music)
	player:SetAttribute(Net.SETTING_EFFECTS, settings.effects)
	player:SetAttribute(Net.SETTING_MUSIC_MUTED, settings.musicMuted == true)
	player:SetAttribute(Net.SETTING_EFFECTS_MUTED, settings.effectsMuted == true)
	player:SetAttribute(Net.SETTING_QUIET_DISCORD, settings.quietDiscord == true)
end

-- Sends the player back into the server they are on; into another one of the game if that
-- cannot be done (it is full, or shutting).
local function rejoin(player: Player)
	if RunService:IsStudio() then
		State.notify(player, "RejoinStudio")
		return
	end
	local options = Instance.new("TeleportOptions")
	options.ServerInstanceId = game.JobId
	local ok = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		ok = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player })
		end)
	end
	if not ok then
		State.notify(player, "RejoinFailed")
	end
end

function Settings.start()
	Data.onLoaded(function(player, data)
		post(player, data.settings)
	end)
	Remotes.Settings.OnServerEvent:Connect(function(player, wanted)
		local data = Data.get(player)
		if data then
			data.settings = SettingsLogic.clean(wanted, data.settings)
			post(player, data.settings)
		end
	end)
	Remotes.Rejoin.OnServerEvent:Connect(rejoin)
end

return Settings
