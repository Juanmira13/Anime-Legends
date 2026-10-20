--!strict
-- Layouts of the islands that are still v0: one shared skeleton (plaza, four
-- zones along one path, mesas at sea) with each island's own seed, mirroring,
-- zone names and terrain materials. Pure data, so the tests check it
-- (LayoutCheck); Islands/Generic decorates it.

local Shape = require(script.Parent.Parent.Gen.Shape)

export type Params = {
	seed: number,
	mirror: boolean, -- mirrors the skeleton left/right for variety
	zoneNames: { string }, -- Easy, Medium, Hard, Boss
	mesaCount: number,
	grass: string, -- terrain material of the meadows
	path: string,
}

local GenericLayout = {}

GenericLayout.Params = {
	Kono = {
		seed = 2202,
		mirror = true,
		zoneNames = { "Campo de Entrenamiento", "Calles de la Aldea", "Bosque Profundo", "Valle de la Cascada" },
		mesaCount = 3,
		grass = "Grass",
		path = "Ground",
	},
	CloverKingdom = {
		seed = 3303,
		mirror = false,
		zoneNames = { "Aldea Humilde", "Camino Real", "Bosque Embrujado", "Altar del Grimorio" },
		mesaCount = 4,
		grass = "Grass",
		path = "Pavement",
	},
	TitanVillage = {
		seed = 4404,
		mirror = true,
		zoneNames = { "Campos Exteriores", "Ciudad Amurallada", "Bosque Gigante", "Brecha del Muro" },
		mesaCount = 2,
		grass = "Grass",
		path = "Ground",
	},
	HeroAcademy = {
		seed = 5505,
		mirror = false,
		zoneNames = { "Campus", "Avenida Central", "Ciudad Simulacro", "Gran Estadio" },
		mesaCount = 2,
		grass = "Grass",
		path = "Pavement",
	},
	DemonCorps = {
		seed = 6606,
		mirror = true,
		zoneNames = { "Aldea de Faroles", "Bosque de Bambú", "Montaña de Toriis", "Tren de la Luna" },
		mesaCount = 3,
		grass = "Grass",
		path = "Ground",
	},
} :: { [string]: Params }

local SEA_MESAS = {
	{ x = 494, z = 175, radius = 38, height = 58 },
	{ x = -512, z = 50, radius = 44, height = 72 },
	{ x = 413, z = -313, radius = 32, height = 48 },
	{ x = -375, z = -400, radius = 40, height = 64 },
	{ x = -325, z = 438, radius = 34, height = 52 },
	{ x = 163, z = -519, radius = 30, height = 60 },
}

function GenericLayout.layoutFor(islandId: string): Shape.Layout
	local params = GenericLayout.Params[islandId]
	assert(params, `No generic layout for {islandId}`)
	local m = if params.mirror then -1 else 1
	local mesas = {}
	for index = 1, math.min(params.mesaCount, #SEA_MESAS) do
		local mesa = SEA_MESAS[index]
		table.insert(mesas, { x = mesa.x * m, z = mesa.z, radius = mesa.radius, height = mesa.height })
	end
	local names = params.zoneNames
	return {
		id = islandId,
		seed = params.seed,
		radius = 390,
		coastNoise = 0.12,
		baseHeight = 9,
		hillHeight = 14,
		hillScale = 130,
		beachWidth = 32,
		seaFloor = -24,
		plaza = { x = 0, z = 225, radius = 36, height = 7 },
		zones = {
			{ rank = "Easy", name = names[1], x = -120 * m, z = 130, radius = 46, height = 8, count = 8 },
			{ rank = "Medium", name = names[2], x = 115 * m, z = 20, radius = 42, height = 12, count = 6 },
			{ rank = "Hard", name = names[3], x = -95 * m, z = -115, radius = 40, height = 17, count = 4 },
			{ rank = "Boss", name = names[4], x = 25 * m, z = -215, radius = 38, height = 22, count = 1 },
		},
		paths = {
			{
				width = 12,
				points = {
					{ 0, 225 },
					{ -50 * m, 200 },
					{ -120 * m, 130 },
					{ -20 * m, 80 },
					{ 115 * m, 20 },
					{ 60 * m, -60 },
					{ -95 * m, -115 },
					{ -50 * m, -185 },
					{ 25 * m, -215 },
				},
			},
		},
		mesas = mesas,
		materials = { grass = params.grass, path = params.path, plaza = "Pavement", cliff = "Rock", beach = "Sand", seabed = "Mud" },
	}
end

return GenericLayout
