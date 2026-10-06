--!strict
-- Server entry point. Each service registers its hooks in start(); Data.start() comes last
-- because it begins loading players, which fires those hooks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Config.Catalog)
local Data = require(script.Data)
local Dojo = require(script.Services.Dojo)
local Hub = require(script.World.Hub)
local Inventory = require(script.Services.Inventory)
local Kicking = require(script.Services.Kicking)
local Loadout = require(script.Services.Loadout)
local Market = require(script.World.Market)
local PlaytestGate = require(script.PlaytestGate)
local Plaza = require(script.World.Plaza)
local Plots = require(script.World.Plots)
local Shop = require(script.Services.Shop)
local Showroom = require(script.World.Showroom)
local State = require(script.Services.State)
local Training = require(script.Services.Training)
local ZoneArt = require(script.World.ZoneArt)

local problems = Catalog.validate()
if #problems > 0 then
	warn(`[Server] config problems:\n{table.concat(problems, "\n")}`)
end

-- Closed playtest: accounts that are not on the list are sent away before anything is loaded
-- for them. The gate is off while its list is empty.
PlaytestGate.start()

-- The world first: services hook up to its prompts when they start.
Hub.start()
Plaza.start()
Market.start()
ZoneArt.start()
Showroom.start()

-- Order matters twice over. Load hooks run in this order (dojo first, snapshot last) and leave
-- hooks in reverse. Training, Inventory and Shop also fill the hotbar in this order, so the
-- training tools take slots 1 and 2 and the shinobi follow.
Plots.start()
Loadout.start()
Training.start()
Inventory.start()
Dojo.start()
Kicking.start()
Shop.start()
State.start()
Data.start()

print(`[Server] started with {#Catalog.characters} characters and {#Catalog.zones} zones`)
