--!strict
-- Raid configuration. See docs/game-design.md and docs/balance.md.

export type RaidEnemyTypeId = "Weak" | "Medium" | "MiniBoss" | "Boss"
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

export type WaveGroup = {
	from: number,
	to: number,
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

	EnemyTypes = {
		{ id = "Weak", displayName = "Débil", timeToKill = 3, yen = 5 },
		{ id = "Medium", displayName = "Mediano", timeToKill = 8, yen = 15 },
		{ id = "MiniBoss", displayName = "Mini jefe", timeToKill = 60, yen = 225 },
		{ id = "Boss", displayName = "Jefe final", timeToKill = 150, yen = 900 },
	} :: { RaidEnemyType },

	Difficulties = {
		{
			id = "Easy",
			displayName = "Fácil",
			referenceIsland = "Kono",
			cooldown = 60 * 60,
			gems = { Weak = 1, Medium = 2, MiniBoss = 20, Boss = 50 },
			boostDropChance = { Weak = 0.5, Medium = 1, MiniBoss = 25, Boss = 100 },
		},
		{
			id = "Medium",
			displayName = "Medio",
			referenceIsland = "TitanVillage",
			cooldown = 90 * 60,
			gems = { Weak = 2, Medium = 5, MiniBoss = 50, Boss = 150 },
			boostDropChance = { Weak = 0.75, Medium = 1.5, MiniBoss = 37.5, Boss = 100 },
		},
		{
			id = "Hard",
			displayName = "Difícil",
			referenceIsland = "DemonCorps",
			cooldown = 120 * 60,
			gems = { Weak = 6, Medium = 12, MiniBoss = 120, Boss = 400 },
			boostDropChance = { Weak = 1, Medium = 2, MiniBoss = 50, Boss = 100 },
		},
	} :: { RaidDifficulty },

	-- Same composition on every difficulty.
	Waves = {
		{ from = 1, to = 5, enemies = { Weak = 10 } },
		{ from = 6, to = 9, enemies = { Weak = 6, Medium = 4 } },
		{ from = 10, to = 10, enemies = { MiniBoss = 1, Medium = 4 } },
		{ from = 11, to = 15, enemies = { Weak = 4, Medium = 6 } },
		{ from = 16, to = 19, enemies = { Medium = 10 } },
		{ from = 20, to = 20, enemies = { Boss = 1, Medium = 6 } },
	} :: { WaveGroup },

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

-- Enemies to spawn on a given wave, e.g. { Weak = 6, Medium = 4 }.
function Raids.getWave(wave: number): { [RaidEnemyTypeId]: number }
	for _, group in Raids.Waves do
		if wave >= group.from and wave <= group.to then
			return group.enemies
		end
	end
	error(`Wave out of range: {wave}`)
end

return Raids
