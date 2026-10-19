-- Checks boost granting, activation stacking and ticking.
local BoostOps = require(Server.Boosts.BoostOps)
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

local MINUTES_15 = 15 * 60
local data = PlayerRecord.newData()

-- Grant
check("starts with none", BoostOps.owned(data, "Luck"), 0)
check("grant", result(BoostOps.grant(data, "Luck")), "ok")
check("grant amount", result(BoostOps.grant(data, "Luck", 2)), "ok")
check("owned after grants", BoostOps.owned(data, "Luck"), 3)
check("grant unknown", result(BoostOps.grant(data, "Speed")), "UnknownBoost")

-- Activate
check("not active yet", BoostOps.isActive(data, "Luck"), false)
check("activate", result(BoostOps.activate(data, "Luck")), "ok")
check("uses one", BoostOps.owned(data, "Luck"), 2)
check("15 minutes", BoostOps.remaining(data, "Luck"), MINUTES_15)
check("active", BoostOps.isActive(data, "Luck"), true)
check("activate again stacks", result(BoostOps.activate(data, "Luck")), "ok")
check("30 minutes", BoostOps.remaining(data, "Luck"), 2 * MINUTES_15)
check("activate without stock", result(BoostOps.activate(data, "Money")), "NotOwned")
check("activate unknown", result(BoostOps.activate(data, "Speed")), "UnknownBoost")

-- Tick
BoostOps.grant(data, "Gems")
BoostOps.activate(data, "Gems")
BoostOps.tick(data, 60)
check("luck ticks", BoostOps.remaining(data, "Luck"), 2 * MINUTES_15 - 60)
check("gems ticks", BoostOps.remaining(data, "Gems"), MINUTES_15 - 60)
check("inactive stays zero", BoostOps.remaining(data, "Money"), 0)
BoostOps.tick(data, MINUTES_15)
check("gems expires at zero", BoostOps.remaining(data, "Gems"), 0)
check("gems inactive", BoostOps.isActive(data, "Gems"), false)
check("luck still active", BoostOps.isActive(data, "Luck"), true)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
