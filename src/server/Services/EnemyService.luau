--!strict
-- Spawns enemies and tracks their health.
--
-- Island enemies: any BasePart tagged "EnemySpawn" with the attributes Island
-- (island id, e.g. "Nameku") and Rank ("Easy", "Medium", "Hard" or "Boss")
-- spawns one, which respawns there after it dies. Other systems (raids) spawn
-- one-off enemies with EnemyService.spawn.
--
-- The model is ServerStorage.EnemyModels.<folder>.<name> if it exists (a Model
-- with a PrimaryPart; e.g. EnemyModels.Nameku.Easy or EnemyModels.Raid.Boss),
-- otherwise a placeholder block.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Formulas = require(Shared.Formulas)
local Islands = require(Shared.Data.Islands)

export type Enemy = {
	id: string,
	health: number,
	maxHealth: number,
	alive: boolean,
	model: Model,
	root: BasePart,
	damagers: { [Player]: boolean },
	-- Island enemies
	island: string?,
	rank: string?,
	spawnPoint: BasePart?, -- respawns here after dying
	-- Raid enemies
	raidSessionId: string?,
	raidType: string?,
}

export type SpawnSpec = {
	cframe: CFrame, -- ground point the enemy stands on
	maxHealth: number,
	displayName: string,
	look: string, -- placeholder look: Easy, Medium, Hard, Boss, Weak or MiniBoss
	template: { string }, -- path under ServerStorage.EnemyModels
	parent: Instance?,
	island: string?,
	rank: string?,
	spawnPoint: BasePart?,
	raidSessionId: string?,
	raidType: string?,
}

local SPAWN_TAG = "EnemySpawn"
local ENEMY_TAG = "Enemy"

local PLACEHOLDER_LOOK: { [string]: { size: number, color: Color3 } } = {
	Easy = { size = 3, color = Color3.fromRGB(110, 200, 110) },
	Weak = { size = 3, color = Color3.fromRGB(110, 200, 110) },
	Medium = { size = 4, color = Color3.fromRGB(230, 200, 80) },
	Hard = { size = 5, color = Color3.fromRGB(230, 110, 60) },
	MiniBoss = { size = 7, color = Color3.fromRGB(220, 60, 60) },
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

local function getTemplate(path: { string }): Model?
	local node: Instance? = ServerStorage:FindFirstChild("EnemyModels")
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	if node and node:IsA("Model") and node.PrimaryPart then
		return node
	end
	return nil
end

local function buildModel(spec: SpawnSpec): Model
	local template = getTemplate(spec.template)
	if template then
		return template:Clone()
	end
	local look = PLACEHOLDER_LOOK[spec.look] or PLACEHOLDER_LOOK.Easy
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

function EnemyService.spawn(spec: SpawnSpec): Enemy
	nextId += 1
	local id = tostring(nextId)
	local model = buildModel(spec)
	local root = model.PrimaryPart :: BasePart
	model.Name = `{spec.displayName}_{id}`
	-- Stream the whole model at once so clients always get its PrimaryPart.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:PivotTo(spec.cframe * CFrame.new(0, root.Size.Y / 2, 0))
	model:SetAttribute("EnemyId", id)
	model:SetAttribute("DisplayName", spec.displayName)
	model:SetAttribute("Health", spec.maxHealth)
	model:SetAttribute("MaxHealth", spec.maxHealth)

	local enemy: Enemy = {
		id = id,
		health = spec.maxHealth,
		maxHealth = spec.maxHealth,
		alive = true,
		model = model,
		root = root,
		damagers = {},
		island = spec.island,
		rank = spec.rank,
		spawnPoint = spec.spawnPoint,
		raidSessionId = spec.raidSessionId,
		raidType = spec.raidType,
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
	model.Parent = spec.parent or enemyFolder
	return enemy
end

local function getIslandDisplayName(islandId: string, rankId: string): string
	if rankId == "Boss" then
		return `Jefe de {Islands.get(islandId).displayName}`
	end
	return `Enemigo {Balance.getEnemyRank(rankId).displayName}`
end

local function spawnAtPoint(spawnPoint: BasePart)
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

	EnemyService.spawn({
		cframe = spawnPoint.CFrame * CFrame.new(0, spawnPoint.Size.Y / 2, 0),
		maxHealth = maxHealth,
		displayName = getIslandDisplayName(islandId, rankId),
		look = rankId,
		template = { islandId, rankId },
		island = islandId,
		rank = rankId,
		spawnPoint = spawnPoint,
	})
end

-- Applies damage from a player. Kills the enemy when health reaches 0 and, for
-- island enemies, schedules the respawn. Returns whether the enemy died from this hit.
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
	local spawnPoint, rank = enemy.spawnPoint, enemy.rank
	if spawnPoint and rank then
		task.delay(Formulas.enemyRespawnTime(rank), spawnAtPoint, spawnPoint)
	end
	return true
end

-- Removes an enemy without killing it (no Died event, no respawn).
function EnemyService.remove(enemy: Enemy)
	if not enemy.alive then
		return
	end
	enemy.alive = false
	enemies[enemy.id] = nil
	enemy.model:Destroy()
end

function EnemyService.get(id: string): Enemy?
	return enemies[id]
end

function EnemyService.start()
	for _, spawnPoint in CollectionService:GetTagged(SPAWN_TAG) do
		if spawnPoint:IsA("BasePart") then
			spawnAtPoint(spawnPoint)
		end
	end
	CollectionService:GetInstanceAddedSignal(SPAWN_TAG):Connect(function(spawnPoint)
		if spawnPoint:IsA("BasePart") then
			spawnAtPoint(spawnPoint)
		end
	end)
end

return EnemyService
