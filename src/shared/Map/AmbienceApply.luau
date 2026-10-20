--!strict
-- Applies an area's ambience (Config.Ambience) to Lighting, its effects and
-- the terrain colors. Used by the client when the area changes and by the
-- island builder plugin so Studio previews the same look.

local Lighting = game:GetService("Lighting")

local Ambience = require(script.Parent.Parent.Config.Ambience)

local AmbienceApply = {}

local function rgb(color: { number }): Color3
	return Color3.fromRGB(color[1], color[2], color[3])
end

-- Finds or creates a Lighting child of a class (one per class).
local function ensure<T>(className: string): T
	local existing = Lighting:FindFirstChildOfClass(className :: any)
	if existing then
		return existing :: any
	end
	local instance = Instance.new(className :: any)
	instance.Parent = Lighting
	return instance :: any
end

function AmbienceApply.apply(areaId: string)
	local ambience = Ambience.get(areaId)

	Lighting.ClockTime = ambience.clockTime
	Lighting.Brightness = ambience.brightness
	Lighting.Ambient = rgb(ambience.ambient)
	Lighting.OutdoorAmbient = rgb(ambience.outdoorAmbient)
	Lighting.ColorShift_Top = rgb(ambience.colorShiftTop)
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1

	local atmosphere = ensure("Atmosphere") :: Atmosphere
	atmosphere.Density = ambience.atmosphere.density
	atmosphere.Offset = ambience.atmosphere.offset
	atmosphere.Color = rgb(ambience.atmosphere.color)
	atmosphere.Decay = rgb(ambience.atmosphere.decay)
	atmosphere.Glare = ambience.atmosphere.glare
	atmosphere.Haze = ambience.atmosphere.haze

	local sky = ensure("Sky") :: Sky
	sky.StarCount = ambience.stars
	sky.CelestialBodiesShown = true

	local correction = ensure("ColorCorrectionEffect") :: ColorCorrectionEffect
	correction.Brightness = ambience.colorCorrection.brightness
	correction.Contrast = ambience.colorCorrection.contrast
	correction.Saturation = ambience.colorCorrection.saturation
	correction.TintColor = rgb(ambience.colorCorrection.tint)

	local bloom = ensure("BloomEffect") :: BloomEffect
	bloom.Intensity = ambience.bloom.intensity
	bloom.Size = ambience.bloom.size
	bloom.Threshold = ambience.bloom.threshold

	local sunRays = ensure("SunRaysEffect") :: SunRaysEffect
	sunRays.Intensity = ambience.sunRays.intensity
	sunRays.Spread = ambience.sunRays.spread

	local terrain = workspace.Terrain
	local water = ambience.water
	terrain.WaterColor = rgb(water.color)
	terrain.WaterTransparency = water.transparency
	terrain.WaterReflectance = water.reflectance
	terrain.WaterWaveSize = water.waveSize
	terrain.WaterWaveSpeed = water.waveSpeed
	for materialName, color in ambience.terrain do
		terrain:SetMaterialColor((Enum.Material :: any)[materialName], rgb(color))
	end
end

return AmbienceApply
