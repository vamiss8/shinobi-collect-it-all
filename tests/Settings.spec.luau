--!strict
-- A player's settings (Logic/Settings): the language they are given, and what of a change a
-- client sends is kept.
local Format = require("../src/shared/Logic/Format")
local Languages = require("../src/shared/Config/Languages")
local Settings = require("../src/shared/Logic/Settings")
local T = require("./harness")

return {
	["a chosen language is kept, whatever the player's Roblox is in"] = function()
		T.eq(Settings.language("ru", "pt-br", "BR"), "ru")
		T.eq(Settings.language("en", "ru-ru", "RU"), "en")
	end,

	["with none chosen, the language of the player's Roblox"] = function()
		T.eq(Settings.language(Languages.AUTO, "pt-br", "US"), "pt")
		T.eq(Settings.language(nil, "ru-ru", nil), "ru")
		T.eq(Settings.language(nil, "es-es", "BR"), "es", "the locale goes before the country")
		T.eq(Settings.language(nil, "fr-ca", nil), "fr")
		T.eq(Settings.language(nil, "de-de", nil), "de")
	end,

	-- The owner's word: a player from Brazil is given Portuguese at once.
	["a player whose Roblox is in English is given their country's language"] = function()
		T.eq(Settings.language(nil, "en-us", "BR"), "pt")
		T.eq(Settings.language(nil, "en-us", "mx"), "es", "the country is read in any case")
		T.eq(Settings.language(nil, "en-us", "RU"), "ru")
		T.eq(Settings.language(nil, "en-us", "US"), "en")
		T.eq(Settings.language(nil, "en-us", nil), "en")
		T.eq(Settings.language(nil, "ja-jp", "JP"), "en", "a language the game has not is English")
		T.eq(Settings.language("klingon", "en-us", "BR"), "pt", "an unknown choice is no choice")
	end,

	["what a client sends is kept only as far as it may be"] = function()
		local now = Settings.defaults()
		local kept =
			Settings.clean({ language = "fr", font = "plain", music = 0.33, effects = 2 }, now)
		T.eq(kept.language, "fr")
		T.eq(kept.font, "plain")
		T.near(kept.music, 0.3, 1e-9, "volumes go in tenths")
		T.eq(kept.effects, 1, "a volume past the top")
		local bad =
			Settings.clean({ language = "xx", font = "comic", music = "loud", effects = -1 }, now)
		T.eq(bad.language, now.language)
		T.eq(bad.font, now.font)
		T.eq(bad.music, now.music)
		T.eq(bad.effects, 0)
		T.eq(Settings.clean("nonsense", now).language, now.language)
		T.eq(Settings.clean({ language = Languages.AUTO }, kept).language, Languages.AUTO)
	end,

	["every language has a pack of words, and names itself"] = function()
		local fs = require("@lune/fs")
		local strings = fs.readFile("src/client/Strings.luau")
		for _, language in Languages.list do
			T.ok(fs.isFile(`src/client/Lang/{language.code}.luau`), `{language.code} has no pack`)
			T.ok(language.name ~= "", `{language.code} has no name`)
			if language.code ~= Languages.DEFAULT then
				T.ok(
					string.find(
						strings,
						`{language.code} = require("./Lang/{language.code}")`,
						1,
						true
					) ~= nil,
					`Strings does not load {language.code}`
				)
			end
		end
	end,

	["capitals are made for every letter the languages use"] = function()
		T.eq(Format.upper("rinnegan"), "RINNEGAN")
		T.eq(Format.upper("Luna Carmesí"), "LUNA CARMESÍ")
		T.eq(Format.upper("Багровая луна, ёж"), "БАГРОВАЯ ЛУНА, ЁЖ")
		T.eq(Format.upper("élève · œuvre"), "ÉLÈVE · ŒUVRE")
		T.eq(Format.upper("Tor der Öffnung, ß"), "TOR DER ÖFFNUNG, ß")
		T.eq(Format.upper("x2 · 1.5K"), "X2 · 1.5K")
	end,
}
