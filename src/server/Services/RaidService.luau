--!strict
-- Raids: lobby, queues, arenas, waves and rewards.
--
-- Map setup (tagged BaseParts):
--   "RaidPortal"        any island; sends the player to the raid lobby
--   "RaidLobbySpawn"    arrival point in the lobby
--   "RaidPad"           lobby pad with a Difficulty attribute (Easy, Medium, Hard)
-- Using a pad joins that difficulty's queue; the raid starts QUEUE_TIME seconds
-- after the first player joins, with everyone queued (up to Raids.MaxPlayers).
-- Each group plays in its own arena, placed high above the map: a clone of
-- ServerStorage.RaidArena (the Island Builder's coliseum: a Model pivoted on the
-- center of its field, with a FieldRadius attribute, a "PlayerSpawn" part and a
-- "RaidExit" part) or a generated platform. Every wave's enemies stand at random
-- points on the field (RaidOps.randomSpots); the exit portal takes a player
-- back to the lobby.
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
local CoinService = require(script.Parent.CoinService)
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
	center: CFrame, -- center of the field, at floor level
	fieldRadius: number,
	clearances: { RaidOps.Clearance }, -- arrival point and exit, relative to the center
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
local EXIT_HOLD = 0.5 -- seconds; nobody leaves a raid by accident
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

local function addPrompt(
	part: BasePart,
	objectText: string,
	actionText: string,
	onTriggered: (Player) -> ()
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(onTriggered)
	prompt.Parent = part
	return prompt
end

-- Arena -----------------------------------------------------------------------

type Arena = {
	model: Model,
	playerSpawn: CFrame,
	fieldRadius: number,
	exit: BasePart?,
}

local GENERATED_FIELD_RADIUS = 80

-- Plain platform used when there is no ServerStorage.RaidArena, pivoted (like
-- the coliseum) on the center of its top face.
local function generateArena(): Model
	local arena = Instance.new("Model")
	arena.Name = "RaidArena"
	arena:SetAttribute("FieldRadius", GENERATED_FIELD_RADIUS)
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(GENERATED_FIELD_RADIUS * 2, 2, GENERATED_FIELD_RADIUS * 2)
	floor.CFrame = CFrame.new(0, -1, 0)
	floor.Anchored = true
	floor.Color = Color3.fromRGB(60, 50, 80)
	floor.Material = Enum.Material.Slate
	floor.PivotOffset = CFrame.new(0, 1, 0)
	floor.Parent = arena
	arena.PrimaryPart = floor
	for _, marker in { { name = "PlayerSpawn", z = 40 }, { name = "RaidExit", z = 66 } } do
		local part = Instance.new("Part")
		part.Name = marker.name
		part.Size = Vector3.new(8, 1, 8)
		part.CFrame = CFrame.new(0, -0.5, marker.z)
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = if marker.name == "RaidExit" then 0 else 1
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(170, 80, 255)
		part.Parent = arena
	end
	return arena
end

local function buildArena(slot: number): Arena
	local origin = CFrame.new(ARENA_ORIGIN + Vector3.new(slot * ARENA_SPACING, 0, 0))
	local template = ServerStorage:FindFirstChild("RaidArena")
	local model: Model
	if template and template:IsA("Model") and template.PrimaryPart and template:FindFirstChild("PlayerSpawn") then
		model = template:Clone()
	else
		if template then
			warn("[RaidService] ServerStorage.RaidArena needs a PrimaryPart and a PlayerSpawn; using a generated arena")
		end
		model = generateArena()
	end
	model:PivotTo(origin)
	-- Markers are read after pivoting, so their CFrames are already in world space.
	local spawnPart = model:FindFirstChild("PlayerSpawn") :: BasePart
	local exit: BasePart? = nil
	for _, descendant in model:GetDescendants() do
		if descendant.Name == "RaidExit" and descendant:IsA("BasePart") then
			exit = descendant
			break
		end
	end
	return {
		model = model,
		playerSpawn = spawnPart.CFrame * CFrame.new(0, spawnPart.Size.Y / 2, 0),
		fieldRadius = tonumber(model:GetAttribute("FieldRadius")) or GENERATED_FIELD_RADIUS,
		exit = exit,
	}
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
			enemy.raidWave or 1,
			data.Boosts.Remaining.Money > 0,
			data.Boosts.Remaining.Gems > 0
		)
		CoinService.drop(player, enemy.ground, yen) -- yen as coins to collect; gems go straight in
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
	local typeIds = RaidOps.waveEnemies(wave)
	local spots = RaidOps.waveSpots(typeIds, session.fieldRadius, session.clearances, function()
		return random:NextNumber()
	end)
	for index, typeId in typeIds do
		local spot = spots[index]
		-- Face the players' side of the field (+Z).
		local position = session.center * CFrame.new(spot[1], 0, spot[2])
		local enemy = EnemyService.spawn({
			cframe = CFrame.lookAt(position.Position, (session.center * CFrame.new(spot[1], 0, spot[2] + 1)).Position),
			maxHealth = Formulas.raidEnemyHealth(session.difficulty, typeId, wave),
			displayName = Raids.getEnemyType(typeId).displayName,
			look = typeId,
			template = { "Raid", typeId },
			parent = session.arena,
			raidSessionId = session.id,
			raidType = typeId,
			raidWave = wave,
		})
		session.enemies[enemy] = true
	end
end

local function runSession(session: Session, endsAt: number)
	for wave = 1, Raids.WaveCount do
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
		if wave < Raids.WaveCount then
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
		if
			player.Parent
			and data
			and playerSession[player] == nil
			and RaidOps.canStart(data, difficultyId, startTime)
		then
			table.insert(members, player)
		end
	end
	if #members == 0 then
		return
	end

	nextSessionId += 1
	local slot = takeSlot()
	local arena = buildArena(slot)
	arena.model.Name = `Raid_{difficultyId}_{nextSessionId}`
	arena.model.Parent = workspace
	local center = arena.model:GetPivot()
	local function relative(position: Vector3, radius: number): RaidOps.Clearance
		local offset = center:PointToObjectSpace(position)
		return { x = offset.X, z = offset.Z, radius = radius }
	end
	local clearances = { relative(arena.playerSpawn.Position, Raids.Arena.spawnClearance) }
	if arena.exit then
		table.insert(clearances, relative(arena.exit.Position, Raids.Arena.exitClearance))
	end
	local session: Session = {
		id = tostring(nextSessionId),
		difficulty = difficultyId,
		players = {},
		arena = arena.model,
		slot = slot,
		playerSpawn = arena.playerSpawn,
		center = center,
		fieldRadius = arena.fieldRadius,
		clearances = clearances,
		enemies = {},
		finished = false,
	}
	sessions[session.id] = session
	if arena.exit then
		local exitPrompt = addPrompt(arena.exit, "Portal de salida", "Abandonar el Raid", function(player)
			if playerSession[player] == session then
				leaveSession(player)
				sendToLobby(player)
				send(player, { kind = "Left", difficulty = difficultyId })
			end
		end)
		exitPrompt.HoldDuration = EXIT_HOLD
	end

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
		moveTo(player, arena.playerSpawn, "Raid")
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

function RaidService.start()
	-- The Island Builder leaves a copy of the arena for screenshots; the game only uses the template.
	local preview = workspace:FindFirstChild("RaidArenaPreview")
	if preview then
		preview:Destroy()
	end
	onTagged(PORTAL_TAG, setupPortal)
	onTagged(PAD_TAG, setupPad)
	EnemyService.Died:Connect(onRaidEnemyDied)

	DataService.Loaded:Connect(replicateCooldowns)
	local function onPlayerAdded(player: Player)
		-- Respawning (e.g. resetting) during a raid leaves it.
		player.CharacterAdded:Connect(function()
			leaveSession(player)
		end)
		-- Leaving the lobby (a portal back to an island, or respawning) leaves the queue,
		-- so nobody is pulled into a raid from elsewhere. Starting a raid sets "Raid"
		-- after the queue is already cleared.
		player:GetAttributeChangedSignal("CurrentArea"):Connect(function()
			local difficultyId = playerQueue[player]
			if difficultyId and player:GetAttribute("CurrentArea") ~= "RaidLobby" then
				leaveQueue(player)
				send(player, { kind = "LeftQueue", difficulty = difficultyId })
			end
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
