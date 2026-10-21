--!strict
-- Raid arena layout: the coliseum's sizes, where players arrive and the exit
-- portal, as (x, z) relative to the center of the floor's top. Players come in
-- by the south gate (+Z), with the exit portal behind them. Enemies stand at
-- random points of the field each wave (RaidOps.randomSpots, which keeps clear
-- of both). Pure data, checked by tests (map.spec).

export type Point = { number } -- { x, z }

local FLOOR_RADIUS = 80

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
	exitPortal = { 0, 66 } :: Point, -- between the arrival point and the south gate
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
