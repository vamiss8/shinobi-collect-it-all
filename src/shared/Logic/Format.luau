--!strict
-- Number formatting for the UI.

local Format = {}

local SUFFIXES = {
	"",
	"K",
	"M",
	"B",
	"T",
	"Qa",
	"Qi",
	"Sx",
	"Sp",
	"Oc",
	"No",
	"Dc",
	"Ud",
	"Dd",
	"Td",
	"Qad",
	"Qid",
}

-- 8 -> "8", 1.25 -> "1.25", 1250 -> "1.25K", 657500000000 -> "657.5B". Up to two decimals,
-- with trailing zeros dropped. Values are truncated rather than rounded, so a price is never
-- shown as affordable a moment too early.
function Format.short(n: number): string
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)

	local tier = 0
	if n >= 1000 then
		tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	end
	local value = n / 1000 ^ tier
	-- log10 can land a hair under a whole number (999999.9999 -> tier 1, value 1000).
	if value >= 1000 and tier < #SUFFIXES - 1 then
		tier += 1
		value /= 1000
	end

	-- The tiny nudge keeps 1.15 from becoming 1.14 through float error.
	local text = string.format("%.2f", math.floor(value * 100 + 1e-6) / 100)
	-- "1.50" -> "1.5", "2.00" -> "2"
	text = (string.gsub(text, "0+$", ""))
	text = (string.gsub(text, "%.$", ""))
	return sign .. text .. SUFFIXES[tier + 1]
end

return Format
