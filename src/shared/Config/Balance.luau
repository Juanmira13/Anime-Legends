--!strict
-- Core balance constants. Every derived value (damage, health, yen, costs) is
-- computed from these in Shared.Formulas. See docs/balance.md.

export type EnemyRankId = "Easy" | "Medium" | "Hard" | "Boss"

export type EnemyRank = {
	id: EnemyRankId,
	displayName: string,
	timeToKill: number, -- seconds for the reference team to defeat it
	yen: number, -- reward on the first island; scaled per island
	respawnTime: number, -- seconds
}

local Balance = {
	-- Damage, health, yen and costs grow by this factor on each island.
	IslandMultiplier = 6,

	-- Damage per hit of a Common character on the first island.
	BaseDamage = 10,

	-- Enemy health is tuned so this team defeats each rank in its timeToKill.
	ReferenceTeam = { size = 3, rarity = "Rare" },

	EnemyRanks = {
		{ id = "Easy", displayName = "Fácil", timeToKill = 4, yen = 5, respawnTime = 20 },
		{ id = "Medium", displayName = "Medio", timeToKill = 10, yen = 15, respawnTime = 20 },
		{ id = "Hard", displayName = "Difícil", timeToKill = 25, yen = 45, respawnTime = 20 },
		{ id = "Boss", displayName = "Jefe", timeToKill = 120, yen = 300, respawnTime = 60 },
	} :: { EnemyRank },

	-- Portal costs are paid with the yen earned farming this rank on the previous island.
	PortalFarmRank = "Medium",

	-- Cost of one gacha roll on the first island.
	GachaBaseCost = 50,

	-- Rolls on the same island until the rarity is guaranteed. Counters are per
	-- island and per rarity, and reset when that rarity is obtained.
	Pity = {
		Legendary = 500,
		Mythic = 5_000,
		Secret = 1_000_000,
	},

	Inventory = {
		startingSlots = 50,
		slotsPerUpgrade = 10,
		maxSlots = 250,
		baseUpgradeCost = 10_000,
		upgradeCostGrowth = 1.5,
	},

	-- Extra equip slots come from raid achievements (see Config.Raids).
	Equip = {
		startingSlots = 3,
		maxSlots = 6,
	},

	Combat = {
		-- Max distance in studs between the player and their target.
		range = 60,
	},
}

local ranksById: { [string]: EnemyRank } = {}
for _, rank in Balance.EnemyRanks do
	ranksById[rank.id] = rank
end

function Balance.getEnemyRank(id: string): EnemyRank
	local rank = ranksById[id]
	assert(rank, `Unknown enemy rank: {id}`)
	return rank
end

return Balance
