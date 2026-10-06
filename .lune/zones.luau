--!strict
-- Builds every zone's scenery outside Roblox and prints what it is made of: how many parts,
-- how many of them cast a shadow, how many lights.
--   lune run zones
-- The rules the scenery must keep (the corridor over the lane, the budget of parts, the last
-- zone unchanged) are tests: `lune run test`.

local Catalog = require("../src/shared/Config/Catalog")
local Zones = require("../tests/zones")

local function pad(text: string, width: number): string
	return text .. string.rep(" ", math.max(width - #text, 0))
end

print(pad("zone", 22) .. pad("parts", 8) .. pad("shadows", 9) .. pad("lights", 8) .. "gate")
local total = 0
for _, zone in Catalog.zones do
	local built = Zones.build(zone.id)
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
		pad(zone.id, 22)
			.. pad(tostring(#built.parts), 8)
			.. pad(tostring(shadows), 9)
			.. pad(tostring(built.lights), 8)
			.. tostring(gate)
	)
end
print(`{total} parts in all`)
