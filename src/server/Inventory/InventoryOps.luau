--!strict
-- Inventory rules on player data: adding, equipping, unequipping, deleting,
-- equipping the best team and inventory upgrades. Pure (no Roblox services
-- beyond shared config), so it can be unit tested.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)

local PlayerRecord = require(script.Parent.Parent.Data.PlayerRecord)

type Data = PlayerRecord.Data

export type Failure = "NotOwned" | "AlreadyEquipped" | "NotEquipped" | "NoEquipSlots" | "Equipped" | "LastCharacter"

-- What the client needs to draw the inventory.
export type Snapshot = {
	characters: { { uid: string, id: string } },
	equipped: { string },
	capacity: number,
	equipSlots: number,
	upgrades: number,
	nextUpgradeCost: number?, -- nil when the inventory is at its maximum size
}

local InventoryOps = {}

function InventoryOps.count(data: Data): number
	local count = 0
	for _ in data.Characters do
		count += 1
	end
	return count
end

function InventoryOps.capacity(data: Data): number
	return Formulas.inventorySlots(data.InventoryUpgrades)
end

function InventoryOps.equipSlots(data: Data): number
	return Formulas.equipSlots(data.Raids.Completions)
end

function InventoryOps.hasSpace(data: Data): boolean
	return InventoryOps.count(data) < InventoryOps.capacity(data)
end

-- Adds a character and returns its new unique id. Callers check hasSpace first.
function InventoryOps.add(data: Data, characterId: string): string
	local uid = tostring(data.NextCharacterUid)
	data.NextCharacterUid += 1
	data.Characters[uid] = { id = characterId }
	return uid
end

function InventoryOps.isEquipped(data: Data, uid: string): boolean
	return table.find(data.Equipped, uid) ~= nil
end

function InventoryOps.equip(data: Data, uid: string): (boolean, Failure?)
	if data.Characters[uid] == nil then
		return false, "NotOwned"
	end
	if InventoryOps.isEquipped(data, uid) then
		return false, "AlreadyEquipped"
	end
	if #data.Equipped >= InventoryOps.equipSlots(data) then
		return false, "NoEquipSlots"
	end
	table.insert(data.Equipped, uid)
	return true, nil
end

function InventoryOps.unequip(data: Data, uid: string): (boolean, Failure?)
	local index = table.find(data.Equipped, uid)
	if index == nil then
		return false, "NotEquipped"
	end
	table.remove(data.Equipped, index)
	return true, nil
end

-- Deletes an owned character. Equipped characters must be unequipped first,
-- and the last character cannot be deleted (the player could no longer attack).
function InventoryOps.delete(data: Data, uid: string): (boolean, Failure?)
	if data.Characters[uid] == nil then
		return false, "NotOwned"
	end
	if InventoryOps.isEquipped(data, uid) then
		return false, "Equipped"
	end
	if InventoryOps.count(data) <= 1 then
		return false, "LastCharacter"
	end
	data.Characters[uid] = nil
	return true, nil
end

local function damagePerSecond(characterId: string): number
	return Formulas.characterDamage(characterId) / Formulas.characterCooldown(characterId)
end

-- Equips the characters with the highest damage per second, filling every slot.
function InventoryOps.equipBest(data: Data): (boolean, Failure?)
	local ranked = {}
	for uid, owned in data.Characters do
		table.insert(ranked, { uid = uid, dps = damagePerSecond(owned.id) })
	end
	table.sort(ranked, function(a, b)
		if a.dps ~= b.dps then
			return a.dps > b.dps
		end
		return (tonumber(a.uid) :: number) < (tonumber(b.uid) :: number)
	end)
	local equipped = {}
	for index = 1, math.min(#ranked, InventoryOps.equipSlots(data)) do
		table.insert(equipped, ranked[index].uid)
	end
	data.Equipped = equipped
	return true, nil
end

-- Yen for the next +slots upgrade, or nil when the inventory is at its maximum.
function InventoryOps.nextUpgradeCost(data: Data): number?
	local next = data.InventoryUpgrades + 1
	if next > Formulas.maxInventoryUpgrades() then
		return nil
	end
	return Formulas.inventoryUpgradeCost(next)
end

function InventoryOps.snapshot(data: Data): Snapshot
	local characters = {}
	for uid, owned in data.Characters do
		table.insert(characters, { uid = uid, id = owned.id })
	end
	return {
		characters = characters,
		equipped = table.clone(data.Equipped),
		capacity = InventoryOps.capacity(data),
		equipSlots = InventoryOps.equipSlots(data),
		upgrades = data.InventoryUpgrades,
		nextUpgradeCost = InventoryOps.nextUpgradeCost(data),
	}
end

return InventoryOps
