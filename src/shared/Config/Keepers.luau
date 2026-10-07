--!strict
-- The market's shopkeepers (World/TentenShop, World/MissionDesk, World/TrainingGround). Each stands in its shop as a
-- placeholder until a model named after its id is put into ReplicatedStorage.Models, the same
-- way as a shinobi's; the model is scaled to the keeper's height. Colors are hex strings rather
-- than Color3 so this module also loads under Lune.

export type Keeper = {
	id: string,
	name: string,
	height: number, -- studs; a shinobi stands 4.8
	color: string, -- the placeholder's body
}

local Keepers: { Keeper } = {
	{ id = "tenten", name = "Tenten", height = 4.8, color = "#E980A0" },
	{ id = "shizune", name = "Shizune", height = 4.8, color = "#343440" },
	{ id = "tonton", name = "Tonton", height = 1.4, color = "#F4AAB4" },
	{ id = "duy", name = "Might Duy", height = 4.8, color = "#2E7D32" },
	{ id = "turtle", name = "Turtle", height = 1.2, color = "#6D8B4A" },
}

return Keepers
