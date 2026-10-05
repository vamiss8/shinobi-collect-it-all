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

	["negative numbers keep their sign"] = function()
		T.eq(Format.short(-1500), "-1.5K")
	end,
}
