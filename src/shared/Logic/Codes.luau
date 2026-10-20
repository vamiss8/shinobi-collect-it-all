--!strict
-- Promo codes, the rules (owner, 2026-10-20: "add promo codes as a working thing; I will put
-- them up in the Discord, so that those who join get a bonus"). The codes themselves are kept
-- on the server alone (server/Codes): this is how one is typed, looked up and told apart.
--
-- A code is written in capitals. What a player types is put in capitals and stripped of
-- spaces before it is looked up, so "hidden leaf" finds HIDDENLEAF. Each code is redeemed
-- once a player; one may have a last day ("YYYY-MM-DD", UTC, through the whole of that day).

local Codes = {}

-- What a code gives: Herbs, minutes of the dojo's income in Ryo (Logic/Daily.ryo, as the daily
-- rewards: at least so much a minute for a dojo that earns little), potions into the pouch of
-- the kind bought for Herbs and premium ones, by potion id (Config/Potions); and its last day.
export type Code = {
	herbs: number?,
	ryoMinutes: number?,
	potions: { string }?,
	premium: { string }?,
	ends: string?,
}

-- What a redemption came to: "ok", "unknown" (no such code), "used" (this player has had
-- it), "ended" (past its last day), "empty" (nothing typed).
export type Outcome = "ok" | "unknown" | "used" | "ended" | "empty"

-- The longest a typed code may be; anything longer is no code.
Codes.LONGEST = 30

-- What a player typed, as codes are written: capitals, no spaces. Letters and digits only
-- are kept, so a code pasted with a stray mark around it still counts.
function Codes.normalize(typed: string): string
	local kept = string.gsub(string.upper(typed), "[^%w]", "")
	return string.sub(kept, 1, Codes.LONGEST)
end

-- The moment a code stops working (seconds since 1970, UTC): the end of its last day; nil for
-- one with none, or with a day that cannot be read (which then never ends, rather than
-- never working).
function Codes.endsAt(code: Code): number?
	local day = code.ends
	if not day then
		return nil
	end
	local year, month, date = string.match(day, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
	if not year then
		return nil
	end
	-- Days since 1970 by the civil calendar (Howard Hinnant's days_from_civil).
	local y = tonumber(year) :: number
	local m = tonumber(month) :: number
	local d = tonumber(date) :: number
	if m < 1 or m > 12 or d < 1 or d > 31 then
		return nil
	end
	y -= if m <= 2 then 1 else 0
	local era = (if y >= 0 then y else y - 399) // 400
	local yearOfEra = y - era * 400
	local dayOfYear = (153 * (m + (if m > 2 then -3 else 9)) + 2) // 5 + d - 1
	local dayOfEra = yearOfEra * 365 + yearOfEra // 4 - yearOfEra // 100 + dayOfYear
	local days = era * 146097 + dayOfEra - 719468
	return (days + 1) * 86400
end

-- Whether `typed` redeems a code of `codes` for a player who has had those in `used`, at
-- `now`; and the code's name and what it gives, when it does.
function Codes.check(
	codes: { [string]: Code },
	used: { [string]: boolean },
	typed: string,
	now: number
): (Outcome, string, Code?)
	local name = Codes.normalize(typed)
	if name == "" then
		return "empty", name, nil
	end
	local code = codes[name]
	if not code then
		return "unknown", name, nil
	end
	if used[name] then
		return "used", name, nil
	end
	local ends = Codes.endsAt(code)
	if ends and now >= ends then
		return "ended", name, nil
	end
	return "ok", name, code
end

return Codes
