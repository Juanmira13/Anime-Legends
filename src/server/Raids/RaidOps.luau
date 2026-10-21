--!strict
-- Raid rules on player data and config: cooldowns, completions, per-enemy
-- rewards, boost drops, wave composition and where enemies stand. Pure
-- (randomness is passed in),
-- so it can be unit tested.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local Formulas = require(Shared.Formulas)
local Raids = require(Shared.Config.Raids)

local PlayerRecord = require(script.Parent.Parent.Data.PlayerRecord)

type Data = PlayerRecord.Data

-- Spawn order inside a wave: bosses first, so they get placed while the field is emptiest.
local SPAWN_ORDER = { "Boss", "MiniBoss", "Strong", "Medium", "Weak" }
-- These stand in the center of the arena (the golden circle).
local CENTER_TYPES: { [string]: boolean } = { Boss = true, MiniBoss = true }

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

-- Yen and gems a raid player gets for an enemy of `wave` (yen grows with the wave), with boosts applied.
function RaidOps.reward(
	difficultyId: string,
	typeId: string,
	wave: number,
	moneyBoost: boolean,
	gemsBoost: boolean
): (number, number)
	local yen = Formulas.raidEnemyYen(difficultyId, typeId, wave)
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

export type Point = { number } -- { x, z } relative to the arena center
export type Clearance = { x: number, z: number, radius: number }

local SPOT_ATTEMPTS = 60

-- `count` random points on a round field of `fieldRadius` (relative to its
-- center): inside the edge margin, at least `enemyGap` apart and outside every
-- `avoid` circle (the players' arrival point, the exit portal). When the field
-- is too crowded for a spot, it takes the attempt farthest from the others.
function RaidOps.randomSpots(count: number, fieldRadius: number, avoid: { Clearance }, random: () -> number): { Point }
	local arena = Raids.Arena
	local radius = math.max(0, fieldRadius - arena.wallMargin)
	local spots: { Point } = {}
	for _ = 1, count do
		local best: Point? = nil
		local bestGap = -math.huge
		for _ = 1, SPOT_ATTEMPTS do
			-- Uniform over the disc: sqrt keeps points from bunching in the middle.
			local distance = radius * math.sqrt(random())
			local angle = random() * 2 * math.pi
			local x, z = math.cos(angle) * distance, math.sin(angle) * distance
			local clear = true
			for _, zone in avoid do
				if (x - zone.x) ^ 2 + (z - zone.z) ^ 2 < zone.radius ^ 2 then
					clear = false
					break
				end
			end
			if clear then
				local gap = math.huge
				for _, spot in spots do
					gap = math.min(gap, math.sqrt((x - spot[1]) ^ 2 + (z - spot[2]) ^ 2))
				end
				if gap >= arena.enemyGap then
					best = { x, z }
					break
				end
				if gap > bestGap then
					best, bestGap = { x, z }, gap
				end
			end
		end
		table.insert(spots, best or { 0, 0 })
	end
	return spots
end

-- Where each enemy of a wave stands, in the order of `typeIds`: the mini boss
-- and the final boss in the center of the field, the rest at random points
-- (kept away from the center when a boss is there).
function RaidOps.waveSpots(
	typeIds: { string },
	fieldRadius: number,
	avoid: { Clearance },
	random: () -> number
): { Point }
	local others = 0
	local hasBoss = false
	for _, typeId in typeIds do
		if CENTER_TYPES[typeId] then
			hasBoss = true
		else
			others += 1
		end
	end
	local clearances = table.clone(avoid)
	if hasBoss then
		table.insert(clearances, { x = 0, z = 0, radius = Raids.Arena.bossClearance })
	end
	local randomSpots = RaidOps.randomSpots(others, fieldRadius, clearances, random)
	local spots: { Point } = {}
	local nextRandom = 1
	for _, typeId in typeIds do
		if CENTER_TYPES[typeId] then
			table.insert(spots, { 0, 0 })
		else
			table.insert(spots, randomSpots[nextRandom])
			nextRandom += 1
		end
	end
	return spots
end

return RaidOps
