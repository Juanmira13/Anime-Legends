--!strict
-- Rarity tiers, ordered from lowest to highest. See docs/balance.md.

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type Rarity = {
	id: RarityId,
	displayName: string,
	order: number,
	damageMultiplier: number, -- relative to the Common character of the same island
	cooldown: number, -- seconds between hits
	gachaChance: number, -- percent; all tiers add up to 100
}

local List: { Rarity } = {
	{ id = "Common", displayName = "Común", order = 1, damageMultiplier = 1, cooldown = 2.0, gachaChance = 50 },
	{ id = "Uncommon", displayName = "Poco común", order = 2, damageMultiplier = 1.6, cooldown = 1.9, gachaChance = 25 },
	{ id = "Rare", displayName = "Raro", order = 3, damageMultiplier = 2.6, cooldown = 1.8, gachaChance = 13.9 },
	{ id = "Epic", displayName = "Épico", order = 4, damageMultiplier = 4.5, cooldown = 1.6, gachaChance = 8 },
	{ id = "Legendary", displayName = "Legendario", order = 5, damageMultiplier = 8, cooldown = 1.4, gachaChance = 2 },
	{ id = "Mythic", displayName = "Mítico", order = 6, damageMultiplier = 15, cooldown = 1.2, gachaChance = 1 },
	{ id = "Secret", displayName = "Secreto", order = 7, damageMultiplier = 30, cooldown = 1.0, gachaChance = 0.1 },
}

local byId: { [string]: Rarity } = {}
for _, rarity in List do
	byId[rarity.id] = rarity
end

local Rarities = {
	List = List,
}

function Rarities.get(id: string): Rarity
	local rarity = byId[id]
	assert(rarity, `Unknown rarity: {id}`)
	return rarity
end

return Rarities
