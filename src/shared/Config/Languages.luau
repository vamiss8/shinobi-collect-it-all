--!strict
-- The languages the game is written in (client/Lang has a pack for each), and how a player is
-- given theirs (Logic/Settings.language): the language their Roblox account, Roblox or their
-- device is set to, the first that is one of these and not English. Not by the country they
-- play from, which is read off the IP and changed by a VPN. A player can choose another in the
-- settings, and keeps it.
--
-- The brush (PermanentMarker) has the letters of every Latin language here, accents too, but
-- no Cyrillic: a language it cannot write names a face of its own, a Roblox font family (a
-- rbxasset://fonts/families/X.json path, or rbxassetid:// for one from the Creator Store), and
-- client Fonts puts that face on every word written in the brush.

export type Language = {
	code: string, -- as client/Lang knows it
	name: string, -- in itself, as the settings show it
	locales: { string }, -- language parts of locales, as "pt" of "pt-br" (Player.LocaleId)
	font: string?, -- the face its words are written in, when the brush lacks its letters
	weight: number?, -- that face's weight, 100..900
}

local Languages = {}

Languages.DEFAULT = "en"
-- What a player's choice is when they have made none: the language worked out for them.
Languages.AUTO = "auto"

Languages.list = {
	{ code = "en", name = "English", locales = { "en" } },
	{
		code = "ru",
		name = "Русский",
		locales = { "ru" },
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
	},
	{
		code = "pt",
		name = "Português",
		locales = { "pt" },
	},
	{ code = "fr", name = "Français", locales = { "fr" } },
	{ code = "de", name = "Deutsch", locales = { "de" } },
} :: { Language }

-- The plain face of the settings' "Font: Plain", for whoever finds the brush hard to read: it
-- has every letter of every language here.
Languages.PLAIN = { font = "rbxasset://fonts/families/Montserrat.json", weight = 700 }

Languages.byCode = {} :: { [string]: Language }
for _, language in Languages.list do
	Languages.byCode[language.code] = language
end

return Languages
