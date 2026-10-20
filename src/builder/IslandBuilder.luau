--!strict
-- Builds one island end to end from its definition (Islands/<Id>): terrain
-- and sea, cartoon sea dressing, gameplay pieces placed from the layout, the
-- island's decoration, and camera spots for screenshots. Everything goes under
-- Workspace.Map.<IslandId>, except the "Manual" folder, which is never touched
-- so hand-made additions survive rebuilds.

local ServerStorage = game:GetService("ServerStorage")

local Root = script.Parent
local Shared = Root.Shared
local Islands = require(Shared.Data.Islands)
local World = require(Shared.Config.World)
local LayoutCheck = require(Root.Gen.LayoutCheck)
local Rng = require(Root.Gen.Rng)
local Scatter = require(Root.Gen.Scatter)
local Shape = require(Root.Gen.Shape)
local Gameplay = require(Root.Kit.Gameplay)
local Parts = require(Root.Kit.Parts)
local Sea = require(Root.Kit.Sea)
local TerrainWriter = require(Root.Kit.TerrainWriter)

export type Context = {
	islandId: string,
	layout: Shape.Layout,
	cx: number,
	cz: number,
	decor: Folder,
	rng: Rng.Rng,
	accent: Color3,
	-- Absolute ground point for coordinates relative to the island center.
	ground: (x: number, z: number) -> Vector3,
	-- Whether a spot is open land, away from paths, the plaza and combat zones.
	isFree: (x: number, z: number, margin: number) -> boolean,
}

export type PhotoSpot = { from: { number }, to: { number } } -- relative { x, y, z }

export type Definition = {
	layout: Shape.Layout,
	decorate: (Context) -> (),
	photoSpots: { PhotoSpot },
}

local ENEMY_SPACING = LayoutCheck.ENEMY_SPACING
local MANUAL_FOLDER = "Manual"

local IslandBuilder = {}

local function getMap(): Folder
	local map = workspace:FindFirstChild("Map")
	if map and map:IsA("Folder") then
		return map
	end
	return Parts.folder("Map", workspace)
end

-- Area folder, emptied except for the Manual folder.
function IslandBuilder.areaFolder(areaId: string): Folder
	local map = getMap()
	local folder = map:FindFirstChild(areaId)
	if folder == nil or not folder:IsA("Folder") then
		folder = Parts.folder(areaId, map)
	end
	assert(folder and folder:IsA("Folder"), "unreachable")
	for _, child in folder:GetChildren() do
		if child.Name ~= MANUAL_FOLDER then
			child:Destroy()
		end
	end
	if folder:FindFirstChild(MANUAL_FOLDER) == nil then
		Parts.folder(MANUAL_FOLDER, folder)
	end
	return folder
end

local function yawToward(fromX: number, fromZ: number, toX: number, toZ: number): number
	return math.atan2(-(toX - fromX), -(toZ - fromZ))
end

local function savePhotoSpots(areaId: string, spots: { PhotoSpot }, cx: number, cy: number, cz: number)
	local root = ServerStorage:FindFirstChild("PhotoSpots") or Parts.folder("PhotoSpots", ServerStorage)
	local existing = root:FindFirstChild(areaId)
	if existing then
		existing:Destroy()
	end
	local folder = Parts.folder(areaId, root)
	for index, spot in spots do
		local value = Instance.new("CFrameValue")
		value.Name = string.format("%02d", index)
		local from = Vector3.new(cx + spot.from[1], cy + spot.from[2], cz + spot.from[3])
		local to = Vector3.new(cx + spot.to[1], cy + spot.to[2], cz + spot.to[3])
		value.Value = CFrame.lookAt(from, to)
		value.Parent = folder
	end
end
IslandBuilder.savePhotoSpots = savePhotoSpots

-- Plaza: arrival on the outer side, gacha toward the island center, portals
-- (and the raid portal on the first island) to the sides, all facing the center.
local function buildPlaza(context: Context, gameplay: Folder)
	local layout, islandId = context.layout, context.islandId
	local plaza = layout.plaza
	local inX, inZ = -plaza.x, -plaza.z
	local length = math.sqrt(inX * inX + inZ * inZ)
	if length < 1 then
		inX, inZ, length = 0, -1, 1
	end
	inX, inZ = inX / length, inZ / length
	local rightX, rightZ = -inZ, inX
	local r = plaza.radius

	local function at(along: number, side: number): (number, number)
		return plaza.x + inX * along + rightX * side, plaza.z + inZ * along + rightZ * side
	end
	local function place(x: number, z: number): (number, number, number)
		return context.cx + x, context.layout.plaza.height, context.cz + z
	end

	local ax, az = at(-r * 0.5, 0)
	local x, y, z = place(ax, az)
	Gameplay.arrival(islandId, x, y, z, gameplay)

	local gx, gz = at(r * 0.55, 0)
	x, y, z = place(gx, gz)
	Gameplay.gacha(islandId, x, y, z, context.accent, gameplay)

	local island = Islands.get(islandId)
	local nextIsland = Islands.List[island.order + 1]
	local previousIsland = Islands.List[island.order - 1]
	local function portalAt(side: number, build: (number, number, number, number) -> ())
		local px, pz = at(0, side * r * 0.62)
		local wx, wy, wz = place(px, pz)
		build(wx, wy, wz, yawToward(px, pz, plaza.x, plaza.z))
	end
	if nextIsland then
		portalAt(1, function(wx, wy, wz, yaw)
			Gameplay.islandPortal(nextIsland.id, wx, wy, wz, yaw, gameplay)
		end)
	end
	if previousIsland then
		portalAt(-1, function(wx, wy, wz, yaw)
			Gameplay.islandPortal(previousIsland.id, wx, wy, wz, yaw, gameplay)
		end)
	else
		portalAt(-1, function(wx, wy, wz, yaw)
			Gameplay.raidPortal(wx, wy, wz, yaw, gameplay)
		end)
	end
end

local function buildZones(context: Context, gameplay: Folder)
	local layout = context.layout
	for _, zone in layout.zones do
		local points = Scatter.spawnPoints(context.rng, zone.x, zone.z, zone.radius * LayoutCheck.SPAWN_AREA, zone.count, ENEMY_SPACING)
		for _, point in points do
			Gameplay.enemySpawn(context.islandId, zone.rank, context.cx + point.x, zone.height, context.cz + point.z, gameplay)
		end
		-- Sign at the zone's edge on the plaza side, readable on the way in.
		local dx, dz = layout.plaza.x - zone.x, layout.plaza.z - zone.z
		local length = math.max(1, math.sqrt(dx * dx + dz * dz))
		local sx, sz = zone.x + dx / length * (zone.radius + 4), zone.z + dz / length * (zone.radius + 4)
		local ground = context.ground(sx, sz)
		Gameplay.zoneSign(zone.name, zone.rank, ground.X, ground.Y, ground.Z, yawToward(sx, sz, layout.plaza.x, layout.plaza.z), context.accent, gameplay)
	end
end

function IslandBuilder.build(islandId: string, definition: Definition, onStatus: (string) -> ())
	local island = Islands.get(islandId)
	local cx, cz = World.islandCenter(island.order)
	local layout = definition.layout
	layout.seaFloor = World.SeaLevel - World.SeaDepth
	for _, problem in LayoutCheck.run(layout) do
		warn(`[IslandBuilder] {problem}`)
	end

	onStatus(`{island.displayName}: limpiando`)
	local folder = IslandBuilder.areaFolder(islandId)

	onStatus(`{island.displayName}: terreno y mar`)
	TerrainWriter.writeIsland(layout, cx, cz, function(fraction)
		onStatus(`{island.displayName}: terreno {math.floor(fraction * 100)}%`)
	end)
	Sea.build(layout, cx, cz, folder)

	local context: Context = {
		islandId = islandId,
		layout = layout,
		cx = cx,
		cz = cz,
		decor = Parts.folder("Decor", folder),
		rng = Rng.new(layout.seed),
		accent = Parts.rgb(World.AccentColors[islandId]),
		ground = function(x: number, z: number): Vector3
			return Vector3.new(cx + x, Shape.height(layout, x, z), cz + z)
		end,
		isFree = function(x: number, z: number, margin: number): boolean
			if Shape.coastFraction(layout, x, z) > 0.9 or Shape.height(layout, x, z) < 3 then
				return false
			end
			if Shape.pathInside(layout, x, z) > -margin then
				return false
			end
			local plaza = layout.plaza
			if (x - plaza.x) ^ 2 + (z - plaza.z) ^ 2 < (plaza.radius + margin) ^ 2 then
				return false
			end
			for _, zone in layout.zones do
				if (x - zone.x) ^ 2 + (z - zone.z) ^ 2 < (zone.radius + margin) ^ 2 then
					return false
				end
			end
			return Shape.slope(layout, x, z) < 0.7
		end,
	}

	onStatus(`{island.displayName}: jugabilidad`)
	local gameplay = Parts.folder("Gameplay", folder)
	buildPlaza(context, gameplay)
	buildZones(context, gameplay)

	onStatus(`{island.displayName}: decoración`)
	definition.decorate(context)

	savePhotoSpots(islandId, definition.photoSpots, cx, World.SeaLevel, cz)
	onStatus(`{island.displayName}: lista`)
end

return IslandBuilder
