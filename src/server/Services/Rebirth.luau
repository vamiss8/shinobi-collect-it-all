--!strict
-- Rebirth: a player whose Chakra has reached what their next rebirth asks (Config/Rebirths)
-- starts over, without their Chakra, shinobi, Ryo or run speed, for what a rebirth pays for
-- good: more Ryo, more Chakra from every rep and better luck with mutations (Logic/Rebirth,
-- by way of Logic/Boosts), and the next rank. Their kunai, their dojo's pads and floors and
-- their Bingo Book are left alone. The client only asks; whether they may is decided here.
--
-- Logic/Rebirth.apply changes the save. What is done here is the rest of the world catching
-- up with it: the shinobi come off the pads and out of the player's hands, the runner slows
-- to a walk and loses their speed's look, and their rank changes over their head.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require("../Data")
local Dojo = require("./Dojo")
local Economy = require(ReplicatedStorage.Shared.Logic.Economy)
local Inventory = require("./Inventory")
local Kicking = require("./Kicking")
local Rebirths = require(ReplicatedStorage.Shared.Logic.Rebirth)
local Remotes = require("../Remotes")
local Session = require("../Session")
local SpeedLook = require("./SpeedLook")
local State = require("./State")
local Titles = require("./Titles")

local Rebirth = {}

local function rebirth(player: Player)
	local data = Data.get(player)
	-- Not in the middle of a throw: its power was taken from the Chakra about to be given up,
	-- and the catch it brings home would be of a life already over.
	if not data or Kicking.throwing(player) then
		return
	end
	local following = Rebirths.next(data.rebirths)
	if not following or data.chakra < following.chakra then
		return
	end

	Rebirths.apply(data)

	-- The shinobi are gone: out of the hands, off the pads, out of the inventory's window.
	Inventory.hold(player, nil)
	Dojo.redraw(player)
	Inventory.sync(player)
	-- The amount they had chosen to throw with was of the Chakra they no longer have.
	Session.of(player).throwChakra = 0
	-- Run speed is back to none. (Nobody is frozen here: a throw was ruled out above.)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if character and humanoid then
		if humanoid.WalkSpeed > 0 then
			humanoid.WalkSpeed = Economy.walkSpeed(0)
		end
		SpeedLook.apply(character, 0)
	end
	Titles.dress(player)
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
