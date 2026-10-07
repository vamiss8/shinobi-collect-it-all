--!strict
-- The dojo's building, checked on the building itself: its builder is run outside Roblox
-- (tests/zones) with all three floors up.

local PlazaPlan = require("../src/shared/Logic/PlazaPlan")
local T = require("./harness")
local Zones = require("./zones")

local halls: any = nil
local function parts(): { any }
	if not halls then
		halls = Zones.dojos({ 3, 3, 3, 3, 3, 3 })
	end
	local list = {}
	for _, item in halls:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(list, item)
		end
	end
	return list
end

local function where(part: any): string
	local at = part.CFrame.Position
	return string.format("%s at %.0f, %.0f, %.0f", part.Name, at.X, at.Y, at.Z)
end

return {
	-- They can be reached from the end of a landing, and whoever stepped onto one fell through.
	["the small roofs round a dojo's upper floors are solid"] = function()
		local eaves = 0
		for _, part in parts() do
			if part.Name == "Eave" then
				eaves += 1
				T.ok(part.CanCollide, `{where(part)} is fallen through`)
			end
		end
		-- Two along the sides and one along the back, on each of two upper floors of six dojos.
		T.eq(eaves, 3 * 2 * PlazaPlan.DOJOS)
	end,

	["the roof and the floors are solid"] = function()
		local roofs, floors = 0, 0
		for _, part in parts() do
			if part.Name == "Roof" then
				roofs += 1
				T.ok(part.CanCollide, `{where(part)} is fallen through`)
			elseif part.Name == "Floor" or part.Name == "Floor2" or part.Name == "Floor3" then
				floors += 1
				T.ok(part.CanCollide, `{where(part)} is fallen through`)
			end
		end
		-- Two slabs to each half of a roof; a floor to each storey.
		T.eq(roofs, 4 * PlazaPlan.DOJOS)
		T.eq(floors, 3 * PlazaPlan.DOJOS)
	end,
}
