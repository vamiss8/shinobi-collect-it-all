--!strict
-- The languages the game is written in (client/Strings is English, client/Lang has the rest),
-- and how a player is given theirs (Logic/Language): the language their Roblox is set to, and
-- for a player whose Roblox is in English, the one of the country they play from (owner,
-- 2026-10-15: "a player from Brazil gets Portuguese at once"). A player can choose another in
-- the settings, and keeps it.
--
-- The brush (PermanentMarker) has the letters of every Latin language here, accents too, but
-- no Cyrillic: a language it cannot write names a face of its own, a Roblox font family (a
-- rbxasset://fonts/families/X.json path, or rbxassetid:// for one from the Creator Store), and
-- client Fonts puts that face on every word written in the brush.

export type Language = {
	code: string, -- as client/Lang knows it
	name: string, -- in itself, as the settings show it
	locales: { string }, -- language parts of Roblox locales (LocalizationService.RobloxLocaleId)
	countries: { string }, -- ISO countries whose players get it when their Roblox is in English
	font: string?, -- the face its words are written in, when the brush lacks its letters
	weight: number?, -- that face's weight, 100..900
}

local Languages = {}

Languages.DEFAULT = "en"
-- What a player's choice is when they have made none: the language worked out for them.
Languages.AUTO = "auto"

Languages.list = {
	{ code = "en", name = "English", locales = { "en" }, countries = {} },
	{
		code = "ru",
		name = "Русский",
		locales = { "ru" },
		countries = { "RU", "BY", "KZ", "KG" },
		-- Caveat, from the Creator Store, a handwriting with Cyrillic: the owner's choice of the
		-- faces scripts/studio/font-samples.lua showed him (2026-10-15). Marhey, which was tried
		-- first as the nearest to the brush, he found poor.
		font = "rbxassetid://12187369802",
		weight = 700,
	},
	{
		code = "es",
		name = "Español",
		locales = { "es" },
		countries = {
			"ES",
			"MX",
			"AR",
			"CO",
			"CL",
			"PE",
			"VE",
			"EC",
			"GT",
			"CU",
			"BO",
			"DO",
			"HN",
			"PY",
			"SV",
			"NI",
			"CR",
			"PA",
			"UY",
			"PR",
		},
	},
	{
		code = "pt",
		name = "Português",
		locales = { "pt" },
		countries = { "BR", "PT", "AO", "MZ" },
	},
	{ code = "fr", name = "Français", locales = { "fr" }, countries = { "FR", "MC" } },
	{ code = "de", name = "Deutsch", locales = { "de" }, countries = { "DE", "AT", "LI" } },
} :: { Language }

-- The plain face of the settings' "Font: Plain", for whoever finds the brush hard to read: it
-- has every letter of every language here.
Languages.PLAIN = { font = "rbxasset://fonts/families/Montserrat.json", weight = 700 }

Languages.byCode = {} :: { [string]: Language }
for _, language in Languages.list do
	Languages.byCode[language.code] = language
end

return Languages
