-- Checks inventory rules: add, equip, unequip, delete, equip best and upgrades.
local InventoryOps = require(Server.Inventory.InventoryOps)
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

-- Fresh player: Krilin (uid "1") equipped
local data = PlayerRecord.newData()
check("starts with one", InventoryOps.count(data), 1)
check("capacity", InventoryOps.capacity(data), 50)
check("equip slots", InventoryOps.equipSlots(data), 3)
check("has space", InventoryOps.hasSpace(data), true)

-- Add
local piccolo = InventoryOps.add(data, "Piccolo")
check("add returns next uid", piccolo, "2")
check("add stores character", data.Characters[piccolo].id, "Piccolo")
check("uid counter advances", data.NextCharacterUid, 3)
local yamcha = InventoryOps.add(data, "Yamcha")
local gohan = InventoryOps.add(data, "Gohan")

-- Equip / unequip
check("equip", result(InventoryOps.equip(data, piccolo)), "ok")
check("equip twice", result(InventoryOps.equip(data, piccolo)), "AlreadyEquipped")
check("equip unknown", result(InventoryOps.equip(data, "999")), "NotOwned")
check("equip third", result(InventoryOps.equip(data, yamcha)), "ok")
check("equip over slots", result(InventoryOps.equip(data, gohan)), "NoEquipSlots")
check("unequip", result(InventoryOps.unequip(data, yamcha)), "ok")
check("unequip twice", result(InventoryOps.unequip(data, yamcha)), "NotEquipped")
check("equipped count", #data.Equipped, 2)

-- Delete
check("delete equipped", result(InventoryOps.delete(data, piccolo)), "Equipped")
check("delete unknown", result(InventoryOps.delete(data, "999")), "NotOwned")
check("delete", result(InventoryOps.delete(data, yamcha)), "ok")
check("deleted is gone", data.Characters[yamcha], nil)
local single = PlayerRecord.newData()
InventoryOps.unequip(single, "1")
check("delete last character", result(InventoryOps.delete(single, "1")), "LastCharacter")

-- Equip best ranks by damage per second: Gohan 80/1.4 ≈ 57, Sakura (Kono Common)
-- 60/2 = 30, Piccolo 26/1.8 ≈ 14, Yamcha 16/1.9 ≈ 8, Krilin 10/2 = 5.
local team = PlayerRecord.newData()
local t1 = InventoryOps.add(team, "Piccolo")
local t2 = InventoryOps.add(team, "Gohan")
local t3 = InventoryOps.add(team, "Yamcha")
local t4 = InventoryOps.add(team, "Sakura")
InventoryOps.equipBest(team)
check("best count", #team.Equipped, 3)
check("best first", team.Equipped[1], t2)
check("best second", team.Equipped[2], t4)
check("best third", team.Equipped[3], t1)
check("best skips weaker", InventoryOps.isEquipped(team, t3), false)
check("best skips starter", InventoryOps.isEquipped(team, "1"), false)
local few = PlayerRecord.newData()
few.Equipped = {}
InventoryOps.equipBest(few)
check("best with fewer characters", #few.Equipped, 1)

-- Active team: equip order, capped at the slots, skipping missing characters
local active = InventoryOps.activeTeam(team)
check("active team size", #active, 3)
check("active team order", active[1].id, "Gohan")
check("active team uid", active[2].uid, t4)
local capped = PlayerRecord.newData()
local c1 = InventoryOps.add(capped, "Piccolo")
local c2 = InventoryOps.add(capped, "Gohan")
local c3 = InventoryOps.add(capped, "Yamcha")
capped.Equipped = { "999", c1, "1", c2, c3 }
local cappedTeam = InventoryOps.activeTeam(capped)
check("active team skips missing", cappedTeam[1].id, "Piccolo")
check("active team capped", #cappedTeam, 3)
check("active team last slot", cappedTeam[3].id, "Gohan")

-- Space
local full = PlayerRecord.newData()
for _ = 1, 49 do
	InventoryOps.add(full, "Krilin")
end
check("full at 50", InventoryOps.hasSpace(full), false)
full.InventoryUpgrades = 1
check("upgrade adds space", InventoryOps.hasSpace(full), true)

-- Upgrades
local upgrades = PlayerRecord.newData()
check("first upgrade cost", InventoryOps.nextUpgradeCost(upgrades), 10000)
upgrades.InventoryUpgrades = 19
check("last upgrade cost", InventoryOps.nextUpgradeCost(upgrades), 22000000)
upgrades.InventoryUpgrades = 20
check("no upgrade at max", InventoryOps.nextUpgradeCost(upgrades), nil)

-- Snapshot
local snapshot = InventoryOps.snapshot(team)
check("snapshot characters", #snapshot.characters, 5)
check("snapshot equipped", #snapshot.equipped, 3)
check("snapshot copies equipped", snapshot.equipped == team.Equipped, false)
check("snapshot capacity", snapshot.capacity, 50)
check("snapshot equip slots", snapshot.equipSlots, 3)
check("snapshot next cost", snapshot.nextUpgradeCost, 10000)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
