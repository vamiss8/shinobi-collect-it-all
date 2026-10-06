--!strict
-- Runs every spec under tests/. Usage: `lune run test`. Exits non-zero on any failure.

local process = require("@lune/process")

type Spec = { [string]: () -> () }

local specs: { [string]: Spec } = {
	Boosts = require("../tests/Boosts.spec"),
	Catalog = require("../tests/Catalog.spec"),
	Chase = require("../tests/Chase.spec"),
	Economy = require("../tests/Economy.spec"),
	Focus = require("../tests/Focus.spec"),
	Format = require("../tests/Format.spec"),
	Index = require("../tests/Index.spec"),
	Kick = require("../tests/Kick.spec"),
	Roll = require("../tests/Roll.spec"),
	Roster = require("../tests/Roster.spec"),
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
