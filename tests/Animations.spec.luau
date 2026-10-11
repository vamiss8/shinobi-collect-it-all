--!strict
local Animations = require("../src/shared/Config/Animations")
local T = require("./harness")

-- The config is shared with other specs. Restore it even when an assertion fails so
-- a test of the future published clip cannot change another suite's defaults.
local function withThrow(id: string, check: () -> ())
	local saved = Animations.player.Throw
	Animations.player.Throw = id
	local ok, err = pcall(check)
	Animations.player.Throw = saved
	if not ok then
		error(err, 0)
	end
end

return {
	["player clips have all six named string ids"] = function()
		local names = {
			"Throw",
			"MeditateStart",
			"MeditateLoop",
			"MeditateEnd",
			"ChakraLoop",
			"ChakraHit",
		}
		for _, name in names do
			T.eq(type((Animations.player :: { [string]: string })[name]), "string", name)
		end
		local count = 0
		for _ in Animations.player do
			count += 1
		end
		T.eq(count, #names)
		withThrow("", function()
			T.eq(Animations.hasThrow(), false)
			T.eq(Animations.throwDelay(), 0)
		end)
	end,

	["an empty clip has no asset"] = function()
		T.eq(Animations.asset(""), nil)
	end,

	["numeric ids and full asset ids refer to the same clip"] = function()
		T.eq(Animations.asset("123"), "rbxassetid://123")
		T.eq(Animations.asset("rbxassetid://123"), "rbxassetid://123")
	end,

	["a configured throw delays release until its marker"] = function()
		withThrow("123", function()
			T.eq(Animations.hasThrow(), true)
			T.eq(Animations.THROW_RELEASE, 0.75)
			T.eq(Animations.throwDelay(), 0.75)
		end)
		withThrow("rbxassetid://123", function()
			T.eq(Animations.hasThrow(), true)
			T.eq(Animations.throwDelay(), Animations.THROW_RELEASE)
		end)
	end,

	["removing the throw restores immediate release"] = function()
		withThrow("123", function()
			T.eq(Animations.throwDelay(), Animations.THROW_RELEASE)
			Animations.player.Throw = ""
			T.eq(Animations.hasThrow(), false)
			T.eq(Animations.throwDelay(), 0)
		end)
	end,
}
