--!strict
-- Hero Academy's layout: a city island with a rounded square coast and low
-- sea cliffs (seawall), a grid of asphalt streets, the campus on a terrace to
-- the west, a hill park to the north-east, the ruined simulation city to the
-- east and the great stadium to the north-west. Pure data.

local Shape = require(script.Parent.Parent.Gen.Shape)

local layout: Shape.Layout = {
	id = "HeroAcademy",
	seed = 5505,
	radius = 420,
	coastNoise = 0.03,
	coast = { lobes = 4, lobeDepth = 0.08, lobeAngle = math.pi / 4 },
	baseHeight = 10,
	hillHeight = 4,
	hillScale = 160,
	beachWidth = 14,
	seaFloor = -24,
	plaza = { x = 0, z = 285, radius = 36, height = 6 },
	zones = {
		{ rank = "Easy", name = "Campus", x = -200, z = 120, radius = 46, height = 18, count = 8 },
		{ rank = "Medium", name = "Avenida Central", x = 60, z = 40, radius = 44, height = 10, count = 6 },
		{ rank = "Hard", name = "Ciudad Simulacro", x = 240, z = -120, radius = 40, height = 12, count = 4 },
		{ rank = "Boss", name = "Gran Estadio", x = -110, z = -215, radius = 46, height = 14, count = 1 },
	},
	paths = {
		-- Main avenue through every zone.
		{
			width = 14,
			points = {
				{ 0, 285, 6 },
				{ -90, 240, 9 },
				{ -150, 180, 15 },
				{ -200, 120, 18 },
				{ -110, 70, 12 },
				{ 60, 40, 10 },
				{ 160, -20, 10 },
				{ 240, -120, 12 },
				{ 100, -200, 13 },
				{ -110, -215, 14 },
			},
		},
		-- Street grid.
		{ width = 12, points = { { -20, 255 }, { -20, -330 } } },
		{ width = 12, points = { { 150, 250 }, { 150, -300 } } },
		{ width = 12, points = { { -330, -60 }, { 330, -60 } } },
		{ width = 12, points = { { -120, 130 }, { 330, 130 } } },
	},
	mesas = {},
	plateaus = {
		{ x = -205, z = 115, radius = 95, height = 18 }, -- campus terrace
	},
	mountains = {
		{ x = 200, z = 180, radius = 130, height = 40, sharpness = 1.2 }, -- hill park
	},
	-- Paved city; the campus lawn and the hill park stay green.
	surfaces = {
		{ x = 0, z = 0, radius = 360, material = "Pavement" },
		{ x = -205, z = 115, radius = 70, material = "Grass" },
		{ x = 200, z = 180, radius = 125, material = "Grass" },
	},
	materials = { grass = "Grass", path = "Asphalt", plaza = "Concrete", cliff = "Rock", beach = "Sand", seabed = "Mud" },
}

return layout
