--!strict
-- Cartoon sea dressing for an island: a textured surface over the terrain
-- water (tag "SeaSurface", its Texture scrolls on the client) and rings of
-- foam along every shore (tag "SeaFoam", pulsed on the client). Also the open
-- ocean around all the islands, out to the horizon.

local CollectionService = game:GetService("CollectionService")

local Root = script.Parent.Parent
local Shape = require(Root.Gen.Shape)
local Islands = require(Root.Shared.Data.Islands)
local World = require(Root.Shared.Config.World)
local Parts = require(script.Parent.Parts)

local FOAM_SEGMENT = 7 -- studs of shore per foam segment
local FOAM_COLOR = Color3.fromRGB(245, 252, 255)
local SURFACE_HEIGHT = 0.15 -- studs above the sea level, to avoid z-fighting
local MAX_PART_SIZE = 2048

local Sea = {}

local function surface(cx: number, cz: number, parent: Instance)
	local seaConfig = World.Sea
	-- Transparent carrier part; only its texture shows.
	local size = math.min(World.AreaSize, MAX_PART_SIZE)
	local part = Parts.block(Vector3.new(size, 0.2, size), CFrame.new(cx, World.SeaLevel + SURFACE_HEIGHT, cz), Color3.new(1, 1, 1), parent, {
		transparency = 1,
		shadow = false,
		name = "SeaSurface",
	})
	part.Locked = true -- no Studio hover outline or accidental selection when clicking the sea
	if seaConfig.textureId ~= "" then
		local texture = Instance.new("Texture")
		texture.Texture = seaConfig.textureId
		texture.Face = Enum.NormalId.Top
		texture.StudsPerTileU = seaConfig.studsPerTile
		texture.StudsPerTileV = seaConfig.studsPerTile
		texture.Transparency = seaConfig.textureTransparency
		texture.Parent = part
	end
	CollectionService:AddTag(part, "SeaSurface")
end

-- Foam ring around a shoreline given as radius(angle) around (ox, oz).
local function foamRing(shoreRadius: (number) -> number, ox: number, oz: number, cx: number, cz: number, parent: Instance)
	local seaConfig = World.Sea
	local averageRadius = shoreRadius(0) + seaConfig.foamOffset
	local segments = math.max(12, math.floor(2 * math.pi * averageRadius / FOAM_SEGMENT))
	for index = 0, segments - 1 do
		local a0 = index / segments * 2 * math.pi
		local a1 = (index + 1) / segments * 2 * math.pi
		local r0, r1 = shoreRadius(a0) + seaConfig.foamOffset, shoreRadius(a1) + seaConfig.foamOffset
		local p0 = Vector3.new(cx + ox + math.cos(a0) * r0, World.SeaLevel + SURFACE_HEIGHT, cz + oz + math.sin(a0) * r0)
		local p1 = Vector3.new(cx + ox + math.cos(a1) * r1, World.SeaLevel + SURFACE_HEIGHT, cz + oz + math.sin(a1) * r1)
		local length = (p1 - p0).Magnitude * 1.15
		local cframe = CFrame.lookAt((p0 + p1) / 2, p1)
		local foam = Parts.block(Vector3.new(seaConfig.foamWidth, 0.2, length), cframe, FOAM_COLOR, parent, {
			transparency = 0.2,
			shadow = false,
			name = "Foam",
		})
		foam.Locked = true
		foam:SetAttribute("Phase", index * 0.6)
		CollectionService:AddTag(foam, "SeaFoam")
	end
end

-- Fills the open ocean: squares of AreaSize around the island squares, out to
-- OceanMargin, each with water, a sand floor and the textured surface. Island
-- squares are skipped; each island writes its own.
function Sea.buildOcean(parent: Instance, onStatus: (string) -> ())
	local terrain = workspace.Terrain
	local size = World.AreaSize
	local floor = World.SeaLevel - World.SeaDepth
	local folder = parent:FindFirstChild("Sea") or Parts.folder("Sea", parent)
	folder:ClearAllChildren()

	local islandSquares: { [string]: boolean } = {}
	local minX, maxX = math.huge, -math.huge
	for _, island in Islands.List do
		local x, z = World.islandCenter(island.order)
		islandSquares[`{x},{z}`] = true
		minX, maxX = math.min(minX, x), math.max(maxX, x)
	end
	local tiles = math.ceil(World.OceanMargin / size)
	local total = (math.floor((maxX - minX) / size) + 1 + 2 * tiles) * (2 * tiles + 1)
	local done = 0
	for x = minX - tiles * size, maxX + tiles * size, size do
		for z = -tiles * size, tiles * size, size do
			if not islandSquares[`{x},{z}`] then
				terrain:FillBlock(CFrame.new(x, (floor + World.SeaLevel) / 2, z), Vector3.new(size, World.SeaLevel - floor, size), Enum.Material.Water)
				terrain:FillBlock(CFrame.new(x, floor - 2, z), Vector3.new(size, 4, size), Enum.Material.Mud)
				surface(x, z, folder)
			end
			done += 1
			onStatus(`Océano: {math.floor(done / total * 100)}%`)
			task.wait()
		end
	end
end

-- Builds the sea dressing of an island centered at (cx, cz).
function Sea.build(layout: Shape.Layout, cx: number, cz: number, parent: Instance)
	local folder = Parts.folder("Sea", parent)
	surface(cx, cz, folder)
	foamRing(function(angle)
		return Shape.shoreRadius(layout, angle, World.SeaLevel)
	end, 0, 0, cx, cz, folder)
	-- Mesas standing in the sea get their own ring.
	for _, mesa in layout.mesas do
		if Shape.height(layout, mesa.x + mesa.radius * 1.3, mesa.z) < World.SeaLevel then
			foamRing(function()
				return mesa.radius * 0.95
			end, mesa.x, mesa.z, cx, cz, folder)
		end
	end
end

return Sea
