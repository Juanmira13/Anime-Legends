--!strict
-- Sanity rules for an island layout, checked before building and in the
-- tests: zones and plaza inland and apart, every one reached by a path,
-- mesas, rivers and lakes clear of them, walkable graded paths, and room
-- for the enemy spawns on flat ground.

local Shape = require(script.Parent.Shape)

local LayoutCheck = {}
local list = Shape.list

LayoutCheck.ENEMY_SPACING = 24 -- studs between enemy spawn points (keeps health bars apart)
LayoutCheck.SPAWN_AREA = 0.85 -- enemies spawn within this fraction of the zone radius
local FLAT_BLEND = Shape.FLAT_BLEND
local GAP = 10 -- studs between areas
LayoutCheck.MAX_PATH_SLOPE = 0.5 -- rise over run of graded paths (about 27°)

type Area = { name: string, x: number, z: number, radius: number }

function LayoutCheck.run(layout: Shape.Layout): { string }
	local problems = {}
	local function problem(message: string)
		table.insert(problems, `{layout.id}: {message}`)
	end

	local areas: { Area } = { { name = "plaza", x = layout.plaza.x, z = layout.plaza.z, radius = layout.plaza.radius } }
	for _, zone in layout.zones do
		table.insert(areas, { name = zone.name, x = zone.x, z = zone.z, radius = zone.radius })
	end

	for index, area in areas do
		-- The whole flat area and its blend stay inland, before the beach.
		local angle = math.atan2(area.z, area.x)
		local reach = math.sqrt(area.x ^ 2 + area.z ^ 2) + area.radius + FLAT_BLEND
		local beachStart = Shape.coastRadius(layout, angle) - layout.beachWidth
		if reach > beachStart then
			problem(`{area.name} reaches the beach ({math.floor(reach)} > {math.floor(beachStart)})`)
		end
		for other = index + 1, #areas do
			local b = areas[other]
			if math.sqrt((area.x - b.x) ^ 2 + (area.z - b.z) ^ 2) < area.radius + b.radius + GAP then
				problem(`{area.name} overlaps {b.name}`)
			end
		end
		if Shape.pathInside(layout, area.x, area.z) < -area.radius then
			problem(`{area.name} is not on a path`)
		end
	end

	for index, mesa in layout.mesas do
		for _, area in areas do
			if math.sqrt((mesa.x - area.x) ^ 2 + (mesa.z - area.z) ^ 2) < mesa.radius + area.radius + FLAT_BLEND then
				problem(`mesa {index} is too close to {area.name}`)
			end
		end
		if Shape.pathInside(layout, mesa.x, mesa.z) > -mesa.radius then
			problem(`mesa {index} blocks a path`)
		end
	end

	-- Water stays clear of the flat areas (they would fill it in).
	for index, river: Shape.River in list(layout.rivers) do
		for _, area in areas do
			for _, point in river.points do
				if math.sqrt((point[1] - area.x) ^ 2 + (point[2] - area.z) ^ 2) < area.radius + FLAT_BLEND + river.width / 2 then
					problem(`river {index} runs through {area.name}`)
					break
				end
			end
		end
	end
	for index, lake: Shape.Lake in list(layout.lakes) do
		for _, area in areas do
			if math.sqrt((lake.x - area.x) ^ 2 + (lake.z - area.z) ^ 2) < lake.radius + area.radius + FLAT_BLEND then
				problem(`lake {index} is too close to {area.name}`)
			end
		end
	end

	for pathIndex, path in layout.paths do
		if Shape.isGraded(path) then
			for index = 1, #path.points - 1 do
				local a, b = path.points[index], path.points[index + 1]
				local run = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
				if run > 0 and math.abs(b[3] - a[3]) / run > LayoutCheck.MAX_PATH_SLOPE then
					problem(`path {pathIndex} is too steep between points {index} and {index + 1}`)
				end
			end
		end
	end

	local plaza = layout.plaza
	if math.abs(Shape.height(layout, plaza.x, plaza.z) - plaza.height) > 0.5 then
		problem("plaza is not flat at its height")
	end
	for _, zone in layout.zones do
		if math.abs(Shape.height(layout, zone.x, zone.z) - zone.height) > 0.5 then
			problem(`{zone.name} is not flat at its height`)
		end
		-- Spawns fall back to a ring; it must fit on the flat ground.
		if zone.count > 1 then
			local ring = LayoutCheck.ENEMY_SPACING / (2 * math.sin(math.pi / zone.count))
			if ring > zone.radius * LayoutCheck.SPAWN_AREA then
				problem(`{zone.name} is too small for {zone.count} enemies`)
			end
		end
	end
	return problems
end

return LayoutCheck
