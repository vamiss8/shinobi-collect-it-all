--!strict
-- Every collectible shinobi. `income` is Ryo per second before mutation, merge level and boosts.
-- Listed from the weakest to the strongest: by rank, and by income within a rank. A rank belongs
-- to one zone (see Zones), so each group below is what that zone drops.
-- Ids are stored in player saves: never rename or reuse one, only add new ids. A character
-- that leaves the roster is listed in Config/Replaced with whoever takes its place.
-- Nobody here is also a zone's enemy (Config/Zones).

export type Character = {
	id: string,
	name: string,
	rank: string,
	income: number,
}

local Characters: { Character } = {
	-- D: Academy Grounds
	{ id = "teuchi", name = "Teuchi (Ichiraku)", rank = "D", income = 1 },
	{ id = "konohamaru", name = "Konohamaru", rank = "D", income = 2 },
	{ id = "naruto_academy", name = "Naruto (Academy)", rank = "D", income = 3 },
	{ id = "iruka", name = "Iruka", rank = "D", income = 4 },
	{ id = "ebisu", name = "Ebisu", rank = "D", income = 5 },

	-- C: Land of Waves
	{ id = "sakura", name = "Sakura (Genin)", rank = "C", income = 8 },
	{ id = "sasuke_genin", name = "Sasuke (Genin)", rank = "C", income = 10 },
	{ id = "haku", name = "Haku", rank = "C", income = 12 },
	{ id = "tazuna", name = "Tazuna", rank = "C", income = 14 },
	{ id = "kakashi", name = "Kakashi", rank = "C", income = 16 },

	-- B: Forest of Death
	{ id = "kiba", name = "Kiba", rank = "B", income = 25 },
	{ id = "hinata", name = "Hinata", rank = "B", income = 30 },
	{ id = "ino", name = "Ino", rank = "B", income = 35 },
	{ id = "shikamaru", name = "Shikamaru", rank = "B", income = 40 },
	{ id = "choji", name = "Choji", rank = "B", income = 50 },

	-- A: Chunin Exam Finals
	{ id = "kankuro", name = "Kankuro", rank = "A", income = 80 },
	{ id = "temari", name = "Temari", rank = "A", income = 95 },
	{ id = "shino", name = "Shino", rank = "A", income = 110 },
	{ id = "gaara_genin", name = "Gaara (Genin)", rank = "A", income = 125 },
	{ id = "hiruzen", name = "Hiruzen", rank = "A", income = 150 },

	-- A+: Valley of the End
	{ id = "neji", name = "Neji", rank = "A+", income = 250 },
	{ id = "choji_butterfly", name = "Choji (Butterfly)", rank = "A+", income = 300 },
	{ id = "rock_lee", name = "Rock Lee (Drunken Fist)", rank = "A+", income = 350 },
	{ id = "naruto_kyubi_cloak", name = "Naruto (Kyubi Cloak)", rank = "A+", income = 400 },
	{ id = "kimimaro", name = "Kimimaro", rank = "A+", income = 500 },

	-- S: Hidden Sand
	{ id = "chiyo", name = "Chiyo", rank = "S", income = 800 },
	{ id = "sai", name = "Sai", rank = "S", income = 950 },
	{ id = "deidara", name = "Deidara", rank = "S", income = 1100 },
	{ id = "sasori", name = "Sasori", rank = "S", income = 1250 },
	{ id = "gaara_kazekage", name = "Gaara (Kazekage)", rank = "S", income = 1500 },

	-- S+: Akatsuki Lair
	{ id = "hidan", name = "Hidan", rank = "S+", income = 2500 },
	{ id = "kakuzu", name = "Kakuzu", rank = "S+", income = 3000 },
	{ id = "kisame", name = "Kisame", rank = "S+", income = 3500 },
	{ id = "orochimaru", name = "Orochimaru", rank = "S+", income = 4000 },
	{ id = "kabuto", name = "Kabuto Yakushi", rank = "S+", income = 5000 },

	-- SS: Hidden Rain
	{ id = "konan", name = "Konan", rank = "SS", income = 8000 },
	{ id = "fukasaku", name = "Fukasaku", rank = "SS", income = 9500 },
	{ id = "jiraiya", name = "Jiraiya", rank = "SS", income = 11000 },
	{ id = "naruto_sage", name = "Naruto (Sage Mode)", rank = "SS", income = 12500 },
	{ id = "hinata_shippuden", name = "Hinata (Shippuden)", rank = "SS", income = 15000 },

	-- SSS: Kamui Dimension
	{ id = "rin", name = "Rin", rank = "SSS", income = 25000 },
	{ id = "black_zetsu", name = "Black Zetsu", rank = "SSS", income = 30000 },
	{ id = "might_guy", name = "Might Guy", rank = "SSS", income = 35000 },
	{ id = "kakashi_mangekyo", name = "Kakashi (Mangekyo)", rank = "SSS", income = 40000 },
	{ id = "shisui", name = "Shisui Uchiha", rank = "SSS", income = 50000 },

	-- Six Paths: Great Ninja War
	{ id = "minato", name = "Minato", rank = "SixPaths", income = 80000 },
	{ id = "hashirama", name = "Hashirama", rank = "SixPaths", income = 95000 },
	{ id = "madara", name = "Madara", rank = "SixPaths", income = 110000 },
	{ id = "naruto_six_paths", name = "Naruto (Six Paths)", rank = "SixPaths", income = 125000 },
	{ id = "sasuke_six_paths", name = "Sasuke (Six Paths)", rank = "SixPaths", income = 150000 },
}

return Characters
