--!strict
-- Studio-only test setup. When the place has no enemy spawn points or gacha
-- stands yet, builds Nameku ones near the origin so they can be tried right away.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local SPAWN_TAG = "EnemySpawn"
local STAND_TAG = "GachaStand"

-- Spawn points per rank, laid out along the X axis in front of the default spawn.
local LAYOUT = {
	{ rank = "Easy", count = 3 },
	{ rank = "Medium", count = 2 },
	{ rank = "Hard", count = 1 },
	{ rank = "Boss", count = 1 },
}
local SPACING = 14
local DISTANCE = 30
local STAND_POSITION = Vector3.new(20, 3, 0)

local TestArena = {}

local function getFolder(): Folder
	local existing = workspace:FindFirstChild("TestArena")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "TestArena"
	folder.Parent = workspace
	return folder
end

local function buildSpawns(folder: Folder)
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
	print(`[TestArena] No enemy spawn points found; built {total} test spawns for Nameku.`)
end

local function buildStand(folder: Folder)
	local stand = Instance.new("Part")
	stand.Name = "GachaStand_Nameku"
	stand.Shape = Enum.PartType.Ball
	stand.Size = Vector3.one * 5
	stand.Position = STAND_POSITION
	stand.Color = Color3.fromRGB(255, 200, 60)
	stand.Material = Enum.Material.Neon
	stand.Anchored = true
	stand:SetAttribute("Island", "Nameku")
	stand.Parent = folder
	CollectionService:AddTag(stand, STAND_TAG)
	print("[TestArena] No gacha stands found; built a test stand for Nameku.")
end

function TestArena.buildIfNeeded()
	if not RunService:IsStudio() then
		return
	end
	if #CollectionService:GetTagged(SPAWN_TAG) == 0 then
		buildSpawns(getFolder())
	end
	if #CollectionService:GetTagged(STAND_TAG) == 0 then
		buildStand(getFolder())
	end
end

return TestArena
