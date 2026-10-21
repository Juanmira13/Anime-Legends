--!strict
-- Raid lobby: a temple floating in the sky. Round stone platform with a ring
-- of pillars, one altar pad per difficulty, the portal back to the first
-- island, a rocky underside, crystals and clouds around it.

local Root = script.Parent
local Shared = Root.Shared
local Islands = require(Shared.Data.Islands)
local Raids = require(Shared.Config.Raids)
local World = require(Shared.Config.World)
local Rng = require(Root.Gen.Rng)
local Gameplay = require(Root.Kit.Gameplay)
local Parts = require(Root.Kit.Parts)
local IslandBuilder = require(Root.IslandBuilder)

local rgb = Parts.rgb

local AREA = "RaidLobby"
local PLATFORM_DIAMETER = 130
local STONE = rgb({ 225, 220, 235 })
local STONE_DARK = rgb({ 150, 140, 170 })
local ROCK = rgb({ 120, 105, 130 })
local CLOUD = rgb({ 255, 245, 255 })
local PAD_COLORS: { [string]: Color3 } = {
	Easy = rgb({ 110, 220, 120 }),
	Medium = rgb({ 255, 205, 70 }),
	Hard = rgb({ 240, 70, 70 }),
}

local RaidLobby = {}

function RaidLobby.build(onStatus: (string) -> ())
	onStatus("Lobby de Raids: construyendo")
	local folder = IslandBuilder.areaFolder(AREA)
	local decor = Parts.folder("Decor", folder)
	local gameplay = Parts.folder("Gameplay", folder)
	local rng = Rng.new(9090)
	local c = World.RaidLobbyCenter
	local center = Vector3.new(c[1], c[2], c[3])
	local accent = rgb(World.RaidAccentColor)
	local radius = PLATFORM_DIAMETER / 2

	-- Platform with an inlaid ring pattern.
	Parts.disc(PLATFORM_DIAMETER, 4, center - Vector3.new(0, 2, 0), STONE, decor, { collide = true })
	Parts.disc(PLATFORM_DIAMETER + 6, 2, center - Vector3.new(0, 3, 0), STONE_DARK, decor, { collide = true })
	Parts.disc(
		PLATFORM_DIAMETER * 0.62,
		0.3,
		center + Vector3.new(0, 0.05, 0),
		accent,
		decor,
		{ material = Enum.Material.Neon, shadow = false }
	)
	Parts.disc(PLATFORM_DIAMETER * 0.58, 0.4, center + Vector3.new(0, 0.1, 0), STONE, decor, { shadow = false })

	-- Rocky underside: stacked shrinking discs, like an upside-down mountain.
	for level = 1, 7 do
		local diameter = PLATFORM_DIAMETER * (1 - level * 0.12)
		local tilt = CFrame.Angles(Rng.range(rng, -0.05, 0.05), 0, Rng.range(rng, -0.05, 0.05))
		local position = center - Vector3.new(Rng.range(rng, -3, 3), 4 + level * 9, Rng.range(rng, -3, 3))
		local part = Parts.disc(diameter, 10, position, Parts.vary(ROCK, 0.25, level / 7), decor)
		part.CFrame = CFrame.new(position) * tilt * CFrame.Angles(0, 0, math.rad(90))
	end

	-- Ring of pillars, some broken.
	for index = 0, 15 do
		local angle = index / 16 * 2 * math.pi
		local base = center + Vector3.new(math.cos(angle) * (radius - 4), 0, math.sin(angle) * (radius - 4))
		local height = if index % 3 == 1 then Rng.range(rng, 6, 12) else 22
		Parts.column(4.5, 1.2, CFrame.new(base), STONE_DARK, decor, { collide = true })
		Parts.column(3.4, height, CFrame.new(base + Vector3.new(0, 1.2, 0)), STONE, decor, { collide = true })
		if height == 22 then
			Parts.column(4.5, 1.2, CFrame.new(base + Vector3.new(0, 23.2, 0)), STONE_DARK, decor, { shadow = false })
			local flame = Parts.ball(
				1.8,
				base + Vector3.new(0, 25.4, 0),
				accent,
				decor,
				{ material = Enum.Material.Neon, shadow = false }
			)
			if index % 4 == 0 then
				Parts.light(flame, accent, 22, 1.5)
			end
		end
	end

	-- Altars for each difficulty on the far side, arrival and portal on the near side.
	for index, difficulty in Raids.Difficulties do
		local angle = math.rad(-90 + (index - 2) * 38)
		local x, z = center.X + math.cos(angle) * radius * 0.55, center.Z + math.sin(angle) * radius * 0.55
		Gameplay.raidPad(
			difficulty.id,
			`Raid {difficulty.displayName}`,
			x,
			center.Y,
			z,
			PAD_COLORS[difficulty.id] or accent,
			gameplay
		)
	end
	Gameplay.raidLobbyArrival(center.X, center.Y, center.Z + radius * 0.35, gameplay)
	local first = Islands.List[1]
	local portalX, portalZ = center.X - radius * 0.45, center.Z + radius * 0.45
	Gameplay.islandPortal(
		first.id,
		portalX,
		center.Y,
		portalZ,
		math.atan2(-(center.X - portalX), -(center.Z - portalZ)),
		gameplay
	)

	-- Floating crystals and clouds around the temple.
	for index = 1, 10 do
		local angle = index / 10 * 2 * math.pi + Rng.range(rng, -0.2, 0.2)
		local distance = radius + Rng.range(rng, 18, 45)
		local position = center
			+ Vector3.new(math.cos(angle) * distance, Rng.range(rng, -10, 25), math.sin(angle) * distance)
		local crystal = Parts.block(
			Vector3.new(3, 8, 3),
			CFrame.new(position) * CFrame.Angles(Rng.range(rng, 0, 1), Rng.range(rng, 0, 6), Rng.range(rng, 0, 1)),
			accent,
			decor,
			{ material = Enum.Material.Neon, shadow = false }
		)
		crystal.Transparency = 0.15
	end
	for _ = 1, 26 do
		local angle = Rng.range(rng, 0, 2 * math.pi)
		local distance = Rng.range(rng, radius * 0.6, radius * 2.2)
		local position = center
			+ Vector3.new(math.cos(angle) * distance, Rng.range(rng, -70, -25), math.sin(angle) * distance)
		for puff = 1, 3 do
			local offset = Vector3.new(puff * 9 - 18, Rng.range(rng, -2, 3), Rng.range(rng, -5, 5))
			Parts.ball(Rng.range(rng, 14, 24), position + offset, CLOUD, decor, { transparency = 0.2, shadow = false })
		end
	end

	IslandBuilder.savePhotoSpots(AREA, {
		{ from = { 0, 30, radius + 40 }, to = { 0, 0, 0 } },
		{ from = { -160, 40, 160 }, to = { 0, -30, 0 } },
	}, center.X, center.Y, center.Z)
	onStatus("Lobby de Raids: listo")
end

return RaidLobby
