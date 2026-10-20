--!strict
-- Island terrain as pure functions of (x, z), relative to the island center:
-- ground height, surface material, coastline and slope. The terrain writer,
-- prop placement and gameplay spawns all read the same functions, so props and
-- spawn points always sit on the ground. Pure math, unit tested.

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

export type Path = { points: { { number } }, width: number } -- points are { x, z }

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
	baseHeight: number, -- inland ground height
	hillHeight: number, -- extra height of rolling hills
	hillScale: number, -- studs per hill
	beachWidth: number, -- studs of sand along the coast
	seaFloor: number, -- y of the sea floor
	plaza: { x: number, z: number, radius: number, height: number },
	zones: { Zone },
	paths: { Path },
	mesas: { Mesa },
	materials: Materials,
}

local FLAT_BLEND = 26 -- studs over which flat areas blend into the hills
local SHORE_HEIGHT = -3 -- ground height right at the coastline (under water)
local BEACH_HEIGHT = 2.5 -- top of the beach, where grass starts
local CLIFF_SLOPE = 1.1 -- rise over run above which ground is cliff

local Shape = {}

local function smoothstep(edge0: number, edge1: number, x: number): number
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

Shape.smoothstep = smoothstep

-- Coast radius in the direction `angle` (radians); irregular but closed.
function Shape.coastRadius(layout: Layout, angle: number): number
	local n = math.noise(math.cos(angle) * 1.4 + layout.seed * 0.0131, math.sin(angle) * 1.4, 0.37)
	n += 0.5 * math.noise(math.cos(angle) * 3.1, math.sin(angle) * 3.1 + layout.seed * 0.0173, 0.71)
	return layout.radius * (1 + layout.coastNoise * math.clamp(n * 1.6, -1, 1))
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

function Shape.height(layout: Layout, x: number, z: number): number
	local t = Shape.coastFraction(layout, x, z)
	local height: number
	if t >= 1 then
		-- Under the sea: slope from the shore down to the sea floor.
		height = lerp(SHORE_HEIGHT, layout.seaFloor, smoothstep(1, 1.35, t))
	else
		local beachStart = 1 - layout.beachWidth / layout.radius
		local beach = lerp(BEACH_HEIGHT, SHORE_HEIGHT, smoothstep(beachStart, 1, t))
		local inland = layout.baseHeight + hills(layout, x, z)
		height = lerp(inland, beach, smoothstep(beachStart - 0.14, beachStart, t))

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
	end

	-- Mesas: rock pillars with flat tops, also out at sea.
	for _, mesa in layout.mesas do
		local distance = math.sqrt((x - mesa.x) ^ 2 + (z - mesa.z) ^ 2)
		local core = 1 - smoothstep(mesa.radius * 0.8, mesa.radius, distance)
		if core > 0 then
			local top = mesa.height + 2 * math.noise(x / 18, z / 18, mesa.x * 0.01)
			height = math.max(height, lerp(height, top, core))
		end
	end
	return height
end

-- Steepest rise over run around a point.
function Shape.slope(layout: Layout, x: number, z: number): number
	local step = 2
	local dx = Shape.height(layout, x + step, z) - Shape.height(layout, x - step, z)
	local dz = Shape.height(layout, x, z + step) - Shape.height(layout, x, z - step)
	return math.sqrt(dx * dx + dz * dz) / (2 * step)
end

local function distanceToSegment(px: number, pz: number, ax: number, az: number, bx: number, bz: number): number
	local abx, abz = bx - ax, bz - az
	local lengthSquared = abx * abx + abz * abz
	local t = if lengthSquared > 0 then math.clamp(((px - ax) * abx + (pz - az) * abz) / lengthSquared, 0, 1) else 0
	local cx, cz = ax + abx * t, az + abz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- Distance to the nearest path center line, measured against each path's half width.
-- Returns how far inside the nearest path the point is (negative when outside).
function Shape.pathInside(layout: Layout, x: number, z: number): number
	local best = -math.huge
	for _, path in layout.paths do
		for index = 1, #path.points - 1 do
			local a, b = path.points[index], path.points[index + 1]
			local inside = path.width / 2 - distanceToSegment(x, z, a[1], a[2], b[1], b[2])
			best = math.max(best, inside)
		end
	end
	return best
end

-- Surface material name (Enum.Material item) at a point with this height and slope.
function Shape.material(layout: Layout, x: number, z: number, height: number, slope: number): string
	local materials = layout.materials
	if height < -1 then
		return materials.seabed
	end
	if slope > CLIFF_SLOPE then
		return materials.cliff
	end
	local plaza = layout.plaza
	if (x - plaza.x) ^ 2 + (z - plaza.z) ^ 2 < plaza.radius ^ 2 then
		return materials.plaza
	end
	if Shape.pathInside(layout, x, z) > 0 and height > 1 then
		return materials.path
	end
	local beachStart = 1 - layout.beachWidth / layout.radius
	if height < BEACH_HEIGHT + 1 and Shape.coastFraction(layout, x, z) > beachStart - 0.05 then
		return materials.beach
	end
	return materials.grass
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

-- Solid occupancy (0..1) of a voxel whose bottom is at `bottom`, for ground at `height`.
function Shape.occupancy(height: number, bottom: number, voxelSize: number): number
	return math.clamp((height - bottom) / voxelSize, 0, 1)
end

-- Water occupancy of the same voxel: fills what the ground leaves, up to the sea surface.
function Shape.waterOccupancy(height: number, bottom: number, voxelSize: number, seaLevel: number): number
	local waterTop = math.clamp((seaLevel - bottom) / voxelSize, 0, 1)
	return math.max(0, waterTop - Shape.occupancy(height, bottom, voxelSize))
end

return Shape
