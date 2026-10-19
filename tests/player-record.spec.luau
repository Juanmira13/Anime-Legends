-- Checks default data, reconciliation, migration and session locking in PlayerRecord.
local PlayerRecord = require(Server.Data.PlayerRecord)
local Characters = require(Shared.Data.Characters)
local Boosts = require(Shared.Config.Boosts)
local Raids = require(Shared.Config.Raids)

local failures = 0
local function check(label, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end

local NOW = 1_000_000
local TIMEOUT = PlayerRecord.LockTimeout

-- Default data
local fresh = PlayerRecord.newData()
check("starter equipped", fresh.Equipped[1], "1")
check("starter character", fresh.Characters["1"].id, "Krilin")
check("starter is a real Common", Characters.get(fresh.Characters["1"].id).rarity, "Common")
check("next uid", fresh.NextCharacterUid, 2)
check("first island unlocked", fresh.UnlockedIslands.Nameku, true)
for _, boost in Boosts.List do
	check(`boost owned slot {boost.id}`, fresh.Boosts.Owned[boost.id], 0)
	check(`boost remaining slot {boost.id}`, fresh.Boosts.Remaining[boost.id], 0)
end
for _, difficulty in Raids.Difficulties do
	check(`raid completions slot {difficulty.id}`, fresh.Raids.Completions[difficulty.id], 0)
end
check("newData returns fresh tables", PlayerRecord.newData().Characters == fresh.Characters, false)

-- New player
local created = PlayerRecord.acquire(nil, "server-a", NOW)
check("new record created", created ~= nil, true)
check("new record locked", created and created.lock and created.lock.jobId, "server-a")
check("new record version", created and created.version, PlayerRecord.CurrentVersion)

-- Locks
local function lockedRecord(jobId, time)
	return { version = PlayerRecord.CurrentVersion, data = PlayerRecord.newData(), lock = { jobId = jobId, time = time } }
end
check("live lock blocks", PlayerRecord.acquire(lockedRecord("server-b", NOW - 10), "server-a", NOW), nil)
check("lock just under timeout blocks", PlayerRecord.acquire(lockedRecord("server-b", NOW - TIMEOUT + 1), "server-a", NOW), nil)
local stolen = PlayerRecord.acquire(lockedRecord("server-b", NOW - TIMEOUT), "server-a", NOW)
check("expired lock is taken", stolen and stolen.lock and stolen.lock.jobId, "server-a")
local reacquired = PlayerRecord.acquire(lockedRecord("server-a", NOW - 10), "server-a", NOW)
check("own lock is reacquired", reacquired and reacquired.lock and reacquired.lock.time, NOW)
local unlocked = { version = PlayerRecord.CurrentVersion, data = PlayerRecord.newData() }
check("unlocked record is acquired", PlayerRecord.acquire(unlocked, "server-a", NOW) ~= nil, true)

-- Reconcile: adds missing fields, never touches player-owned collections
local old = {
	version = PlayerRecord.CurrentVersion,
	data = {
		Yen = 500,
		Characters = { ["7"] = { id = "Piccolo" } },
		Equipped = { "7" },
		Boosts = { Owned = { Luck = 3 } },
	},
}
local reconciled = PlayerRecord.acquire(old, "server-a", NOW)
local data = reconciled and reconciled.data
check("keeps yen", data and data.Yen, 500)
check("adds missing gems", data and data.Gems, 0)
check("keeps owned boost", data and data.Boosts.Owned.Luck, 3)
check("adds missing boost key", data and data.Boosts.Owned.Money, 0)
check("adds missing nested table", data and data.Boosts.Remaining.Gems, 0)
check("adds missing raids", data and data.Raids.Completions.Hard, 0)
check("does not add starter to existing characters", data and data.Characters["1"], nil)
check("keeps existing character", data and data.Characters["7"].id, "Piccolo")
check("keeps equipped", data and #data.Equipped, 1)

-- Migrate
local migrated = PlayerRecord.migrate({ version = 0, data = PlayerRecord.newData() })
check("migrate bumps version", migrated.version, PlayerRecord.CurrentVersion)

-- Write
local saved = PlayerRecord.write(lockedRecord("server-a", NOW - 100), fresh, "server-a", NOW, false)
check("owner can save", saved ~= nil, true)
check("save refreshes lock", saved and saved.lock and saved.lock.time, NOW)
check("save keeps data", saved and saved.data, fresh)
local released = PlayerRecord.write(lockedRecord("server-a", NOW - 100), fresh, "server-a", NOW, true)
check("release clears lock", released ~= nil and released.lock == nil, true)
check("other server cannot save", PlayerRecord.write(lockedRecord("server-b", NOW - 100), fresh, "server-a", NOW, false), nil)
check("other server cannot save even if expired", PlayerRecord.write(lockedRecord("server-b", NOW - TIMEOUT * 2), fresh, "server-a", NOW, true), nil)
check("save to unlocked record", PlayerRecord.write(nil, fresh, "server-a", NOW, false) ~= nil, true)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
