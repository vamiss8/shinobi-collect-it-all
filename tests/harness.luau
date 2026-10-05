--!strict
-- Assertion helpers and a seeded RNG for specs.

local T = {}

function T.eq(actual: any, expected: any, label: string?)
	if actual ~= expected then
		local what = label or "values differ"
		error(`{what}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function T.near(actual: number, expected: number, eps: number, label: string?)
	if math.abs(actual - expected) > eps then
		local what = label or "values differ"
		error(`{what}: expected {expected} +-{eps}, got {actual}`, 2)
	end
end

function T.ok(condition: any, label: string)
	if not condition then
		error(label, 2)
	end
end

-- Deterministic RNG (32-bit LCG) so statistical specs never flake.
-- Products stay below 2^53, so the arithmetic is exact in doubles.
function T.rng(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1664525 + 1013904223) % 4294967296
		return state / 4294967296
	end
end

return T
