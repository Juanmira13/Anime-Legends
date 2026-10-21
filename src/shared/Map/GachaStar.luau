--!strict
-- The gacha machine's star: a chunky five-pointed 3D star in three layers (a
-- dark outline behind, the golden body and a glowing heart), standing upright
-- so the client can spin it around its vertical axis. Its core is the part
-- tagged "GachaStand". Used by the Island Builder plugin and Dev/TestArena.
-- `pieces` is pure (plain numbers) so the geometry is unit tested in map.spec;
-- `build` makes the parts.

export type Vec = { x: number, y: number, z: number }

-- A WedgePart in the star's own frame (the star lies in the XY plane, points
-- up, depth along Z): its center, its axes and its size along them.
export type Wedge = {
	center: Vec,
	right: Vec,
	up: Vec,
	back: Vec,
	size: Vec,
}

local GachaStar = {}

GachaStar.POINTS = 5
GachaStar.INNER_RATIO = 0.45 -- inner radius over outer radius (classic stars use 0.38; chunkier is cuter)

local function vec(x: number, y: number, z: number): Vec
	return { x = x, y = y, z = z }
end

local function cross(a: Vec, b: Vec): Vec
	return vec(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
end

-- Radius of the star's inner vertices (where two points meet).
function GachaStar.innerRadius(radius: number): number
	return radius * GachaStar.INNER_RATIO
end

-- The wedges of a star with outer `radius` and `depth`: each point is two
-- right-triangle wedges back to back, from its base on the inner pentagon to
-- its tip. A WedgePart's right angle is at its bottom back (-Y, +Z) and it is
-- tall at the back, so: up = toward the tip, back = away from the point's side.
function GachaStar.pieces(radius: number, depth: number): { Wedge }
	local inner = GachaStar.innerRadius(radius)
	local halfAngle = math.pi / GachaStar.POINTS
	local baseDistance = inner * math.cos(halfAngle) -- center to the middle of a point's base
	local halfBase = inner * math.sin(halfAngle)
	local length = radius - baseDistance
	local wedges = {}
	for point = 0, GachaStar.POINTS - 1 do
		local angle = point * 2 * halfAngle
		local dir = vec(math.sin(angle), math.cos(angle), 0)
		local perp = vec(math.cos(angle), -math.sin(angle), 0)
		for _, side in { 1, -1 } do
			local sideX, sideY = perp.x * side, perp.y * side
			local up = dir
			local back = vec(-sideX, -sideY, 0)
			table.insert(wedges, {
				center = vec(
					dir.x * (baseDistance + length / 2) + sideX * halfBase / 2,
					dir.y * (baseDistance + length / 2) + sideY * halfBase / 2,
					0
				),
				right = cross(up, back),
				up = up,
				back = back,
				size = vec(depth, length, halfBase),
			})
		end
	end
	return wedges
end

local function part(class: string, name: string, color: Color3, material: Enum.Material, parent: Instance): BasePart
	local piece = Instance.new(class) :: BasePart
	piece.Name = name
	piece.Color = color
	piece.Material = material
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.Parent = parent
	return piece
end

-- Builds the star centered on `center` (facing its -Z), `radius` studs to the
-- tips, with a light and sparkles in `accent`. Returns the model and its core
-- (the part to tag "GachaStand").
function GachaStar.build(center: CFrame, radius: number, accent: Color3, parent: Instance): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "GachaStar"
	local depth = radius * 0.42
	local core: BasePart? = nil
	-- A dark outline behind, the golden body and a glowing heart that pokes out of both faces.
	local layers = {
		{
			name = "Outline",
			scale = 1.14,
			depth = 0.55,
			color = Color3.fromRGB(150, 70, 0),
			material = Enum.Material.SmoothPlastic,
		},
		{
			name = "Body",
			scale = 1,
			depth = 1,
			color = Color3.fromRGB(255, 196, 40),
			material = Enum.Material.SmoothPlastic,
		},
		{
			name = "Heart",
			scale = 0.5,
			depth = 1.15,
			color = Color3.fromRGB(255, 245, 170),
			material = Enum.Material.Neon,
		},
	}
	for _, layer in layers do
		local layerRadius = radius * layer.scale
		local layerDepth = depth * layer.depth
		for index, wedge in GachaStar.pieces(layerRadius, layerDepth) do
			local piece = part("WedgePart", `{layer.name}{index}`, layer.color, layer.material, model)
			piece.Size = Vector3.new(wedge.size.x, wedge.size.y, wedge.size.z)
			piece.CFrame = center
				* CFrame.fromMatrix(
					Vector3.new(wedge.center.x, wedge.center.y, wedge.center.z),
					Vector3.new(wedge.right.x, wedge.right.y, wedge.right.z),
					Vector3.new(wedge.up.x, wedge.up.y, wedge.up.z),
					Vector3.new(wedge.back.x, wedge.back.y, wedge.back.z)
				)
		end
		-- The inner pentagon, as a cylinder along Z (a cylinder's axis is its X).
		local hub = part("Part", `{layer.name}Core`, layer.color, layer.material, model) :: Part
		hub.Shape = Enum.PartType.Cylinder
		local diameter = GachaStar.innerRadius(layerRadius) * 2
		hub.Size = Vector3.new(layerDepth * 1.08, diameter, diameter)
		hub.CFrame = center * CFrame.Angles(0, math.pi / 2, 0)
		if layer.name == "Body" then
			core = hub
		end
	end
	local body = core :: BasePart
	body.Name = "Core"
	model.PrimaryPart = body

	local light = Instance.new("PointLight")
	light.Color = accent
	light.Range = radius * 4
	light.Brightness = 2
	light.Parent = body

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.new(1, 1, 1), accent)
	sparkles.LightEmission = 1
	sparkles.Rate = 8
	sparkles.Lifetime = NumberRange.new(0.8, 1.6)
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Size = NumberSequence.new(radius * 0.18, 0)
	sparkles.Parent = body

	model.Parent = parent
	return model, body
end

return GachaStar
