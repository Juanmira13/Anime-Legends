--!strict
-- Titan Village's layout: a round island ruled by a giant ring wall around the
-- town (south and east gates, a breach to the north), farmland outside to the
-- west, a giant forest on a plateau to the east and hills on the north-west
-- coast. The road goes through the south gate into town, out the east gate up
-- to the forest and around the wall to the breach. Pure data.

local Shape = require(script.Parent.Parent.Gen.Shape)

local layout: Shape.Layout = {
	id = "TitanVillage",
	seed = 4404,
	radius = 430,
	coastNoise = 0.05,
	coast = { bays = { { angle = -2.3, width = 0.22, depth = 0.12 } } },
	baseHeight = 9,
	hillHeight = 8,
	hillScale = 140,
	beachWidth = 30,
	seaFloor = -24,
	plaza = { x = 0, z = 290, radius = 36, height = 6 },
	zones = {
		{ rank = "Easy", name = "Campos Exteriores", x = -250, z = 140, radius = 46, height = 8, count = 8 },
		{ rank = "Medium", name = "Ciudad Amurallada", x = 30, z = -30, radius = 44, height = 10, count = 6 },
		{ rank = "Hard", name = "Bosque Gigante", x = 290, z = 85, radius = 40, height = 24, count = 4 },
		{ rank = "Boss", name = "Brecha del Muro", x = 30, z = -275, radius = 40, height = 12, count = 1 },
	},
	paths = {
		{
			width = 12,
			points = {
				{ 0, 290, 6 },
				{ -120, 250, 7 },
				{ -250, 140, 8 },
				{ -150, 140, 9 },
				{ 20, 150, 10 }, -- south gate
				{ 30, -30, 10 },
				{ 150, -25, 10 },
				{ 220, -30, 12 }, -- east gate
				{ 250, 40, 20 },
				{ 290, 85, 24 },
				{ 330, 0, 22 },
				{ 300, -100, 18 },
				{ 200, -260, 13 },
				{ 30, -275, 12 },
			},
		},
	},
	mesas = {},
	plateaus = {
		{ x = 300, z = 90, radius = 85, height = 24 }, -- giant forest
	},
	mountains = {
		{ x = -230, z = -210, radius = 170, height = 62, sharpness = 1.3 },
		{ x = -330, z = -40, radius = 110, height = 34, sharpness = 1.2 },
	},
	materials = {
		grass = "Grass",
		path = "Ground",
		plaza = "Cobblestone",
		cliff = "Rock",
		beach = "Sand",
		seabed = "Mud",
	},
}

return layout
