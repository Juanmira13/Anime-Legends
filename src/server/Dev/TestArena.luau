--!strict
-- Studio-only test world. When the place has no island arrival points yet,
-- builds the first two islands side by side on the baseplate, each with an
-- arrival point, enemy spawns, a gacha stand and portals between them, plus a
-- raid portal on the first island and the raid lobby.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GachaStar = require(Shared.Map.GachaStar)
local Islands = require(Shared.Data.Islands)

local ISLAND_SPAWN_TAG = "IslandSpawn"

-- Islands to build and where; the next island in the list is the portal target.
local LAYOUT = {
	{ island = "Nameku", origin = Vector3.new(0, 0, 0), color = Color3.fromRGB(120, 200, 120) },
	{ island = "Kono", origin = Vector3.new(400, 0, 0), color = Color3.fromRGB(255, 150, 60) },
}

-- Enemy spawn points per rank, laid out in a row in front of the arrival point.
local ENEMIES = {
	{ rank = "Easy", count = 3 },
	{ rank = "Medium", count = 2 },
	{ rank = "Hard", count = 1 },
	{ rank = "Boss", count = 1 },
}
local ENEMY_SPACING = 14
local ENEMY_DISTANCE = 30

local RAID_COLOR = Color3.fromRGB(170, 80, 255)
local RAID_LOBBY_ORIGIN = Vector3.new(-400, 0, 0)
local RAID_PADS = {
	{ difficulty = "Easy", color = Color3.fromRGB(110, 200, 110) },
	{ difficulty = "Medium", color = Color3.fromRGB(230, 200, 80) },
	{ difficulty = "Hard", color = Color3.fromRGB(220, 60, 60) },
}

local TestArena = {}

local function tagged(part: BasePart, tag: string, attributes: { [string]: any }, parent: Instance): BasePart
	for name, value in attributes do
		part:SetAttribute(name, value)
	end
	part.Anchored = true
	part.Parent = parent
	CollectionService:AddTag(part, tag)
	return part
end

local function marker(name: string, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(4, 1, 4)
	part.Position = position
	part.CanCollide = false
	part.Transparency = 1
	return part
end

local function buildEnemies(islandId: string, origin: Vector3, parent: Instance)
	local total = 0
	for _, entry in ENEMIES do
		total += entry.count
	end
	local index = 0
	for _, entry in ENEMIES do
		for _ = 1, entry.count do
			local offset = Vector3.new((index - (total - 1) / 2) * ENEMY_SPACING, 0.5, -ENEMY_DISTANCE)
			tagged(
				marker(`Spawn_{entry.rank}`, origin + offset),
				"EnemySpawn",
				{ Island = islandId, Rank = entry.rank },
				parent
			)
			index += 1
		end
	end
end

local function buildGacha(islandId: string, origin: Vector3, color: Color3, parent: Instance)
	local star, stand = GachaStar.build(CFrame.new(origin + Vector3.new(20, 4.5, 0)), 3, color, parent)
	stand.Name = `GachaStand_{islandId}`
	tagged(stand, "GachaStand", { Island = islandId }, star)
end

-- A portal is a pad on the ground (holds the prompt) under a column of light.
local function buildPortal(
	name: string,
	tag: string,
	attributes: { [string]: any },
	position: Vector3,
	color: Color3,
	parent: Instance
)
	local pad = Instance.new("Part")
	pad.Name = name
	pad.Shape = Enum.PartType.Cylinder
	pad.Size = Vector3.new(1, 10, 10)
	pad.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pad.Color = color
	pad.Material = Enum.Material.Neon
	tagged(pad, tag, attributes, parent)

	local beam = Instance.new("Part")
	beam.Name = "LightBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(40, 7, 7)
	beam.CFrame = CFrame.new(position + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Color = color
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.45
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Parent = pad

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 20
	light.Brightness = 3
	light.Parent = beam
end

local function buildIsland(index: number, folder: Folder)
	local entry = LAYOUT[index]
	local islandFolder = Instance.new("Folder")
	islandFolder.Name = entry.island
	islandFolder.Parent = folder

	tagged(
		marker("Arrival", entry.origin + Vector3.new(0, 0.5, 8)),
		ISLAND_SPAWN_TAG,
		{ Island = entry.island },
		islandFolder
	)
	buildEnemies(entry.island, entry.origin, islandFolder)
	buildGacha(entry.island, entry.origin, entry.color, islandFolder)

	local function islandPortal(target, offset: Vector3)
		buildPortal(
			`Portal_{target.island}`,
			"Portal",
			{ TargetIsland = target.island },
			entry.origin + offset,
			target.color,
			islandFolder
		)
	end
	local nextEntry = LAYOUT[index + 1]
	if nextEntry then
		islandPortal(nextEntry, Vector3.new(-20, 0, 0))
	end
	local previousEntry = LAYOUT[index - 1]
	if previousEntry then
		islandPortal(previousEntry, Vector3.new(-20, 0, 14))
	end
	if index == 1 then
		buildPortal("RaidPortal", "RaidPortal", {}, entry.origin + Vector3.new(-20, 0, -14), RAID_COLOR, islandFolder)
	end
end

-- Raid lobby: arrival point, one pad per difficulty, the boost shop NPC and a
-- portal back to the first island.
local function buildRaidLobby(folder: Folder)
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "RaidLobby"
	lobbyFolder.Parent = folder

	tagged(marker("Arrival", RAID_LOBBY_ORIGIN + Vector3.new(0, 0.5, 12)), "RaidLobbySpawn", {}, lobbyFolder)
	for index, pad in RAID_PADS do
		local part = Instance.new("Part")
		part.Name = `RaidPad_{pad.difficulty}`
		part.Size = Vector3.new(10, 1, 10)
		part.Position = RAID_LOBBY_ORIGIN + Vector3.new((index - 2) * 18, 0.5, -10)
		part.Color = pad.color
		part.Material = Enum.Material.Neon
		tagged(part, "RaidPad", { Difficulty = pad.difficulty }, lobbyFolder)
	end
	local shop = Instance.new("Part")
	shop.Name = "BoostShop"
	shop.Size = Vector3.new(3, 5, 2)
	shop.Position = RAID_LOBBY_ORIGIN + Vector3.new(28, 2.5, 12)
	shop.Color = Color3.fromRGB(130, 75, 215)
	tagged(shop, "BoostShop", {}, lobbyFolder)
	local first = LAYOUT[1]
	buildPortal(
		`Portal_{first.island}`,
		"Portal",
		{ TargetIsland = first.island },
		RAID_LOBBY_ORIGIN + Vector3.new(-30, 0, 12),
		first.color,
		lobbyFolder
	)
end

function TestArena.buildIfNeeded()
	if not RunService:IsStudio() or #CollectionService:GetTagged(ISLAND_SPAWN_TAG) > 0 then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "TestArena"
	folder.Parent = workspace
	for index in LAYOUT do
		buildIsland(index, folder)
	end
	buildRaidLobby(folder)
	local names = {}
	for _, entry in LAYOUT do
		table.insert(names, Islands.get(entry.island).displayName)
	end
	print(`[TestArena] No islands found; built a test world: {table.concat(names, ", ")} and the raid lobby.`)
end

return TestArena
