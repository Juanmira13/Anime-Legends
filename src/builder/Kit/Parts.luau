--!strict
-- Part helpers for the map kit. Decoration is anchored, cartoon smooth, and
-- invisible to queries (clicks on enemies and ground rays pass through), so the
-- map never gets in the way of gameplay.

local Parts = {}

export type Options = {
	collide: boolean?, -- default false; buildings and big trunks set it
	shadow: boolean?, -- default true; small props turn it off
	material: Enum.Material?,
	transparency: number?,
	name: string?,
}

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end
Parts.rgb = rgb

local function make(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3, parent: Instance, options: Options?): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	part.CanCollide = options ~= nil and options.collide == true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = options == nil or options.shadow ~= false
	part.Material = options and options.material or Enum.Material.SmoothPlastic
	part.Transparency = options and options.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Name = options and options.name or "Part"
	part.Parent = parent
	return part
end

function Parts.block(size: Vector3, cframe: CFrame, color: Color3, parent: Instance, options: Options?): Part
	return make(Enum.PartType.Block, size, cframe, color, parent, options)
end

-- Ball of a diameter centered at `position`.
function Parts.ball(diameter: number, position: Vector3, color: Color3, parent: Instance, options: Options?): Part
	return make(Enum.PartType.Ball, Vector3.one * diameter, CFrame.new(position), color, parent, options)
end

-- Upright cylinder whose base center is at `base` (rotated by `tilt` if given).
function Parts.column(diameter: number, height: number, base: CFrame, color: Color3, parent: Instance, options: Options?): Part
	-- Roblox cylinders run along X; turn them upright.
	local cframe = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
	return make(Enum.PartType.Cylinder, Vector3.new(height, diameter, diameter), cframe, color, parent, options)
end

-- Cylinder along `axis` (a direction) centered at `position`.
function Parts.cylinder(diameter: number, length: number, position: Vector3, axis: Vector3, color: Color3, parent: Instance, options: Options?): Part
	-- lookAt points -Z along the axis; turning 90° about Y puts the cylinder's X there.
	local cframe = CFrame.lookAt(position, position + axis) * CFrame.Angles(0, math.rad(90), 0)
	return make(Enum.PartType.Cylinder, Vector3.new(length, diameter, diameter), cframe, color, parent, options)
end

-- Block stretched between two points (beams, legs, rails).
function Parts.beam(from: Vector3, to: Vector3, width: number, color: Color3, parent: Instance, options: Options?): Part
	local length = (to - from).Magnitude
	local cframe = CFrame.lookAt((from + to) / 2, to)
	return make(Enum.PartType.Block, Vector3.new(width, width, length), cframe, color, parent, options)
end

-- Flat disc (cylinder lying down) centered at `position`.
function Parts.disc(diameter: number, thickness: number, position: Vector3, color: Color3, parent: Instance, options: Options?): Part
	local cframe = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return make(Enum.PartType.Cylinder, Vector3.new(thickness, diameter, diameter), cframe, color, parent, options)
end

function Parts.wedge(size: Vector3, cframe: CFrame, color: Color3, parent: Instance, options: Options?): WedgePart
	local part = Instance.new("WedgePart")
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	part.CanCollide = options ~= nil and options.collide == true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = options == nil or options.shadow ~= false
	part.Material = options and options.material or Enum.Material.SmoothPlastic
	part.Name = options and options.name or "Wedge"
	part.Parent = parent
	return part
end

function Parts.folder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Parts.model(name: string, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Parts.light(parent: BasePart, color: Color3, range: number, brightness: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = parent
	return light
end

-- Slightly varies a color for natural-looking repetition.
function Parts.vary(color: Color3, amount: number, t: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v * (1 + (t - 0.5) * amount), 0, 1))
end

return Parts
