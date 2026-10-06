--!strict
-- Builds every zone's scenery and the village's outside Roblox and prints what each is made
-- of: how many parts, how many of them cast a shadow, how many lights, and how many parts its
-- gate is.
--   lune run zones
-- The rules the scenery must keep (the corridor over the lane, the budget of parts, a horizon
-- that is closed) are tests: `lune run test`.

local Catalog = require("../src/shared/Config/Catalog")
local Zones = require("../tests/zones")

local function pad(text: string, width: number): string
	return text .. string.rep(" ", math.max(width - #text, 0))
end

local ids = { Zones.HOME }
for _, zone in Catalog.zones do
	table.insert(ids, zone.id)
end

print(pad("scene", 22) .. pad("parts", 8) .. pad("shadows", 9) .. pad("lights", 8) .. "gate")
local total = 0
for _, id in ids do
	local built = Zones.build(id)
	local shadows, gate = 0, 0
	for _, part in built.parts do
		if part.CastShadow then
			shadows += 1
		end
		if built.gate[part] then
			gate += 1
		end
	end
	total += #built.parts
	print(
		pad(id, 22)
			.. pad(tostring(#built.parts), 8)
			.. pad(tostring(shadows), 9)
			.. pad(tostring(built.lights), 8)
			.. tostring(gate)
	)
end
print(`{total} parts in all`)
