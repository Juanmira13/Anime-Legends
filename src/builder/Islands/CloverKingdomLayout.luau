--!strict
-- Clover Kingdom's layout: a two-lobed island. The west lobe holds the humble
-- village and its fields, a river runs from the castle hill to the west coast
-- under a stone bridge, the white castle crowns a plateau in the middle, the
-- east lobe is the haunted forest and the grimoire altar sits on a cliff to
-- the north-east. Pure data, checked by LayoutCheck.

local Shape = require(script.Parent.Parent.Gen.Shape)

local layout: Shape.Layout = {
	id = "CloverKingdom",
	seed = 3303,
	radius = 400,
	coastNoise = 0.05,
	coast = { lobes = 2, lobeDepth = 0.2, lobeAngle = 0 },
	baseHeight = 8,
	hillHeight = 9,
	hillScale = 110,
	beachWidth = 30,
	seaFloor = -24,
	plaza = { x = 0, z = 200, radius = 36, height = 6 },
	zones = {
		{ rank = "Easy", name = "Aldea Humilde", x = -260, z = 130, radius = 46, height = 8, count = 8 },
		{ rank = "Medium", name = "Camino Real", x = -40, z = 40, radius = 42, height = 16, count = 6 },
		{ rank = "Hard", name = "Bosque Embrujado", x = 260, z = 40, radius = 40, height = 12, count = 4 },
		{ rank = "Boss", name = "Altar del Grimorio", x = 230, z = -170, radius = 38, height = 34, count = 1 },
	},
	paths = {
		-- Royal road: village, bridge over the river, the castle hill, the forest, the altar cliff.
		{
			width = 12,
			material = "Cobblestone",
			points = {
				{ 0, 200, 6 },
				{ -120, 190, 7 },
				{ -260, 130, 8 },
				{ -185, 75, 9 },
				{ -140, 0, 11 },
				{ -40, 40, 16 },
				{ 80, 45, 18 },
				{ 170, 60, 14 },
				{ 260, 40, 12 },
				{ 300, -60, 20 },
				{ 280, -120, 30 },
				{ 230, -170, 34 },
			},
		},
		-- Castle road up the hill.
		{ width = 10, material = "Pavement", points = { { -40, 40, 16 }, { 20, -20, 30 }, { 42, -52, 46 } } },
	},
	mesas = {},
	plateaus = {
		{ x = 80, z = -90, radius = 75, height = 48 }, -- castle hill
		{ x = 230, z = -180, radius = 70, height = 34 }, -- altar cliff
	},
	mountains = {
		{ x = 80, z = -90, radius = 200, height = 22, sharpness = 1 },
		{ x = -150, z = -200, radius = 150, height = 45, sharpness = 1.3 },
	},
	rivers = {
		{
			width = 16,
			depth = 4,
			points = {
				{ 20, -130, 30 },
				{ -60, -60, 16 },
				{ -130, 10, 8 },
				{ -200, 60, 5 },
				{ -300, 40, 3 },
				{ -420, 20, 1 },
				{ -520, 10, 0 },
			},
		},
	},
	lakes = {
		{ x = -330, z = 40, radius = 18, level = 4, depth = 3 }, -- village pond
	},
	materials = { grass = "Grass", path = "Ground", plaza = "Pavement", cliff = "Rock", beach = "Sand", seabed = "Mud" },
}

return layout
