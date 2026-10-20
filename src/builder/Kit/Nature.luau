--!strict
-- Vegetation and rocks in a cartoon style. Each builder takes the ground
-- point, a 0..1 variation seed `t` and a palette, and parents its parts to a
-- model so a tree can be moved or deleted as one piece.

local Parts = require(script.Parent.Parts)

export type TreePalette = {
	trunk: Color3,
	leaves: { Color3 },
}

local Nature = {}

local function pick(colors: { Color3 }, t: number): Color3
	return colors[math.clamp(math.floor(t * #colors) + 1, 1, #colors)]
end

-- Tall thin trunk with a cluster of round canopies (also the Namek tree).
function Nature.roundTree(ground: Vector3, height: number, t: number, palette: TreePalette, parent: Instance): Model
	local model = Parts.model("Tree", parent)
	local lean = CFrame.Angles(math.rad((t - 0.5) * 10), t * 6.28, 0)
	local base = CFrame.new(ground) * lean
	local trunkWidth = math.max(1.2, height * 0.09)
	Parts.column(trunkWidth, height, base * CFrame.new(0, -1, 0), palette.trunk, model, { collide = true })
	local top = (base * CFrame.new(0, height, 0)).Position
	local canopy = height * 0.55
	local leaf = pick(palette.leaves, t)
	Parts.ball(canopy, top, leaf, model)
	for index = 1, 3 do
		local angle = t * 6.28 + index * 2.1
		local offset = Vector3.new(math.cos(angle) * canopy * 0.38, -canopy * 0.12 + index * 0.3, math.sin(angle) * canopy * 0.38)
		Parts.ball(canopy * (0.55 + 0.08 * index), top + offset, Parts.vary(leaf, 0.18, (t * 7 + index) % 1), model, { shadow = index == 1 })
	end
	return model
end

-- Conifer: trunk and stacked cones made of wedges.
function Nature.pineTree(ground: Vector3, height: number, t: number, palette: TreePalette, parent: Instance): Model
	local model = Parts.model("Pine", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, t * 6.28, 0)
	Parts.column(math.max(1.2, height * 0.08), height * 0.45, base * CFrame.new(0, -1, 0), palette.trunk, model, { collide = true })
	local leaf = pick(palette.leaves, t)
	for tier = 0, 2 do
		local width = height * (0.55 - tier * 0.13)
		local tierHeight = height * 0.32
		local y = height * 0.3 + tier * height * 0.2
		for quarter = 0, 3 do
			local rotation = CFrame.Angles(0, quarter * math.pi / 2, 0)
			Parts.wedge(Vector3.new(width, tierHeight, width / 2), base * CFrame.new(0, y + tierHeight / 2, 0) * rotation * CFrame.new(0, 0, -width / 4), Parts.vary(leaf, 0.15, tier / 3), model, { shadow = tier == 0 })
		end
	end
	return model
end

function Nature.bush(ground: Vector3, size: number, t: number, colors: { Color3 }, parent: Instance): Model
	local model = Parts.model("Bush", parent)
	local color = pick(colors, t)
	Parts.ball(size, ground + Vector3.new(0, size * 0.3, 0), color, model, { shadow = false })
	for index = 1, 2 do
		local angle = t * 6.28 + index * 2.6
		local offset = Vector3.new(math.cos(angle) * size * 0.4, size * 0.15, math.sin(angle) * size * 0.4)
		Parts.ball(size * 0.7, ground + offset, Parts.vary(color, 0.2, (t + index * 0.37) % 1), model, { shadow = false })
	end
	return model
end

-- Chunky boulder: a few rotated blocks around a ball.
function Nature.rock(ground: Vector3, size: number, t: number, color: Color3, parent: Instance): Model
	local model = Parts.model("Rock", parent)
	local spin = CFrame.Angles(t * 3, t * 6.28, t * 1.7)
	Parts.block(Vector3.new(size, size * 0.7, size * 0.85), CFrame.new(ground + Vector3.new(0, size * 0.2, 0)) * spin, color, model, { collide = size > 4 })
	Parts.block(Vector3.new(size * 0.7, size * 0.6, size * 0.6), CFrame.new(ground + Vector3.new(size * 0.35, size * 0.1, -size * 0.2)) * spin:Inverse(), Parts.vary(color, 0.25, 0.3), model, { shadow = false })
	return model
end

-- Small glowing flower patch (stem-less cartoon flowers).
function Nature.flowers(ground: Vector3, t: number, colors: { Color3 }, parent: Instance): Model
	local model = Parts.model("Flowers", parent)
	for index = 1, 5 do
		local angle = t * 6.28 + index * 1.26
		local distance = 0.8 + (index % 3) * 0.9
		local position = ground + Vector3.new(math.cos(angle) * distance, 0.35, math.sin(angle) * distance)
		Parts.ball(0.7, position, pick(colors, (t + index * 0.21) % 1), model, { shadow = false })
	end
	return model
end

return Nature
