--!strict
-- Loads, autosaves and releases player data in a DataStore with session locking.
-- Other services read and change data through this module; currencies are
-- replicated to the client as player attributes.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerRecord = require(script.Parent.Parent.Data.PlayerRecord)

type Data = PlayerRecord.Data
type Currency = "Yen" | "Gems"

type Session = {
	data: Data,
	canSave: boolean, -- false when running on fallback data that must not overwrite the real save
}

local STORE_NAME = "PlayerData"
local AUTOSAVE_INTERVAL = 2 * 60
local LOAD_ATTEMPTS = 5
local RETRY_DELAY = 7 -- seconds; also lets another server finish releasing the lock
local KICK_MESSAGE = "No se pudieron cargar tus datos. Vuelve a intentarlo en unos minutos."

-- GetDataStore errors in unpublished places; fall back to unsaved data in that case.
local storeOk, storeResult = pcall(function()
	return DataStoreService:GetDataStore(STORE_NAME)
end)
local store: DataStore? = if storeOk then storeResult else nil
if not storeOk then
	warn(`[DataService] DataStore unavailable: {storeResult}`)
end

-- In Studio, fail fast instead of retrying so testing without API access is quick.
local loadAttempts = if RunService:IsStudio() then 1 else LOAD_ATTEMPTS

local sessions: { [Player]: Session } = {}
local pendingSaves = 0
local loadedEvent = Instance.new("BindableEvent")

local DataService = {}

-- Fires (player, data) once a player's data is ready.
DataService.Loaded = loadedEvent.Event

local function getKey(player: Player): string
	return `player_{player.UserId}`
end

local function replicateCurrencies(player: Player, data: Data)
	player:SetAttribute("Yen", data.Yen)
	player:SetAttribute("Gems", data.Gems)
end

-- Returns the loaded data, or nil if the lock could not be acquired or the
-- DataStore kept failing.
local function load(player: Player): Data?
	local dataStore = store
	if dataStore == nil then
		return nil
	end
	for attempt = 1, loadAttempts do
		local acquired: PlayerRecord.Record? = nil
		local ok, err = pcall(function()
			dataStore:UpdateAsync(getKey(player), function(stored: PlayerRecord.Record?)
				acquired = PlayerRecord.acquire(stored, game.JobId, os.time())
				return acquired
			end)
		end)
		if ok and acquired then
			return acquired.data
		end
		if not ok then
			warn(`[DataService] Load attempt {attempt} failed for {player.Name}: {err}`)
		else
			warn(`[DataService] Data for {player.Name} is locked by another server (attempt {attempt})`)
		end
		if attempt < loadAttempts then
			task.wait(RETRY_DELAY)
		end
		if player.Parent == nil then
			return nil
		end
	end
	return nil
end

local function save(player: Player, session: Session, release: boolean)
	local dataStore = store
	if dataStore == nil or not session.canSave then
		return
	end
	pendingSaves += 1
	local ok, err = pcall(function()
		dataStore:UpdateAsync(getKey(player), function(stored: PlayerRecord.Record?)
			return PlayerRecord.write(stored, session.data, game.JobId, os.time(), release)
		end)
	end)
	pendingSaves -= 1
	if not ok then
		warn(`[DataService] Save failed for {player.Name}: {err}`)
	end
end

local function onPlayerAdded(player: Player)
	local data = load(player)
	local canSave = true

	if data == nil then
		if player.Parent == nil then
			return
		end
		if not RunService:IsStudio() then
			player:Kick(KICK_MESSAGE)
			return
		end
		-- In Studio without API access, play on fresh data that is never saved.
		warn("[DataService] Using unsaved fallback data. Enable Studio Access to API Services to test saving.")
		data = PlayerRecord.newData()
		canSave = false
	end
	assert(data, "unreachable")

	local session: Session = { data = data, canSave = canSave }

	-- The player left while loading: release the lock right away.
	if player.Parent == nil then
		save(player, session, true)
		return
	end

	sessions[player] = session
	replicateCurrencies(player, data)
	loadedEvent:Fire(player, data)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if session == nil then
		return
	end
	sessions[player] = nil
	save(player, session, true)
end

-- Saves everyone still loaded and waits for every in-flight save, including
-- the ones started by PlayerRemoving, before the server closes.
local function saveAllOnShutdown()
	for player, session in sessions do
		task.spawn(save, player, session, true)
	end
	table.clear(sessions)
	while pendingSaves > 0 do
		task.wait()
	end
end

-- Data of a loaded player, or nil if it is not ready. Callers may change the
-- returned table directly; it is saved as-is.
function DataService.getData(player: Player): Data?
	local session = sessions[player]
	return session and session.data
end

-- Yields until the player's data is loaded. Returns nil if the player leaves first.
function DataService.waitForData(player: Player): Data?
	while player.Parent ~= nil do
		local data = DataService.getData(player)
		if data then
			return data
		end
		task.wait()
	end
	return nil
end

function DataService.addCurrency(player: Player, currency: Currency, amount: number)
	assert(amount >= 0, "amount must be non-negative")
	local data = DataService.getData(player)
	if data == nil then
		return
	end
	data[currency] += amount
	replicateCurrencies(player, data)
end

-- Spends currency if the player has enough. Returns whether it was spent.
function DataService.spendCurrency(player: Player, currency: Currency, amount: number): boolean
	assert(amount >= 0, "amount must be non-negative")
	local data = DataService.getData(player)
	if data == nil or data[currency] < amount then
		return false
	end
	data[currency] -= amount
	replicateCurrencies(player, data)
	return true
end

function DataService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(saveAllOnShutdown)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, session in sessions do
				task.spawn(save, player, session, false)
			end
		end
	end)
end

return DataService
