--!strict
-- Writes an island's terrain (land, beaches, cliffs and the sea around it)
-- from the pure height and material functions in Gen/Shape. Land and water
-- share voxels at the shore (WriteVoxelChannels) so the coast has no gaps.

local Root = script.Parent.Parent
local Shape = require(Root.Gen.Shape)
local World = require(Root.Shared.Config.World)

local VOXEL = 4
local CHUNK = 32 -- voxel columns per chunk side
local SUBSOIL_DEPTH = 8 -- studs of surface material before the cliff material

local TerrainWriter = {}

local function material(name: string): Enum.Material
	return (Enum.Material :: any)[name]
end

local function alignDown(value: number): number
	return math.floor(value / VOXEL) * VOXEL
end

local function alignUp(value: number): number
	return math.ceil(value / VOXEL) * VOXEL
end

-- Highest point of the island (sampled every 8 studs), for the vertical
-- extent of the writes.
local function maxHeight(layout: Shape.Layout, landHalf: number): number
	local top = 0
	for x = -landHalf, landHalf, 8 do
		for z = -landHalf, landHalf, 8 do
			top = math.max(top, Shape.height(layout, x, z))
		end
	end
	return top + 12
end

-- Half size of the square that holds every land voxel (beyond it is open sea).
local function landHalfSize(layout: Shape.Layout): number
	local reach = Shape.maxCoastRadius(layout) * 1.4
	for _, mesa in layout.mesas do
		reach = math.max(reach, math.abs(mesa.x) + mesa.radius, math.abs(mesa.z) + mesa.radius)
	end
	local chunkSize = CHUNK * VOXEL
	return math.min(World.AreaSize / 2, math.ceil(reach / chunkSize) * chunkSize)
end

local function writeChunk(
	terrain: Terrain,
	layout: Shape.Layout,
	cx: number,
	cz: number,
	x0: number,
	z0: number,
	yMin: number,
	yMax: number
)
	local seaLevel = World.SeaLevel
	local sizeY = (yMax - yMin) // VOXEL
	local solidMaterial, solidOccupancy, liquidOccupancy = {}, {}, {}
	local seabed = material(layout.materials.seabed)
	local cliff = material(layout.materials.cliff)

	for i = 1, CHUNK do
		local columnMaterials, columnSolid, columnLiquid = {}, {}, {}
		solidMaterial[i], solidOccupancy[i], liquidOccupancy[i] = columnMaterials, columnSolid, columnLiquid
		for j = 1, sizeY do
			columnMaterials[j], columnSolid[j], columnLiquid[j] = {}, {}, {}
		end
		local x = x0 + (i - 0.5) * VOXEL
		for k = 1, CHUNK do
			local z = z0 + (k - 0.5) * VOXEL
			local height = Shape.height(layout, x, z)
			local water = Shape.waterLevel(layout, x, z, seaLevel)
			local surface = material(Shape.material(layout, x, z, height, Shape.slope(layout, x, z)))
			local deep = if height < water then seabed else cliff
			for j = 1, sizeY do
				local bottom = yMin + (j - 1) * VOXEL
				columnMaterials[j][k] = if bottom + VOXEL > height - SUBSOIL_DEPTH then surface else deep
				columnSolid[j][k] = Shape.occupancy(height, bottom, VOXEL)
				columnLiquid[j][k] = Shape.waterOccupancy(height, bottom, VOXEL, water)
			end
		end
	end

	local region = Region3.new(
		Vector3.new(cx + x0, yMin, cz + z0),
		Vector3.new(cx + x0 + CHUNK * VOXEL, yMax, cz + z0 + CHUNK * VOXEL)
	)
	local ok = pcall(function()
		terrain:WriteVoxelChannels(region, VOXEL, {
			SolidMaterial = solidMaterial,
			SolidOccupancy = solidOccupancy,
			LiquidOccupancy = liquidOccupancy,
		})
	end)
	if not ok then
		-- Older engines: one material per voxel, water where water wins.
		for i = 1, CHUNK do
			for j = 1, sizeY do
				for k = 1, CHUNK do
					if liquidOccupancy[i][j][k] > solidOccupancy[i][j][k] then
						solidMaterial[i][j][k] = Enum.Material.Water
						solidOccupancy[i][j][k] = liquidOccupancy[i][j][k]
					end
				end
			end
		end
		terrain:WriteVoxels(region, VOXEL, solidMaterial, solidOccupancy)
	end
end

-- Clears the island's square of the world and writes its land and sea.
-- `cx`, `cz` is the island center. `onProgress` gets a 0..1 fraction.
function TerrainWriter.writeIsland(layout: Shape.Layout, cx: number, cz: number, onProgress: ((number) -> ())?)
	local terrain = workspace.Terrain
	local half = World.AreaSize / 2
	local seaLevel = World.SeaLevel
	local seaFloor = alignDown(layout.seaFloor)
	local yMin = seaFloor - VOXEL
	local landHalf = landHalfSize(layout)
	local yMax = alignUp(maxHeight(layout, landHalf))

	-- Wipe whatever was here (previous builds), from below the sea floor up high.
	local clearTop = math.max(400, yMax + 40)
	terrain:FillBlock(
		CFrame.new(cx, (yMin + clearTop) / 2, cz),
		Vector3.new(World.AreaSize, clearTop - yMin, World.AreaSize),
		Enum.Material.Air
	)

	-- Open sea around the land square: water down to the sea floor.
	local band = half - landHalf
	if band > 0 then
		local function sea(x: number, z: number, sizeX: number, sizeZ: number)
			terrain:FillBlock(
				CFrame.new(cx + x, (seaFloor + seaLevel) / 2, cz + z),
				Vector3.new(sizeX, seaLevel - seaFloor, sizeZ),
				Enum.Material.Water
			)
			terrain:FillBlock(
				CFrame.new(cx + x, seaFloor - VOXEL / 2, cz + z),
				Vector3.new(sizeX, VOXEL, sizeZ),
				material(layout.materials.seabed)
			)
		end
		local middle = landHalf + band / 2
		sea(0, -middle, World.AreaSize, band)
		sea(0, middle, World.AreaSize, band)
		sea(-middle, 0, band, landHalf * 2)
		sea(middle, 0, band, landHalf * 2)
	end

	-- Land square, chunk by chunk.
	local chunkSize = CHUNK * VOXEL
	local chunksPerSide = (landHalf * 2) // chunkSize
	local done, total = 0, chunksPerSide * chunksPerSide
	for a = 0, chunksPerSide - 1 do
		for b = 0, chunksPerSide - 1 do
			writeChunk(terrain, layout, cx, cz, -landHalf + a * chunkSize, -landHalf + b * chunkSize, yMin, yMax)
			done += 1
			if onProgress then
				onProgress(done / total)
			end
			if done % 8 == 0 then
				task.wait() -- keep Studio responsive
			end
		end
	end
end

return TerrainWriter
