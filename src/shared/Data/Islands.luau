--!strict
-- Islands in progression order. See docs/game-design.md.

export type Island = {
	id: string,
	displayName: string,
	anime: string,
	order: number,
	-- Hours of farming on the previous island needed to pay this island's portal.
	portalFarmHours: number,
}

local List: { Island } = {
	{ id = "Nameku", displayName = "Nameku", anime = "Dragon Ball", order = 1, portalFarmHours = 0 },
	{ id = "Kono", displayName = "Kono", anime = "Naruto", order = 2, portalFarmHours = 0.5 },
	{ id = "CloverKingdom", displayName = "Clover Kingdom", anime = "Black Clover", order = 3, portalFarmHours = 1 },
	{ id = "TitanVillage", displayName = "Titan Village", anime = "Attack on Titan", order = 4, portalFarmHours = 1.5 },
	{ id = "HeroAcademy", displayName = "Hero Academy", anime = "My Hero Academia", order = 5, portalFarmHours = 2 },
	{ id = "DemonCorps", displayName = "Demon Corps", anime = "Demon Slayer", order = 6, portalFarmHours = 3 },
}

local byId: { [string]: Island } = {}
for _, island in List do
	byId[island.id] = island
end

local Islands = {
	List = List,
}

function Islands.get(id: string): Island
	local island = byId[id]
	assert(island, `Unknown island: {id}`)
	return island
end

-- The island before this one in progression order, or nil for the first.
function Islands.getPrevious(id: string): Island?
	return List[Islands.get(id).order - 1]
end

return Islands
