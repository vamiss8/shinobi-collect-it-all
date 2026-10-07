--!strict
local Catalog = require("../src/shared/Config/Catalog")
local Chase = require("../src/shared/Logic/Chase")
local Economy = require("../src/shared/Logic/Economy")
local SpeedStages = require("../src/shared/Config/SpeedStages")
local T = require("./harness")
local Tuning = require("../src/shared/Config/Tuning")

local stages = SpeedStages.list

-- Everything a stage may put on a runner (Services/SpeedLook knows how each looks).
local WEARS = {
	"dust",
	"warmers",
	"weights",
	"heavy",
	"wrists",
	"steam",
	"trail",
	"motes",
	"flame",
	"sparks",
	"streaks",
	"fan",
	"burst",
	"embers",
}

-- What a stage wears, as one word to compare two stages by.
local function look(stage: SpeedStages.Stage): string
	local list = table.clone(stage.wears)
	table.sort(list)
	return table.concat(list, "+")
end

return {
	["stages start at the first level and climb"] = function()
		T.eq(stages[1].level, 0, "a new player has a stage")
		for i = 2, #stages do
			T.ok(stages[i].level > stages[i - 1].level, `stage {i} comes after stage {i - 1}`)
			T.ok(stages[i].level <= Tuning.Speed.maxLevel, `stage {i} can be reached`)
		end
	end,

	["the eight Gates come in order and the last is the top level"] = function()
		local gates = 0
		for _, stage in stages do
			if stage.gate > 0 then
				gates += 1
				T.eq(stage.gate, gates, `{stage.name} is Gate {gates}`)
			else
				T.eq(gates, 0, `{stage.name} comes before the Gates`)
			end
		end
		T.eq(gates, SpeedStages.GATES)
		T.eq(gates, 8)
		T.eq(stages[#stages].level, Tuning.Speed.maxLevel, "the Gate of Death is the top level")
	end,

	["every level has the stage it has reached"] = function()
		for level = 0, Tuning.Speed.maxLevel do
			local stage, index = SpeedStages.at(level)
			T.eq(stages[index], stage)
			T.ok(stage.level <= level, `level {level} has reached its stage`)
			local following = SpeedStages.after(level)
			T.ok(following == nil or following.level > level, `level {level} is short of the next`)
		end
		T.eq(SpeedStages.after(Tuning.Speed.maxLevel), nil, "nothing after the last Gate")
	end,

	["every stage has a color"] = function()
		for _, stage in stages do
			T.ok(string.match(stage.color, "^#%x%x%x%x%x%x$") ~= nil, `{stage.name} color`)
		end
	end,

	-- The owner on the first table of stages, where five Gates in a row read "the same": fill
	-- them with something. A stage a player has paid four levels for must show.
	["no two stages look alike, and each shows something the one before did not"] = function()
		T.eq(#stages[1].wears, 0, "a beginner shows nothing")
		local seen: { [string]: string } = {}
		for i, stage in stages do
			for _, wear in stage.wears do
				T.ok(table.find(WEARS, wear) ~= nil, `{stage.name} wears an unknown {wear}`)
			end
			local shows = look(stage)
			T.ok(seen[shows] == nil, `{stage.name} looks like {seen[shows]}`)
			seen[shows] = stage.name
			if i > 1 then
				local new = false
				for _, wear in stage.wears do
					if not SpeedStages.wears(stages[i - 1], wear :: any) then
						new = true
					end
				end
				T.ok(new, `{stage.name} shows nothing that {stages[i - 1].name} did not`)
			end
		end
	end,

	["the weights come off when the first Gate opens"] = function()
		for _, stage in stages do
			local strapped = SpeedStages.wears(stage, "weights")
				or SpeedStages.wears(stage, "wrists")
			if stage.gate > 0 then
				T.ok(not strapped, `{stage.name} still carries weights`)
				T.ok(SpeedStages.wears(stage, "steam"), `{stage.name} gives off no steam`)
				T.ok(SpeedStages.wears(stage, "trail"), `{stage.name} leaves no trail`)
			else
				T.ok(not SpeedStages.wears(stage, "steam"), `{stage.name} steams before any Gate`)
			end
		end
	end,

	["a new stage is never more than four levels away"] = function()
		for i = 2, #stages do
			local apart = stages[i].level - stages[i - 1].level
			T.ok(apart >= 2 and apart <= 4, `{stages[i].name} is {apart} levels on`)
		end
	end,

	-- A zone asks for about four more levels than the one before, and so does a stage: a
	-- runner who has just become fast enough for a zone has a stage to show for it.
	["every zone from the third on brings a new stage with the speed it asks for"] = function()
		local function levelFor(distance: number): number
			for level = 0, Tuning.Speed.maxLevel do
				if Chase.escapesFrom(Economy.walkSpeed(level), distance) then
					return level
				end
			end
			return Tuning.Speed.maxLevel
		end
		local previous = 0
		for i = 3, #Catalog.zones do
			local zone = Catalog.zones[i]
			local _, index = SpeedStages.at(levelFor(zone.startsAt) + 1)
			T.ok(index > previous, `{zone.id} is entered with the stage of the zone before`)
			previous = index
		end
	end,
}
