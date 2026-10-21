--!strict
-- Demon Corps' layout: a mountain island. The road spirals up from the
-- lantern village at the foot of the central peak, through the bamboo
-- terrace to the east, up the torii stairway to the mountain shrine and down
-- the western slope to the moonlit railway where the train stands. A pond
-- with an arched bridge sits by the village. Pure data.

local Shape = require(script.Parent.Parent.Gen.Shape)

local layout: Shape.Layout = {
	id = "DemonCorps",
	seed = 6606,
	radius = 420,
	coastNoise = 0.08,
	coast = { lobes = 3, lobeDepth = 0.08, lobeAngle = math.pi / 2 },
	baseHeight = 9,
	hillHeight = 10,
	hillScale = 110,
	beachWidth = 28,
	seaFloor = -24,
	plaza = { x = 0, z = 280, radius = 36, height = 6 },
	zones = {
		{ rank = "Easy", name = "Aldea de Faroles", x = -170, z = 160, radius = 46, height = 8, count = 8 },
		{ rank = "Medium", name = "Bosque de Bambú", x = 170, z = 140, radius = 44, height = 22, count = 6 },
		{ rank = "Hard", name = "Montaña de Toriis", x = 110, z = -110, radius = 40, height = 58, count = 4 },
		{ rank = "Boss", name = "Tren de la Luna", x = -230, z = -120, radius = 42, height = 30, count = 1 },
	},
	paths = {
		{
			width = 12,
			points = {
				{ 0, 280, 6 },
				{ -90, 230, 7 },
				{ -170, 160, 8 },
				{ -60, 150, 12 },
				{ 60, 170, 17 },
				{ 170, 140, 22 },
				{ 230, 60, 30 },
				{ 220, -20, 42 },
				{ 170, -80, 52 },
				{ 110, -110, 58 },
				{ 20, -180, 50 },
				{ -110, -190, 40 },
				{ -230, -120, 30 },
			},
		},
	},
	mesas = {
		{ x = 330, z = 330, radius = 26, height = 30 }, -- sea stacks
		{ x = -380, z = 260, radius = 22, height = 26 },
	},
	mountains = {
		{ x = -20, z = -70, radius = 260, height = 150, sharpness = 1.6 },
		{ x = 190, z = -230, radius = 120, height = 70, sharpness = 1.4 },
	},
	lakes = {
		{ x = -90, z = 90, radius = 16, level = 9, depth = 3 }, -- village pond
	},
	materials = { grass = "Grass", path = "Ground", plaza = "Pavement", cliff = "Rock", beach = "Sand", seabed = "Mud" },
}

return layout
