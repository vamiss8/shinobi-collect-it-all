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

-- What a typed suffix multiplies by: the ones Format.short writes, in any case, and the
-- Russian ones, since half the players type on that keyboard.
local MULTIPLIERS: { [string]: number } = {}
for index, suffix in SUFFIXES do
	MULTIPLIERS[string.lower(suffix)] = 1000 ^ (index - 1)
end
local RUSSIAN: { [string]: number } = {
	["к"] = 1,
	["К"] = 1,
	["тыс"] = 1,
	["м"] = 2,
	["М"] = 2,
	["млн"] = 2,
	["б"] = 3,
	["Б"] = 3,
	["млрд"] = 3,
	["т"] = 4,
	["Т"] = 4,
	["трлн"] = 4,
}
for word, power in RUSSIAN do
	MULTIPLIERS[word] = 1000 ^ power
end

-- Reads a number the way a player types one: "3000", "3 000", "3,000", "1.5" or "1,5", and
-- with a suffix as Format.short writes it, "3k", "1.5M", "2Qa", or in Russian, "3к",
-- "1,5 млн". Returns nil for anything that is not a number of that kind.
function Format.parse(text: string): number?
	local cleaned = string.gsub(text, "[%s_']", "")
	local digits: string?, rest: string? = string.match(cleaned, "^([%d%.,]+)(.*)$")
	if not digits then
		return nil
	end
	local suffix = rest or ""

	if string.find(digits, ",", 1, true) then
		-- Commas between groups of three digits separate thousands; a lone comma before
		-- anything else is a decimal one. With a point in the number they can only be the first.
		local groups = string.split(digits, ",")
		local thousands = #groups[1] >= 1 and #groups[1] <= 3
		for i = 2, #groups do
			local whole = string.match(groups[i], "^%d+") or ""
			thousands = thousands and #whole == 3
		end
		if thousands or string.find(digits, ".", 1, true) then
			digits = string.gsub(digits, ",", "")
		elseif #groups == 2 then
			digits = groups[1] .. "." .. groups[2]
		else
			return nil
		end
	end

	local value = tonumber(digits)
	local multiplier = MULTIPLIERS[string.lower(suffix)] or MULTIPLIERS[suffix]
	if not value or not multiplier then
		return nil
	end
	local result = value * multiplier
	-- NaN is the one number that is not equal to itself.
	if result ~= result or result == math.huge then
		return nil
	end
	return result
end

-- A length of time by its two largest units, leaving out a second one that is zero:
-- 42 -> "42s", 300 -> "5m", 11520 -> "3h 12m", 187200 -> "2d 4h", 259200 -> "3d".
function Format.duration(seconds: number): string
	local whole = math.max(math.floor(seconds), 0)
	local days, hours, minutes = whole // 86400, whole % 86400 // 3600, whole % 3600 // 60
	if days > 0 then
		return if hours > 0 then `{days}d {hours}h` else `{days}d`
	elseif hours > 0 then
		return if minutes > 0 then `{hours}h {minutes}m` else `{hours}h`
	elseif minutes > 0 then
		return `{minutes}m`
	end
	return `{whole}s`
end

return Format
