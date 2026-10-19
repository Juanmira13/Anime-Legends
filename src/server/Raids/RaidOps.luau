--!strict
-- Raid rules on player data and config: cooldowns, completions, per-enemy
-- rewards, boost drops and wave composition. Pure (randomness is passed in),
-- so it can be unit tested.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local Formulas = require(Shared.Formulas)
local Raids = require(Shared.Config.Raids)

local PlayerRecord = require(script.Parent.Parent.Data.PlayerRecord)

type Data = PlayerRecord.Data

-- Spawn order inside a wave: bosses first so they get the central spots.
local SPAWN_ORDER = { "Boss", "MiniBoss", "Medium", "Weak" }

local RaidOps = {}

-- os.time() at which the player can start this difficulty again.
function RaidOps.readyAt(data: Data, difficultyId: string): number
	local lastStarted = data.Raids.LastStarted[difficultyId] or 0
	if lastStarted == 0 then
		return 0
	end
	return lastStarted + Raids.getDifficulty(difficultyId).cooldown
end

function RaidOps.canStart(data: Data, difficultyId: string, now: number): boolean
	return now >= RaidOps.readyAt(data, difficultyId)
end

function RaidOps.markStarted(data: Data, difficultyId: string, now: number)
	data.Raids.LastStarted[difficultyId] = now
end

-- Records a completed raid. Returns the equip slots before and after, so the
-- caller can announce a newly earned slot.
function RaidOps.complete(data: Data, difficultyId: string): (number, number)
	local before = Formulas.equipSlots(data.Raids.Completions)
	data.Raids.Completions[difficultyId] = (data.Raids.Completions[difficultyId] or 0) + 1
	return before, Formulas.equipSlots(data.Raids.Completions)
end

-- Enemy types to spawn on a wave, in spawn order.
function RaidOps.waveEnemies(wave: number): { string }
	local composition = Raids.getWave(wave)
	local list = {}
	for _, typeId in SPAWN_ORDER do
		for _ = 1, (composition :: any)[typeId] or 0 do
			table.insert(list, typeId)
		end
	end
	return list
end

-- Yen and gems a raid player gets when an enemy dies, with boosts applied.
function RaidOps.reward(difficultyId: string, typeId: string, moneyBoost: boolean, gemsBoost: boolean): (number, number)
	local yen = Formulas.raidEnemyYen(difficultyId, typeId)
	local gems = Formulas.raidEnemyGems(difficultyId, typeId)
	if moneyBoost then
		yen *= Boosts.get("Money").multiplier
	end
	if gemsBoost then
		gems *= Boosts.get("Gems").multiplier
	end
	return yen, gems
end

-- Rolls the boost drop for one player and one enemy. `random` returns [0, 1).
-- Returns the boost id that dropped, or nil.
function RaidOps.rollBoostDrop(difficultyId: string, typeId: string, random: () -> number): string?
	local chance = (Raids.getDifficulty(difficultyId).boostDropChance :: any)[typeId] or 0
	if random() * 100 >= chance then
		return nil
	end
	local index = math.floor(random() * #Boosts.List) + 1
	return Boosts.List[math.min(index, #Boosts.List)].id
end

return RaidOps
