--!strict
-- Brings the cartoon sea to life: scrolls the texture of every "SeaSurface"
-- part and makes the "SeaFoam" rings along the shores breathe. Only foam near
-- the camera is animated.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local World = require(ReplicatedStorage:WaitForChild("Shared").Config.World)

local FOAM_DISTANCE = 500 -- studs from the camera
local FOAM_REFRESH = 1 -- seconds between rebuilding the list of nearby foam
local FOAM_SPEED = 1.6 -- radians per second
local FOAM_MIN, FOAM_MAX = 0.1, 0.55 -- transparency range

local SeaController = {}

local nearbyFoam: { BasePart } = {}
local lastRefresh = -math.huge

local function refreshFoam(cameraPosition: Vector3)
	nearbyFoam = {}
	for _, instance in CollectionService:GetTagged("SeaFoam") do
		if instance:IsA("BasePart") and (instance.Position - cameraPosition).Magnitude < FOAM_DISTANCE then
			table.insert(nearbyFoam, instance)
		end
	end
end

local function step()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local now = os.clock()
	local sea = World.Sea

	for _, surface in CollectionService:GetTagged("SeaSurface") do
		local texture = surface:FindFirstChildOfClass("Texture")
		if texture then
			texture.OffsetStudsU = (now * sea.scrollSpeed[1]) % sea.studsPerTile
			texture.OffsetStudsV = (now * sea.scrollSpeed[2]) % sea.studsPerTile
		end
	end

	if now - lastRefresh > FOAM_REFRESH then
		lastRefresh = now
		refreshFoam(camera.CFrame.Position)
	end
	for _, foam in nearbyFoam do
		local phase = tonumber(foam:GetAttribute("Phase")) or 0
		local wave = (math.sin(now * FOAM_SPEED + phase) + 1) / 2
		foam.Transparency = FOAM_MIN + (FOAM_MAX - FOAM_MIN) * wave
	end
end

function SeaController.start()
	RunService.RenderStepped:Connect(step)
end

return SeaController
