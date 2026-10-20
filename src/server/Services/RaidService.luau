--!strict
-- Raids: lobby, queues, arenas, waves and rewards.
--
-- Map setup (tagged BaseParts):
--   "RaidPortal"        any island; sends the player to the raid lobby
--   "RaidLobbySpawn"    arrival point in the lobby
--   "RaidPad"           lobby pad with a Difficulty attribute (Easy, Medium, Hard)
-- Using a pad joins that difficulty's queue; the raid starts QUEUE_TIME seconds
-- after the first player joins, with everyone queued (up to Raids.MaxPlayers).
-- Each group plays in its own arena: a clone of ServerStorage.RaidArena (a Model
-- with a PrimaryPart, a "PlayerSpawn" part and an "EnemySpawns" folder of parts)
-- or a generated platform, placed high above the map.
--
-- Replicated to the client as player attributes: RaidQueue, RaidQueueStartsAt,
-- RaidSessionId, RaidDifficulty, RaidWave, RaidEndsAt, RaidReady_<Difficulty>,
-- and CurrentArea ("RaidLobby" or "Raid") for the client's ambience.
-- Times are unix seconds (compare with workspace:GetServerTimeNow()).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Raids = require(Shared.Config.Raids)

local Server = script.Parent.Parent
local RaidOps = require(Server.Raids.RaidOps)
local Remotes = require(Server.Remotes)
local BoostService = require(script.Parent.BoostService)
local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)
local InventoryService = require(script.Parent.InventoryService)

type Data = DataService.Data
type Enemy = EnemyService.Enemy

type Session = {
	id: string,
	difficulty: string,
	players: { [Player]: boolean },
	arena: Model,
	slot: number,
	playerSpawn: CFrame,
	enemySpots: { CFrame },
	enemies: { [Enemy]: boolean },
	finished: boolean,
}

type Queue = {
	players: { Player },
	startsAt: number, -- unix seconds
}

local PORTAL_TAG = "RaidPortal"
local LOBBY_SPAWN_TAG = "RaidLobbySpawn"
local PAD_TAG = "RaidPad"
local QUEUE_TIME = 15
local NEXT_WAVE_DELAY = 3
local PROMPT_DISTANCE = 10
local MIN_TIME_BETWEEN_USES = 0.5
local ARENA_ORIGIN = Vector3.new(0, 1500, 0)
local ARENA_SPACING = 400

local eventRemote = Remotes.event("RaidEvent")
local random = Random.new()
local queues: { [string]: Queue } = {}
local sessions: { [string]: Session } = {}
local playerQueue: { [Player]: string } = {}
local playerSession: { [Player]: Session } = {}
local usedSlots: { [number]: boolean } = {}
local lastUseTime: { [Player]: number } = {}
local nextSessionId = 0

-- Waves to play. Normally 1..WaveCount; DevCheats can shorten it in Studio.
local waveSequence: { number } = {}
for wave = 1, Raids.WaveCount do
	table.insert(waveSequence, wave)
end

local RaidService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function send(player: Player, payload: { [string]: any })
	eventRemote:FireClient(player, payload)
end

local function findTagged(tag: string): BasePart?
	for _, instance in CollectionService:GetTagged(tag) do
		if instance:IsA("BasePart") then
			return instance
		end
	end
	return nil
end

local function moveTo(player: Player, cframe: CFrame, area: string)
	local character = player.Character
	if character and character.PrimaryPart then
		local target = cframe * CFrame.new(0, 3, 0)
		-- With streaming, load the destination first so the player does not fall through it.
		pcall(player.RequestStreamAroundAsync, player, target.Position)
		character:PivotTo(target)
		player:SetAttribute("CurrentArea", area)
	end
end

local function sendToLobby(player: Player)
	local lobby = findTagged(LOBBY_SPAWN_TAG)
	if lobby then
		moveTo(player, lobby.CFrame * CFrame.new(0, lobby.Size.Y / 2, 0), "RaidLobby")
	else
		warn("[RaidService] No RaidLobbySpawn in the map")
	end
end

local function replicateCooldowns(player: Player, data: Data)
	for _, difficulty in Raids.Difficulties do
		player:SetAttribute(`RaidReady_{difficulty.id}`, RaidOps.readyAt(data, difficulty.id))
	end
end

local function clearSessionAttributes(player: Player)
	for _, name in { "RaidSessionId", "RaidDifficulty", "RaidWave", "RaidEndsAt" } do
		player:SetAttribute(name, nil)
	end
end

-- Arena -----------------------------------------------------------------------

local function generateArena(): (Model, CFrame, { CFrame })
	local arena = Instance.new("Model")
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(160, 2, 160)
	floor.Anchored = true
	floor.Color = Color3.fromRGB(60, 50, 80)
	floor.Material = Enum.Material.Slate
	floor.Parent = arena
	arena.PrimaryPart = floor

	local top = floor.Size.Y / 2
	local playerSpawn = CFrame.new(0, top, 60)
	local spots = {}
	-- Center first so bosses (spawned first) stand in the middle.
	table.insert(spots, CFrame.new(0, top, -35))
	for row = 0, 2 do
		for column = -2, 2 do
			if not (row == 1 and column == 0) then
				table.insert(spots, CFrame.new(column * 22, top, -15 - row * 20))
			end
		end
	end
	return arena, playerSpawn, spots
end

local function buildArena(slot: number): (Model, CFrame, { CFrame })
	local origin = CFrame.new(ARENA_ORIGIN + Vector3.new(slot * ARENA_SPACING, 0, 0))
	local template = ServerStorage:FindFirstChild("RaidArena")
	if template and template:IsA("Model") and template.PrimaryPart then
		local arena = template:Clone()
		arena:PivotTo(origin)
		-- Markers are read after pivoting, so their CFrames are already in world space.
		local spawnPart = arena:FindFirstChild("PlayerSpawn")
		local spotsFolder = arena:FindFirstChild("EnemySpawns")
		local spots = {}
		if spotsFolder then
			for _, part in spotsFolder:GetChildren() do
				if part:IsA("BasePart") then
					table.insert(spots, part.CFrame * CFrame.new(0, part.Size.Y / 2, 0))
				end
			end
		end
		if spawnPart and spawnPart:IsA("BasePart") and #spots > 0 then
			return arena, spawnPart.CFrame * CFrame.new(0, spawnPart.Size.Y / 2, 0), spots
		end
		warn("[RaidService] ServerStorage.RaidArena needs PlayerSpawn and EnemySpawns; using a generated arena")
		arena:Destroy()
	end

	local arena, playerSpawn, spots = generateArena()
	arena:PivotTo(origin)
	for index, spot in spots do
		spots[index] = origin * spot
	end
	return arena, origin * playerSpawn, spots
end

local function takeSlot(): number
	local slot = 0
	while usedSlots[slot] do
		slot += 1
	end
	usedSlots[slot] = true
	return slot
end

-- Sessions --------------------------------------------------------------------

local function leaveSession(player: Player)
	local session = playerSession[player]
	if session == nil then
		return
	end
	playerSession[player] = nil
	session.players[player] = nil
	clearSessionAttributes(player)
end

local function hasPlayers(session: Session): boolean
	return next(session.players) ~= nil
end

local function finish(session: Session, success: boolean)
	if session.finished then
		return
	end
	session.finished = true

	for enemy in session.enemies do
		EnemyService.remove(enemy)
	end
	table.clear(session.enemies)

	for player in session.players do
		local data = DataService.getData(player)
		if success and data then
			local before, after = RaidOps.complete(data, session.difficulty)
			if after > before then
				InventoryService.refresh(player)
				send(player, { kind = "Achievement", equipSlots = after })
			end
		end
		send(player, { kind = if success then "Completed" else "Failed", difficulty = session.difficulty })
		playerSession[player] = nil
		clearSessionAttributes(player)
		sendToLobby(player)
	end
	table.clear(session.players)

	session.arena:Destroy()
	usedSlots[session.slot] = nil
	sessions[session.id] = nil
end

local function onRaidEnemyDied(enemy: Enemy)
	local session = enemy.raidSessionId and sessions[enemy.raidSessionId]
	local typeId = enemy.raidType
	if session == nil or typeId == nil or session.finished then
		return
	end
	session.enemies[enemy] = nil

	for player in session.players do
		local data = DataService.getData(player)
		if data == nil then
			continue
		end
		local yen, gems = RaidOps.reward(
			session.difficulty,
			typeId,
			data.Boosts.Remaining.Money > 0,
			data.Boosts.Remaining.Gems > 0
		)
		DataService.addCurrency(player, "Yen", yen)
		DataService.addCurrency(player, "Gems", gems)
		local boostId = RaidOps.rollBoostDrop(session.difficulty, typeId, function()
			return random:NextNumber()
		end)
		if boostId then
			BoostService.grant(player, boostId)
			send(player, { kind = "BoostDrop", boost = boostId })
		end
	end
end

local function spawnWave(session: Session, wave: number)
	for index, typeId in RaidOps.waveEnemies(wave) do
		local spot = session.enemySpots[(index - 1) % #session.enemySpots + 1]
		local enemy = EnemyService.spawn({
			cframe = spot,
			maxHealth = Formulas.raidEnemyHealth(session.difficulty, typeId),
			displayName = Raids.getEnemyType(typeId).displayName,
			look = typeId,
			template = { "Raid", typeId },
			parent = session.arena,
			raidSessionId = session.id,
			raidType = typeId,
		})
		session.enemies[enemy] = true
	end
end

local function runSession(session: Session, endsAt: number)
	for _, wave in waveSequence do
		if session.finished then
			return
		end
		for player in session.players do
			player:SetAttribute("RaidWave", wave)
			send(player, { kind = "Wave", wave = wave })
		end
		spawnWave(session, wave)
		while next(session.enemies) ~= nil do
			if now() >= endsAt or not hasPlayers(session) then
				finish(session, false)
				return
			end
			task.wait(0.25)
		end
		if wave ~= waveSequence[#waveSequence] then
			task.wait(NEXT_WAVE_DELAY)
		end
	end
	finish(session, hasPlayers(session))
end

local function startQueue(difficultyId: string, queue: Queue)
	if queues[difficultyId] ~= queue then
		return
	end
	queues[difficultyId] = nil

	local startTime = os.time()
	local members = {}
	for _, player in queue.players do
		playerQueue[player] = nil
		player:SetAttribute("RaidQueue", nil)
		player:SetAttribute("RaidQueueStartsAt", nil)
		local data = DataService.getData(player)
		if player.Parent and data and playerSession[player] == nil and RaidOps.canStart(data, difficultyId, startTime) then
			table.insert(members, player)
		end
	end
	if #members == 0 then
		return
	end

	nextSessionId += 1
	local slot = takeSlot()
	local arena, playerSpawn, spots = buildArena(slot)
	arena.Name = `Raid_{difficultyId}_{nextSessionId}`
	arena.Parent = workspace
	local session: Session = {
		id = tostring(nextSessionId),
		difficulty = difficultyId,
		players = {},
		arena = arena,
		slot = slot,
		playerSpawn = playerSpawn,
		enemySpots = spots,
		enemies = {},
		finished = false,
	}
	sessions[session.id] = session

	local endsAt = now() + Raids.TimeLimit
	for _, player in members do
		local data = DataService.getData(player) :: Data
		RaidOps.markStarted(data, difficultyId, startTime)
		replicateCooldowns(player, data)
		session.players[player] = true
		playerSession[player] = session
		player:SetAttribute("RaidSessionId", session.id)
		player:SetAttribute("RaidDifficulty", difficultyId)
		player:SetAttribute("RaidEndsAt", endsAt)
		moveTo(player, playerSpawn, "Raid")
		send(player, { kind = "Started", difficulty = difficultyId })
	end
	task.spawn(runSession, session, endsAt)
end

-- Queues ----------------------------------------------------------------------

local function leaveQueue(player: Player)
	local difficultyId = playerQueue[player]
	if difficultyId == nil then
		return
	end
	playerQueue[player] = nil
	player:SetAttribute("RaidQueue", nil)
	player:SetAttribute("RaidQueueStartsAt", nil)
	local queue = queues[difficultyId]
	if queue then
		local index = table.find(queue.players, player)
		if index then
			table.remove(queue.players, index)
		end
	end
end

-- Joins (or, if already queued for it, leaves) a difficulty's queue.
function RaidService.usePad(player: Player, difficultyId: string)
	local data = DataService.getData(player)
	if data == nil or playerSession[player] then
		return
	end
	local current = time()
	if current - (lastUseTime[player] or -math.huge) < MIN_TIME_BETWEEN_USES then
		return
	end
	lastUseTime[player] = current

	if playerQueue[player] == difficultyId then
		leaveQueue(player)
		send(player, { kind = "LeftQueue", difficulty = difficultyId })
		return
	end
	if not RaidOps.canStart(data, difficultyId, os.time()) then
		send(player, { kind = "Cooldown", difficulty = difficultyId, readyAt = RaidOps.readyAt(data, difficultyId) })
		return
	end

	local queue = queues[difficultyId]
	if queue and #queue.players >= Raids.MaxPlayers then
		send(player, { kind = "Full", difficulty = difficultyId })
		return
	end
	leaveQueue(player)
	if queue == nil then
		local newQueue: Queue = { players = {}, startsAt = now() + QUEUE_TIME }
		queue = newQueue
		queues[difficultyId] = newQueue
		task.delay(QUEUE_TIME, startQueue, difficultyId, newQueue)
	end
	assert(queue, "unreachable")
	table.insert(queue.players, player)
	playerQueue[player] = difficultyId
	player:SetAttribute("RaidQueue", difficultyId)
	player:SetAttribute("RaidQueueStartsAt", queue.startsAt)
	send(player, { kind = "Queued", difficulty = difficultyId })
end

-- Map setup -------------------------------------------------------------------

local function addPrompt(part: BasePart, objectText: string, actionText: string, onTriggered: (Player) -> ())
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(onTriggered)
	prompt.Parent = part
end

local function setupPortal(portal: Instance)
	if portal:IsA("BasePart") then
		addPrompt(portal, "Portal de Raids", "Viajar", function(player)
			if playerSession[player] == nil then
				sendToLobby(player)
			end
		end)
	end
end

local function setupPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	local difficultyId = pad:GetAttribute("Difficulty")
	local ok, difficulty = pcall(Raids.getDifficulty, difficultyId :: any)
	if not ok or type(difficultyId) ~= "string" then
		warn(`[RaidService] Invalid raid pad {pad:GetFullName()}: {difficulty}`)
		return
	end
	-- The client replaces the action text with Entrar / Salir / cooldown.
	addPrompt(pad, `Raid {difficulty.displayName}`, "Entrar", function(player)
		RaidService.usePad(player, difficultyId)
	end)
end

local function onTagged(tag: string, setup: (Instance) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		setup(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(setup)
end

-- Studio testing: play only these waves (e.g. { 1, 10, 20 }).
function RaidService.setWaveSequence(waves: { number })
	waveSequence = waves
end

function RaidService.start()
	onTagged(PORTAL_TAG, setupPortal)
	onTagged(PAD_TAG, setupPad)
	EnemyService.Died:Connect(onRaidEnemyDied)

	DataService.Loaded:Connect(replicateCooldowns)
	local function onPlayerAdded(player: Player)
		-- Respawning (e.g. resetting) during a raid leaves it.
		player.CharacterAdded:Connect(function()
			leaveSession(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
		leaveSession(player)
		lastUseTime[player] = nil
	end)
end

return RaidService
