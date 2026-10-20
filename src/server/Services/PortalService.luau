--!strict
-- Portals between islands.
--
-- A portal is any BasePart tagged "Portal" with a TargetIsland attribute; the
-- server gives it a ProximityPrompt. Using it unlocks the island (paying yen,
-- in progression order) if needed, then teleports the player to the island's
-- arrival point: a BasePart tagged "IslandSpawn" with an Island attribute.
-- Unlocked islands are replicated as player attributes "Unlocked_<IslandId>".
-- The island the player is on is replicated as "CurrentArea" (the client uses
-- it for the island's ambience).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Islands = require(Shared.Data.Islands)

local Server = script.Parent.Parent
local PortalOps = require(Server.Portals.PortalOps)
local Remotes = require(Server.Remotes)
local DataService = require(script.Parent.DataService)

type Data = DataService.Data

export type UseResult = {
	ok: boolean,
	reason: string?,
	island: string?,
	unlocked: boolean?, -- true when this use unlocked the island
}

local PORTAL_TAG = "Portal"
local SPAWN_TAG = "IslandSpawn"
local PROMPT_DISTANCE = 10
local PROMPT_HOLD = 0.5 -- seconds; avoids paying for an island by accident
local MIN_TIME_BETWEEN_USES = 1

local resultRemote = Remotes.event("PortalResult")
local lastUseTime: { [Player]: number } = {}

local PortalService = {}

local function findSpawn(islandId: string): BasePart?
	for _, spawnPoint in CollectionService:GetTagged(SPAWN_TAG) do
		if spawnPoint:IsA("BasePart") and spawnPoint:GetAttribute("Island") == islandId then
			return spawnPoint
		end
	end
	return nil
end

local function replicateUnlocked(player: Player, data: Data)
	for islandId, unlocked in data.UnlockedIslands do
		player:SetAttribute(`Unlocked_{islandId}`, unlocked)
	end
end

-- Moves the player's character to an island's arrival point.
local function placeOnIsland(player: Player, islandId: string): boolean
	local spawnPoint = findSpawn(islandId)
	local character = player.Character
	if spawnPoint == nil or character == nil or character.PrimaryPart == nil then
		return false
	end
	local target = spawnPoint.CFrame * CFrame.new(0, spawnPoint.Size.Y / 2 + 3, 0)
	-- With streaming, load the destination first so the player does not fall through it.
	pcall(player.RequestStreamAroundAsync, player, target.Position)
	character:PivotTo(target)
	player:SetAttribute("CurrentArea", islandId)
	return true
end

function PortalService.use(player: Player, islandId: string): UseResult
	local data = DataService.getData(player)
	if data == nil then
		return { ok = false, reason = "NotLoaded" }
	end

	local now = time()
	if now - (lastUseTime[player] or -math.huge) < MIN_TIME_BETWEEN_USES then
		return { ok = false, reason = "TooFast" }
	end
	lastUseTime[player] = now

	local unlockedNow = false
	if not PortalOps.isUnlocked(data, islandId) then
		local canUnlock, reason = PortalOps.canUnlock(data, islandId)
		if not canUnlock then
			return { ok = false, reason = reason, island = islandId }
		end
		if not DataService.spendCurrency(player, "Yen", PortalOps.unlockCost(islandId)) then
			return { ok = false, reason = "NotEnoughYen", island = islandId }
		end
		PortalOps.unlock(data, islandId)
		replicateUnlocked(player, data)
		unlockedNow = true
	end

	if not placeOnIsland(player, islandId) then
		warn(`[PortalService] No IslandSpawn for {islandId}; cannot teleport {player.Name}`)
		return { ok = false, reason = "NoSpawn", island = islandId, unlocked = unlockedNow }
	end
	data.LastIsland = islandId
	return { ok = true, island = islandId, unlocked = unlockedNow }
end

local function setupPortal(portal: Instance)
	if not portal:IsA("BasePart") then
		return
	end
	local islandId = portal:GetAttribute("TargetIsland")
	local ok, island = pcall(Islands.get, islandId :: any)
	if not ok or type(islandId) ~= "string" then
		warn(`[PortalService] Invalid portal {portal:GetFullName()}: {island}`)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = `Portal a {island.displayName}`
	prompt.ActionText = "Viajar" -- the client shows the unlock cost when locked
	prompt.HoldDuration = PROMPT_HOLD
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		resultRemote:FireClient(player, PortalService.use(player, islandId))
	end)
	prompt.Parent = portal
end

-- On join or respawn, put the player on their last island once data is ready.
local function placeAtSpawnIsland(player: Player)
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	local islandId = PortalOps.spawnIsland(data)
	data.LastIsland = islandId
	placeOnIsland(player, islandId)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		-- Wait for the root part, then move after the default spawn has placed the character.
		character:WaitForChild("HumanoidRootPart", 10)
		task.defer(placeAtSpawnIsland, player)
	end)
end

function PortalService.start()
	for _, portal in CollectionService:GetTagged(PORTAL_TAG) do
		setupPortal(portal)
	end
	CollectionService:GetInstanceAddedSignal(PORTAL_TAG):Connect(setupPortal)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	DataService.Loaded:Connect(function(player: Player, data: Data)
		replicateUnlocked(player, data)
		placeAtSpawnIsland(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastUseTime[player] = nil
	end)
end

return PortalService
