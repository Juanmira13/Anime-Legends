--!strict
-- Draws a health bar over every enemy and highlights the local player's target.
-- Reads the attributes the server sets on enemy models (DisplayName, Health,
-- MaxHealth, EnemyId) and on the player (TargetEnemyId).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))

local ENEMY_TAG = "Enemy"
local BAR_MAX_DISTANCE = 150

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

type Tracked = {
	billboard: BillboardGui,
	connections: { RBXScriptConnection },
}

local tracked: { [Model]: Tracked } = {}
local modelsById: { [string]: Model } = {}
local highlight = Instance.new("Highlight")
highlight.FillTransparency = 0.7
highlight.OutlineColor = Color3.fromRGB(255, 255, 255)

local EnemyController = {}

local function createBillboard(model: Model, root: BasePart): (BillboardGui, () -> ())
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EnemyHealthBar"
	billboard.Adornee = root
	billboard.Size = UDim2.fromOffset(170, 44)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, root.Size.Y / 2 + 2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = BAR_MAX_DISTANCE
	billboard.ResetOnSpawn = false

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 18)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text = tostring(model:GetAttribute("DisplayName") or "")
	nameLabel.Parent = billboard

	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromOffset(0, 22)
	bar.Size = UDim2.new(1, 0, 0, 20)
	bar.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bar.BorderSizePixel = 0
	bar.Parent = billboard
	Instance.new("UICorner").Parent = bar

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Instance.new("UICorner").Parent = fill

	local healthLabel = Instance.new("TextLabel")
	healthLabel.Size = UDim2.fromScale(1, 1)
	healthLabel.BackgroundTransparency = 1
	healthLabel.Font = Enum.Font.GothamBold
	healthLabel.TextScaled = true
	healthLabel.TextColor3 = Color3.new(1, 1, 1)
	healthLabel.TextStrokeTransparency = 0.4
	healthLabel.ZIndex = 2
	healthLabel.Parent = bar

	local function update()
		local health = tonumber(model:GetAttribute("Health")) or 0
		local maxHealth = tonumber(model:GetAttribute("MaxHealth")) or 1
		fill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
		healthLabel.Text = `{Format.number(health)} / {Format.number(maxHealth)}`
	end
	update()

	billboard.Parent = playerGui
	return billboard, update
end

local function updateHighlight()
	local targetId = player:GetAttribute("TargetEnemyId")
	local model = if type(targetId) == "string" then modelsById[targetId] else nil
	highlight.Adornee = model
	-- Highlights only render inside the workspace; the camera is local to this client.
	highlight.Parent = if model then workspace.CurrentCamera else nil
end

local function track(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] then
		return
	end
	local model = instance
	local root = model.PrimaryPart
	if root == nil then
		return
	end
	local billboard, update = createBillboard(model, root)
	tracked[model] = {
		billboard = billboard,
		connections = { model:GetAttributeChangedSignal("Health"):Connect(update) },
	}
	local id = model:GetAttribute("EnemyId")
	if type(id) == "string" then
		modelsById[id] = model
	end
	updateHighlight()
end

local function untrack(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local entry = tracked[instance]
	if entry == nil then
		return
	end
	tracked[instance] = nil
	for _, connection in entry.connections do
		connection:Disconnect()
	end
	entry.billboard:Destroy()
	local id = instance:GetAttribute("EnemyId")
	if type(id) == "string" and modelsById[id] == instance then
		modelsById[id] = nil
	end
	updateHighlight()
end

function EnemyController.start()
	CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(ENEMY_TAG):Connect(untrack)
	for _, instance in CollectionService:GetTagged(ENEMY_TAG) do
		track(instance)
	end
	player:GetAttributeChangedSignal("TargetEnemyId"):Connect(updateHighlight)
end

return EnemyController
