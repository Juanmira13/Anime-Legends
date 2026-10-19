--!strict
-- Island unlock and travel rules on player data. Pure, so it can be unit tested.
-- Islands unlock in progression order: each one requires the previous island.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Islands = require(Shared.Data.Islands)

local PlayerRecord = require(script.Parent.Parent.Data.PlayerRecord)

type Data = PlayerRecord.Data

export type Failure = "UnknownIsland" | "AlreadyUnlocked" | "PreviousLocked" | "Locked"

local PortalOps = {}

local function isKnown(islandId: string): boolean
	return (pcall(Islands.get, islandId))
end

function PortalOps.unlockCost(islandId: string): number
	return Formulas.portalCost(islandId)
end

function PortalOps.isUnlocked(data: Data, islandId: string): boolean
	return data.UnlockedIslands[islandId] == true
end

function PortalOps.canUnlock(data: Data, islandId: string): (boolean, Failure?)
	if not isKnown(islandId) then
		return false, "UnknownIsland"
	end
	if PortalOps.isUnlocked(data, islandId) then
		return false, "AlreadyUnlocked"
	end
	local previous = Islands.getPrevious(islandId)
	if previous and not PortalOps.isUnlocked(data, previous.id) then
		return false, "PreviousLocked"
	end
	return true, nil
end

-- Marks an island unlocked. Callers check canUnlock and charge the cost first.
function PortalOps.unlock(data: Data, islandId: string)
	data.UnlockedIslands[islandId] = true
end

function PortalOps.canTravel(data: Data, islandId: string): (boolean, Failure?)
	if not isKnown(islandId) then
		return false, "UnknownIsland"
	end
	if not PortalOps.isUnlocked(data, islandId) then
		return false, "Locked"
	end
	return true, nil
end

-- Where the player should appear when they spawn: their last visited island
-- if it is still unlocked, otherwise the first island.
function PortalOps.spawnIsland(data: Data): string
	if isKnown(data.LastIsland) and PortalOps.isUnlocked(data, data.LastIsland) then
		return data.LastIsland
	end
	return Islands.List[1].id
end

return PortalOps
