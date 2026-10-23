--!strict
-- Rules a map must follow so every system finds what it needs (see the tag
-- table in CLAUDE.md). Takes a plain description of the tagged parts, so it is
-- pure and unit tested; Studio collects the parts (Dev/MapValidator and the
-- island builder plugin).

local Shared = script.Parent.Parent
local Balance = require(Shared.Config.Balance)
local Islands = require(Shared.Data.Islands)
local Raids = require(Shared.Config.Raids)

export type Entry = {
	tag: string,
	name: string, -- full name, for messages
	area: string?, -- folder under Workspace.Map it belongs to (island id or "RaidLobby")
	attributes: { [string]: any },
}

export type Report = {
	errors: { string },
	warnings: { string },
}

local MapCheck = {}

-- Parts per area above this are reported (mobile performance).
MapCheck.PartBudget = 9000

local function isIsland(id: unknown): boolean
	return type(id) == "string" and (pcall(Islands.get, id))
end

local function isRank(id: unknown): boolean
	return type(id) == "string" and (pcall(Balance.getEnemyRank, id))
end

local function isDifficulty(id: unknown): boolean
	for _, difficulty in Raids.Difficulties do
		if difficulty.id == id then
			return true
		end
	end
	return false
end

-- `partCounts` (optional): parts per area, checked against the budget.
function MapCheck.run(entries: { Entry }, partCounts: { [string]: number }?): Report
	local errors, warnings = {}, {}
	local function err(message: string)
		table.insert(errors, message)
	end

	local spawnsByIsland: { [string]: number } = {}
	local ranksByIsland: { [string]: { [string]: boolean } } = {}
	local gachaByIsland: { [string]: number } = {}
	local portalsByArea: { [string]: { [string]: boolean } } = {}
	local raidPortals, lobbySpawns, shops = 0, 0, 0
	local padsByDifficulty: { [string]: number } = {}

	for _, entry in entries do
		local attributes = entry.attributes
		if entry.tag == "IslandSpawn" then
			local island = attributes.Island
			if isIsland(island) then
				spawnsByIsland[island] = (spawnsByIsland[island] or 0) + 1
			else
				err(`{entry.name}: IslandSpawn has unknown Island "{tostring(island)}"`)
			end
		elseif entry.tag == "EnemySpawn" then
			local island, rank = attributes.Island, attributes.Rank
			if not isIsland(island) then
				err(`{entry.name}: EnemySpawn has unknown Island "{tostring(island)}"`)
			elseif not isRank(rank) then
				err(`{entry.name}: EnemySpawn has unknown Rank "{tostring(rank)}"`)
			else
				ranksByIsland[island] = ranksByIsland[island] or {}
				ranksByIsland[island][rank] = true
			end
		elseif entry.tag == "GachaStand" then
			local island = attributes.Island
			if isIsland(island) then
				gachaByIsland[island] = (gachaByIsland[island] or 0) + 1
			else
				err(`{entry.name}: GachaStand has unknown Island "{tostring(island)}"`)
			end
		elseif entry.tag == "Portal" then
			local target = attributes.TargetIsland
			if not isIsland(target) then
				err(`{entry.name}: Portal has unknown TargetIsland "{tostring(target)}"`)
			elseif entry.area then
				portalsByArea[entry.area] = portalsByArea[entry.area] or {}
				portalsByArea[entry.area][target] = true
			end
		elseif entry.tag == "RaidPortal" then
			raidPortals += 1
		elseif entry.tag == "RaidLobbySpawn" then
			lobbySpawns += 1
		elseif entry.tag == "BoostShop" then
			if entry.area == "RaidLobby" then
				shops += 1
			else
				err(`{entry.name}: BoostShop must be in the raid lobby`)
			end
		elseif entry.tag == "RaidPad" then
			local difficulty = attributes.Difficulty
			if isDifficulty(difficulty) then
				padsByDifficulty[difficulty] = (padsByDifficulty[difficulty] or 0) + 1
			else
				err(`{entry.name}: RaidPad has unknown Difficulty "{tostring(difficulty)}"`)
			end
		end
	end

	for index, island in Islands.List do
		local spawns = spawnsByIsland[island.id] or 0
		if spawns ~= 1 then
			err(`{island.id}: needs exactly one IslandSpawn (found {spawns})`)
		end
		for _, rank in Balance.EnemyRanks do
			if not (ranksByIsland[island.id] and ranksByIsland[island.id][rank.id]) then
				err(`{island.id}: no EnemySpawn with Rank {rank.id}`)
			end
		end
		if (gachaByIsland[island.id] or 0) == 0 then
			err(`{island.id}: no GachaStand`)
		end
		local portals = portalsByArea[island.id] or {}
		for _, neighbor in { Islands.List[index - 1], Islands.List[index + 1] } do
			if neighbor and not portals[neighbor.id] then
				err(`{island.id}: no Portal to {neighbor.id}`)
			end
		end
	end

	if raidPortals == 0 then
		err("No RaidPortal (it goes on the first island)")
	end
	if lobbySpawns ~= 1 then
		err(`Raid lobby needs exactly one RaidLobbySpawn (found {lobbySpawns})`)
	end
	if shops ~= 1 then
		err(`Raid lobby needs exactly one BoostShop (found {shops})`)
	end
	for _, difficulty in Raids.Difficulties do
		local pads = padsByDifficulty[difficulty.id] or 0
		if pads ~= 1 then
			err(`Raid lobby needs exactly one RaidPad for {difficulty.id} (found {pads})`)
		end
	end
	local lobbyPortals = portalsByArea.RaidLobby or {}
	if not lobbyPortals[Islands.List[1].id] then
		err(`RaidLobby: no Portal back to {Islands.List[1].id}`)
	end

	if partCounts then
		for area, count in partCounts do
			if count > MapCheck.PartBudget then
				table.insert(warnings, `{area}: {count} parts, over the budget of {MapCheck.PartBudget}`)
			end
		end
	end

	table.sort(errors)
	table.sort(warnings)
	return { errors = errors, warnings = warnings }
end

return MapCheck
