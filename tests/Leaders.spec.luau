--!strict
-- The leaderboards' keeping (Logic/Leaders): what is kept orders as the value does, comes back
-- as the value, and the board leaves off whom it is to.
local Leaders = require("../src/shared/Logic/Leaders")
local T = require("./harness")

return {
	["what is kept orders as the value and comes back as it"] = function()
		local values = { 0.5, 1, 9, 10, 999, 1e6, 1.5e9, 4e18, 2.5e30 }
		local last = -1
		for _, value in values do
			local kept = Leaders.encode(value)
			T.ok(kept > last, `{value} is kept below a smaller value`)
			T.ok(kept == math.floor(kept) and kept < 2 ^ 53, `{value} is kept as no whole number`)
			T.ok(
				math.abs(Leaders.decode(kept) - value) <= value * 1e-9,
				`{value} comes back changed`
			)
			last = kept
		end
		T.eq(Leaders.encode(0), 0)
		T.eq(Leaders.encode(-5), 0)
		T.eq(Leaders.encode(0 / 0), 0)
		T.ok(Leaders.encode(math.huge) > 0, "an endless value is kept as the largest")
		T.eq(Leaders.decode(0), 0)
	end,

	["a board leaves off the owner and what is not a player"] = function()
		local entries = {
			{ key = "2893192350", value = Leaders.encode(1e20) },
			{ key = "11", value = Leaders.encode(500) },
			{ key = "not a player", value = Leaders.encode(400) },
			{ key = "12", value = 0 },
			{ key = "13", value = Leaders.encode(300) },
			{ key = "14", value = Leaders.encode(200) },
		}
		local shown = Leaders.ranked(entries, { [2893192350] = true }, 2)
		T.eq(#shown, 2)
		T.eq(shown[1].userId, 11)
		T.eq(shown[2].userId, 13)
		T.ok(math.abs(shown[1].value - 500) < 1e-6, "the value comes back")
	end,
}
