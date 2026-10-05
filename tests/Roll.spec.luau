--!strict
local Catalog = require("../src/shared/Config/Catalog")
local Roll = require("../src/shared/Logic/Roll")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

local EPS = 1e-9

local function weightOf(entries: { Roll.Entry }, id: string): number
	for _, e in entries do
		if e.id == id then
			return e.weight
		end
	end
	return 0
end

return {
	["luck x1 keeps the odds"] = function()
		local out = Roll.withLuck({ { id = "a", weight = 90 }, { id = "b", weight = 10 } }, 1)
		T.near(weightOf(out, "a"), 0.9, EPS)
		T.near(weightOf(out, "b"), 0.1, EPS)
	end,

	["luck multiplies every rarer entry and the common one gives way"] = function()
		local out = Roll.withLuck({ { id = "a", weight = 90 }, { id = "b", weight = 10 } }, 2)
		T.near(weightOf(out, "a"), 0.8, EPS)
		T.near(weightOf(out, "b"), 0.2, EPS)
	end,

	["overflowing luck keeps rare entries in proportion"] = function()
		local out = Roll.withLuck({
			{ id = "a", weight = 50 },
			{ id = "b", weight = 30 },
			{ id = "c", weight = 20 },
		}, 10)
		T.near(weightOf(out, "a"), 0, EPS)
		T.near(weightOf(out, "b"), 0.6, EPS)
		T.near(weightOf(out, "c"), 0.4, EPS)
	end,

	["pick walks the cumulative weights"] = function()
		local t = { { id = "a", weight = 0.5 }, { id = "b", weight = 0.5 } }
		T.eq(Roll.pick(t, 0), "a")
		T.eq(Roll.pick(t, 0.49), "a")
		T.eq(Roll.pick(t, 0.5), "b")
		T.eq(Roll.pick(t, 0.999999), "b")
	end,

	["pick never returns a zero-weight entry"] = function()
		local t = { { id = "a", weight = 0 }, { id = "b", weight = 1 }, { id = "c", weight = 0 } }
		T.eq(Roll.pick(t, 0), "b")
		T.eq(Roll.pick(t, 0.999999), "b")
	end,

	["every 10th, 20th and 100th kick gets extra luck"] = function()
		T.eq(Roll.spinLuck(0), 1)
		T.eq(Roll.spinLuck(7), 1)
		T.eq(Roll.spinLuck(10), 2)
		T.eq(Roll.spinLuck(20), 5)
		T.eq(Roll.spinLuck(30), 2)
		T.eq(Roll.spinLuck(40), 5)
		T.eq(Roll.spinLuck(100), 10, "100 is also a multiple of 10 and 20; the biggest wins")
		T.eq(Roll.spinLuck(200), 10)
	end,

	["the countdown points at the next lucky kick"] = function()
		local left, luck = Roll.nextMilestone(0)
		T.eq(left, 10)
		T.eq(luck, 2)
		left, luck = Roll.nextMilestone(17)
		T.eq(left, 3)
		T.eq(luck, 5, "kick 20")
		left, luck = Roll.nextMilestone(99)
		T.eq(left, 1)
		T.eq(luck, 10, "kick 100")
		left = Roll.nextMilestone(10)
		T.eq(left, 10, "right after a lucky kick")
	end,

	["bubbles only come in the configured multipliers"] = function()
		T.eq(Roll.bubble(0), 2, "the most common bubble comes first")
		T.eq(Roll.bubble(0.999999), 10, "the rarest comes last")
	end,

	["mutation odds add up to one and leave events out"] = function()
		local t = Roll.mutationTable(nil)
		local total = 0
		for _, e in t do
			total += e.weight
		end
		T.near(total, 1, EPS)
		T.eq(t[1].id, Catalog.NONE)
		T.eq(weightOf(t, "tsukuyomi"), 0, "event mutation outside its event")
	end,

	["event mutations join while their event runs"] = function()
		T.ok(
			weightOf(Roll.mutationTable("blood_moon"), "tsukuyomi") > 0,
			"tsukuyomi during blood moon"
		)
		T.eq(weightOf(Roll.mutationTable("blood_moon"), "akatsuki"), 0, "other events stay out")
	end,

	["zones switch at their start distance"] = function()
		local second = Catalog.zones[2]
		T.eq(Catalog.zoneAt(0).id, Catalog.zones[1].id)
		T.eq(Catalog.zoneAt(second.startsAt - 0.1).id, Catalog.zones[1].id)
		T.eq(Catalog.zoneAt(second.startsAt).id, second.id)
		T.eq(Catalog.zoneAt(1e9).id, Catalog.zones[#Catalog.zones].id)
	end,

	["a zone drops its own rank and, rarely, the next one up"] = function()
		local zone = Catalog.zones[1]
		local odds = Roll.rankTable(zone, zone.startsAt)
		T.eq(#odds, 2)
		T.eq(odds[1].id, zone.rank)
		T.eq(odds[2].id, Catalog.zones[2].rank)
		T.near(odds[2].weight, Tuning.Zones.nextRankAtStart, EPS)
	end,

	["the next rank gets likelier towards the far end of a zone"] = function()
		local zone = Catalog.zones[2]
		local finish = Catalog.zoneEnd(zone)
		local middle = (zone.startsAt + finish) / 2
		T.near(Roll.nextRankChance(zone, zone.startsAt), Tuning.Zones.nextRankAtStart, EPS)
		T.near(Roll.nextRankChance(zone, finish), Tuning.Zones.nextRankAtEnd, EPS)
		T.ok(
			Roll.nextRankChance(zone, middle) > Roll.nextRankChance(zone, zone.startsAt),
			"farther into the zone, better odds"
		)
		T.ok(Tuning.Zones.nextRankAtEnd <= 0.25, "the next rank must stay a rare treat")
	end,

	["a zone never drops a rank below its own"] = function()
		local rng = T.rng(42)
		for _, zone in Catalog.zones do
			local own = Catalog.rankOrder[zone.rank]
			local finish = Catalog.zoneEnd(zone)
			for _ = 1, 500 do
				local distance = zone.startsAt + rng() * (finish - zone.startsAt) * 0.999
				local drop = Roll.drop(distance, 1, 1, nil, rng)
				T.eq(drop.zone, zone.id)
				T.ok(
					Catalog.rankOrder[drop.rank] >= own,
					`{zone.id} dropped {drop.rank}, below its own {zone.rank}`
				)
				T.ok(
					Catalog.rankOrder[drop.rank] <= own + 1,
					`{zone.id} dropped {drop.rank}, two ranks above its own`
				)
			end
		end
	end,

	["depth in the last zone pays in mutation luck, and only there"] = function()
		local last = Catalog.zones[#Catalog.zones]
		local finish = Catalog.zoneEnd(last)
		T.near(Roll.depthMutationLuck(last, last.startsAt), 1, EPS, "nothing on the near edge")
		T.near(Roll.depthMutationLuck(last, finish), Tuning.Zones.deepMutationLuck, EPS)
		T.near(
			Roll.depthMutationLuck(last, (last.startsAt + finish) / 2),
			(1 + Tuning.Zones.deepMutationLuck) / 2,
			EPS,
			"halfway in"
		)
		T.ok(Tuning.Zones.deepMutationLuck > 1, "depth must be worth something")
		for i = 1, #Catalog.zones - 1 do
			local zone = Catalog.zones[i]
			T.eq(Roll.depthMutationLuck(zone, Catalog.zoneEnd(zone)), 1, zone.id)
		end
	end,

	["deep throws into the last zone mutate more often"] = function()
		local last = Catalog.zones[#Catalog.zones]
		local function mutated(distance: number): number
			local rng = T.rng(11)
			local count = 0
			for _ = 1, 4000 do
				if Roll.drop(distance, 1, 1, nil, rng).mutation ~= Catalog.NONE then
					count += 1
				end
			end
			return count
		end
		local near = mutated(last.startsAt)
		local far = mutated(Catalog.zoneEnd(last) - 0.01)
		T.ok(far > near * 1.4, `{far} mutations deep against {near} on the near edge`)
	end,

	["the last zone drops only its own rank"] = function()
		local last = Catalog.zones[#Catalog.zones]
		local odds = Roll.rankTable(last, last.startsAt + 1)
		T.eq(#odds, 1)
		T.eq(odds[1].id, last.rank)
	end,

	["rank frequencies follow the odds"] = function()
		local rng = T.rng(42)
		local zone = Catalog.zones[1]
		local finish = Catalog.zoneEnd(zone)
		local odds = Roll.withLuck(Roll.rankTable(zone, finish), 1)
		local n, own = 20000, 0
		for _ = 1, n do
			if Roll.pick(odds, rng()) == zone.rank then
				own += 1
			end
		end
		T.near(own / n, 1 - Tuning.Zones.nextRankAtEnd, 0.01, "share of the zone's own rank")
	end,

	["every character of a rank can be rolled"] = function()
		local pool = Catalog.charactersByRank.D
		local seen: { [string]: boolean } = {}
		for i = 0, 999 do
			seen[Roll.character("D", i / 1000)] = true
		end
		for _, c in pool do
			T.ok(seen[c.id], `{c.id} is never rolled`)
		end
	end,

	["drops only contain ids from the catalog"] = function()
		local rng = T.rng(7)
		for _ = 1, 2000 do
			local drop = Roll.drop(rng() * 1500, 3, 3, nil, rng)
			T.ok(Catalog.characterById[drop.character] ~= nil, `unknown character {drop.character}`)
			T.eq(Catalog.characterById[drop.character].rank, drop.rank, "character matches rank")
			T.ok(
				drop.mutation == Catalog.NONE or Catalog.mutationById[drop.mutation] ~= nil,
				`unknown mutation {drop.mutation}`
			)
		end
	end,
}
