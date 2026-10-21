--!strict
-- The loading screen's words, in the game's six languages. They live here, beside the screen
-- in ReplicatedFirst, and not in client/Lang: the screen comes up before anything else of the
-- game has reached the player, the language packs among it. tests/Loading.spec holds every
-- language to the same stages and the same number of tips as English.
--
-- A tip marks words as Iruka's lines do: {r|...} what matters, {y|...} Chakra, Ryo and Herbs,
-- {b|...} where it is in the game, {g|...} how much.

export type Pack = {
	stages: { string }, -- entering, the world, the interface, the save, ready
	tip: string,
	skip: string,
	tips: { string },
}

local Words: { [string]: Pack } = {
	en = {
		stages = {
			"Entering the Hidden Leaf...",
			"Raising the village...",
			"Sharpening kunai...",
			"Gathering Chakra...",
			"Ready!",
		},
		tip = "TIP:",
		skip = "Skip",
		tips = {
			"A {r|PERFECT} press throws your kunai the farthest. {g|Five} in a row make a {r|Sage throw}!",
			"{y|Chakra} decides how far your kunai flies. Train it with {b|Meditate} and {b|Chakra Control}.",
			"Two {r|identical} shinobi merge into a stronger one. Look for the {r|violet glow} in the {b|Inventory}.",
			"After a catch, {r|run home fast}: the zone's enemy is right behind you.",
			"Buy {r|run speed} at the {b|Youth Training Ground} to outrun the enemies of farther zones.",
			"{r|Mutations} multiply a shinobi's income. {r|Events} bring mutations of their own!",
			"Fill a {b|Bingo Book} page for a {g|permanent} income bonus.",
			"Upgrade your shinobi on the {b|console} at the foot of each pad: every level is {g|x1.25} income.",
			"{y|Herbs} come from catches you bring home. Trade them for potions at {b|Kabuto's Remedies}.",
			"Lost? The {b|notice board} on the plaza explains everything.",
		},
	},
	ru = {
		stages = {
			"Входим в Скрытый Лист...",
			"Возводим деревню...",
			"Точим кунаи...",
			"Собираем Чакру...",
			"Готово!",
		},
		tip = "СОВЕТ:",
		skip = "Пропустить",
		tips = {
			"Нажатие {r|ИДЕАЛЬНО} бросает кунай дальше всего. {g|Пять} подряд дают {r|бросок мудреца}!",
			"{y|Чакра} решает, как далеко полетит кунай. Тренируй её {b|Медитацией} и {b|Контролем чакры}.",
			"Два {r|одинаковых} шиноби сливаются в одного сильнее. Ищи {r|фиолетовое свечение} в {b|Инвентаре}.",
			"Поймал шиноби? {r|Беги домой}: враг зоны прямо за тобой.",
			"Покупай {r|скорость бега} на {b|Полигоне юности}, чтобы уходить от врагов дальних зон.",
			"{r|Мутации} умножают доход шиноби. {r|События} приносят свои мутации!",
			"Заполни страницу {b|Книги Бинго}, и доход вырастет {g|навсегда}.",
			"Улучшай шиноби на {b|пульте} у каждой платформы: каждый уровень даёт доход {g|x1,25}.",
			"{y|Травы} дают уловы, принесённые домой. Меняй их на зелья в {b|Снадобьях Кабуто}.",
			"Заблудился? {b|Доска объявлений} на площади всё объяснит.",
		},
	},
	es = {
		stages = {
			"Entrando en la Hoja Oculta...",
			"Levantando la aldea...",
			"Afilando kunais...",
			"Reuniendo chakra...",
			"¡Listo!",
		},
		tip = "CONSEJO:",
		skip = "Saltar",
		tips = {
			"Un {r|PERFECTO} lanza tu kunai lo más lejos. ¡{g|Cinco} seguidos dan un {r|lanzamiento del sabio}!",
			"El {y|chakra} decide hasta dónde vuela tu kunai. Entrénalo con {b|Meditar} y {b|Control de chakra}.",
			"Dos shinobi {r|idénticos} se funden en uno más fuerte. Busca el {r|brillo violeta} en el {b|Inventario}.",
			"Tras una captura, {r|corre a casa}: el enemigo de la zona va justo detrás de ti.",
			"Compra {r|velocidad} en el {b|Campo de Entrenamiento Juvenil} para escapar de las zonas lejanas.",
			"Las {r|mutaciones} multiplican los ingresos. ¡Los {r|eventos} traen sus propias mutaciones!",
			"Completa una página del {b|Libro Bingo} para un bono de ingresos {g|permanente}.",
			"Mejora a tus shinobi en la {b|consola} al pie de cada plataforma: cada nivel da {g|x1,25} de ingresos.",
			"Las {y|hierbas} vienen de las capturas que llevas a casa. Cámbialas por pociones en {b|Remedios de Kabuto}.",
			"¿Perdido? El {b|tablón de anuncios} de la plaza lo explica todo.",
		},
	},
	pt = {
		stages = {
			"Entrando na Folha Oculta...",
			"Erguendo a vila...",
			"Afiando kunais...",
			"Reunindo chakra...",
			"Pronto!",
		},
		tip = "DICA:",
		skip = "Pular",
		tips = {
			"Um {r|PERFEITO} lança sua kunai mais longe. {g|Cinco} seguidos dão um {r|arremesso do sábio}!",
			"O {y|chakra} decide até onde sua kunai voa. Treine com {b|Meditar} e {b|Controle de chakra}.",
			"Dois shinobi {r|idênticos} se fundem em um mais forte. Procure o {r|brilho violeta} no {b|Inventário}.",
			"Depois de uma captura, {r|corra para casa}: o inimigo da zona está logo atrás de você.",
			"Compre {r|velocidade} no {b|Campo de Treino da Juventude} para escapar das zonas distantes.",
			"{r|Mutações} multiplicam a renda. {r|Eventos} trazem mutações próprias!",
			"Complete uma página do {b|Livro Bingo} para um bônus de renda {g|permanente}.",
			"Melhore seus shinobi no {b|console} ao pé de cada plataforma: cada nível dá {g|x1,25} de renda.",
			"As {y|ervas} vêm das capturas que você leva para casa. Troque por poções nos {b|Remédios do Kabuto}.",
			"Perdido? O {b|quadro de avisos} da praça explica tudo.",
		},
	},
	fr = {
		stages = {
			"Entrée dans la Feuille cachée...",
			"Le village se dresse...",
			"Affûtage des kunaïs...",
			"Rassemblement du chakra...",
			"Prêt !",
		},
		tip = "ASTUCE :",
		skip = "Passer",
		tips = {
			"Un {r|PARFAIT} lance ton kunaï le plus loin. {g|Cinq} d'affilée donnent un {r|lancer d'ermite} !",
			"Le {y|chakra} décide jusqu'où vole ton kunaï. Entraîne-le avec {b|Méditer} et {b|Contrôle du chakra}.",
			"Deux shinobi {r|identiques} fusionnent en un plus fort. Cherche la {r|lueur violette} dans l'{b|Inventaire}.",
			"Après une prise, {r|cours à la maison} : l'ennemi de la zone est juste derrière toi.",
			"Achète de la {r|vitesse} au {b|Terrain d'entraînement de la jeunesse} pour semer les zones lointaines.",
			"Les {r|mutations} multiplient les revenus. Les {r|événements} apportent leurs propres mutations !",
			"Complète une page du {b|Bingo Book} pour un bonus de revenus {g|permanent}.",
			"Améliore tes shinobi sur la {b|console} au pied de chaque plateforme : chaque niveau donne {g|x1,25}.",
			"Les {y|herbes} viennent des prises ramenées à la maison. Échange-les contre des potions aux {b|Remèdes de Kabuto}.",
			"Perdu ? Le {b|tableau d'affichage} de la place explique tout.",
		},
	},
	de = {
		stages = {
			"Betrete das Versteckte Blatt...",
			"Das Dorf erwacht...",
			"Kunai werden geschärft...",
			"Chakra wird gesammelt...",
			"Bereit!",
		},
		tip = "TIPP:",
		skip = "Überspringen",
		tips = {
			"Ein {r|PERFEKT} wirft dein Kunai am weitesten. {g|Fünf} in Folge ergeben einen {r|Eremiten-Wurf}!",
			"{y|Chakra} entscheidet, wie weit dein Kunai fliegt. Trainiere es mit {b|Meditieren} und {b|Chakra-Kontrolle}.",
			"Zwei {r|gleiche} Shinobi verschmelzen zu einem stärkeren. Achte auf das {r|violette Leuchten} im {b|Inventar}.",
			"Nach einem Fang {r|lauf schnell nach Hause}: der Gegner der Zone ist dir dicht auf den Fersen.",
			"Kauf {r|Laufgeschwindigkeit} auf dem {b|Trainingsplatz der Jugend}, um fernen Zonen zu entkommen.",
			"{r|Mutationen} vervielfachen das Einkommen. {r|Events} bringen eigene Mutationen!",
			"Fülle eine Seite im {b|Bingo-Buch} für einen {g|dauerhaften} Einkommensbonus.",
			"Verbessere deine Shinobi an der {b|Konsole} am Fuß jeder Plattform: jedes Level bringt {g|x1,25}.",
			"{y|Kräuter} gibt es für Fänge, die du nach Hause bringst. Tausche sie bei {b|Kabutos Heilmittel} gegen Tränke.",
			"Verloren? Das {b|Schwarze Brett} auf dem Platz erklärt alles.",
		},
	},
}

return Words
