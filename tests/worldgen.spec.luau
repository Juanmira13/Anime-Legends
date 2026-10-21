-- Checks the island generator: seeded random, terrain shape, materials,
-- shoreline, voxel occupancy and scattering.
local Rng = require(Builder.Gen.Rng)
local Shape = require(Builder.Gen.Shape)
local Scatter = require(Builder.Gen.Scatter)
local LayoutCheck = require(Builder.Gen.LayoutCheck)
local NamekuLayout = require(Builder.Islands.NamekuLayout)
local IslandLayouts = require(Builder.Islands.Layouts)
local Islands = require(Shared.Data.Islands)

local failures = 0
local function check(label, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end
local function near(label, actual, expected, tolerance)
	if math.abs(actual - expected) > (tolerance or 1e-6) then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end

-- Seeded random: deterministic and in range
local a, b = Rng.new(42), Rng.new(42)
local same = true
for _ = 1, 100 do
	local x, y = Rng.next(a), Rng.next(b)
	if x ~= y or x < 0 or x >= 1 then
		same = false
	end
end
check("same seed, same numbers", same, true)
check("different seeds differ", Rng.next(Rng.new(1)) ~= Rng.next(Rng.new(2)), true)
local ints = Rng.new(7)
local inRange = true
for _ = 1, 200 do
	local n = Rng.int(ints, 3, 5)
	if n < 3 or n > 5 or n % 1 ~= 0 then
		inRange = false
	end
end
check("ints in range", inRange, true)
check("zero seed works", Rng.next(Rng.new(0)) > 0, true)

-- Terrain shape on a test island
local layout = {
	id = "Test",
	seed = 11,
	radius = 300,
	coastNoise = 0.15,
	baseHeight = 8,
	hillHeight = 10,
	hillScale = 120,
	beachWidth = 30,
	seaFloor = -24,
	plaza = { x = 0, z = 200, radius = 30, height = 6 },
	zones = {
		{ rank = "Easy", name = "Easy", x = -100, z = 80, radius = 40, height = 7, count = 8 },
		{ rank = "Boss", name = "Boss", x = 0, z = -180, radius = 35, height = 14, count = 1 },
	},
	paths = { { points = { { 0, 200 }, { 0, -180 } }, width = 10 } },
	mesas = { { x = 420, z = 0, radius = 40, height = 60 } },
	materials = {
		grass = "Grass",
		path = "Ground",
		plaza = "Pavement",
		cliff = "Rock",
		beach = "Sand",
		seabed = "Sand",
	},
}

near("plaza is flat at its height", Shape.height(layout, 0, 200), 6)
near("plaza edge still flat", Shape.height(layout, 20, 200), 6)
near("zone is flat at its height", Shape.height(layout, -100, 80), 7)
near("boss zone height", Shape.height(layout, 0, -180), 14)
check("center is land", Shape.height(layout, 50, 0) > 0, true)
near("far sea reaches the floor", Shape.height(layout, 0, 900), -24)
check("past the coast is under water", Shape.height(layout, 380, 380) < 0, true)
check("mesa rises from the sea", Shape.height(layout, 420, 0) > 55, true)
check("beside the mesa is sea", Shape.height(layout, 520, 0) < 0, true)
check("deterministic height", Shape.height(layout, 123, -45) == Shape.height(layout, 123, -45), true)

-- Coast stays near the radius
local minCoast, maxCoast = math.huge, -math.huge
for step = 0, 63 do
	local radius = Shape.coastRadius(layout, step / 64 * 2 * math.pi)
	minCoast, maxCoast = math.min(minCoast, radius), math.max(maxCoast, radius)
end
check("coast never shrinks too much", minCoast >= 300 * 0.85 - 1e-6, true)
check("coast never grows too much", maxCoast <= 300 * 1.15 + 1e-6, true)
check("coast is irregular", maxCoast - minCoast > 5, true)

-- Shoreline: ground crosses the sea level there
for _, angle in { 0.3, 2, 4.5 } do
	local radius = Shape.shoreRadius(layout, angle, 0)
	local x, z = math.cos(angle), math.sin(angle)
	check(`land just inside shore {angle}`, Shape.height(layout, x * (radius - 2), z * (radius - 2)) > 0, true)
	check(`sea just outside shore {angle}`, Shape.height(layout, x * (radius + 2), z * (radius + 2)) < 0, true)
end

-- Materials
local function materialAt(x, z)
	return Shape.material(layout, x, z, Shape.height(layout, x, z), Shape.slope(layout, x, z))
end
check("plaza material", materialAt(0, 200), "Pavement")
check("path material", materialAt(0, 60), "Ground")
check("sea floor material", materialAt(0, 900), "Sand")
check("mesa side is cliff", materialAt(420 + 36, 0), "Rock")
check("mesa top is grass", materialAt(420, 0), "Grass")
check("inland is grass", materialAt(-100, 80), "Grass")
check("flat zone is not steep", Shape.slope(layout, -100, 80) < 0.1, true)

-- Voxel occupancy: solid fills from the ground, water fills the rest below the sea
near("voxel fully under ground", Shape.occupancy(10, 0, 4), 1)
near("voxel fully above ground", Shape.occupancy(-10, 0, 4), 0)
near("voxel half ground", Shape.occupancy(2, 0, 4), 0.5)
near("water fills above ground", Shape.waterOccupancy(-10, -8, 4, 0), 1)
near("water shares a shore voxel", Shape.waterOccupancy(-2, -4, 4, 0), 0.5)
near("no water above the sea", Shape.waterOccupancy(-10, 4, 4, 0), 0)
near("no water inside ground", Shape.waterOccupancy(5, -8, 4, 0), 0)
near("water meets the surface", Shape.waterOccupancy(-10, -2, 4, 0), 0.5)

-- Scatter: spacing, inside the circle, filter and determinism
local points = Scatter.inCircle(Rng.new(5), 10, 20, 100, 30, 12)
local ok = true
for i, p in points do
	if (p.x - 10) ^ 2 + (p.z - 20) ^ 2 > 100 ^ 2 + 1e-6 then
		ok = false
	end
	for j = i + 1, #points do
		if (p.x - points[j].x) ^ 2 + (p.z - points[j].z) ^ 2 < 12 ^ 2 then
			ok = false
		end
	end
end
check("scatter inside and spaced", ok, true)
check("scatter fills the count", #points, 30)
local filtered = Scatter.inCircle(Rng.new(5), 0, 0, 100, 20, 5, function(x)
	return x > 0
end)
local allRight = true
for _, p in filtered do
	if p.x <= 0 then
		allRight = false
	end
end
check("scatter filter", allRight, true)
local again = Scatter.inCircle(Rng.new(5), 10, 20, 100, 30, 12)
check("scatter deterministic", again[7].x == points[7].x and again[7].z == points[7].z, true)
local avoided = Scatter.inCircle(Rng.new(9), 0, 0, 50, 10, 4, nil, { { x = 0, z = 0 } })
local clear = true
for _, p in avoided do
	if p.x * p.x + p.z * p.z < 16 then
		clear = false
	end
end
check("scatter avoids points", clear, true)

-- Spawn points: exact count, boss in the center, spaced even when crowded
local boss = Scatter.spawnPoints(Rng.new(3), 5, 6, 30, 1, 16)
check("boss spawn count", #boss, 1)
check("boss at center", boss[1].x == 5 and boss[1].z == 6, true)
for _, case in { { radius = 40, count = 8 }, { radius = 10, count = 6 } } do
	local spawns = Scatter.spawnPoints(Rng.new(3), 0, 0, case.radius, case.count, 16)
	check(`spawn count r{case.radius}`, #spawns, case.count)
	local spaced = true
	for i, p in spawns do
		for j = i + 1, #spawns do
			if (p.x - spawns[j].x) ^ 2 + (p.z - spawns[j].z) ^ 2 < 16 ^ 2 - 1e-6 then
				spaced = false
			end
		end
	end
	check(`spawns spaced r{case.radius}`, spaced, true)
end

local function hasProblemIn(problems, text)
	for _, message in problems do
		if string.find(message, text, 1, true) then
			return true
		end
	end
	return false
end

-- Relief: mountains, rivers with waterfalls, lakes, graded paths and coast shapes
local relief = {
	id = "Relief",
	seed = 21,
	radius = 400,
	coastNoise = 0.05,
	baseHeight = 8,
	hillHeight = 0,
	hillScale = 100,
	beachWidth = 30,
	seaFloor = -24,
	plaza = { x = 0, z = 250, radius = 30, height = 6 },
	zones = {
		{ rank = "Easy", name = "Low", x = -150, z = 150, radius = 40, height = 8, count = 6 },
		{ rank = "Hard", name = "High", x = 150, z = 0, radius = 40, height = 40, count = 4 },
	},
	paths = {
		{ width = 12, points = { { 0, 250, 6 }, { -150, 150, 8 }, { 0, 100, 12 }, { 100, 50, 30 }, { 150, 0, 40 } } },
	},
	mesas = {},
	mountains = { { x = 0, z = -200, radius = 150, height = 90 } },
	rivers = {
		{
			width = 14,
			depth = 4,
			points = { { -100, -150, 40 }, { -120, -100, 38 }, { -125, -90, 10 }, { -250, 0, 3 }, { -420, 0, 0 } },
		},
	},
	lakes = { { x = 150, z = 200, radius = 30, level = 9, depth = 5 } },
	materials = { grass = "Grass", path = "Ground", plaza = "Pavement", cliff = "Rock", beach = "Sand", seabed = "Mud" },
}
check("mountain rises", Shape.height(relief, 0, -200) > 85, true)
check("mountain fades out", Shape.height(relief, 0, -200 + 160) < 20, true)
near("graded path follows its heights", Shape.height(relief, 50, 75), 21, 0.01)
check("graded path cuts a ramp", Shape.slope(relief, 50, 75) < 0.5, true)
near("lake water level", Shape.waterLevel(relief, 150, 200, 0), 9)
check("lake bed is under water", Shape.height(relief, 150, 200) < 9 - 4, true)
near("river surface above the fall", Shape.waterLevel(relief, -110, -125, 0), 39, 1)
check("waterfall drops", Shape.waterLevel(relief, -110, -125, 0) - Shape.waterLevel(relief, -180, -50, 0) > 20, true)
check("river bed is under its surface", Shape.height(relief, -250, 0) < 3, true)
near("away from water is the sea level", Shape.waterLevel(relief, 0, 0, 0), 0)
check("river bed material", Shape.material(relief, -250, 0, Shape.height(relief, -250, 0), 0), "Mud")
check("relief layout passes the rules", #LayoutCheck.run(relief), 0)
for _, message in LayoutCheck.run(relief) do
	print(`  {message}`)
end
local steep = table.clone(relief)
steep.paths = { { width = 12, points = { { 0, 250, 6 }, { -150, 150, 8 }, { -140, 140, 30 }, { 150, 0, 40 } } } }
check("catches a steep path", hasProblemIn(LayoutCheck.run(steep), "too steep"), true)
local flooded = table.clone(relief)
flooded.lakes = { { x = -150, z = 120, radius = 20, level = 9, depth = 4 } }
check("catches a lake in a zone", hasProblemIn(LayoutCheck.run(flooded), "lake 1 is too close"), true)

local paved = table.clone(relief)
paved.surfaces = {
	{ x = -150, z = 150, radius = 120, material = "Pavement" },
	{ x = -200, z = 200, radius = 20, material = "Grass" },
}
check("surface paves the ground", Shape.material(paved, -100, 220, Shape.height(paved, -100, 220), 0), "Pavement")
check("later surface wins", Shape.material(paved, -200, 200, Shape.height(paved, -200, 200), 0), "Grass")
check("paths keep their material", Shape.material(paved, -75, 125, Shape.height(paved, -75, 125), 0), "Ground")

local stretched = table.clone(relief)
stretched.coast = { elongation = 0.3, angle = 0 }
check("elongated along x", Shape.coastRadius(stretched, 0) > Shape.coastRadius(stretched, math.pi / 2) * 1.6, true)
local bay = table.clone(relief)
bay.coast = { bays = { { angle = math.pi / 2, width = 0.3, depth = 0.4 } } }
check(
	"bay pulls the coast in",
	Shape.coastRadius(bay, math.pi / 2) < Shape.coastRadius(relief, math.pi / 2) * 0.65,
	true
)
check(
	"bay is local",
	math.abs(Shape.coastRadius(bay, -math.pi / 2) - Shape.coastRadius(relief, -math.pi / 2)) < 1,
	true
)
local lobed = table.clone(relief)
lobed.coast = { lobes = 4, lobeDepth = 0.12 }
check("lobes bulge", Shape.coastRadius(lobed, 0) > Shape.coastRadius(lobed, math.pi / 4), true)
check("max coast radius", Shape.maxCoastRadius(stretched) >= Shape.coastRadius(stretched, 0) - 1e-6, true)

-- Every real island layout passes the layout rules
local layouts = IslandLayouts
for _, island in Islands.List do
	local real = layouts[island.id]
	check(`layout exists {island.id}`, real ~= nil, true)
	if real then
		local problems = LayoutCheck.run(real)
		check(`layout rules {island.id}`, #problems, 0)
		for _, message in problems do
			print(`  {message}`)
		end
	end
end

-- The layout rules catch broken layouts
local function copyLayout()
	local copy = table.clone(NamekuLayout)
	copy.zones = table.clone(NamekuLayout.zones)
	copy.mesas = table.clone(NamekuLayout.mesas)
	return copy
end
local function hasProblem(problems, text)
	for _, message in problems do
		if string.find(message, text, 1, true) then
			return true
		end
	end
	return false
end
local overlapping = copyLayout()
overlapping.zones[2] = table.clone(overlapping.zones[2])
overlapping.zones[2].x, overlapping.zones[2].z = -110, 120
check("catches overlapping zones", hasProblem(LayoutCheck.run(overlapping), "overlaps"), true)
local coastal = copyLayout()
coastal.zones[1] = table.clone(coastal.zones[1])
coastal.zones[1].x, coastal.zones[1].z = -335, 0
check("catches zone on the beach", hasProblem(LayoutCheck.run(coastal), "reaches the beach"), true)
local blocked = copyLayout()
table.insert(blocked.mesas, { x = -20, z = 80, radius = 20, height = 40 })
check("catches mesa on the path", hasProblem(LayoutCheck.run(blocked), "blocks a path"), true)
local crowded = copyLayout()
crowded.zones[3] = table.clone(crowded.zones[3])
crowded.zones[3].count = 12
check("catches crowded zone", hasProblem(LayoutCheck.run(crowded), "too small"), true)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
