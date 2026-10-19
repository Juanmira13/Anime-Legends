--!strict
-- Studio-only test setup: when the place has no enemy spawn points yet, builds
-- a row of Nameku spawn points near the origin so combat can be tried right away.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SPAWN_TAG = "EnemySpawn"

-- Spawn points per rank, laid out along the X axis in front of the default spawn.
local LAYOUT = {
	{ rank = "Easy", count = 3 },
	{ rank = "Medium", count = 2 },
	{ rank = "Hard", count = 1 },
	{ rank = "Boss", count = 1 },
}
local SPACING = 14
local DISTANCE = 30

local TestArena = {}

function TestArena.buildIfNeeded()
	if not RunService:IsStudio() or #CollectionService:GetTagged(SPAWN_TAG) > 0 then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "TestArena"

	local total = 0
	for _, entry in LAYOUT do
		total += entry.count
	end

	local index = 0
	for _, entry in LAYOUT do
		for _ = 1, entry.count do
			local spawnPoint = Instance.new("Part")
			spawnPoint.Name = `Spawn_{entry.rank}`
			spawnPoint.Size = Vector3.new(4, 1, 4)
			spawnPoint.Position = Vector3.new((index - (total - 1) / 2) * SPACING, 0.5, -DISTANCE)
			spawnPoint.Anchored = true
			spawnPoint.CanCollide = false
			spawnPoint.Transparency = 1
			spawnPoint:SetAttribute("Island", "Nameku")
			spawnPoint:SetAttribute("Rank", entry.rank)
			spawnPoint.Parent = folder
			CollectionService:AddTag(spawnPoint, SPAWN_TAG)
			index += 1
		end
	end

	folder.Parent = workspace
	print(`[TestArena] No enemy spawn points found; built {total} test spawns for Nameku.`)
end

return TestArena
