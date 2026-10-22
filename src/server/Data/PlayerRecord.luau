--!strict
-- Pure logic for the saved player record: default data, reconciliation,
-- migrations and session locking. No Roblox APIs, so it can be unit tested.

export type OwnedCharacter = {
	id: string, -- character id from Shared.Data.Characters
}

export type Data = {
	Yen: number,
	Gems: number,
	-- Owned characters keyed by a per-player unique id (string), so duplicates are allowed.
	Characters: { [string]: OwnedCharacter },
	NextCharacterUid: number,
	Equipped: { string }, -- unique ids from Characters
	InventoryUpgrades: number,
	UnlockedIslands: { [string]: boolean },
	LastIsland: string, -- where the player spawns when they join or respawn
	-- Rolls since the last hit of each rarity, per island: Pity[islandId][rarityId].
	Pity: { [string]: { [string]: number } },
	Boosts: {
		Owned: { [string]: number }, -- unused boosts by boost id
		Remaining: { [string]: number }, -- active seconds left; only ticks while online
	},
	Raids: {
		Completions: { [string]: number },
		LastStarted: { [string]: number }, -- os.time() of the last start, for cooldowns
	},
	Settings: { [string]: boolean }, -- player options by name (Config.Sounds.Settings)
}

export type Lock = {
	jobId: string,
	time: number,
}

export type Record = {
	version: number,
	data: Data,
	lock: Lock?,
}

local PlayerRecord = {}

PlayerRecord.CurrentVersion = 1

-- A lock older than this is assumed to belong to a crashed server and can be taken.
-- Must be well above the autosave interval, which refreshes the lock.
PlayerRecord.LockTimeout = 6 * 60

-- Keys whose values are maps or lists owned by the player. Reconciliation fills
-- them only when missing and never merges template entries into them.
local PLAYER_OWNED_KEYS = {
	Characters = true,
	Equipped = true,
	UnlockedIslands = true,
	Pity = true,
}

-- Migrations from version n - 1 to n, indexed by n.
local MIGRATIONS: { [number]: (data: any) -> () } = {}

-- New players start with the Common character of the first island equipped.
function PlayerRecord.newData(): Data
	return {
		Yen = 0,
		Gems = 0,
		Characters = { ["1"] = { id = "Krilin" } },
		NextCharacterUid = 2,
		Equipped = { "1" },
		InventoryUpgrades = 0,
		UnlockedIslands = { Nameku = true },
		LastIsland = "Nameku",
		Pity = {},
		Boosts = {
			Owned = { Luck = 0, Money = 0, Gems = 0 },
			Remaining = { Luck = 0, Money = 0, Gems = 0 },
		},
		Raids = {
			Completions = { Easy = 0, Medium = 0, Hard = 0 },
			LastStarted = { Easy = 0, Medium = 0, Hard = 0 },
		},
		Settings = { Music = true, Effects = true },
	}
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in value do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function fillMissing(data: { [string]: any }, template: { [string]: any })
	for key, default in template do
		local current = data[key]
		if current == nil then
			data[key] = deepCopy(default)
		elseif type(current) == "table" and type(default) == "table" and not PLAYER_OWNED_KEYS[key] then
			fillMissing(current, default)
		end
	end
end

-- Adds any fields introduced after the data was first saved.
function PlayerRecord.reconcile(data: { [string]: any }): Data
	fillMissing(data, PlayerRecord.newData() :: any)
	return data :: any
end

function PlayerRecord.migrate(record: Record): Record
	for version = record.version + 1, PlayerRecord.CurrentVersion do
		local migration = MIGRATIONS[version]
		if migration then
			migration(record.data)
		end
		record.version = version
	end
	return record
end

local function isLockedByOther(record: Record?, jobId: string, now: number): boolean
	local lock = record and record.lock
	return lock ~= nil and lock.jobId ~= jobId and now - lock.time < PlayerRecord.LockTimeout
end

-- UpdateAsync transform for loading. Returns the record locked to this server,
-- or nil if another live server holds the lock (the caller should retry).
function PlayerRecord.acquire(stored: Record?, jobId: string, now: number): Record?
	if isLockedByOther(stored, jobId, now) then
		return nil
	end
	local record: Record = stored
		or { version = PlayerRecord.CurrentVersion, data = PlayerRecord.newData(), lock = nil }
	PlayerRecord.migrate(record)
	PlayerRecord.reconcile(record.data :: any)
	record.lock = { jobId = jobId, time = now }
	return record
end

-- UpdateAsync transform for saving. Returns nil (cancel the write) if this server
-- no longer owns the lock, so it never overwrites a newer session's data.
function PlayerRecord.write(stored: Record?, data: Data, jobId: string, now: number, release: boolean): Record?
	local lock = stored and stored.lock
	if lock ~= nil and lock.jobId ~= jobId then
		return nil
	end
	return {
		version = PlayerRecord.CurrentVersion,
		data = data,
		lock = if release then nil else { jobId = jobId, time = now },
	}
end

return PlayerRecord
