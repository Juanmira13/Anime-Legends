--!strict
-- Walks along polylines at a fixed spacing, for things placed along paths and
-- walls: lanterns, torii gates, fence posts, power poles, wall segments.
-- Pure, unit tested.

export type Sample = {
	x: number,
	z: number,
	dx: number, -- unit direction of travel
	dz: number,
	distance: number, -- studs from the start
}

local PathWalk = {}

-- Points every `spacing` studs along the polyline (the first at `start`).
function PathWalk.samples(points: { { number } }, spacing: number, start: number?): { Sample }
	local samples: { Sample } = {}
	local travelled = 0
	local nextAt = start or 0
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local length = math.sqrt(dx * dx + dz * dz)
		if length > 0 then
			local ux, uz = dx / length, dz / length
			while nextAt <= travelled + length do
				local along = nextAt - travelled
				table.insert(samples, { x = a[1] + ux * along, z = a[2] + uz * along, dx = ux, dz = uz, distance = nextAt })
				nextAt += spacing
			end
			travelled += length
		end
	end
	return samples
end

-- Total length of a polyline.
function PathWalk.length(points: { { number } }): number
	local total = 0
	for index = 1, #points - 1 do
		total += math.sqrt((points[index + 1][1] - points[index][1]) ^ 2 + (points[index + 1][2] - points[index][2]) ^ 2)
	end
	return total
end

-- Points on a circle (a closed wall), every `spacing` studs, with tangents.
function PathWalk.circle(cx: number, cz: number, radius: number, spacing: number): { Sample }
	local count = math.max(3, math.floor(2 * math.pi * radius / spacing))
	local samples: { Sample } = {}
	for index = 0, count - 1 do
		local angle = index / count * 2 * math.pi
		table.insert(samples, {
			x = cx + math.cos(angle) * radius,
			z = cz + math.sin(angle) * radius,
			dx = -math.sin(angle),
			dz = math.cos(angle),
			distance = angle * radius,
		})
	end
	return samples
end

return PathWalk
