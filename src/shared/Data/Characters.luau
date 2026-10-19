--!strict
-- Gacha characters: one per rarity on each island. Damage and cooldown are
-- derived from the rarity and island in Shared.Formulas.
-- Display names are slight variations of the originals (provisional).

export type Character = {
	id: string,
	displayName: string,
	island: string,
	rarity: string,
}

local List: { Character } = {
	-- Nameku (Dragon Ball)
	{ id = "Krilin", displayName = "Kurilin", island = "Nameku", rarity = "Common" },
	{ id = "Yamcha", displayName = "Yamucha", island = "Nameku", rarity = "Uncommon" },
	{ id = "Piccolo", displayName = "Pikkolo", island = "Nameku", rarity = "Rare" },
	{ id = "Freezer", displayName = "Freezor", island = "Nameku", rarity = "Epic" },
	{ id = "Gohan", displayName = "Gohen", island = "Nameku", rarity = "Legendary" },
	{ id = "Vegeta", displayName = "Vejita", island = "Nameku", rarity = "Mythic" },
	{ id = "GokuSSJ1", displayName = "Gokuh SSJ1", island = "Nameku", rarity = "Secret" },

	-- Kono (Naruto)
	{ id = "Sakura", displayName = "Sakara", island = "Kono", rarity = "Common" },
	{ id = "Yamato", displayName = "Yamado", island = "Kono", rarity = "Uncommon" },
	{ id = "Shikamaru", displayName = "Shikamarou", island = "Kono", rarity = "Rare" },
	{ id = "Sasuke", displayName = "Sazuke", island = "Kono", rarity = "Epic" },
	{ id = "Kakashi", displayName = "Kakashy", island = "Kono", rarity = "Legendary" },
	{ id = "Itachi", displayName = "Itashi", island = "Kono", rarity = "Mythic" },
	{ id = "Naruto4Tails", displayName = "Narutto 4 Tails", island = "Kono", rarity = "Secret" },

	-- Clover Kingdom (Black Clover)
	{ id = "Noelle", displayName = "Noella", island = "CloverKingdom", rarity = "Common" },
	{ id = "Magna", displayName = "Magno", island = "CloverKingdom", rarity = "Uncommon" },
	{ id = "Charmy", displayName = "Charmi", island = "CloverKingdom", rarity = "Rare" },
	{ id = "Fuegoleon", displayName = "Fuegolion", island = "CloverKingdom", rarity = "Epic" },
	{ id = "Yami", displayName = "Yamy", island = "CloverKingdom", rarity = "Legendary" },
	{ id = "Julius", displayName = "Julios", island = "CloverKingdom", rarity = "Mythic" },
	{ id = "AstaDevilUnion", displayName = "Azta Devil Union", island = "CloverKingdom", rarity = "Secret" },

	-- Titan Village (Attack on Titan)
	{ id = "Connie", displayName = "Conny", island = "TitanVillage", rarity = "Common" },
	{ id = "Armin", displayName = "Armen", island = "TitanVillage", rarity = "Uncommon" },
	{ id = "Hanje", displayName = "Hanjie", island = "TitanVillage", rarity = "Rare" },
	{ id = "Zeke", displayName = "Zeek", island = "TitanVillage", rarity = "Epic" },
	{ id = "Mikasa", displayName = "Mikaza", island = "TitanVillage", rarity = "Legendary" },
	{ id = "Levi", displayName = "Levy", island = "TitanVillage", rarity = "Mythic" },
	{ id = "Eren", displayName = "Erem", island = "TitanVillage", rarity = "Secret" },

	-- Hero Academy (My Hero Academia)
	{ id = "Mineta", displayName = "Mineto", island = "HeroAcademy", rarity = "Common" },
	{ id = "Uraraka", displayName = "Urarako", island = "HeroAcademy", rarity = "Uncommon" },
	{ id = "Shoto", displayName = "Shotto", island = "HeroAcademy", rarity = "Rare" },
	{ id = "Deku", displayName = "Dekku", island = "HeroAcademy", rarity = "Epic" },
	{ id = "Hawks", displayName = "Hawkz", island = "HeroAcademy", rarity = "Legendary" },
	{ id = "Shigaraki", displayName = "Shigaraky", island = "HeroAcademy", rarity = "Mythic" },
	{ id = "AllMight", displayName = "All Mighty", island = "HeroAcademy", rarity = "Secret" },

	-- Demon Corps (Demon Slayer)
	{ id = "Zenitsu", displayName = "Zenitzu", island = "DemonCorps", rarity = "Common" },
	{ id = "Inosuke", displayName = "Inozuke", island = "DemonCorps", rarity = "Uncommon" },
	{ id = "Nezuko", displayName = "Nezuco", island = "DemonCorps", rarity = "Rare" },
	{ id = "Tanjiro", displayName = "Tanjiru", island = "DemonCorps", rarity = "Epic" },
	{ id = "Tomioka", displayName = "Tomiokka", island = "DemonCorps", rarity = "Legendary" },
	{ id = "Akaza", displayName = "Akazza", island = "DemonCorps", rarity = "Mythic" },
	{ id = "Rengoku", displayName = "Rengokku", island = "DemonCorps", rarity = "Secret" },
}

local byId: { [string]: Character } = {}
local byIsland: { [string]: { Character } } = {}
for _, character in List do
	assert(byId[character.id] == nil, `Duplicate character id: {character.id}`)
	byId[character.id] = character
	byIsland[character.island] = byIsland[character.island] or {}
	table.insert(byIsland[character.island], character)
end

local Characters = {
	List = List,
}

function Characters.get(id: string): Character
	local character = byId[id]
	assert(character, `Unknown character: {id}`)
	return character
end

-- Characters of an island, ordered from lowest to highest rarity.
function Characters.forIsland(islandId: string): { Character }
	return byIsland[islandId] or {}
end

-- The character of an island for a given rarity.
function Characters.forIslandAndRarity(islandId: string, rarityId: string): Character
	for _, character in Characters.forIsland(islandId) do
		if character.rarity == rarityId then
			return character
		end
	end
	error(`No {rarityId} character on island {islandId}`)
end

return Characters
