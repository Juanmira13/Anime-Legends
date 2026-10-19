--!strict
-- Gacha roll logic: rarity chances, the Luck boost and pity. Pure (no
-- randomness of its own), so it can be unit tested.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Boosts = require(Shared.Config.Boosts)
local Rarities = require(Shared.Config.Rarities)

-- Rolls since the last hit of each pity rarity, for one island.
export type PityCounters = { [string]: number }

local PITY_THRESHOLDS: { [string]: number } = Balance.Pity :: any

-- Pity rarities from highest to lowest, so the best guarantee wins when two
-- counters reach their threshold on the same roll.
local PITY_ORDER: { string } = {}
for index = #Rarities.List, 1, -1 do
	local id = Rarities.List[index].id
	if PITY_THRESHOLDS[id] then
		table.insert(PITY_ORDER, id)
	end
end

local GachaRoll = {}

-- Percent chance of each rarity. With the Luck boost, boosted rarities are
-- multiplied and the extra chance is taken from Common, so the total stays 100.
function GachaRoll.getChances(luckActive: boolean): { [string]: number }
	local chances: { [string]: number } = {}
	for _, rarity in Rarities.List do
		chances[rarity.id] = rarity.gachaChance
	end
	if luckActive then
		local multiplier = Boosts.get("Luck").multiplier
		local extra = 0
		for _, id in Boosts.LuckRarities do
			local boosted = chances[id] * multiplier
			extra += boosted - chances[id]
			chances[id] = boosted
		end
		chances.Common -= extra
	end
	return chances
end

-- Rolls one rarity and updates `counters` in place: every roll adds 1 to each
-- pity counter, and the counter of the rarity obtained resets to 0.
-- `random` must return a number in [0, 1).
function GachaRoll.roll(counters: PityCounters, luckActive: boolean, random: () -> number): string
	for _, id in PITY_ORDER do
		counters[id] = (counters[id] or 0) + 1
	end

	local result: string? = nil
	for _, id in PITY_ORDER do
		if counters[id] >= PITY_THRESHOLDS[id] then
			result = id
			break
		end
	end

	if result == nil then
		local chances = GachaRoll.getChances(luckActive)
		local point = random() * 100
		local cumulative = 0
		for _, rarity in Rarities.List do
			cumulative += chances[rarity.id]
			if point < cumulative then
				result = rarity.id
				break
			end
		end
		-- Floating point sums can fall a hair short of 100; that sliver belongs to the last tier.
		result = result or Rarities.List[#Rarities.List].id
	end
	assert(result, "unreachable")

	if counters[result] ~= nil then
		counters[result] = 0
	end
	return result
end

return GachaRoll
