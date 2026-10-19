--!strict
-- Owned characters. Clients send requests through Remotes.InventoryAction
-- (Refresh, Equip, Unequip, Delete, EquipBest, Upgrade) and get back the
-- outcome plus a fresh snapshot. Server-side changes (e.g. a gacha roll) push
-- a snapshot through Remotes.InventoryChanged.

local Players = game:GetService("Players")

local Server = script.Parent.Parent
local InventoryOps = require(Server.Inventory.InventoryOps)
local Remotes = require(Server.Remotes)
local DataService = require(script.Parent.DataService)

type Data = DataService.Data

export type ActionResult = {
	ok: boolean,
	reason: string?,
	snapshot: InventoryOps.Snapshot?,
}

local MIN_TIME_BETWEEN_ACTIONS = 0.1 -- seconds

local actionRemote = Remotes.func("InventoryAction")
local changedRemote = Remotes.event("InventoryChanged")
local lastActionTime: { [Player]: number } = {}

local InventoryService = {}

-- Actions that take a character uid.
local UID_ACTIONS: { [string]: (Data, string) -> (boolean, string?) } = {
	Equip = InventoryOps.equip,
	Unequip = InventoryOps.unequip,
	Delete = InventoryOps.delete,
}

local function upgrade(player: Player, data: Data): (boolean, string?)
	local cost = InventoryOps.nextUpgradeCost(data)
	if cost == nil then
		return false, "MaxUpgrades"
	end
	if not DataService.spendCurrency(player, "Yen", cost) then
		return false, "NotEnoughYen"
	end
	data.InventoryUpgrades += 1
	return true, nil
end

local function handleAction(player: Player, action: unknown, uid: unknown): ActionResult
	if type(action) ~= "string" or (uid ~= nil and type(uid) ~= "string") then
		return { ok = false, reason = "BadRequest" }
	end

	local now = time()
	if action ~= "Refresh" and now - (lastActionTime[player] or -math.huge) < MIN_TIME_BETWEEN_ACTIONS then
		return { ok = false, reason = "TooFast" }
	end
	lastActionTime[player] = now

	local data = DataService.waitForData(player)
	if data == nil then
		return { ok = false, reason = "NotLoaded" }
	end

	local ok, reason = true, nil
	if action == "Refresh" then
		ok = true
	elseif action == "EquipBest" then
		ok, reason = InventoryOps.equipBest(data)
	elseif action == "Upgrade" then
		ok, reason = upgrade(player, data)
	elseif UID_ACTIONS[action] then
		if type(uid) ~= "string" then
			return { ok = false, reason = "BadRequest" }
		end
		ok, reason = UID_ACTIONS[action](data, uid)
	else
		return { ok = false, reason = "BadRequest" }
	end

	return { ok = ok, reason = reason, snapshot = InventoryOps.snapshot(data) }
end

local function pushSnapshot(player: Player, data: Data)
	changedRemote:FireClient(player, InventoryOps.snapshot(data))
end

function InventoryService.hasSpace(player: Player): boolean
	local data = DataService.getData(player)
	return data ~= nil and InventoryOps.hasSpace(data)
end

-- Adds a character to a loaded player's inventory and notifies the client.
-- Returns the new uid, or nil if the player's data is not loaded.
function InventoryService.addCharacter(player: Player, characterId: string): string?
	local data = DataService.getData(player)
	if data == nil then
		return nil
	end
	local uid = InventoryOps.add(data, characterId)
	pushSnapshot(player, data)
	return uid
end

function InventoryService.start()
	actionRemote.OnServerInvoke = handleAction
	DataService.Loaded:Connect(pushSnapshot)
	Players.PlayerRemoving:Connect(function(player)
		lastActionTime[player] = nil
	end)
end

return InventoryService
