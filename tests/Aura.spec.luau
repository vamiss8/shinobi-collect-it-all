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

	-- What Robux buy is to be known from across the plaza.
	["every legendary shinobi has an aura of its own, with more to it than any mutation's"] = function()
		local most = 0
		for _, look in Aura.looks do
			most = math.max(most, layers(look))
		end
		local before = 0
		for _, legend in Catalog.legends do
			local own = Aura.legends[legend.id]
			T.ok(own ~= nil, `{legend.name} has no aura`)
			local count = layers(own.look)
			T.ok(
				count > most,
				`{legend.name}'s aura is {count} kinds of particle, a mutation's {most}`
			)
			T.ok(count >= before, `{legend.name} has less to its aura than a cheaper one`)
			before = count
			T.ok(string.match(own.color, "^#%x%x%x%x%x%x$") ~= nil, `{legend.name}: not a color`)
			local alive = 0
			for _, place in { own.look.body, own.look.ground, own.look.around } do
				for _, layer in place or {} do
					local largest = math.max(table.unpack(layer.size))
					T.ok(largest >= 0.7, `{legend.name}: a particle {largest} of a stud across`)
					T.ok(layer.streak == nil, `{legend.name}: darts are the storm's alone`)
					alive += layer.rate * (layer.life[1] + layer.life[2]) / 2
				end
			end
			-- A player has one of each at the most, and three more stand on show.
			T.ok(alive <= 100, `{legend.name}: about {math.floor(alive)} particles at once`)
		end
	end,

	-- An event's mutation is the event in small: more than one kind of particle.
	["every event mutation's aura has several kinds of particle"] = function()
		for _, mutation in Catalog.mutations do
			if mutation.event then
				local count = layers(Aura.looks[mutation.id])
				T.ok(count >= 3, `{mutation.name}'s aura is {count} kinds of particle`)
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
