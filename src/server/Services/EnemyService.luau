--!strict
-- Spawns enemies at spawn points and tracks their health.
--
-- A spawn point is any BasePart tagged "EnemySpawn" with the attributes
-- Island (island id, e.g. "Nameku") and Rank ("Easy", "Medium", "Hard" or "Boss").
-- The enemy model is ServerStorage.EnemyModels.<Island>.<Rank> if it exists
-- (a Model with a PrimaryPart), otherwise a placeholder block.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Formulas = require(Shared.Formulas)
local Islands = require(Shared.Data.Islands)

export type Enemy = {
	id: string,
	island: string,
	rank: string,
	health: number,
	maxHealth: number,
	alive: boolean,
	model: Model,
	root: BasePart,
	spawnPoint: BasePart,
	damagers: { [Player]: boolean }, -- everyone who hit it gets the kill reward
}

local SPAWN_TAG = "EnemySpawn"
local ENEMY_TAG = "Enemy"

local PLACEHOLDER_LOOK: { [string]: { size: number, color: Color3 } } = {
	Easy = { size = 3, color = Color3.fromRGB(110, 200, 110) },
	Medium = { size = 4, color = Color3.fromRGB(230, 200, 80) },
	Hard = { size = 5, color = Color3.fromRGB(230, 110, 60) },
	Boss = { size = 9, color = Color3.fromRGB(170, 50, 200) },
}

local enemies: { [string]: Enemy } = {}
local nextId = 0
local clickedEvent = Instance.new("BindableEvent")
local diedEvent = Instance.new("BindableEvent")

local enemyFolder = Instance.new("Folder")
enemyFolder.Name = "Enemies"
enemyFolder.Parent = workspace

local EnemyService = {}

-- Fires (player, enemy) when a player clicks an enemy.
EnemyService.Clicked = clickedEvent.Event

-- Fires (enemy) when an enemy's health reaches 0, before its model is removed.
EnemyService.Died = diedEvent.Event

local function getTemplate(islandId: string, rankId: string): Model?
	local models = ServerStorage:FindFirstChild("EnemyModels")
	local islandFolder = models and models:FindFirstChild(islandId)
	local template = islandFolder and islandFolder:FindFirstChild(rankId)
	if template and template:IsA("Model") and template.PrimaryPart then
		return template
	end
	return nil
end

local function buildModel(islandId: string, rankId: string): Model
	local template = getTemplate(islandId, rankId)
	if template then
		return template:Clone()
	end
	local look = PLACEHOLDER_LOOK[rankId]
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * look.size
	root.Color = look.color
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = true
	root.Parent = model
	model.PrimaryPart = root
	return model
end

local function getDisplayName(islandId: string, rankId: string): string
	if rankId == "Boss" then
		return `Jefe de {Islands.get(islandId).displayName}`
	end
	return `Enemigo {Balance.getEnemyRank(rankId).displayName}`
end

local function spawnAt(spawnPoint: BasePart)
	if not spawnPoint:IsDescendantOf(workspace) then
		return
	end
	local islandId = spawnPoint:GetAttribute("Island")
	local rankId = spawnPoint:GetAttribute("Rank")
	local ok, maxHealth = pcall(function()
		assert(type(islandId) == "string" and type(rankId) == "string", "Island and Rank attributes are required")
		return Formulas.enemyHealth(islandId, rankId)
	end)
	if not ok then
		warn(`[EnemyService] Invalid spawn point {spawnPoint:GetFullName()}: {maxHealth}`)
		return
	end
	assert(type(islandId) == "string" and type(rankId) == "string", "unreachable")

	nextId += 1
	local id = tostring(nextId)
	local model = buildModel(islandId, rankId)
	local root = model.PrimaryPart :: BasePart
	model.Name = `{islandId}_{rankId}_{id}`
	-- Stream the whole model at once so clients always get its PrimaryPart.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:PivotTo(spawnPoint.CFrame * CFrame.new(0, spawnPoint.Size.Y / 2 + root.Size.Y / 2, 0))
	model:SetAttribute("EnemyId", id)
	model:SetAttribute("Island", islandId)
	model:SetAttribute("Rank", rankId)
	model:SetAttribute("DisplayName", getDisplayName(islandId, rankId))
	model:SetAttribute("Health", maxHealth)
	model:SetAttribute("MaxHealth", maxHealth)

	local enemy: Enemy = {
		id = id,
		island = islandId,
		rank = rankId,
		health = maxHealth,
		maxHealth = maxHealth,
		alive = true,
		model = model,
		root = root,
		spawnPoint = spawnPoint,
		damagers = {},
	}
	enemies[id] = enemy

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = Balance.Combat.range
	clickDetector.MouseClick:Connect(function(player)
		if enemy.alive then
			clickedEvent:Fire(player, enemy)
		end
	end)
	clickDetector.Parent = root

	CollectionService:AddTag(model, ENEMY_TAG)
	model.Parent = enemyFolder
end

-- Applies damage from a player. Kills and schedules the respawn when health
-- reaches 0. Returns whether the enemy died from this hit.
function EnemyService.damage(enemy: Enemy, player: Player, amount: number): boolean
	if not enemy.alive then
		return false
	end
	enemy.damagers[player] = true
	enemy.health = math.max(0, enemy.health - amount)
	enemy.model:SetAttribute("Health", enemy.health)
	if enemy.health > 0 then
		return false
	end

	enemy.alive = false
	enemies[enemy.id] = nil
	diedEvent:Fire(enemy)
	enemy.model:Destroy()
	task.delay(Formulas.enemyRespawnTime(enemy.rank), spawnAt, enemy.spawnPoint)
	return true
end

function EnemyService.get(id: string): Enemy?
	return enemies[id]
end

function EnemyService.start()
	for _, spawnPoint in CollectionService:GetTagged(SPAWN_TAG) do
		if spawnPoint:IsA("BasePart") then
			spawnAt(spawnPoint)
		end
	end
	CollectionService:GetInstanceAddedSignal(SPAWN_TAG):Connect(function(spawnPoint)
		if spawnPoint:IsA("BasePart") then
			spawnAt(spawnPoint)
		end
	end)
end

return EnemyService
