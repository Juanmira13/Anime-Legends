--!strict
-- World layout: where each island sits in the sea, the sea itself and the raid
-- lobby. Plain numbers only (no Roblox types) so it can be unit tested; the
-- island builder plugin and the client read it. See docs/game-design.md.

export type RGB = { number } -- { r, g, b } in 0..255

local World = {
	SeaLevel = 0, -- y of the water surface
	SeaDepth = 24, -- studs of water down to the sea floor
	IslandSpacing = 2000, -- studs between island centers, along +X in progression order
	AreaSize = 2000, -- each island owns a square of sea this wide around its center
	OceanMargin = 4000, -- open ocean around all the islands, so the sea reaches the horizon

	Sea = {
		-- Cartoon overlay over the terrain water: a tiling texture with
		-- transparent background (assets/Textures/SeaCartoon.png). Empty until
		-- the image is uploaded to Roblox; the water still shows its color.
		textureId = "",
		studsPerTile = 48,
		textureTransparency = 0.1,
		scrollSpeed = { 1.6, 0.9 }, -- studs per second along U and V
		foamWidth = 3, -- studs of foam ring at each shore
		foamOffset = 2, -- studs from the shoreline out to sea
	},

	-- The raid lobby is a temple floating in the sky, away from the islands.
	RaidLobbyCenter = { 0, 450, -1700 },

	-- Accent color per island: portals to it and its map labels.
	AccentColors = {
		Nameku = { 90, 220, 140 },
		Kono = { 255, 140, 50 },
		CloverKingdom = { 120, 200, 255 },
		TitanVillage = { 190, 150, 110 },
		HeroAcademy = { 230, 60, 70 },
		DemonCorps = { 190, 110, 255 },
	} :: { [string]: RGB },
	RaidAccentColor = { 170, 80, 255 } :: RGB,
}

-- Center of an island on the sea plane (x, z), from its progression order.
function World.islandCenter(order: number): (number, number)
	return (order - 1) * World.IslandSpacing, 0
end

return World
