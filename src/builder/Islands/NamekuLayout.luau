--!strict
-- Nameku's layout: coast, hills, plaza, combat zones, path and mesas. Pure
-- data, so the tests check it (LayoutCheck); Islands/Nameku decorates it.

local Shape = require(script.Parent.Parent.Gen.Shape)

local layout: Shape.Layout = {
	id = "Nameku",
	seed = 1701,
	radius = 390,
	coastNoise = 0.12,
	baseHeight = 9,
	hillHeight = 14,
	hillScale = 140,
	beachWidth = 34,
	seaFloor = -24,
	plaza = { x = 0, z = 225, radius = 36, height = 7 },
	zones = {
		{ rank = "Easy", name = "Praderas Azules", x = -120, z = 130, radius = 46, height = 8, count = 8 },
		{ rank = "Medium", name = "Aldea Namek", x = 115, z = 20, radius = 42, height = 12, count = 6 },
		{ rank = "Hard", name = "Mesetas Rocosas", x = -95, z = -115, radius = 40, height = 17, count = 4 },
		{ rank = "Boss", name = "Nave del Tirano", x = 25, z = -215, radius = 38, height = 22, count = 1 },
	},
	paths = {
		{
			width = 12,
			points = {
				{ 0, 225 },
				{ -50, 200 },
				{ -120, 130 },
				{ -20, 80 },
				{ 115, 20 },
				{ 60, -60 },
				{ -95, -115 },
				{ -50, -185 },
				{ 25, -215 },
			},
		},
	},
	mesas = {
		-- In the sea, around the island.
		{ x = 494, z = 175, radius = 38, height = 58 },
		{ x = -512, z = 50, radius = 44, height = 72 },
		{ x = 413, z = -313, radius = 32, height = 48 },
		{ x = -375, z = -400, radius = 40, height = 64 },
		{ x = 250, z = 463, radius = 28, height = 40 },
		{ x = -325, z = 438, radius = 34, height = 52 },
		{ x = 569, z = -88, radius = 26, height = 44 },
		{ x = -150, z = -538, radius = 36, height = 80 },
		{ x = 163, z = -519, radius = 30, height = 60 },
		-- Inland, around the rocky zone.
		{ x = -185, z = -170, radius = 28, height = 48 },
		{ x = -10, z = -135, radius = 20, height = 36 },
		{ x = 210, z = -120, radius = 26, height = 40 },
	},
	materials = { grass = "Grass", path = "Ground", plaza = "Pavement", cliff = "Rock", beach = "Sand", seabed = "Mud" },
}

return layout
