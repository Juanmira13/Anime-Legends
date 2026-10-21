--!strict
-- Kono's layout: a long island (east-west) with a mountain ridge on the north
-- coast, a waterfall that falls from the ridge into a lake and a river to the
-- west coast, the village in the middle and a raised forest terrace to the
-- east. Pure data, checked by LayoutCheck; Islands/Kono decorates it.

local Shape = require(script.Parent.Parent.Gen.Shape)

local layout: Shape.Layout = {
	id = "Kono",
	seed = 2202,
	radius = 400,
	coastNoise = 0.06,
	coast = { elongation = 0.18, angle = 0 },
	baseHeight = 9,
	hillHeight = 10,
	hillScale = 120,
	beachWidth = 30,
	seaFloor = -24,
	plaza = { x = 0, z = 200, radius = 36, height = 6 },
	zones = {
		{ rank = "Easy", name = "Campo de Entrenamiento", x = -250, z = 90, radius = 46, height = 8, count = 8 },
		{ rank = "Medium", name = "Calles de la Aldea", x = 20, z = 40, radius = 44, height = 12, count = 6 },
		{ rank = "Hard", name = "Bosque Profundo", x = 290, z = -10, radius = 40, height = 26, count = 4 },
		{ rank = "Boss", name = "Valle de la Cascada", x = 150, z = -120, radius = 40, height = 20, count = 1 },
	},
	paths = {
		-- Main road, graded from the plaza up to the forest terrace and down to the valley.
		{
			width = 12,
			points = {
				{ 0, 200, 6 },
				{ -120, 170, 7 },
				{ -250, 90, 8 },
				{ -150, 60, 10 },
				{ 20, 40, 12 },
				{ 140, 20, 14 },
				{ 240, 0, 26 },
				{ 290, -10, 26 },
				{ 250, -80, 24 },
				{ 200, -110, 21 },
				{ 150, -120, 20 },
			},
		},
		-- Village streets around the square.
		{ width = 8, points = { { -60, 110 }, { 20, 120 }, { 100, 100 }, { 120, 40 } } },
		{ width = 8, points = { { -70, -10 }, { 0, -40 }, { 80, -30 }, { 120, 40 } } },
	},
	mesas = {},
	plateaus = {
		{ x = 290, z = -10, radius = 120, height = 26 }, -- forest terrace
	},
	mountains = {
		{ x = -200, z = -215, radius = 170, height = 85, sharpness = 1.3 },
		{ x = 20, z = -255, radius = 190, height = 115, sharpness = 1.2 },
		{ x = 240, z = -215, radius = 150, height = 80, sharpness = 1.4 },
	},
	rivers = {
		{
			width = 14,
			depth = 4,
			points = {
				{ 60, -310, 72 },
				{ 70, -262, 66 },
				{ 74, -232, 62 },
				{ 76, -226, 24 }, -- waterfall
				{ 66, -204, 20 },
			},
		},
		{
			width = 16,
			depth = 4,
			points = {
				{ 40, -186, 19 },
				{ -60, -140, 14 },
				{ -160, -60, 9 },
				{ -300, -40, 4 },
				{ -420, -60, 1 },
				{ -540, -60, 0 },
			},
		},
	},
	lakes = {
		{ x = 58, z = -190, radius = 26, level = 20, depth = 5 }, -- pool under the waterfall
	},
	materials = { grass = "Grass", path = "Ground", plaza = "Cobblestone", cliff = "Rock", beach = "Sand", seabed = "Mud" },
}

return layout
