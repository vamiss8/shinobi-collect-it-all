--!strict
-- The auras of the mutations (View/Aura): every mutation has one, a rarer one has more to it,
-- and none is too faint to see or too much to draw.
local Aura = require("../src/shared/View/Aura")
local Catalog = require("../src/shared/Config/Catalog")
local T = require("./harness")

-- The ones the owner said to leave as they are: one kind of particle each.
local PLAIN = { chakra = true, kurama = true }

local function layers(look: Aura.Look): number
	return #(look.body or {}) + #(look.ground or {}) + #(look.around or {})
end

return {
	["every mutation has an aura, and a rarer one has as much to it or more"] = function()
		local before = 0
		for _, mutation in Catalog.mutations do
			local look = Aura.looks[mutation.id]
			T.ok(look ~= nil, `{mutation.name} has no aura of its own`)
			if not mutation.event then
				local count = layers(look)
				T.ok(count >= before, `{mutation.name} has less to its aura than a commoner one`)
				before = count
				if not PLAIN[mutation.id] then
					T.ok(count >= 3, `{mutation.name}'s aura is {count} kinds of particle`)
				end
			end
		end
	end,

	["nothing in an aura is too small to be seen or too much to draw"] = function()
		for id, look in Aura.looks do
			if not PLAIN[id] then
				local alive = 0
				for _, place in { look.body, look.ground, look.around } do
					for _, layer in place or {} do
						local largest = math.max(table.unpack(layer.size))
						T.ok(largest >= 0.7, `{id}: a particle {largest} of a stud across`)
						alive += layer.rate * (layer.life[1] + layer.life[2]) / 2
					end
				end
				-- A dojo can stand thirty figures, and there are six dojos.
				T.ok(alive <= 70, `{id}: about {math.floor(alive)} particles in the air at once`)
			end
		end
	end,
}
