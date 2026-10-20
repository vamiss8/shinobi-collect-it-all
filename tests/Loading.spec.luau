--!strict
-- The loading screen (src/first): its words in every language, and the names it hears the
-- client by, which it writes out itself because it runs before the game's Net has come.
local Languages = require("../src/shared/Config/Languages")
local Net = require("../src/shared/Net")
local T = require("./harness")
local Words = require("../src/first/Words")

return {
	["every language says every stage and as many tips as English"] = function()
		local english = Words.en
		T.ok(english ~= nil, "English is there")
		for _, language in Languages.list do
			local pack = Words[language.code]
			T.ok(pack ~= nil, `{language.code} has the loading screen's words`)
			if pack then
				T.eq(#pack.stages, #english.stages, `{language.code}: stages`)
				T.eq(#pack.tips, #english.tips, `{language.code}: tips`)
				T.ok(pack.tip ~= "" and pack.skip ~= "", `{language.code}: tip and skip`)
				for index, tip in pack.tips do
					local opened = select(2, string.gsub(tip, "{%a|", ""))
					local closed = select(2, string.gsub(tip, "}", ""))
					T.eq(opened, closed, `{language.code} tip {index}: every mark is closed`)
					local seen = string.gsub(string.gsub(tip, "{%a|", ""), "}", "")
					T.ok(
						(utf8.len(seen) or #seen) <= 115,
						`{language.code} tip {index} is short enough for two lines`
					)
				end
			end
		end
	end,

	["the screen hears the client by the names Net gives them"] = function()
		local fs = require("@lune/fs")
		local source = fs.readFile("src/first/init.client.luau")
		T.ok(
			string.find(source, `"{Net.LOADING_ATTRIBUTE}"`, 1, true) ~= nil,
			"the screen waits on Net.LOADING_ATTRIBUTE"
		)
		T.ok(
			string.find(source, `"{Net.LOADING_LANGUAGE_ATTRIBUTE}"`, 1, true) ~= nil,
			"the screen listens for Net.LOADING_LANGUAGE_ATTRIBUTE"
		)
	end,
}
