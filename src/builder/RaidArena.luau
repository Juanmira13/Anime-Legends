--!strict
-- Raid arena: a stone coliseum floating in the sky at dusk. A sand floor ringed
-- by a podium wall with torches, stepped stands, an outer wall with arches and
-- banners, two closed gates (the enemies' one glows red), the exit portal, a
-- rocky underside and clouds. Saved as ServerStorage.RaidArena, the template
-- RaidService clones for every raid group: pivoted on the center of the field,
-- with a FieldRadius attribute (enemies appear at random inside it), a
-- PlayerSpawn part and the "RaidExit" portal pad. A copy is left at
-- Workspace.RaidArenaPreview for screenshots; the server deletes it on start.

local ServerStorage = game:GetService("ServerStorage")

local Root = script.Parent
local Shared = Root.Shared
local World = require(Shared.Config.World)
local Rng = require(Root.Gen.Rng)
local Parts = require(Root.Kit.Parts)
local Gameplay = require(Root.Kit.Gameplay)
local IslandBuilder = require(Root.IslandBuilder)
local RaidArenaLayout = require(Root.RaidArenaLayout)

local rgb = Parts.rgb

local AREA = "Raid"
local PREVIEW_NAME = "RaidArenaPreview"
-- Far from the raid slots (they run along +X from x = 0 at this height).
local PREVIEW_CENTER = Vector3.new(-1500, 1500, 0)
-- Cool, neutral stone and pale sand: the dusk light already warms everything.
local SAND = rgb({ 224, 212, 184 })
local SAND_DARK = rgb({ 176, 160, 132 })
local STONE = rgb({ 206, 202, 196 })
local STONE_DARK = rgb({ 142, 138, 140 })
local SHADOW = rgb({ 70, 58, 52 })
local IRON = rgb({ 52, 52, 58 })
local GOLD = rgb({ 230, 180, 70 })
local FLAME = rgb({ 255, 150, 50 })
local DANGER = rgb({ 255, 50, 40 })
local ROCK = rgb({ 120, 100, 92 })
local CLOUD = rgb({ 255, 236, 226 })

local RaidArena = {}

-- Block on the ring at `radius` (its inner face toward the center), `depth`
-- deep and `height` tall from `bottom`, covering one segment around `angle`.
local function ringBlock(
	center: Vector3,
	angle: number,
	radius: number,
	depth: number,
	bottom: number,
	height: number,
	color: Color3,
	parent: Instance,
	options: Parts.Options?
): Part
	local layout = RaidArenaLayout
	local middle = radius + depth / 2
	local width = 2 * math.pi * (radius + depth) * layout.segmentDegrees / 360 + 0.4
	local position = center + Vector3.new(math.cos(angle) * middle, bottom + height / 2, math.sin(angle) * middle)
	local frame = CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z))
	return Parts.block(Vector3.new(width, height, depth), frame, color, parent, options)
end

-- Gap between two angles, in radians (0..pi).
local function angleGap(a: number, b: number): number
	return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
end

-- Closed gate on the podium wall: dark arch with iron bars, `glow` behind them.
local function gate(center: Vector3, angle: number, glow: Color3?, parent: Instance)
	local layout = RaidArenaLayout
	local model = Parts.model("Gate", parent)
	local radius = layout.floorRadius
	local position = center + Vector3.new(math.cos(angle) * (radius - 0.4), 0, math.sin(angle) * (radius - 0.4))
	local frame = CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z))
	local height = layout.podiumHeight + layout.tierRise
	Parts.block(Vector3.new(16, height, 1), frame * CFrame.new(0, height / 2, 0.4), SHADOW, model, { collide = true })
	if glow then
		local light = Parts.block(
			Vector3.new(12, height - 3, 0.2),
			frame * CFrame.new(0, (height - 3) / 2, -0.2),
			glow,
			model,
			{ material = Enum.Material.Neon, transparency = 0.35, shadow = false }
		)
		Parts.light(light, glow, 26, 2)
	end
	for index = -2, 2 do
		Parts.block(
			Vector3.new(0.6, height - 2, 0.6),
			frame * CFrame.new(index * 2.6, (height - 2) / 2, -0.6),
			IRON,
			model,
			{ collide = true, shadow = false }
		)
	end
	Parts.block(Vector3.new(13, 0.8, 0.8), frame * CFrame.new(0, height * 0.55, -0.6), IRON, model, { shadow = false })
	-- Stone frame and a golden keystone.
	for _, side in { -1, 1 } do
		Parts.block(
			Vector3.new(2.4, height + 2, 2.4),
			frame * CFrame.new(side * 9, (height + 2) / 2, -0.4),
			STONE_DARK,
			model,
			{
				collide = true,
			}
		)
	end
	Parts.block(
		Vector3.new(20.8, 2.4, 2.6),
		frame * CFrame.new(0, height + 1.6, -0.4),
		STONE_DARK,
		model,
		{ collide = true }
	)
	Parts.block(Vector3.new(3, 3, 2.8), frame * CFrame.new(0, height + 1.6, -0.6), GOLD, model, { shadow = false })
end

local function torch(base: Vector3, parent: Instance, withLight: boolean)
	local model = Parts.model("Torch", parent)
	Parts.column(0.9, 4.5, CFrame.new(base), IRON, model, { shadow = false })
	Parts.disc(2.6, 0.8, base + Vector3.new(0, 4.6, 0), IRON, model, { shadow = false })
	local flame =
		Parts.ball(1.8, base + Vector3.new(0, 5.6, 0), FLAME, model, { material = Enum.Material.Neon, shadow = false })
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 5
	fire.Color = FLAME
	fire.SecondaryColor = DANGER
	fire.Parent = flame
	if withLight then
		Parts.light(flame, FLAME, 14, 0.8)
	end
end

-- Invisible marker whose top face is level with the floor.
local function marker(name: string, center: Vector3, point: { number }, parent: Instance): Part
	return Parts.block(Vector3.new(4, 1, 4), CFrame.new(center + Vector3.new(point[1], -0.5, point[2])), SAND, parent, {
		transparency = 1,
		shadow = false,
		name = name,
	})
end

-- Builds the coliseum as a Model whose floor top is centered at `center`.
local function buildModel(center: Vector3): Model
	local layout = RaidArenaLayout
	local rng = Rng.new(7070)
	local accent = rgb(World.RaidAccentColor)
	local model = Instance.new("Model")
	model.Name = "RaidArena"
	local decor = Parts.folder("Decor", model)
	local step = math.rad(layout.segmentDegrees)
	local segments = math.floor(360 / layout.segmentDegrees + 0.5)

	-- Floor (the PrimaryPart): a square slab whose corners hide under the stands
	-- and inside the outer wall, so the round podium wall shapes the field (a big
	-- cylinder would show its facets). Its center is the model's pivot.
	local floorRadius = layout.floorRadius
	local half = floorRadius + 4
	local floor = Parts.block(
		Vector3.new(half * 2, layout.floorThickness, half * 2),
		CFrame.new(center - Vector3.new(0, layout.floorThickness / 2, 0)),
		SAND,
		model,
		{ collide = true, material = Enum.Material.Sand, name = "Floor" }
	)
	model.PrimaryPart = floor
	floor.PivotOffset = CFrame.new(0, layout.floorThickness / 2, 0)
	model:SetAttribute("FieldRadius", floorRadius)
	-- Inlaid rings, built from segments to stay round: a wide dark band and a
	-- golden circle in the middle.
	for index = 0, segments - 1 do
		local angle = index * step
		ringBlock(center, angle, floorRadius * 0.7, 2.5, -0.1, 0.3, SAND_DARK, decor, { shadow = false })
		ringBlock(center, angle, 12, 1.2, -0.1, 0.35, GOLD, decor, { shadow = false })
	end

	-- Podium wall and stepped stands, then the outer wall with arches and crenellations.
	for index = 0, segments - 1 do
		local angle = index * step
		for tier = 0, layout.tiers - 1 do
			local radius = floorRadius + tier * layout.tierDepth
			local height = layout.podiumHeight + tier * layout.tierRise
			local color = if tier % 2 == 0 then STONE else Parts.vary(STONE, 0.08, 0.7)
			ringBlock(
				center,
				angle,
				radius,
				layout.tierDepth,
				-layout.floorThickness,
				height + layout.floorThickness,
				color,
				decor,
				{
					collide = true,
				}
			)
		end
		ringBlock(center, angle, floorRadius - 0.3, 0.4, 6, 1, GOLD, decor, { shadow = false })
		local outer = floorRadius + layout.tiers * layout.tierDepth
		ringBlock(
			center,
			angle,
			outer,
			layout.outerWallThickness,
			-layout.floorThickness,
			layout.outerWallHeight + layout.floorThickness,
			STONE_DARK,
			decor,
			{
				collide = true,
			}
		)
		if index % 2 == 0 then
			-- Arch on the outside face and a merlon on top.
			ringBlock(center, angle, outer + layout.outerWallThickness, 0.4, 8, 14, SHADOW, decor, { shadow = false })
			ringBlock(center, angle, outer, layout.outerWallThickness, layout.outerWallHeight, 3, STONE_DARK, decor, {
				collide = true,
			})
		end
	end

	-- Gates: players come in from the south, enemies from the glowing north gate.
	gate(center, layout.playerGate, nil, decor)
	gate(center, layout.enemyGate, DANGER, decor)

	-- Torches along the top of the podium wall, away from the gates.
	for index = 0, 11 do
		local angle = index / 12 * 2 * math.pi + math.pi / 12
		if angleGap(angle, layout.playerGate) > 0.3 and angleGap(angle, layout.enemyGate) > 0.3 then
			local radius = floorRadius + 2.5
			torch(
				center + Vector3.new(math.cos(angle) * radius, layout.podiumHeight, math.sin(angle) * radius),
				decor,
				index % 2 == 0
			)
		end
	end

	-- Banners in the raid color on the inside of the outer wall.
	local bannerRadius = floorRadius + layout.tiers * layout.tierDepth - 0.3
	local bannerTop = layout.outerWallHeight - 1
	for index = 0, 7 do
		local angle = index / 8 * 2 * math.pi
		local position = center
			+ Vector3.new(math.cos(angle) * bannerRadius, bannerTop - 4, math.sin(angle) * bannerRadius)
		local frame = CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z))
		Parts.block(Vector3.new(6, 8, 0.3), frame, accent, decor, { shadow = false })
		Parts.block(Vector3.new(6.6, 0.6, 0.6), frame * CFrame.new(0, 4.2, 0), GOLD, decor, { shadow = false })
		Parts.block(Vector3.new(2, 2, 0.4), frame * CFrame.new(0, 0.5, -0.2), GOLD, decor, {
			material = Enum.Material.Neon,
			shadow = false,
		})
	end

	-- Rocky underside: stacked shrinking discs, like an upside-down mountain.
	local outerRadius = RaidArenaLayout.outerRadius()
	for level = 1, 8 do
		local diameter = outerRadius * 2 * (1 - level * 0.11)
		local tilt = CFrame.Angles(Rng.range(rng, -0.04, 0.04), 0, Rng.range(rng, -0.04, 0.04))
		local position = center
			- Vector3.new(Rng.range(rng, -4, 4), layout.floorThickness + level * 10, Rng.range(rng, -4, 4))
		local part = Parts.disc(diameter, 12, position, Parts.vary(ROCK, 0.25, level / 8), decor)
		part.CFrame = CFrame.new(position) * tilt * CFrame.Angles(0, 0, math.rad(90))
	end

	-- Clouds below the arena (kept inside half the spacing between raid arenas).
	for _ = 1, 14 do
		local angle = Rng.range(rng, 0, 2 * math.pi)
		local distance = Rng.range(rng, outerRadius * 0.5, outerRadius * 1.3)
		local position = center
			+ Vector3.new(math.cos(angle) * distance, Rng.range(rng, -80, -35), math.sin(angle) * distance)
		for puff = 1, 3 do
			local offset = Vector3.new(puff * 10 - 20, Rng.range(rng, -2, 3), Rng.range(rng, -5, 5))
			Parts.ball(Rng.range(rng, 16, 26), position + offset, CLOUD, decor, { transparency = 0.2, shadow = false })
		end
	end

	-- Where players arrive, and the portal back to the lobby behind them.
	marker("PlayerSpawn", center, layout.playerSpawn, model)
	local exit = layout.exitPortal
	Gameplay.raidExit(center.X + exit[1], center.Y, center.Z + exit[2], 0, model)
	return model
end

function RaidArena.build(onStatus: (string) -> ())
	onStatus("Arena de Raid: construyendo")
	local old = ServerStorage:FindFirstChild("RaidArena")
	if old then
		old:Destroy()
	end
	local oldPreview = workspace:FindFirstChild(PREVIEW_NAME)
	if oldPreview then
		oldPreview:Destroy()
	end

	local template = buildModel(PREVIEW_CENTER)
	local preview = template:Clone()
	preview.Name = PREVIEW_NAME
	preview.Parent = workspace
	template.Parent = ServerStorage

	local radius = RaidArenaLayout.outerRadius()
	IslandBuilder.savePhotoSpots(AREA, {
		{ from = { 0, 90, radius + 70 }, to = { 0, 0, -10 } }, -- the whole coliseum
		{ from = { 0, 8, 72 }, to = { 0, 6, -30 } }, -- arriving: the field and the enemy gate
		{ from = { -radius * 1.6, -20, radius * 1.4 }, to = { 0, -30, 0 } }, -- floating, from below
	}, PREVIEW_CENTER.X, PREVIEW_CENTER.Y, PREVIEW_CENTER.Z)
	onStatus("Arena de Raid: lista (plantilla en ServerStorage.RaidArena)")
end

return RaidArena
