--!strict
-- Runs every spec under tests/. Usage: `lune run test`. Exits non-zero on any failure.

local process = require("@lune/process")

type Spec = { [string]: () -> () }

local specs: { [string]: Spec } = {
	Achievements = require("../tests/Achievements.spec"),
	Guide = require("../tests/Guide.spec"),
	Animations = require("../tests/Animations.spec"),
	Aura = require("../tests/Aura.spec"),
	Boosts = require("../tests/Boosts.spec"),
	Catalog = require("../tests/Catalog.spec"),
	Codes = require("../tests/Codes.spec"),
	Chase = require("../tests/Chase.spec"),
	Corridor = require("../tests/Corridor.spec"),
	Crossing = require("../tests/Crossing.spec"),
	Daylight = require("../tests/Daylight.spec"),
	DojoHall = require("../tests/DojoHall.spec"),
	DojoPlan = require("../tests/DojoPlan.spec"),
	Economy = require("../tests/Economy.spec"),
	EnemyMotion = require("../tests/EnemyMotion.spec"),
	Events = require("../tests/Events.spec"),
	SkyLook = require("../tests/SkyLook.spec"),
	Footing = require("../tests/Footing.spec"),
	Lettering = require("../tests/Lettering.spec"),
	Focus = require("../tests/Focus.spec"),
	Format = require("../tests/Format.spec"),
	Index = require("../tests/Index.spec"),
	Kick = require("../tests/Kick.spec"),
	Leaders = require("../tests/Leaders.spec"),
	Listeners = require("../tests/Listeners.spec"),
	Loading = require("../tests/Loading.spec"),
	Market = require("../tests/Market.spec"),
	Plaza = require("../tests/Plaza.spec"),
	PlazaPlan = require("../tests/PlazaPlan.spec"),
	Pouch = require("../tests/Pouch.spec"),
	Purchases = require("../tests/Purchases.spec"),
	RankLook = require("../tests/RankLook.spec"),
	Rebirth = require("../tests/Rebirth.spec"),
	Roll = require("../tests/Roll.spec"),
	Roster = require("../tests/Roster.spec"),
	Saves = require("../tests/Saves.spec"),
	Settings = require("../tests/Settings.spec"),
	Sounds = require("../tests/Sounds.spec"),
	SpeedStages = require("../tests/SpeedStages.spec"),
	Strings = require("../tests/Strings.spec"),
	ThrowMoves = require("../tests/ThrowMoves.spec"),
	Words = require("../tests/Words.spec"),
	ZoneArt = require("../tests/ZoneArt.spec"),
	ZoneBuild = require("../tests/ZoneBuild.spec"),
}

local function sortedKeys<V>(t: { [string]: V }): { string }
	local keys = {}
	for key in t do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local passed, failed = 0, 0
for _, specName in sortedKeys(specs) do
	local cases = specs[specName]
	for _, caseName in sortedKeys(cases) do
		local ok, err = pcall(cases[caseName])
		if ok then
			passed += 1
		else
			failed += 1
			print(`FAIL  {specName}: {caseName}\n      {err}`)
		end
	end
end

print(`{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
