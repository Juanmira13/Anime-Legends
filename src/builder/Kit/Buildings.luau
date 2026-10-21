--!strict
-- Architecture building blocks shared by the islands: walls on a foundation,
-- gable roofs, cone roofs, windows, fences and stairs. Each island combines
-- them in its own style (Islands/<Island>.luau). All parts are anchored and
-- unclickable (see Kit/Parts); walls and roofs collide.

local Parts = require(script.Parent.Parts)

local Buildings = {}

local SOLID = { collide = true }

-- Foundation that reaches below the ground, so buildings on slopes do not float.
function Buildings.foundation(base: CFrame, width: number, depth: number, color: Color3, parent: Instance): Part
	return Parts.block(Vector3.new(width + 1, 8, depth + 1), base * CFrame.new(0, -3.4, 0), color, parent, SOLID)
end

-- Box walls standing on `base` (bottom center), facing -Z.
function Buildings.walls(base: CFrame, width: number, depth: number, height: number, color: Color3, parent: Instance): Part
	return Parts.block(Vector3.new(width, height, depth), base * CFrame.new(0, height / 2, 0), color, parent, SOLID)
end

-- Gable roof whose ridge runs along local X, sitting on `base` (eaves level).
function Buildings.gableRoof(base: CFrame, length: number, depth: number, height: number, color: Color3, parent: Instance, overhang: number?)
	local extra = overhang or 1.5
	local half = (depth + extra * 2) / 2
	local size = Vector3.new(length + extra * 2, height, half)
	-- A wedge is tall at its back (+Z): put both backs on the ridge.
	Parts.wedge(size, base * CFrame.new(0, height / 2, -half / 2), color, parent, SOLID)
	Parts.wedge(size, base * CFrame.new(0, height / 2, half / 2) * CFrame.Angles(0, math.pi, 0), color, parent, SOLID)
end

-- Round roof made of stacked, shrinking discs (cartoon cone).
function Buildings.coneRoof(base: CFrame, diameter: number, height: number, color: Color3, parent: Instance, tiers: number?)
	local count = tiers or 6
	for tier = 0, count - 1 do
		local t = tier / count
		local tierDiameter = diameter * (1 - t) + 0.6
		local position = (base * CFrame.new(0, height * t + height / count / 2, 0)).Position
		Parts.disc(tierDiameter, height / count + 0.05, position, Parts.vary(color, 0.12, t), parent, { shadow = tier == 0 })
	end
end

-- Row of windows on the front face (-Z) of walls standing on `base`.
function Buildings.windows(base: CFrame, wallWidth: number, wallDepth: number, y: number, count: number, size: Vector2, color: Color3, parent: Instance, glow: boolean?)
	local spacing = wallWidth / count
	for index = 1, count do
		local x = -wallWidth / 2 + spacing * (index - 0.5)
		for _, face in { -1, 1 } do
			local window = Parts.block(
				Vector3.new(size.X, size.Y, 0.3),
				base * CFrame.new(x, y, face * (wallDepth / 2 + 0.1)),
				color,
				parent,
				{ shadow = false, material = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic }
			)
			window.Name = "Window"
		end
	end
end

-- Door on the front face (-Z).
function Buildings.door(base: CFrame, wallDepth: number, width: number, height: number, color: Color3, parent: Instance)
	Parts.block(Vector3.new(width, height, 0.4), base * CFrame.new(0, height / 2, -wallDepth / 2 - 0.15), color, parent, { shadow = false })
end

-- Fence of posts and two rails between two ground points.
function Buildings.fence(from: Vector3, to: Vector3, color: Color3, parent: Instance)
	local length = (to - from).Magnitude
	local posts = math.max(2, math.floor(length / 5) + 1)
	for index = 0, posts - 1 do
		local point = from:Lerp(to, index / (posts - 1))
		Parts.block(Vector3.new(0.6, 3.4, 0.6), CFrame.new(point + Vector3.new(0, 1.7, 0)), color, parent, { shadow = false })
	end
	for _, y in { 1.4, 2.8 } do
		Parts.beam(from + Vector3.new(0, y, 0), to + Vector3.new(0, y, 0), 0.35, color, parent, { shadow = false })
	end
end

-- Steps climbing from one ground point to another (decorative, on a ramp).
function Buildings.steps(from: Vector3, to: Vector3, width: number, color: Color3, parent: Instance)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local count = math.max(2, math.floor(flat.Magnitude / 2.5))
	local yaw = math.atan2(-flat.X, -flat.Z)
	for index = 0, count - 1 do
		local point = from:Lerp(to, (index + 0.5) / count)
		Parts.block(Vector3.new(width, 0.6, flat.Magnitude / count + 0.2), CFrame.new(point) * CFrame.Angles(0, yaw, 0), Parts.vary(color, 0.1, index % 2), parent, { shadow = false })
	end
end

return Buildings
