-- Checks the Luau modules against the tables in docs/balance.md.
local Formulas = require(Shared.Formulas)
local Rarities = require(Shared.Config.Rarities)
local Raids = require(Shared.Config.Raids)
local Islands = require(Shared.Data.Islands)
local Characters = require(Shared.Data.Characters)

local failures = 0
local function check(label, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end

local islandIds = { "Nameku", "Kono", "CloverKingdom", "TitanVillage", "HeroAcademy", "DemonCorps" }

-- Damage per hit, rows by rarity, columns by island (docs/balance.md).
local damage = {
	Common = { 10, 60, 360, 2200, 13000, 78000 },
	Uncommon = { 16, 96, 580, 3500, 21000, 120000 },
	Rare = { 26, 160, 940, 5600, 34000, 200000 },
	Epic = { 45, 270, 1600, 9700, 58000, 350000 },
	Legendary = { 80, 480, 2900, 17000, 100000, 620000 },
	Mythic = { 150, 900, 5400, 32000, 190000, 1200000 },
	Secret = { 300, 1800, 11000, 65000, 390000, 2300000 },
}
for rarityId, row in damage do
	for i, islandId in islandIds do
		local character = Characters.forIslandAndRarity(islandId, rarityId)
		check(`damage {character.id}`, Formulas.characterDamage(character.id), row[i])
	end
end

local health = {
	Easy = { 170, 1000, 6200, 37000, 220000, 1300000 },
	Medium = { 430, 2600, 16000, 94000, 560000, 3400000 },
	Hard = { 1100, 6500, 39000, 230000, 1400000, 8400000 },
	Boss = { 5200, 31000, 190000, 1100000, 6700000, 40000000 },
}
local yen = {
	Easy = { 5, 30, 180, 1100, 6500, 39000 },
	Medium = { 15, 90, 540, 3200, 19000, 120000 },
	Hard = { 45, 270, 1600, 9700, 58000, 350000 },
	Boss = { 300, 1800, 11000, 65000, 390000, 2300000 },
}
for rankId, row in health do
	for i, islandId in islandIds do
		check(`health {islandId} {rankId}`, Formulas.enemyHealth(islandId, rankId), row[i])
		check(`yen {islandId} {rankId}`, Formulas.enemyYen(islandId, rankId), yen[rankId][i])
	end
end

local gacha = { 50, 300, 1800, 11000, 65000, 390000 }
local portal = { 0, 2700, 32000, 290000, 2300000, 21000000 }
for i, islandId in islandIds do
	check(`gacha {islandId}`, Formulas.gachaCost(islandId), gacha[i])
	check(`portal {islandId}`, Formulas.portalCost(islandId), portal[i])
end

local inventoryCosts = {
	10000,
	15000,
	23000,
	34000,
	51000,
	76000,
	110000,
	170000,
	260000,
	380000,
	580000,
	860000,
	1300000,
	1900000,
	2900000,
	4400000,
	6600000,
	9900000,
	15000000,
	22000000,
}
check("max inventory upgrades", Formulas.maxInventoryUpgrades(), 20)
check("inventory slots after 20", Formulas.inventorySlots(20), 250)
for n, cost in inventoryCosts do
	check(`inventory upgrade {n}`, Formulas.inventoryUpgradeCost(n), cost)
end

local raidHealth = {
	Easy = { Weak = 780, Medium = 2100, MiniBoss = 16000, Boss = 39000 },
	Medium = { Weak = 28000, Medium = 75000, MiniBoss = 560000, Boss = 1400000 },
	Hard = { Weak = 1000000, Medium = 2700000, MiniBoss = 20000000, Boss = 51000000 },
}
local raidYen = {
	Easy = { Weak = 30, Medium = 90, MiniBoss = 1400, Boss = 5400 },
	Medium = { Weak = 1100, Medium = 3200, MiniBoss = 49000, Boss = 190000 },
	Hard = { Weak = 39000, Medium = 120000, MiniBoss = 1700000, Boss = 7000000 },
}
local raidTotalGems = { Easy = 356, Medium = 868, Hard = 2236 }
for difficultyId, row in raidHealth do
	local totalGems = 0
	local counts = { Weak = 0, Medium = 0, MiniBoss = 0, Boss = 0 }
	for wave = 1, Raids.WaveCount do
		for enemyTypeId, count in Raids.getWave(wave) do
			counts[enemyTypeId] += count
			totalGems += count * Formulas.raidEnemyGems(difficultyId, enemyTypeId)
		end
	end
	check(`raid {difficultyId} counts`, `{counts.Weak}/{counts.Medium}/{counts.MiniBoss}/{counts.Boss}`, "94/96/1/1")
	check(`raid {difficultyId} total gems`, totalGems, raidTotalGems[difficultyId])
	for enemyTypeId, expected in row do
		check(`raid health {difficultyId} {enemyTypeId}`, Formulas.raidEnemyHealth(difficultyId, enemyTypeId), expected)
		check(
			`raid yen {difficultyId} {enemyTypeId}`,
			Formulas.raidEnemyYen(difficultyId, enemyTypeId),
			raidYen[difficultyId][enemyTypeId]
		)
	end
end

-- Structural checks.
local chanceTotal = 0
for _, rarity in Rarities.List do
	chanceTotal += rarity.gachaChance
end
check("gacha chances total", math.round(chanceTotal * 1000) / 1000, 100)
check("character count", #Characters.List, 42)
for _, island in Islands.List do
	check(`characters on {island.id}`, #Characters.forIsland(island.id), 7)
end
check("equip slots none", Formulas.equipSlots({}), 3)
check("equip slots easy", Formulas.equipSlots({ Easy = 15 }), 4)
check("equip slots all", Formulas.equipSlots({ Easy = 15, Medium = 25, Hard = 50 }), 6)
check("equip slots almost", Formulas.equipSlots({ Easy = 14, Medium = 24, Hard = 49 }), 3)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
