--!strict
local Catalog = require("../src/shared/Config/Catalog")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

return {
	["config is consistent"] = function()
		local problems = Catalog.validate()
		T.ok(#problems == 0, table.concat(problems, "; "))
	end,

	["unit titles show mutation, merge stars and level only when present"] = function()
		T.eq(Catalog.unitTitle("kakashi", Catalog.NONE, 1), "Kakashi")
		T.eq(Catalog.unitTitle("kakashi", "ice", 1), "Kakashi [Ice]")
		T.eq(Catalog.unitTitle("kakashi", "ice", 3), "Kakashi [Ice] ★★")
		T.eq(Catalog.unitTitle("kakashi", Catalog.NONE, 1, 0), "Kakashi")
		T.eq(Catalog.unitTitle("kakashi", Catalog.NONE, 2, 4), "Kakashi ★ Lvl 5")
		T.eq(Catalog.unitTitle("gone", Catalog.NONE, 1), "gone", "unknown id falls back to the id")
	end,

	["there is one zone per rank, in rank order"] = function()
		T.eq(#Catalog.zones, #Catalog.ranks)
		for i, zone in Catalog.zones do
			T.eq(zone.rank, Catalog.ranks[i].id, `zone {i}`)
		end
	end,

	["characters are listed from the weakest to the strongest"] = function()
		for i = 2, #Catalog.characters do
			local previous, character = Catalog.characters[i - 1], Catalog.characters[i]
			T.ok(
				Catalog.rankOrder[character.rank] >= Catalog.rankOrder[previous.rank],
				`{character.id} is listed after a higher rank`
			)
			T.ok(
				character.income >= previous.income,
				`{character.id} earns less than {previous.id} listed before it`
			)
		end
	end,

	["every rank has shinobi to drop"] = function()
		for _, rank in Catalog.ranks do
			T.ok(#Catalog.charactersByRank[rank.id] > 0, `nobody has rank {rank.id}`)
		end
	end,

	["zones end where the next one starts"] = function()
		T.eq(Catalog.zoneEnd(Catalog.zones[1]), Catalog.zones[2].startsAt)
		T.eq(Catalog.zoneEnd(Catalog.zones[#Catalog.zones]), Tuning.Kick.trackLength)
	end,

	["a zone takes more Chakra than the one before"] = function()
		T.eq(Catalog.zones[1].chakra, 1, "a new save has 1 Chakra and must reach the first zone")
		for i = 2, #Catalog.zones do
			local zone = Catalog.zones[i]
			T.ok(zone.chakra > Catalog.zones[i - 1].chakra, `{zone.id} takes no more Chakra`)
			T.eq(Catalog.zoneCeiling(Catalog.zones[i - 1]), zone.chakra, `ceiling before {zone.id}`)
		end
		local last = Catalog.zones[#Catalog.zones]
		T.eq(Catalog.zoneCeiling(last), last.chakra * Tuning.Kick.lastZoneSpan)
		T.eq(Catalog.zoneAfter(last), nil, "nothing follows the last zone")
		T.eq(Catalog.zoneAfter(Catalog.zones[1]), Catalog.zones[2])
	end,

	["a kunai is worth its price in training"] = function()
		for i = 2, #Catalog.kunai do
			local kunai, previous = Catalog.kunai[i], Catalog.kunai[i - 1]
			T.ok(kunai.price > previous.price, `{kunai.id} is no pricier`)
			T.ok(kunai.chakraPerRep > previous.chakraPerRep, `{kunai.id} trains no faster`)
		end
		-- The starting kunai, then two for every zone after the first.
		T.eq(#Catalog.kunai, 2 * #Catalog.zones - 1, "two kunai for every zone step")
	end,

	["the last zone starts before the end of the track"] = function()
		local last = Catalog.zones[#Catalog.zones]
		T.ok(last.startsAt < Tuning.Kick.trackLength, `{last.id} is past the end of the track`)
	end,
}
