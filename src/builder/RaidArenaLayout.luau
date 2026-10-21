--!strict
-- Raid arena layout: the coliseum's sizes and where players and enemies appear,
-- as (x, z) relative to the center of the floor's top. Players come in from the
-- south gate (+Z); enemies stand in the north half, the first spot in the
-- middle for the mini boss and the final boss (they spawn first). Pure data,
-- checked by tests (map.spec).

export type Point = { number } -- { x, z }

local FLOOR_RADIUS = 80

local enemySpots: { Point } = { { 0, -28 } }
for _, z in { -8, -28, -48 } do
	for column = -2, 2 do
		local x = column * 22
		if not (x == 0 and z == -28) then
			table.insert(enemySpots, { x, z })
		end
	end
end

local RaidArenaLayout = {
	floorRadius = FLOOR_RADIUS,
	floorThickness = 4,
	-- Stepped stands behind the podium wall: each tier is deeper and taller.
	tiers = 4,
	tierDepth = 9,
	podiumHeight = 9, -- first tier, the wall around the floor
	tierRise = 5,
	outerWallThickness = 6,
	outerWallHeight = 34,
	segmentDegrees = 7.5, -- angular size of each wall and stand block
	playerSpawn = { 0, 40 } :: Point, -- the front row is within combat range
	enemySpots = enemySpots,
	-- Gates in the podium wall, as angles (radians) around the center.
	playerGate = math.pi / 2, -- south, behind the players
	enemyGate = -math.pi / 2, -- north, behind the enemies
}

-- Outer radius of the whole coliseum (outside face of the outer wall).
function RaidArenaLayout.outerRadius(): number
	local layout = RaidArenaLayout
	return layout.floorRadius + layout.tiers * layout.tierDepth + layout.outerWallThickness
end

return RaidArenaLayout
