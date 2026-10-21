--!strict
-- Derived balance values. Everything scales from the constants in Config so
-- tuning one number keeps the whole game proportional. See docs/balance.md.

local Shared = script.Parent
local Balance = require(Shared.Config.Balance)
local Boosts = require(Shared.Config.Boosts)
local Rarities = require(Shared.Config.Rarities)
local Raids = require(Shared.Config.Raids)
local Islands = require(Shared.Data.Islands)
local Characters = require(Shared.Data.Characters)

local getEnemyRank = Balance.getEnemyRank

local Formulas = {}

-- Rounds to 2 significant digits (e.g. 1234 -> 1200) so values read cleanly in UI.
function Formulas.niceRound(value: number): number
	if value < 100 then
		return math.round(value)
	end
	local step = 10 ^ (math.floor(math.log10(value)) - 1)
	return math.round(value / step) * step
end

-- Growth factor of an island relative to the first one.
function Formulas.islandScale(islandId: string): number
	return Balance.IslandMultiplier ^ (Islands.get(islandId).order - 1)
end

function Formulas.characterDamage(characterId: string): number
	local character = Characters.get(characterId)
	local rarity = Rarities.get(character.rarity)
	return Formulas.niceRound(Balance.BaseDamage * rarity.damageMultiplier * Formulas.islandScale(character.island))
end

function Formulas.characterCooldown(characterId: string): number
	return Rarities.get(Characters.get(characterId).rarity).cooldown
end

-- Damage per second of the reference team on an island (unrounded).
function Formulas.referenceDps(islandId: string): number
	local rarity = Rarities.get(Balance.ReferenceTeam.rarity)
	local characterDps = Balance.BaseDamage * rarity.damageMultiplier / rarity.cooldown
	return Balance.ReferenceTeam.size * characterDps * Formulas.islandScale(islandId)
end

function Formulas.enemyHealth(islandId: string, rankId: string): number
	return Formulas.niceRound(Formulas.referenceDps(islandId) * getEnemyRank(rankId).timeToKill)
end

function Formulas.enemyYen(islandId: string, rankId: string): number
	return Formulas.niceRound(getEnemyRank(rankId).yen * Formulas.islandScale(islandId))
end

-- Yen a player gets for defeating an enemy, with the Money boost applied if active.
function Formulas.killReward(islandId: string, rankId: string, moneyBoostActive: boolean): number
	local yen = Formulas.enemyYen(islandId, rankId)
	if moneyBoostActive then
		yen *= Boosts.get("Money").multiplier
	end
	return yen
end

function Formulas.enemyRespawnTime(rankId: string): number
	return getEnemyRank(rankId).respawnTime
end

-- Yen for `count` rolls (default 1) on an island's gacha; no discount for many.
function Formulas.gachaCost(islandId: string, count: number?): number
	return Formulas.niceRound(Balance.GachaBaseCost * Formulas.islandScale(islandId)) * (count or 1)
end

-- Percent chance of each gacha rarity. With the Luck boost, boosted rarities
-- are multiplied and the extra chance is taken from Common, so the total stays 100.
function Formulas.gachaChances(luckActive: boolean): { [string]: number }
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

-- Yen to unlock an island's portal; 0 for the first island.
function Formulas.portalCost(islandId: string): number
	local island = Islands.get(islandId)
	local previous = Islands.getPrevious(islandId)
	if previous == nil then
		return 0
	end
	local rank = getEnemyRank(Balance.PortalFarmRank)
	local yenPerSecond = rank.yen / rank.timeToKill * Formulas.islandScale(previous.id)
	return Formulas.niceRound(yenPerSecond * 3600 * island.portalFarmHours)
end

function Formulas.maxInventoryUpgrades(): number
	local inventory = Balance.Inventory
	return (inventory.maxSlots - inventory.startingSlots) // inventory.slotsPerUpgrade
end

-- Cost of the nth inventory upgrade (1-based).
function Formulas.inventoryUpgradeCost(upgradeNumber: number): number
	assert(upgradeNumber >= 1 and upgradeNumber <= Formulas.maxInventoryUpgrades(), "Upgrade out of range")
	local inventory = Balance.Inventory
	return Formulas.niceRound(inventory.baseUpgradeCost * inventory.upgradeCostGrowth ^ (upgradeNumber - 1))
end

function Formulas.inventorySlots(upgradesBought: number): number
	return Balance.Inventory.startingSlots + upgradesBought * Balance.Inventory.slotsPerUpgrade
end

-- Raid enemy health and yen grow by Raids.WaveGrowth each wave (`wave` defaults to 1).
function Formulas.raidEnemyHealth(difficultyId: string, enemyTypeId: string, wave: number?): number
	local difficulty = Raids.getDifficulty(difficultyId)
	local enemyType = Raids.getEnemyType(enemyTypeId)
	local base = Formulas.referenceDps(difficulty.referenceIsland) * enemyType.timeToKill
	return Formulas.niceRound(base * Raids.waveScale(wave or 1))
end

function Formulas.raidEnemyYen(difficultyId: string, enemyTypeId: string, wave: number?): number
	local difficulty = Raids.getDifficulty(difficultyId)
	local enemyType = Raids.getEnemyType(enemyTypeId)
	local base = enemyType.yen * Formulas.islandScale(difficulty.referenceIsland)
	return Formulas.niceRound(base * Raids.waveScale(wave or 1))
end

function Formulas.raidEnemyGems(difficultyId: string, enemyTypeId: string): number
	return Raids.getDifficulty(difficultyId).gems[enemyTypeId :: Raids.RaidEnemyTypeId]
end

-- Total equip slots for a player given their raid completions per difficulty.
function Formulas.equipSlots(raidCompletions: { [string]: number }): number
	local slots = Balance.Equip.startingSlots
	for _, achievement in Raids.Achievements do
		if (raidCompletions[achievement.difficulty] or 0) >= achievement.completions then
			slots += achievement.extraEquipSlots
		end
	end
	return math.min(slots, Balance.Equip.maxSlots)
end

return Formulas
