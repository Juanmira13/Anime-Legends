-- Checks island unlock order, travel rules and spawn island.
local PortalOps = require(Server.Portals.PortalOps)
local PlayerRecord = require(Server.Data.PlayerRecord)

local failures = 0
local function check(label, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end
local function result(ok, reason)
	return if ok then "ok" else reason
end

local data = PlayerRecord.newData()

-- Costs come from Formulas (docs/balance.md)
check("cost Kono", PortalOps.unlockCost("Kono"), 2700)
check("cost Demon Corps", PortalOps.unlockCost("DemonCorps"), 21000000)

-- Unlock order
check("first island already unlocked", result(PortalOps.canUnlock(data, "Nameku")), "AlreadyUnlocked")
check("next island can unlock", result(PortalOps.canUnlock(data, "Kono")), "ok")
check("skipping is blocked", result(PortalOps.canUnlock(data, "CloverKingdom")), "PreviousLocked")
check("unknown island", result(PortalOps.canUnlock(data, "Atlantis")), "UnknownIsland")
PortalOps.unlock(data, "Kono")
check("unlocked", PortalOps.isUnlocked(data, "Kono"), true)
check("now the next one", result(PortalOps.canUnlock(data, "CloverKingdom")), "ok")

-- Travel
check("travel to unlocked", result(PortalOps.canTravel(data, "Kono")), "ok")
check("travel back", result(PortalOps.canTravel(data, "Nameku")), "ok")
check("travel to locked", result(PortalOps.canTravel(data, "CloverKingdom")), "Locked")
check("travel to unknown", result(PortalOps.canTravel(data, "Atlantis")), "UnknownIsland")

-- Spawn island
check("default spawn", PortalOps.spawnIsland(PlayerRecord.newData()), "Nameku")
data.LastIsland = "Kono"
check("spawn at last island", PortalOps.spawnIsland(data), "Kono")
data.LastIsland = "CloverKingdom"
check("locked last island falls back", PortalOps.spawnIsland(data), "Nameku")
data.LastIsland = "Atlantis"
check("unknown last island falls back", PortalOps.spawnIsland(data), "Nameku")

-- Old saves get LastIsland through reconciliation
local old = { version = PlayerRecord.CurrentVersion, data = { Yen = 1 } }
local reconciled = PlayerRecord.acquire(old, "server", 0)
check("reconcile adds LastIsland", reconciled and reconciled.data.LastIsland, "Nameku")

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
