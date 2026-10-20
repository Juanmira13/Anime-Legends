--!strict
-- Seeded scattering of points with a minimum spacing (dart throwing), used for
-- props (trees, rocks, houses) and enemy spawn points. Pure, unit tested.

local Rng = require(script.Parent.Rng)

export type Point = { x: number, z: number }

local Scatter = {}

-- Up to `count` points inside a circle, at least `spacing` apart from each
-- other and from `avoid`. `accept` filters candidates (e.g. only on land).
function Scatter.inCircle(
	rng: Rng.Rng,
	cx: number,
	cz: number,
	radius: number,
	count: number,
	spacing: number,
	accept: ((x: number, z: number) -> boolean)?,
	avoid: { Point }?
): { Point }
	local points: { Point } = {}
	local spacingSquared = spacing * spacing
	local function farEnough(list: { Point }, x: number, z: number): boolean
		for _, other in list do
			if (other.x - x) ^ 2 + (other.z - z) ^ 2 < spacingSquared then
				return false
			end
		end
		return true
	end
	local attempts = count * 40
	while #points < count and attempts > 0 do
		attempts -= 1
		-- sqrt keeps the density uniform over the disc.
		local angle = Rng.range(rng, 0, 2 * math.pi)
		local distance = radius * math.sqrt(Rng.next(rng))
		local x, z = cx + math.cos(angle) * distance, cz + math.sin(angle) * distance
		if farEnough(points, x, z) and (avoid == nil or farEnough(avoid, x, z)) and (accept == nil or accept(x, z)) then
			table.insert(points, { x = x, z = z })
		end
	end
	return points
end

-- Exactly `count` points inside a circle for enemy spawns: the boss rank uses
-- the center; others are scattered with `spacing`, falling back to a ring.
function Scatter.spawnPoints(rng: Rng.Rng, cx: number, cz: number, radius: number, count: number, spacing: number): { Point }
	if count == 1 then
		return { { x = cx, z = cz } }
	end
	local points = Scatter.inCircle(rng, cx, cz, radius, count, spacing)
	if #points < count then
		points = {}
		-- Neighbors on a ring of radius R are 2R·sin(π/count) apart.
		local ringRadius = spacing / (2 * math.sin(math.pi / count))
		for index = 1, count do
			local angle = 2 * math.pi * index / count
			table.insert(points, { x = cx + math.cos(angle) * ringRadius, z = cz + math.sin(angle) * ringRadius })
		end
	end
	return points
end

return Scatter
