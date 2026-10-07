--!strict
local Corridor = require("../src/shared/Logic/Corridor")
local T = require("./harness")

local LIMIT = 29.4

return {
	["a camera between the walls stands where it wants"] = function()
		T.eq(Corridor.reach(0, 12, LIMIT), 1)
		T.eq(Corridor.reach(-20, -29, LIMIT), 1)
		T.eq(Corridor.reach(25, LIMIT, LIMIT), 1)
	end,

	["a camera past a wall is pulled in to the wall, along its line of sight"] = function()
		for _, case in { { 0, 58.8 }, { 10, 41 }, { -5, -80 }, { 28, 40 }, { -12, 33 } } do
			local focus, eye = case[1], case[2]
			local share = Corridor.reach(focus, eye, LIMIT)
			T.ok(share > 0 and share < 1, `share {share} for a camera at {eye}`)
			-- Where it ends up: on the limit, on the side it was on.
			local stands = focus + (eye - focus) * share
			T.near(math.abs(stands), LIMIT, 1e-9)
			T.ok(stands * eye > 0, "the camera changed sides")
		end
	end,

	["it comes no nearer its subject than a small share of the way"] = function()
		-- The subject is right at the wall: the line to the limit is next to nothing.
		T.eq(Corridor.reach(29.39, 45, LIMIT), Corridor.NEAREST)
		-- The subject is itself out past the limit, on the camera's side.
		T.eq(Corridor.reach(31, 45, LIMIT), Corridor.NEAREST)
		T.eq(Corridor.reach(-31, -45, LIMIT), Corridor.NEAREST)
		T.ok(Corridor.NEAREST > 0 and Corridor.NEAREST < 0.2)
	end,

	["a subject past one wall does not stop a camera past the other"] = function()
		local share = Corridor.reach(-31, 45, LIMIT)
		T.near(-31 + (45 + 31) * share, LIMIT, 1e-9)
	end,
}
