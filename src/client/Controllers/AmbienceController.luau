--!strict
-- Gives each area its look: applies Config.Ambience for the player attribute
-- "CurrentArea" (lighting, sky, fog, color grading, terrain and water colors)
-- and floats the area's ambient particles (pollen, leaves, petals...) around
-- the camera.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ambience = require(Shared.Config.Ambience)
local AmbienceApply = require(Shared.Map.AmbienceApply)

local PARTICLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local PARTICLE_BOX = Vector3.new(90, 30, 90) -- studs around the camera

local player = Players.LocalPlayer

local AmbienceController = {}

local emitterPart = Instance.new("Part")
emitterPart.Name = "AmbientParticles"
emitterPart.Size = PARTICLE_BOX
emitterPart.Transparency = 1
emitterPart.Anchored = true
emitterPart.CanCollide = false
emitterPart.CanQuery = false
emitterPart.CanTouch = false

local emitter = Instance.new("ParticleEmitter")
emitter.Texture = PARTICLE_TEXTURE
emitter.Shape = Enum.ParticleEmitterShape.Box
emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
emitter.SpreadAngle = Vector2.new(180, 180)
emitter.RotSpeed = NumberRange.new(-40, 40)
emitter.Rotation = NumberRange.new(0, 360)
emitter.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.2, 0.2),
	NumberSequenceKeypoint.new(0.8, 0.2),
	NumberSequenceKeypoint.new(1, 1),
})
emitter.Parent = emitterPart

local function applyParticles(areaId: string)
	local particles = Ambience.get(areaId).particles
	if particles == nil then
		emitter.Enabled = false
		return
	end
	local color = Color3.fromRGB(particles.color[1], particles.color[2], particles.color[3])
	emitter.Color = ColorSequence.new(color)
	emitter.Rate = particles.rate
	emitter.Size = NumberSequence.new(particles.size)
	emitter.Speed = NumberRange.new(particles.speed * 0.5, particles.speed)
	emitter.Lifetime = NumberRange.new(particles.lifetime * 0.7, particles.lifetime)
	emitter.LightEmission = particles.light
	emitter.Enabled = true
end

local function applyArea()
	local area = player:GetAttribute("CurrentArea")
	local areaId = if type(area) == "string" then area else Ambience.DefaultArea
	AmbienceApply.apply(areaId)
	applyParticles(areaId)
end

function AmbienceController.start()
	emitterPart.Parent = workspace.CurrentCamera
	applyArea()
	player:GetAttributeChangedSignal("CurrentArea"):Connect(applyArea)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera then
			emitterPart.CFrame = CFrame.new(camera.CFrame.Position)
		end
	end)
end

return AmbienceController
