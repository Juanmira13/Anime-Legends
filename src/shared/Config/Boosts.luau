--!strict
-- Boosts drop from raid enemies or can be bought with gems. Activating a boost
-- that is already active adds its duration to the remaining time.

export type BoostId = "Luck" | "Money" | "Gems"

export type Boost = {
	id: BoostId,
	displayName: string,
	multiplier: number,
	duration: number, -- seconds
	gemPrice: number,
}

local List: { Boost } = {
	-- Multiplies the chance of Legendary, Mythic and Secret in the gacha.
	{ id = "Luck", displayName = "Suerte", multiplier = 2, duration = 15 * 60, gemPrice = 200 },
	{ id = "Money", displayName = "Dinero", multiplier = 2, duration = 15 * 60, gemPrice = 125 },
	{ id = "Gems", displayName = "Gemas", multiplier = 2, duration = 15 * 60, gemPrice = 300 },
}

local byId: { [string]: Boost } = {}
for _, boost in List do
	byId[boost.id] = boost
end

local Boosts = {
	List = List,
	-- Rarities affected by the Luck boost.
	LuckRarities = { "Legendary", "Mythic", "Secret" },
}

function Boosts.get(id: string): Boost
	local boost = byId[id]
	assert(boost, `Unknown boost: {id}`)
	return boost
end

return Boosts
