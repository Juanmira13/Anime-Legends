--!strict
-- Island terrain as pure functions of (x, z), relative to the island center:
-- ground height, water level, surface material, coastline and slope. The
-- terrain writer, prop placement and gameplay spawns all read the same
-- functions, so props and spawn points always sit on the ground. Pure math,
-- unit tested.
--
-- Height is built in layers: coast profile and rolling hills, mountains,
-- mesas (rock pillars, also at sea), rivers and lakes carved into the land,
-- flat areas (plaza and combat zones) and finally paths, which cut ramps and
-- terraces between areas at different heights.

export type Zone = {
	rank: string, -- Easy, Medium, Hard or Boss
	name: string, -- shown on the zone's sign
	x: number,
	z: number,
	radius: number, -- flat combat area
	height: number, -- ground height of the flat area
	count: number, -- enemy spawn points
}

export type Mesa = { x: number, z: number, radius: number, height: number }

export type Mountain = {
	x: number,
	z: number,
	radius: number,
	height: number,
	sharpness: number?, -- 1 = dome, 2+ = peak (default 1.6)
}

-- Points are { x, z } or { x, z, height }. When every point has a height the
-- path is graded: the ground along it follows those heights (ramps, cuts).
export type Path = { points: { { number } }, width: number, material: string? }

-- Points are { x, z, surface }: the water surface along the river, falling
-- toward the sea. A sharp drop between two points makes a waterfall.
export type River = { points: { { number } }, width: number, depth: number }

export type Lake = { x: number, z: number, radius: number, level: number, depth: number }

-- Ground material inside a circle instead of the grass (a paved city, a field).
-- Later surfaces win over earlier ones.
export type Surface = { x: number, z: number, radius: number, material: string }

export type Bay = { angle: number, width: number, depth: number } -- radians; depth as a fraction of the radius

-- Coastline silhouette on top of the noise.
export type Coast = {
	elongation: number?, -- stretches the island along `angle` (0..0.4)
	angle: number?,
	lobes: number?, -- number of bulges around the coast (2 = peanut, 4 = rounded square)
	lobeDepth: number?,
	lobeAngle: number?,
	bays: { Bay }?,
}

export type Materials = {
	grass: string,
	path: string,
	plaza: string,
	cliff: string,
	beach: string,
	seabed: string,
}

export type Layout = {
	id: string,
	seed: number,
	radius: number, -- average coast radius in studs
	coastNoise: number, -- coastline irregularity, 0..0.3
	coast: Coast?,
	baseHeight: number, -- inland ground height
	hillHeight: number, -- extra height of rolling hills
	hillScale: number, -- studs per hill
	beachWidth: number, -- studs of sand along the coast
	seaFloor: number, -- y of the sea floor
	plaza: { x: number, z: number, radius: number, height: number },
	zones: { Zone },
	paths: { Path },
	mesas: { Mesa }, -- rock pillars that stand apart (at sea or inland)
	plateaus: { Mesa }?, -- raised terraces with cliff edges; zones and paths may sit on them
	mountains: { Mountain }?,
	rivers: { River }?,
	lakes: { Lake }?,
	surfaces: { Surface }?,
	materials: Materials,
}

local FLAT_BLEND = 26 -- studs over which flat areas blend into the hills
local PATH_SHOULDER = 10 -- studs over which a graded path blends into the ground
local WATER_BANK = 8 -- studs of bank around rivers and lakes
local SHORE_HEIGHT = -3 -- ground height right at the coastline (under water)
local BEACH_HEIGHT = 2.5 -- top of the beach, where grass starts
local CLIFF_SLOPE = 1.1 -- rise over run above which ground is cliff

local Shape = {}

Shape.FLAT_BLEND = FLAT_BLEND
Shape.PATH_SHOULDER = PATH_SHOULDER

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

Shape.smoothstep = smoothstep

-- An optional list as a list (empty when missing).
local function list<T>(value: { T }?): { T }
	return value or {}
end
Shape.list = list

-- Nearest point on a polyline: distance, segment index and position along it.
local function nearestOnPolyline(points: { { number } }, px: number, pz: number): (number, number, number)
	local bestDistance, bestIndex, bestT = math.huge, 1, 0
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local abx, abz = b[1] - a[1], b[2] - a[2]
		local lengthSquared = abx * abx + abz * abz
		local t = if lengthSquared > 0
			then math.clamp(((px - a[1]) * abx + (pz - a[2]) * abz) / lengthSquared, 0, 1)
			else 0
		local cx, cz = a[1] + abx * t, a[2] + abz * t
		local distance = math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
		if distance < bestDistance then
			bestDistance, bestIndex, bestT = distance, index, t
		end
	end
	return bestDistance, bestIndex, bestT
end

-- Value carried by the polyline's points (index 3), interpolated along it.
local function valueAlong(points: { { number } }, index: number, t: number): number
	return lerp(points[index][3], points[index + 1][3], t)
end

local function isGraded(path: Path): boolean
	for _, point in path.points do
		if point[3] == nil then
			return false
		end
	end
	return #path.points >= 2
end
Shape.isGraded = isGraded

-- Coast radius in the direction `angle` (radians); irregular but closed.
function Shape.coastRadius(layout: Layout, angle: number): number
	local n = math.noise(math.cos(angle) * 1.4 + layout.seed * 0.0131, math.sin(angle) * 1.4, 0.37)
	n += 0.5 * math.noise(math.cos(angle) * 3.1, math.sin(angle) * 3.1 + layout.seed * 0.0173, 0.71)
	local radius = layout.radius * (1 + layout.coastNoise * math.clamp(n * 1.6, -1, 1))
	local coast = layout.coast
	if coast then
		if coast.elongation then
			radius *= 1 + coast.elongation * math.cos(2 * (angle - (coast.angle or 0)))
		end
		if coast.lobes then
			radius *= 1 + (coast.lobeDepth or 0.1) * math.cos(coast.lobes * (angle - (coast.lobeAngle or 0)))
		end
		for _, bay: Bay in list(coast.bays) do
			local difference = (angle - bay.angle + math.pi) % (2 * math.pi) - math.pi
			radius *= 1 - bay.depth * math.exp(-(difference / bay.width) ^ 2)
		end
	end
	return radius
end

-- Position across the island: 0 at the center, 1 at the coastline.
function Shape.coastFraction(layout: Layout, x: number, z: number): number
	return math.sqrt(x * x + z * z) / Shape.coastRadius(layout, math.atan2(z, x))
end

local function hills(layout: Layout, x: number, z: number): number
	local scale = layout.hillScale
	local n = math.noise(x / scale, z / scale, layout.seed * 0.29)
	n += 0.4 * math.noise(x / (scale * 0.4), z / (scale * 0.4), layout.seed * 0.53)
	return layout.hillHeight * math.clamp(n + 0.5, 0, 1.4)
end

local function mountains(layout: Layout, x: number, z: number): number
	local total = 0
	for _, mountain: Mountain in list(layout.mountains) do
		local distance = math.sqrt((x - mountain.x) ^ 2 + (z - mountain.z) ^ 2)
		if distance < mountain.radius then
			local k = 1 - smoothstep(0, mountain.radius, distance)
			-- Rocky noise grows toward the top.
			local rough = 1 + 0.18 * math.noise(x / 40, z / 40, mountain.x * 0.01 + layout.seed) * k
			total += mountain.height * k ^ (mountain.sharpness or 1.6) * rough
		end
	end
	return total
end

-- Carves a water channel or basin: ground drops to `surface` at the water's
-- edge and to `surface - depth` in the middle; banks blend over WATER_BANK.
-- `inside` is how far inside the water edge the point is (negative outside).
local function carveWater(height: number, inside: number, halfWidth: number, surface: number, depth: number): number
	if inside < -WATER_BANK then
		return height
	end
	local carved = surface - depth * smoothstep(0, halfWidth, inside)
	return math.min(height, lerp(height, carved, smoothstep(-WATER_BANK, 0, inside)))
end

function Shape.height(layout: Layout, x: number, z: number): number
	local t = Shape.coastFraction(layout, x, z)
	local height: number
	local onLand = t < 1
	if not onLand then
		-- Under the sea: slope from the shore down to the sea floor.
		height = lerp(SHORE_HEIGHT, layout.seaFloor, smoothstep(1, 1.35, t))
	else
		local beachStart = 1 - layout.beachWidth / layout.radius
		local beach = lerp(BEACH_HEIGHT, SHORE_HEIGHT, smoothstep(beachStart, 1, t))
		local inland = layout.baseHeight + hills(layout, x, z) + mountains(layout, x, z)
		height = lerp(inland, beach, smoothstep(beachStart - 0.14, beachStart, t))
	end

	-- Mesas (rock pillars, also out at sea) and plateaus: flat tops, cliff edges.
	local function raise(mesa: Mesa)
		local distance = math.sqrt((x - mesa.x) ^ 2 + (z - mesa.z) ^ 2)
		local core = 1 - smoothstep(mesa.radius * 0.8, mesa.radius, distance)
		if core > 0 then
			local top = mesa.height + 2 * math.noise(x / 18, z / 18, mesa.x * 0.01)
			height = math.max(height, lerp(height, top, core))
		end
	end
	for _, mesa in layout.mesas do
		raise(mesa)
	end
	for _, plateau: Mesa in list(layout.plateaus) do
		raise(plateau)
	end

	if not onLand then
		return height
	end

	-- Rivers and lakes.
	for _, river: River in list(layout.rivers) do
		local distance, index, along = nearestOnPolyline(river.points, x, z)
		height = carveWater(
			height,
			river.width / 2 - distance,
			river.width / 2,
			valueAlong(river.points, index, along),
			river.depth
		)
	end
	for _, lake: Lake in list(layout.lakes) do
		local distance = math.sqrt((x - lake.x) ^ 2 + (z - lake.z) ^ 2)
		height = carveWater(height, lake.radius - distance, lake.radius, lake.level, lake.depth)
	end

	-- Flat areas (plaza and combat zones) for walking and spawning.
	local function flatten(cx: number, cz: number, radius: number, flatHeight: number)
		local distance = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
		local weight = 1 - smoothstep(radius, radius + FLAT_BLEND, distance)
		height = lerp(height, flatHeight, weight)
	end
	local plaza = layout.plaza
	flatten(plaza.x, plaza.z, plaza.radius, plaza.height)
	for _, zone in layout.zones do
		flatten(zone.x, zone.z, zone.radius, zone.height)
	end

	-- Graded paths: ramps and cuts between areas. Bridges keep rivers open.
	if Shape.waterLevel(layout, x, z, -math.huge) > -math.huge then
		return height
	end
	for _, path in layout.paths do
		if isGraded(path) then
			local distance, index, along = nearestOnPolyline(path.points, x, z)
			local inside = path.width / 2 - distance
			if inside > -PATH_SHOULDER then
				height = lerp(height, valueAlong(path.points, index, along), smoothstep(-PATH_SHOULDER, 0, inside))
			end
		end
	end
	return height
end

-- Surface level of standing water at a point: river or lake surface where
-- there is one, otherwise `seaLevel`.
function Shape.waterLevel(layout: Layout, x: number, z: number, seaLevel: number): number
	local level = seaLevel
	for _, river: River in list(layout.rivers) do
		local distance, index, along = nearestOnPolyline(river.points, x, z)
		if distance <= river.width / 2 then
			level = math.max(level, valueAlong(river.points, index, along))
		end
	end
	for _, lake: Lake in list(layout.lakes) do
		if (x - lake.x) ^ 2 + (z - lake.z) ^ 2 <= lake.radius ^ 2 then
			level = math.max(level, lake.level)
		end
	end
	return level
end

-- Steepest rise over run around a point.
function Shape.slope(layout: Layout, x: number, z: number): number
	local step = 2
	local dx = Shape.height(layout, x + step, z) - Shape.height(layout, x - step, z)
	local dz = Shape.height(layout, x, z + step) - Shape.height(layout, x, z - step)
	return math.sqrt(dx * dx + dz * dz) / (2 * step)
end

-- How far inside the nearest path the point is (negative when outside), and
-- that path.
function Shape.nearestPath(layout: Layout, x: number, z: number): (number, Path?)
	local best, bestPath = -math.huge, nil
	for _, path in layout.paths do
		local distance = nearestOnPolyline(path.points, x, z)
		local inside = path.width / 2 - distance
		if inside > best then
			best, bestPath = inside, path
		end
	end
	return best, bestPath
end

-- Closest point on any path's center line.
function Shape.closestPathPoint(layout: Layout, x: number, z: number): (number, number)
	local bestDistance, bestX, bestZ = math.huge, x, z
	for _, path in layout.paths do
		local distance, index, along = nearestOnPolyline(path.points, x, z)
		if distance < bestDistance then
			local a, b = path.points[index], path.points[index + 1]
			bestDistance, bestX, bestZ = distance, lerp(a[1], b[1], along), lerp(a[2], b[2], along)
		end
	end
	return bestX, bestZ
end

function Shape.pathInside(layout: Layout, x: number, z: number): number
	return (Shape.nearestPath(layout, x, z))
end

-- Surface material name (Enum.Material item) at a point with this height and slope.
function Shape.material(layout: Layout, x: number, z: number, height: number, slope: number): string
	local materials = layout.materials
	if height < -1 then
		return materials.seabed
	end
	if Shape.waterLevel(layout, x, z, -math.huge) > height - 0.5 then
		return materials.seabed -- river and lake beds
	end
	if slope > CLIFF_SLOPE then
		return materials.cliff
	end
	local plaza = layout.plaza
	if (x - plaza.x) ^ 2 + (z - plaza.z) ^ 2 < plaza.radius ^ 2 then
		return materials.plaza
	end
	local inside, path = Shape.nearestPath(layout, x, z)
	if inside > 0 and height > 1 and path then
		return path.material or materials.path
	end
	local beachStart = 1 - layout.beachWidth / layout.radius
	if height < BEACH_HEIGHT + 1 and Shape.coastFraction(layout, x, z) > beachStart - 0.05 then
		return materials.beach
	end
	local ground = materials.grass
	for _, surface: Surface in list(layout.surfaces) do
		if (x - surface.x) ^ 2 + (z - surface.z) ^ 2 < surface.radius ^ 2 then
			ground = surface.material
		end
	end
	return ground
end

-- Distance from the center, along `angle`, where the ground meets the sea surface.
function Shape.shoreRadius(layout: Layout, angle: number, seaLevel: number): number
	local cos, sin = math.cos(angle), math.sin(angle)
	local low, high = 0, Shape.coastRadius(layout, angle) * 1.4
	for _ = 1, 24 do
		local middle = (low + high) / 2
		if Shape.height(layout, cos * middle, sin * middle) > seaLevel then
			low = middle
		else
			high = middle
		end
	end
	return (low + high) / 2
end

-- Largest coast radius over all directions (for the extent of the terrain).
function Shape.maxCoastRadius(layout: Layout): number
	local best = 0
	for step = 0, 127 do
		best = math.max(best, Shape.coastRadius(layout, step / 128 * 2 * math.pi))
	end
	return best
end

-- Solid occupancy (0..1) of a voxel whose bottom is at `bottom`, for ground at `height`.
function Shape.occupancy(height: number, bottom: number, voxelSize: number): number
	return math.clamp((height - bottom) / voxelSize, 0, 1)
end

-- Water occupancy of the same voxel: fills what the ground leaves, up to the water level.
function Shape.waterOccupancy(height: number, bottom: number, voxelSize: number, waterLevel: number): number
	local waterTop = math.clamp((waterLevel - bottom) / voxelSize, 0, 1)
	return math.max(0, waterTop - Shape.occupancy(height, bottom, voxelSize))
end

return Shape
