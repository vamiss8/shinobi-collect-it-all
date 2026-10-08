--!strict
-- Rebirth: a player whose Chakra has reached what their next rebirth asks (Config/Rebirths)
-- gives all of it up for what a rebirth pays for good, more Ryo, more Chakra from every rep and
-- better luck with mutations (Logic/Rebirth, by way of Logic/Boosts). Nothing else of theirs
-- is touched. The client only asks; whether they may is decided here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require("../Data")
local Kicking = require("./Kicking")
local Rebirths = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Remotes = require("../Remotes")
local Session = require("../Session")
local State = require("./State")

local Rebirth = {}

local function rebirth(player: Player)
	local data = Data.get(player)
	-- Not in the middle of a throw: its power was taken from the Chakra about to be given up.
	if not data or Kicking.throwing(player) then
		return
	end
	local following = Rebirths.next(data.rebirths)
	if not following or data.chakra < following.chakra then
		return
	end

	data.rebirths = Rebirths.done(data.rebirths) + 1
	data.chakra = Rebirths.START_CHAKRA
	-- The amount they had chosen to throw with was of the Chakra they no longer have.
	Session.of(player).throwChakra = 0
	State.push(player)
	-- News for everyone else; the player's own screen celebrates by itself.
	for _, other in Players:GetPlayers() do
		if other ~= player then
			State.notify(other, "RebirthBy", player.DisplayName, following.title)
		end
	end
end

function Rebirth.start()
	Remotes.Rebirth.OnServerEvent:Connect(rebirth)
end

return Rebirth
