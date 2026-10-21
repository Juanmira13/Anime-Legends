--!strict
-- Look of each area (island, raid lobby, raid arena): lighting, sky, fog,
-- color grading, terrain and water colors and ambient particles. The client
-- blends to the area in the player attribute "CurrentArea". Colors are RGB
-- tables so this module stays pure and testable. See docs/game-design.md
-- (Dirección de arte).

export type RGB = { number }

export type Ambience = {
	clockTime: number, -- 0..24
	brightness: number,
	ambient: RGB,
	outdoorAmbient: RGB,
	colorShiftTop: RGB,
	atmosphere: {
		density: number,
		offset: number,
		color: RGB,
		decay: RGB,
		glare: number,
		haze: number,
	},
	colorCorrection: { brightness: number, contrast: number, saturation: number, tint: RGB },
	bloom: { intensity: number, size: number, threshold: number },
	sunRays: { intensity: number, spread: number },
	stars: number, -- star count in the sky
	water: { color: RGB, transparency: number, reflectance: number, waveSize: number, waveSpeed: number },
	-- Terrain material colors (Roblox material name -> color).
	terrain: { [string]: RGB },
	-- Ambient particles around the camera; nil for none.
	particles: { color: RGB, rate: number, size: number, speed: number, lifetime: number, light: number }?,
}

-- Sand and seafloor colors shared by the sunny islands.
local SAND = { 240, 222, 170 }

local Areas: { [string]: Ambience } = {
	-- Alien planet: green sky, turquoise water, blue-green grass, bright day.
	Nameku = {
		clockTime = 13,
		brightness = 3,
		ambient = { 90, 120, 110 },
		outdoorAmbient = { 140, 170, 150 },
		colorShiftTop = { 200, 255, 220 },
		atmosphere = {
			density = 0.24,
			offset = 0.2,
			color = { 175, 230, 190 },
			decay = { 120, 200, 150 },
			glare = 0.4,
			haze = 1.2,
		},
		colorCorrection = { brightness = 0.02, contrast = 0.1, saturation = 0.1, tint = { 248, 255, 250 } },
		bloom = { intensity = 0.6, size = 28, threshold = 1.6 },
		sunRays = { intensity = 0.08, spread = 0.6 },
		stars = 0,
		water = { color = { 30, 160, 172 }, transparency = 0.25, reflectance = 0.08, waveSize = 0.06, waveSpeed = 8 },
		terrain = {
			Grass = { 85, 175, 125 },
			LeafyGrass = { 70, 160, 120 },
			Sand = SAND,
			Rock = { 120, 140, 150 },
			Slate = { 95, 115, 130 },
			Ground = { 175, 160, 120 },
			Mud = { 35, 110, 115 }, -- sea floor: deep water tone
			Pavement = { 170, 190, 178 },
		},
		particles = { color = { 220, 255, 200 }, rate = 6, size = 0.25, speed = 1, lifetime = 8, light = 0.6 },
	},

	-- Ninja village in the forest at a warm sunset.
	Kono = {
		clockTime = 17.2,
		brightness = 2.6,
		ambient = { 120, 95, 80 },
		outdoorAmbient = { 170, 135, 110 },
		colorShiftTop = { 255, 205, 160 },
		atmosphere = {
			density = 0.22,
			offset = 0.15,
			color = { 255, 205, 160 },
			decay = { 210, 140, 100 },
			glare = 0.6,
			haze = 1.2,
		},
		colorCorrection = { brightness = 0.02, contrast = 0.1, saturation = 0.2, tint = { 255, 244, 232 } },
		bloom = { intensity = 0.7, size = 30, threshold = 1.5 },
		sunRays = { intensity = 0.12, spread = 0.7 },
		stars = 0,
		water = { color = { 35, 130, 175 }, transparency = 0.25, reflectance = 0.2, waveSize = 0.06, waveSpeed = 8 },
		terrain = {
			Grass = { 95, 160, 60 },
			LeafyGrass = { 70, 130, 45 },
			Sand = SAND,
			Rock = { 140, 125, 110 },
			Slate = { 110, 100, 95 },
			Ground = { 150, 115, 80 },
			Mud = { 40, 85, 110 },
			Pavement = { 190, 175, 155 },
			Cobblestone = { 172, 158, 140 },
		},
		particles = { color = { 140, 200, 80 }, rate = 3, size = 0.35, speed = 2, lifetime = 9, light = 0 },
	},

	-- Magic medieval kingdom: clear day with violet sparkles.
	CloverKingdom = {
		clockTime = 11,
		brightness = 2.8,
		ambient = { 100, 100, 130 },
		outdoorAmbient = { 150, 150, 175 },
		colorShiftTop = { 230, 225, 255 },
		atmosphere = {
			density = 0.22,
			offset = 0.2,
			color = { 205, 215, 255 },
			decay = { 150, 140, 220 },
			glare = 0.3,
			haze = 1.1,
		},
		colorCorrection = { brightness = 0.02, contrast = 0.08, saturation = 0.2, tint = { 248, 245, 255 } },
		bloom = { intensity = 0.7, size = 28, threshold = 1.5 },
		sunRays = { intensity = 0.08, spread = 0.6 },
		stars = 0,
		water = { color = { 40, 120, 190 }, transparency = 0.25, reflectance = 0.2, waveSize = 0.06, waveSpeed = 8 },
		terrain = {
			Grass = { 105, 185, 80 },
			LeafyGrass = { 80, 150, 70 },
			Sand = SAND,
			Rock = { 165, 160, 155 },
			Slate = { 120, 115, 130 },
			Ground = { 160, 130, 95 },
			Mud = { 45, 80, 120 },
			Pavement = { 215, 210, 200 },
			Cobblestone = { 178, 172, 164 },
		},
		particles = { color = { 200, 160, 255 }, rate = 4, size = 0.3, speed = 1, lifetime = 7, light = 0.8 },
	},

	-- Walled city in danger: overcast and desaturated.
	TitanVillage = {
		clockTime = 15,
		brightness = 1.8,
		ambient = { 110, 105, 100 },
		outdoorAmbient = { 145, 140, 135 },
		colorShiftTop = { 210, 205, 195 },
		atmosphere = {
			density = 0.3,
			offset = 0.1,
			color = { 200, 195, 185 },
			decay = { 150, 140, 130 },
			glare = 0,
			haze = 1.8,
		},
		colorCorrection = { brightness = 0, contrast = 0.12, saturation = -0.15, tint = { 250, 246, 240 } },
		bloom = { intensity = 0.4, size = 24, threshold = 1.8 },
		sunRays = { intensity = 0.02, spread = 0.4 },
		stars = 0,
		water = { color = { 70, 120, 140 }, transparency = 0.4, reflectance = 0.15, waveSize = 0.08, waveSpeed = 9 },
		terrain = {
			Grass = { 110, 140, 70 },
			LeafyGrass = { 90, 115, 60 },
			Sand = { 210, 195, 160 },
			Rock = { 150, 140, 125 },
			Slate = { 115, 110, 105 },
			Ground = { 140, 115, 85 },
			Mud = { 60, 75, 80 },
			Pavement = { 165, 155, 140 },
			Cobblestone = { 150, 142, 130 },
		},
		particles = { color = { 220, 210, 190 }, rate = 3, size = 0.2, speed = 1.5, lifetime = 8, light = 0 },
	},

	-- Modern hero city: clean blue midday with reflections.
	HeroAcademy = {
		clockTime = 12.5,
		brightness = 3,
		ambient = { 110, 115, 130 },
		outdoorAmbient = { 160, 165, 180 },
		colorShiftTop = { 235, 240, 255 },
		atmosphere = {
			density = 0.2,
			offset = 0.2,
			color = { 200, 220, 255 },
			decay = { 120, 160, 230 },
			glare = 0.4,
			haze = 1,
		},
		colorCorrection = { brightness = 0.02, contrast = 0.1, saturation = 0.15, tint = { 248, 250, 255 } },
		bloom = { intensity = 0.6, size = 26, threshold = 1.6 },
		sunRays = { intensity = 0.06, spread = 0.5 },
		stars = 0,
		water = { color = { 35, 115, 190 }, transparency = 0.25, reflectance = 0.3, waveSize = 0.06, waveSpeed = 8 },
		terrain = {
			Grass = { 100, 180, 80 },
			LeafyGrass = { 80, 150, 65 },
			Sand = SAND,
			Rock = { 150, 150, 155 },
			Slate = { 110, 110, 120 },
			Ground = { 150, 130, 100 },
			Mud = { 40, 75, 115 },
			Pavement = { 142, 146, 154 }, -- city ground: lighter tones wash out to white in the sun
			Asphalt = { 74, 76, 84 },
			Concrete = { 166, 167, 173 },
		},
		particles = nil,
	},

	-- Traditional Japan at night: full moon, wisteria and lanterns.
	DemonCorps = {
		clockTime = 0.5,
		brightness = 2.4,
		ambient = { 110, 100, 155 },
		outdoorAmbient = { 150, 135, 200 },
		colorShiftTop = { 170, 160, 255 },
		atmosphere = {
			density = 0.26,
			offset = 0.1,
			color = { 120, 105, 180 },
			decay = { 80, 60, 135 },
			glare = 0.2,
			haze = 1.2,
		},
		colorCorrection = { brightness = 0.06, contrast = 0.12, saturation = 0.1, tint = { 235, 228, 255 } },
		bloom = { intensity = 1, size = 32, threshold = 1.2 },
		sunRays = { intensity = 0.02, spread = 0.4 },
		stars = 3000,
		water = { color = { 40, 60, 120 }, transparency = 0.3, reflectance = 0.35, waveSize = 0.06, waveSpeed = 7 },
		terrain = {
			Grass = { 70, 110, 80 },
			LeafyGrass = { 60, 95, 75 },
			Sand = { 190, 180, 160 },
			Rock = { 110, 105, 120 },
			Slate = { 85, 80, 100 },
			Ground = { 110, 90, 75 },
			Mud = { 35, 40, 75 },
			Pavement = { 140, 135, 145 },
		},
		particles = { color = { 220, 170, 255 }, rate = 8, size = 0.3, speed = 1.5, lifetime = 8, light = 0.5 },
	},

	-- Floating temple in the sky above the clouds.
	RaidLobby = {
		clockTime = 18,
		brightness = 2.4,
		ambient = { 110, 90, 140 },
		outdoorAmbient = { 160, 130, 190 },
		colorShiftTop = { 255, 200, 240 },
		atmosphere = {
			density = 0.25,
			offset = 0.4,
			color = { 230, 190, 240 },
			decay = { 160, 110, 200 },
			glare = 0.8,
			haze = 1,
		},
		colorCorrection = { brightness = 0.03, contrast = 0.1, saturation = 0.25, tint = { 255, 245, 255 } },
		bloom = { intensity = 0.9, size = 30, threshold = 1.3 },
		sunRays = { intensity = 0.15, spread = 0.8 },
		stars = 500,
		water = { color = { 60, 120, 200 }, transparency = 0.35, reflectance = 0.25, waveSize = 0.06, waveSpeed = 8 },
		terrain = {},
		particles = { color = { 255, 210, 255 }, rate = 6, size = 0.3, speed = 1, lifetime = 8, light = 0.8 },
	},

	-- Raid arena: dramatic dusk.
	Raid = {
		clockTime = 19,
		brightness = 2,
		ambient = { 120, 80, 80 },
		outdoorAmbient = { 160, 110, 100 },
		colorShiftTop = { 255, 170, 130 },
		atmosphere = {
			density = 0.3,
			offset = 0.3,
			color = { 230, 160, 130 },
			decay = { 160, 80, 80 },
			glare = 0.6,
			haze = 1.5,
		},
		colorCorrection = { brightness = 0.02, contrast = 0.15, saturation = 0.15, tint = { 255, 240, 232 } },
		bloom = { intensity = 0.8, size = 28, threshold = 1.4 },
		sunRays = { intensity = 0.1, spread = 0.6 },
		stars = 300,
		water = { color = { 60, 120, 200 }, transparency = 0.35, reflectance = 0.25, waveSize = 0.06, waveSpeed = 8 },
		terrain = {},
		particles = { color = { 255, 170, 90 }, rate = 4, size = 0.25, speed = 2, lifetime = 6, light = 0.9 },
	},
}

local Ambience = {
	Areas = Areas,
	-- Area used before the server reports one.
	DefaultArea = "Nameku",
}

function Ambience.get(areaId: string): Ambience
	return Areas[areaId] or Areas[Ambience.DefaultArea]
end

return Ambience
