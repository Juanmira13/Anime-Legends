--!strict
-- A character's 3D model inside a ViewportFrame, framed to fit, for UI cards
-- (gacha panel and reveal). Uses the character's model (an imported avatar in
-- ReplicatedStorage.ImportedCharacters, else ReplicatedStorage.CharacterModels;
-- see Shared.ModelLookup)
-- like the followers, or a block in the rarity color if the model is missing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Data.Characters)
local ModelLookup = require(Shared.ModelLookup)

local Theme = require(script.Parent.Theme)

local FIELD_OF_VIEW = 30 -- degrees
local MARGIN = 1.12 -- room around the model
local PLACEHOLDER_SIZE = 2 -- studs

export type CharacterView = {
	frame: ViewportFrame,
	model: Model,
	pivot: CFrame, -- model pivot that puts its center at the origin, facing the camera
}

local CharacterViewport = {}

local function buildModel(characterId: string): Model
	local character = Characters.get(characterId)
	local template = ModelLookup.find({
		{
			root = ReplicatedStorage:FindFirstChild("ImportedCharacters"),
			name = "ReplicatedStorage.ImportedCharacters",
		},
		{ root = ReplicatedStorage:FindFirstChild("CharacterModels"), name = "ReplicatedStorage.CharacterModels" },
	}, { character.island, characterId })
	if template then
		return template:Clone()
	end
	local model = Instance.new("Model")
	local block = Instance.new("Part")
	block.Name = "Root"
	block.Size = Vector3.one * PLACEHOLDER_SIZE
	block.Color = Theme.rarityColor(character.rarity)
	block.Parent = model
	model.PrimaryPart = block
	return model
end

-- A transparent ViewportFrame showing the character, centered and facing the camera.
function CharacterViewport.new(
	characterId: string,
	props: {
		size: UDim2,
		position: UDim2,
		zIndex: number?,
		parent: Instance,
	}
): CharacterView
	local frame = Instance.new("ViewportFrame")
	frame.Name = "CharacterView"
	frame.Size = props.size
	frame.Position = props.position
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(190, 190, 200)
	frame.LightColor = Color3.new(1, 1, 1)
	frame.LightDirection = Vector3.new(-0.5, -1, 0.7)
	frame.ZIndex = props.zIndex or 1
	frame.Parent = props.parent

	local model = buildModel(characterId)
	model.Parent = frame
	-- Move the model's center to the origin; rigs face -Z, so the camera looks from -Z.
	local boxCFrame, boxSize = model:GetBoundingBox()
	local pivot = model:GetPivot() - boxCFrame.Position
	model:PivotTo(pivot)

	local camera = Instance.new("Camera")
	camera.FieldOfView = FIELD_OF_VIEW
	local half = math.max(boxSize.X, boxSize.Y, boxSize.Z) / 2
	local distance = half / math.tan(math.rad(FIELD_OF_VIEW / 2)) * MARGIN + half
	camera.CFrame = CFrame.lookAt(Vector3.new(0, boxSize.Y * 0.05, -distance), Vector3.zero)
	camera.Parent = frame
	frame.CurrentCamera = camera

	return { frame = frame, model = model, pivot = pivot }
end

-- Turns the character around its vertical axis (radians; 0 = facing the camera).
function CharacterViewport.setYaw(view: CharacterView, yaw: number)
	view.model:PivotTo(CFrame.Angles(0, yaw, 0) * view.pivot)
end

return CharacterViewport
