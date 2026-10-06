--!strict
-- Keeps saves in step with the roster. When a character leaves it for good, another takes its
-- place (Config/Replaced), and a save that still names the old one is rewritten on load.

local Catalog = require("../Config/Catalog")
local Economy = require("./Economy")
local Index = require("./Index")

local Roster = {}

-- A replacement may itself be replaced later; nothing sane chains further than this.
local LONGEST_CHAIN = 16

-- The id a character goes by now: whoever took its place if it has left the roster, itself
-- otherwise.
function Roster.current(character: string): string
	for _ = 1, LONGEST_CHAIN do
		local successor = Catalog.replaced[character]
		if not successor then
			break
		end
		character = successor
	end
	return character
end

-- Turns every replaced character in a save into its replacement: the units, and the Bingo
-- Book, where whatever was found for the old one counts for the new. Changes both tables in
-- place and returns how many units and book entries it rewrote; 0 for a save already in step.
function Roster.migrate(units: { [string]: Economy.Unit }, found: Index.Found): number
	local changed = 0
	for _, unit in units do
		local now = Roster.current(unit.character)
		if now ~= unit.character then
			unit.character = now
			changed += 1
		end
	end

	-- Collected first: a table must not gain keys while it is being walked.
	local gone: { string } = {}
	for character in found do
		if Roster.current(character) ~= character then
			table.insert(gone, character)
		end
	end
	for _, character in gone do
		local now = Roster.current(character)
		local kept = found[now]
		if not kept then
			kept = {}
			found[now] = kept
		end
		for mutation, has in found[character] do
			if has then
				kept[mutation] = true
			end
		end
		found[character] = nil
		changed += 1
	end
	return changed
end

return Roster
