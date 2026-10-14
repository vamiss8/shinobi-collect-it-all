--!strict
-- The game's words in a language (Logic/Words), with the real packs (client/Lang): templates,
-- names, the titles the server writes, and the server's words in the world.
local Words = require("../src/shared/Logic/Words")
local T = require("./harness")

local English: Words.Pack = require("../src/client/Lang/en")
local Russian: Words.Pack = require("../src/client/Lang/ru")
local Spanish: Words.Pack = require("../src/client/Lang/es")

local ru = Words.book(English, Russian)
local es = Words.book(English, Spanish)
local en = Words.book(English, nil)

return {
	["a template is filled in the language, numbers shortened and names said in it"] = function()
		T.eq(Words.get(ru, "HudRyo", 1250), "1.25K Рё")
		T.eq(
			Words.get(ru, "RunEscaped", "Kakashi"),
			"Ушёл!  Какаши теперь твой."
		)
		T.eq(Words.get(en, "HudRyo", 1250), "1.25K Ryo")
		T.eq(Words.get(ru, "NoSuchKey"), "NoSuchKey", "an unknown key shows itself")
	end,

	["a shinobi's title the server wrote is said in the language"] = function()
		T.eq(
			Words.localize(ru, "Kakashi [Ice] ★★ Lvl 3"),
			"Какаши [Лёд] ★★ Ур. 3"
		)
		T.eq(
			Words.localize(ru, "Naruto (Sage Mode) ★"),
			"Наруто (Режим отшельника) ★"
		)
		T.eq(Words.localize(ru, "Hidan Lvl 12"), "Хидан Ур. 12")
		T.eq(Words.localize(ru, "SomePlayer"), "SomePlayer", "a player's name is left alone")
		T.eq(Words.title(es, "kakashi", "ice", 2, 4), "Kakashi [Hielo] ★ Nv. 5")
	end,

	["time is said in the language"] = function()
		T.eq(Words.duration(ru, 3 * 3600 + 20 * 60), "3 ч 20 мин")
		T.eq(Words.duration(en, 2 * 86400 + 5 * 3600), "2d 5h")
		T.eq(Words.duration(es, 45), "45s")
	end,

	["the world's English is said in the language, its colors kept"] = function()
		T.eq(Words.world(ru, "UNLOCK\n500 Ryo"), "ОТКРЫТЬ\n500 Рё")
		T.eq(
			Words.world(ru, '<font color="#FFF">SSS Rank</font>  |  3K+ Chakra'),
			'<font color="#FFF">Ранг SSS</font>  |  от 3K Чакры'
		)
		T.eq(
			Words.world(ru, '<font color="#FF8A80">Mizuki - speed 14 to 18</font>'),
			'<font color="#FF8A80">Мизуки — скорость от 14 до 18</font>'
		)
		T.eq(
			Words.world(
				ru,
				'<font color="#FFD54F">Lvl 3</font>  <font color="#81C784">1.2K/s</font>'
			),
			'<font color="#FFD54F">Ур. 3</font>  <font color="#81C784">1.2K/с</font>'
		)
		T.eq(Words.world(ru, "Base: 1K/s"), "База: 1K/с")
		T.eq(Words.world(ru, "+10 Lvl"), "+10 ур.")
		T.eq(Words.world(ru, "MAX"), "МАКС")
		T.eq(Words.world(ru, "vamiss8's Dojo"), "Додзё: vamiss8")
		T.eq(Words.world(ru, "Empty pad"), "Пустая платформа")
		T.eq(Words.world(ru, "Take / Swap"), "Взять / Заменить")
	end,

	["names in capitals stay in capitals, and the shops' names are known in them"] = function()
		T.eq(Words.world(ru, "LAVA"), "ЛАВА")
		T.eq(Words.world(ru, "MIZUKI"), "МИЗУКИ")
		T.eq(Words.world(ru, "ITACHI"), "ИТАЧИ")
		T.eq(Words.world(ru, "LAND OF WAVES"), "СТРАНА ВОЛН")
		T.eq(Words.world(ru, "TENTEN'S NINJA TOOLS"), "ЛАВКА ТЕНТЕН")
		T.eq(Words.world(es, "YOUTH TRAINING GROUND"), "CAMPO DE ENTRENAMIENTO JUVENIL")
		T.eq(Words.world(ru, "SSS Rank"), "Ранг SSS")
	end,

	["the notice board is said in the language, blanks and all"] = function()
		T.eq(
			Words.world(ru, "Escort the bridge builder to the Land of Waves."),
			"Сопроводить строителя моста. Цель: Страна Волн."
		)
		T.eq(
			Words.world(ru, "5 Perfect throws in a row charge it: x2 power."),
			"5 идеальных бросков подряд заряжают его: сила x2."
		)
		T.eq(Words.world(ru, "IF SEEN: RUN HOME!"), "УВИДИШЬ — БЕГИ ДОМОЙ!")
	end,

	["in English, and for anything unknown, the world's words are left as they are"] = function()
		T.eq(Words.world(en, "UNLOCK\n500 Ryo"), "UNLOCK\n500 Ryo")
		T.eq(Words.world(ru, "SomePlayer"), "SomePlayer")
		T.eq(Words.world(ru, "火\nの\n意\n志"), "火\nの\n意\n志")
		T.eq(Words.world(ru, ""), "")
	end,
}
