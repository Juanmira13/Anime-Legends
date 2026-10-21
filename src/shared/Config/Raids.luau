--!strict
-- Raid configuration. See docs/game-design.md and docs/balance.md.

export type RaidEnemyTypeId = "Weak" | "Medium" | "Strong" | "MiniBoss" | "Boss"
export type RaidDifficultyId = "Easy" | "Medium" | "Hard"

export type RaidEnemyType = {
	id: RaidEnemyTypeId,
	displayName: string,
	timeToKill: number, -- seconds for the reference team of the difficulty's island
	yen: number, -- reward at island scale 1; scaled by the difficulty's island
}

export type RaidDifficulty = {
	id: RaidDifficultyId,
	displayName: string,
	referenceIsland: string, -- enemies are tuned for this island's reference team
	cooldown: number, -- seconds between raids, per player
	gems: { [RaidEnemyTypeId]: number },
	boostDropChance: { [RaidEnemyTypeId]: number }, -- percent
}

export type WaveExtra = {
	wave: number,
	enemies: { [RaidEnemyTypeId]: number },
}

export type Achievement = {
	difficulty: RaidDifficultyId,
	completions: number,
	extraEquipSlots: number,
}

local Raids = {
	WaveCount = 20,
	TimeLimit = 30 * 60,
	MaxPlayers = 20,
	-- Each wave's enemies have this much more health and yen than the previous
	-- wave's (wave 20 is 1.03^19 = 1.75x wave 1): steady, without big jumps.
	WaveGrowth = 1.03,

	-- Where each wave's enemies appear: random points on the arena field.
	Arena = {
		wallMargin = 12, -- studs kept clear inside the field's edge (bosses are ~12 wide)
		enemyGap = 16, -- min studs between two enemies
		bossClearance = 18, -- the mini boss and the final boss stand in the center; others keep this far
		spawnClearance = 24, -- min studs from the players' arrival point
		exitClearance = 18, -- min studs from the exit portal
	},

	EnemyTypes = {
		{ id = "Weak", displayName = "Débil", timeToKill = 3, yen = 5 },
		{ id = "Medium", displayName = "Mediano", timeToKill = 8, yen = 15 },
		{ id = "Strong", displayName = "Fuerte", timeToKill = 12, yen = 30 },
		{ id = "MiniBoss", displayName = "Mini jefe", timeToKill = 60, yen = 225 },
		{ id = "Boss", displayName = "Jefe final", timeToKill = 150, yen = 900 },
	} :: { RaidEnemyType },

	Difficulties = {
		{
			id = "Easy",
			displayName = "Fácil",
			referenceIsland = "Kono",
			cooldown = 60 * 60,
			gems = { Weak = 1, Medium = 3, Strong = 5, MiniBoss = 20, Boss = 50 },
			boostDropChance = { Weak = 0.5, Medium = 1, Strong = 2, MiniBoss = 25, Boss = 100 },
		},
		{
			id = "Medium",
			displayName = "Medio",
			referenceIsland = "TitanVillage",
			cooldown = 90 * 60,
			gems = { Weak = 3, Medium = 6, Strong = 12, MiniBoss = 50, Boss = 150 },
			boostDropChance = { Weak = 0.75, Medium = 1.5, Strong = 3, MiniBoss = 37.5, Boss = 100 },
		},
		{
			id = "Hard",
			displayName = "Difícil",
			referenceIsland = "DemonCorps",
			cooldown = 120 * 60,
			gems = { Weak = 7, Medium = 14, Strong = 30, MiniBoss = 120, Boss = 400 },
			boostDropChance = { Weak = 1, Medium = 2, Strong = 4, MiniBoss = 50, Boss = 100 },
		},
	} :: { RaidDifficulty },

	-- Same composition on every difficulty: every wave brings weak, medium and
	-- strong enemies (getting tougher with WaveGrowth), plus a boss on some waves.
	WaveEnemies = { Weak = 4, Medium = 2, Strong = 1 } :: { [RaidEnemyTypeId]: number },
	WaveExtras = {
		{ wave = 10, enemies = { MiniBoss = 1 } },
		{ wave = 20, enemies = { Boss = 1 } },
	} :: { WaveExtra },

	-- One-time achievements, each granting extra equip slots.
	Achievements = {
		{ difficulty = "Easy", completions = 15, extraEquipSlots = 1 },
		{ difficulty = "Medium", completions = 25, extraEquipSlots = 1 },
		{ difficulty = "Hard", completions = 50, extraEquipSlots = 1 },
	} :: { Achievement },
}

local difficultiesById: { [string]: RaidDifficulty } = {}
for _, difficulty in Raids.Difficulties do
	difficultiesById[difficulty.id] = difficulty
end

local enemyTypesById: { [string]: RaidEnemyType } = {}
for _, enemyType in Raids.EnemyTypes do
	enemyTypesById[enemyType.id] = enemyType
end

function Raids.getDifficulty(id: string): RaidDifficulty
	local difficulty = difficultiesById[id]
	assert(difficulty, `Unknown raid difficulty: {id}`)
	return difficulty
end

function Raids.getEnemyType(id: string): RaidEnemyType
	local enemyType = enemyTypesById[id]
	assert(enemyType, `Unknown raid enemy type: {id}`)
	return enemyType
end

-- Enemies to spawn on a given wave, e.g. { Weak = 4, Medium = 2, Strong = 1, MiniBoss = 1 }.
function Raids.getWave(wave: number): { [RaidEnemyTypeId]: number }
	assert(wave >= 1 and wave <= Raids.WaveCount and wave == math.floor(wave), `Wave out of range: {wave}`)
	local enemies: { [string]: number } = table.clone(Raids.WaveEnemies) :: any
	for _, extra in Raids.WaveExtras do
		if extra.wave == wave then
			for typeId, count in extra.enemies do
				enemies[typeId] = (enemies[typeId] or 0) + count
			end
		end
	end
	return enemies :: any
end

-- Health and yen multiplier of a wave's enemies (1 on the first wave).
function Raids.waveScale(wave: number): number
	return Raids.WaveGrowth ^ (wave - 1)
end

return Raids
