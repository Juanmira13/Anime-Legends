--!strict
-- Boost rules on player data: granting, activating (stacks duration) and
-- ticking down active time. Pure, so it can be unit tested.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)

local PlayerRecord = require(script.Parent.Parent.Data.PlayerRecord)

type Data = PlayerRecord.Data

export type Failure = "UnknownBoost" | "NotOwned"

local BoostOps = {}

local function isKnown(boostId: string): boolean
	return (pcall(Boosts.get, boostId))
end

function BoostOps.owned(data: Data, boostId: string): number
	return data.Boosts.Owned[boostId] or 0
end

function BoostOps.remaining(data: Data, boostId: string): number
	return data.Boosts.Remaining[boostId] or 0
end

function BoostOps.isActive(data: Data, boostId: string): boolean
	return BoostOps.remaining(data, boostId) > 0
end

-- Adds unused boosts to the player's stock (raid drops, shop purchases).
function BoostOps.grant(data: Data, boostId: string, amount: number?): (boolean, Failure?)
	if not isKnown(boostId) then
		return false, "UnknownBoost"
	end
	data.Boosts.Owned[boostId] = BoostOps.owned(data, boostId) + (amount or 1)
	return true, nil
end

-- Uses one stored boost; its duration is added to any time already left.
function BoostOps.activate(data: Data, boostId: string): (boolean, Failure?)
	if not isKnown(boostId) then
		return false, "UnknownBoost"
	end
	if BoostOps.owned(data, boostId) <= 0 then
		return false, "NotOwned"
	end
	data.Boosts.Owned[boostId] -= 1
	data.Boosts.Remaining[boostId] = BoostOps.remaining(data, boostId) + Boosts.get(boostId).duration
	return true, nil
end

-- Counts active boosts down by `elapsed` seconds. Called only while the player is online.
function BoostOps.tick(data: Data, elapsed: number)
	for boostId, remaining in data.Boosts.Remaining do
		if remaining > 0 then
			data.Boosts.Remaining[boostId] = math.max(0, remaining - elapsed)
		end
	end
end

return BoostOps
