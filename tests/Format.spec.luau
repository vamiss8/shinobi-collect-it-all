--!strict
local Format = require("../src/shared/Logic/Format")
local T = require("./harness")

return {
	["small numbers keep up to two decimals"] = function()
		T.eq(Format.short(0), "0")
		T.eq(Format.short(8), "8")
		T.eq(Format.short(1.25), "1.25")
		T.eq(Format.short(1.5), "1.5")
		T.eq(Format.short(83.333), "83.33")
		T.eq(Format.short(999), "999")
	end,

	["large numbers get a suffix and up to two decimals"] = function()
		T.eq(Format.short(1000), "1K")
		T.eq(Format.short(1250), "1.25K")
		T.eq(Format.short(12345), "12.34K")
		T.eq(Format.short(123456), "123.45K")
		T.eq(Format.short(1500000), "1.5M")
		T.eq(Format.short(657.5e9), "657.5B")
		T.eq(Format.short(89.33e15), "89.33Qa")
	end,

	["values are truncated, never rounded up"] = function()
		T.eq(Format.short(1999), "1.99K")
		T.eq(Format.short(999999), "999.99K")
		T.eq(Format.short(7.999), "7.99")
	end,

	["float error does not shave a cent off"] = function()
		T.eq(Format.short(1.15), "1.15")
		T.eq(Format.short(0.07), "0.07")
	end,

	["numbers past the last suffix stay readable"] = function()
		T.eq(Format.short(1e51), "1000Qid")
	end,

	["a length of time shows its two largest units"] = function()
		T.eq(Format.duration(0), "0s")
		T.eq(Format.duration(42), "42s")
		T.eq(Format.duration(60), "1m")
		T.eq(Format.duration(359), "5m", "seconds are dropped once there are minutes")
		T.eq(Format.duration(3600), "1h", "a zero second unit is left out")
		T.eq(Format.duration(11520), "3h 12m")
		T.eq(Format.duration(86400), "1d")
		T.eq(Format.duration(187200), "2d 4h")
		T.eq(Format.duration(72 * 3600), "3d")
		T.eq(Format.duration(-5), "0s", "clock skew")
		T.eq(Format.duration(90.9), "1m", "fractions of a second do not count")
	end,

	["a typed number is read with or without a suffix"] = function()
		T.eq(Format.parse("3000"), 3000)
		T.eq(Format.parse(" 3 000 "), 3000, "spaces")
		T.eq(Format.parse("1.5"), 1.5)
		T.eq(Format.parse("3k"), 3000)
		T.eq(Format.parse("3K"), 3000)
		T.eq(Format.parse("1.55K"), 1550)
		T.eq(Format.parse("1.5 M"), 1500000)
		T.eq(Format.parse("8m"), 8000000)
		T.eq(Format.parse("2b"), 2e9)
		T.eq(Format.parse("2qa"), 2e15)
		T.eq(Format.parse("2QA"), 2e15)
	end,

	["commas are thousands between groups of three, a decimal mark otherwise"] = function()
		T.eq(Format.parse("3,000"), 3000)
		T.eq(Format.parse("12,345,678"), 12345678)
		T.eq(Format.parse("1,5"), 1.5)
		T.eq(Format.parse("1,5k"), 1500)
		T.eq(Format.parse("1,234.5"), 1234.5)
		T.eq(Format.parse("1,2,3"), nil)
	end,

	["Russian suffixes are read too"] = function()
		T.eq(Format.parse("3к"), 3000)
		T.eq(Format.parse("3К"), 3000)
		T.eq(Format.parse("1,5 млн"), 1500000)
		T.eq(Format.parse("2 млрд"), 2e9)
		T.eq(Format.parse("7 тыс"), 7000)
	end,

	["what is not a number is turned down"] = function()
		T.eq(Format.parse(""), nil)
		T.eq(Format.parse("abc"), nil)
		T.eq(Format.parse("k"), nil)
		T.eq(Format.parse("3x"), nil)
		T.eq(Format.parse("1.2.3"), nil)
		T.eq(Format.parse("-5"), nil, "there is no negative Chakra to throw")
		T.eq(Format.parse("3k5"), nil)
	end,

	["what Format.short writes can be read back"] = function()
		for _, n in { 8, 999, 1000, 1250, 1500000, 657.5e9, 89.33e15 } do
			T.near(Format.parse(Format.short(n)) :: number, n, n * 1e-9)
		end
	end,

	["negative numbers keep their sign"] = function()
		T.eq(Format.short(-1500), "-1.5K")
	end,
}
