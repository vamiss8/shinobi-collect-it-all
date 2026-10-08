--!strict
-- The lettering of mutations' and ranks' names (Config/Lettering): which of them have one, and
-- that it can be read.
local Catalog = require("../src/shared/Config/Catalog")
local Lettering = require("../src/shared/Config/Lettering")
local T = require("./harness")

-- The ones the owner said to leave as they are.
local PLAIN = { chakra = true, kurama = true }

local function isHex(color: string): boolean
	return string.match(color, "^#%x%x%x%x%x%x$") ~= nil
end

-- How bright a hex color is, 0..1.
local function brightness(color: string): number
	local r = tonumber(string.sub(color, 2, 3), 16) :: number
	local g = tonumber(string.sub(color, 4, 5), 16) :: number
	local b = tonumber(string.sub(color, 6, 7), 16) :: number
	return (0.299 * r + 0.587 * g + 0.114 * b) / 255
end

return {
	["every mutation past Kurama is lettered, and Chakra and Kurama are left alone"] = function()
		for _, mutation in Catalog.mutations do
			local key = Lettering.key("mutation", mutation.id)
			if PLAIN[mutation.id] then
				T.eq(key, nil, `{mutation.name} was to be left as it is`)
			else
				T.ok(key ~= nil, `{mutation.name} is written in a plain color`)
				T.ok(Lettering.style(key :: string) ~= nil, `{mutation.name}'s key leads nowhere`)
			end
		end
	end,

	["the two highest ranks are lettered, the last not in plain white"] = function()
		local ranks = Catalog.ranks
		for index, rank in ranks do
			local key = Lettering.key("rank", rank.id)
			if index >= #ranks - 1 then
				T.ok(key ~= nil, `{rank.name} is written in a plain color`)
			end
		end
		local last = Lettering.style(Lettering.key("rank", ranks[#ranks].id) :: string)
		local colored = false
		for _, color in (last :: Lettering.Style).fill do
			colored = colored or string.upper(color) ~= "#FFFFFF"
		end
		T.ok(colored, "the last rank is all white")
	end,

	["the legendary shinobi's rank is lettered"] = function()
		local key = Lettering.key("rank", Catalog.legendRank.id)
		T.ok(key ~= nil and Lettering.style(key) ~= nil, "Legendary is written in a plain color")
	end,

	["a lettering is of several colors, legible on its outline, and comes round"] = function()
		for _, styles in { Lettering.mutations, Lettering.ranks, Lettering.titles } do
			for id, style in styles do
				T.ok(#style.fill >= 3, `{id} is of {#style.fill} colors`)
				T.ok(
					style.period >= 1.5 and style.period <= 6,
					`{id} comes round in {style.period} s`
				)
				T.ok(isHex(style.edge) and isHex(style.flare), `{id}: a color is not a color`)
				T.ok(style.shade == nil or isHex(style.shade), `{id}: its shade is not a color`)
				-- Only letters with an aura have anything rise off them.
				T.ok(style.shade == nil or style.motion == "aura", `{id}: a shade and no aura`)
				local light = 0
				for _, color in style.fill do
					T.ok(isHex(color), `{id}: {color} is not a color`)
					light += brightness(color) / #style.fill
				end
				-- Light letters on a dark outline: read on a dark card and against the sky.
				T.ok(light >= 0.4, `{id}'s letters are too dark to read on a card`)
				T.ok(brightness(style.edge) <= 0.3, `{id}'s outline is not dark`)
				T.ok(
					light - brightness(style.edge) >= 0.35,
					`{id}'s letters run into their outline`
				)
			end
		end
	end,

	["a key that nobody gave out is no lettering"] = function()
		T.eq(Lettering.style("mutation:nothing"), nil)
		T.eq(Lettering.style("rank"), nil)
		T.eq(Lettering.style(""), nil)
		T.eq(Lettering.key("rank", "D"), nil)
	end,
}
