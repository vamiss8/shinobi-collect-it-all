--!strict
-- The market round the fountain, checked on what its builder makes (tests/zones runs it outside
-- Roblox): the three shops, Tenten's Ninja Tools, the Mission Desk and the Youth Training
-- Ground, stand where the plan puts them (Logic/PlazaPlan), open towards the fountain, keep
-- inside the ground the plan gives them, and can be used from in front of their counters.
-- Kabuto's cart, off the ring, is held to the same but for where it looks.

local PlazaPlan = require("../src/shared/Logic/PlazaPlan")
local T = require("./harness")
local Zones = require("./zones")

-- How far a shop's prompt reaches from the middle of its counter (World/ShopHouse).
local REACH = 8
-- How far over the ground the plan gives it a part may reach: the round of a cylinder or a ball
-- is measured by its box here, which stands a little past it.
local SLACK = 0.05

-- Which folder each shop is built in.
local SHOPS = {
	tenten = "TentenShop",
	sell = "MissionDesk",
	speed = "TrainingGround",
	herbs = "PotionStall",
}
-- The shops round the fountain.
local RING = { tenten = true, sell = true, speed = true }

local market: any, keepers: { any } = nil, {}
local function build(): any
	if not market then
		market, keepers = Zones.market()
	end
	return market
end

local function partsOf(folder: any): { any }
	local list = {}
	for _, item in folder:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(list, item)
		end
	end
	return list
end

local function where(part: any): string
	local at = part.CFrame.Position
	return string.format("%s at %.1f, %.1f, %.1f", part.Name, at.X, at.Y, at.Z)
end

-- The corners of a part's box, on the ground.
local function footprint(part: any): { PlazaPlan.Spot }
	local frame, half = part.CFrame, part.Size / 2
	local corners = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local at = frame.Position
					+ frame.RightVector * (x * half.X)
					+ frame.UpVector * (y * half.Y)
					+ frame.LookVector * (z * half.Z)
				table.insert(corners, { along = at.X, side = at.Z })
			end
		end
	end
	return corners
end

-- Whether a point of the ground lies inside the corners given in order round it, or within
-- `slack` of it.
local function within(point: PlazaPlan.Spot, corners: { PlazaPlan.Spot }, slack: number): boolean
	return PlazaPlan.apart({ point }, corners) <= slack
end

return {
	["every shop is built, with a counter and a keeper"] = function()
		local folder = build()
		for id, name in SHOPS do
			local shop = folder:FindFirstChild(name)
			T.ok(shop ~= nil, `the {id} shop is built`)
			T.ok(shop:FindFirstChild("Counter") ~= nil, `the {id} shop has a counter`)
		end
		-- Tenten; Shizune and Tonton; Might Duy and his turtle; Kabuto at his cart.
		T.eq(#keepers, 6)
		local kabuto = false
		for _, keeper in keepers do
			kabuto = kabuto or keeper.id == "kabuto_shop"
		end
		T.ok(kabuto, "Kabuto stands at his cart")
		for _, keeper in keepers do
			T.ok(keeper.at ~= nil, `{keeper.id} is stood somewhere`)
		end
	end,

	["every part of a shop keeps to the ground the plan gives it"] = function()
		local folder = build()
		for id, name in SHOPS do
			local corners = PlazaPlan.shopCorners(PlazaPlan.shops[id])
			for _, part in partsOf(folder:FindFirstChild(name)) do
				for _, corner in footprint(part) do
					T.ok(
						within(corner, corners, SLACK),
						`{where(part)} reaches out of the {id} shop`
					)
				end
			end
		end
	end,

	["the shops open towards the fountain, their keepers looking out of them"] = function()
		local folder = build()
		local fountain = PlazaPlan.FOUNTAIN
		for id, name in SHOPS do
			local spot = PlazaPlan.shops[id]
			local counter = folder:FindFirstChild(name):FindFirstChild("Counter")
			local at = counter.CFrame.Position
			local out = PlazaPlan.facing(spot)
			-- How far in from the line of the front the counter stands.
			local inward = -((at.X - spot.along) * out.along + (at.Z - spot.side) * out.side)
			T.ok(inward > 0 and inward < 4, `the {id} counter stands just inside the open front`)
			if RING[id] then
				local toCounter =
					math.sqrt((at.X - fountain.along) ^ 2 + (at.Z - fountain.side) ^ 2)
				T.ok(
					toCounter > PlazaPlan.SHOP_RING and toCounter < PlazaPlan.SHOP_RING + 4,
					`the {id} counter is on the ring`
				)
			end
			-- A customer in front of the counter reaches the prompt; one passing beside does not.
			local porch = { along = spot.along + out.along * 1, side = spot.side + out.side * 1 }
			local fromPorch = math.sqrt((at.X - porch.along) ^ 2 + (at.Z - porch.side) ^ 2)
			T.ok(fromPorch <= REACH - 2, `the {id} counter is in reach from the porch`)
			local beside = {
				along = spot.along - out.side * (PlazaPlan.SHOP.half + 1),
				side = spot.side + out.along * (PlazaPlan.SHOP.half + 1),
			}
			local fromSide = math.sqrt((at.X - beside.along) ^ 2 + (at.Z - beside.side) ^ 2)
			T.ok(fromSide > REACH, `the {id} counter is out of reach from beside the shop`)
		end
		for _, keeper in keepers do
			local look, at = keeper.at.LookVector, keeper.at.Position
			local towards = look.X * (fountain.along - at.X) + look.Z * (fountain.side - at.Z)
			T.ok(towards > 0, `{keeper.id} looks towards the fountain`)
		end
		local herbs = PlazaPlan.facing(PlazaPlan.shops.herbs)
		T.eq(herbs.along, 0, "Kabuto's cart looks across the plaza")
		T.ok(herbs.side * PlazaPlan.shops.herbs.side < 0, "at the middle path")
	end,

	["nothing in a shop flickers"] = function()
		local folder = build()
		for id, name in SHOPS do
			local fights = Zones.fights(partsOf(folder:FindFirstChild(name)))
			for _, fight in fights do
				T.ok(
					fight.area < 0.01,
					`{where(fight.first)} and {where(fight.second)} flicker in the {id} shop`
				)
			end
		end
	end,
}
