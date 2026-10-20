--!strict
-- Collects the tagged map parts and part counts that MapCheck validates.
-- Areas are the folders under Workspace.Map (island ids and "RaidLobby").

local CollectionService = game:GetService("CollectionService")

local MapCheck = require(script.Parent.MapCheck)

local TAGS = { "IslandSpawn", "EnemySpawn", "GachaStand", "Portal", "RaidPortal", "RaidLobbySpawn", "RaidPad" }

local MapScan = {}

local function areaOf(instance: Instance, map: Instance?): string?
	if map == nil then
		return nil
	end
	local node: Instance? = instance
	while node and node.Parent ~= map do
		node = node.Parent
	end
	return node and node.Name
end

function MapScan.collect(): ({ MapCheck.Entry }, { [string]: number })
	local map = workspace:FindFirstChild("Map")
	local entries: { MapCheck.Entry } = {}
	for _, tag in TAGS do
		for _, instance in CollectionService:GetTagged(tag) do
			if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
				table.insert(entries, {
					tag = tag,
					name = instance:GetFullName(),
					area = areaOf(instance, map),
					attributes = instance:GetAttributes(),
				})
			end
		end
	end
	local partCounts: { [string]: number } = {}
	if map then
		for _, area in map:GetChildren() do
			local count = 0
			for _, descendant in area:GetDescendants() do
				if descendant:IsA("BasePart") then
					count += 1
				end
			end
			partCounts[area.Name] = count
		end
	end
	return entries, partCounts
end

-- Runs the checks and prints the report. Returns whether there were no errors.
function MapScan.validate(prefix: string): boolean
	local entries, partCounts = MapScan.collect()
	local report = MapCheck.run(entries, partCounts)
	for _, message in report.errors do
		warn(`{prefix} {message}`)
	end
	for _, message in report.warnings do
		warn(`{prefix} (aviso) {message}`)
	end
	if #report.errors == 0 then
		print(`{prefix} Map OK: {#entries} tagged parts, {#report.warnings} warnings`)
	end
	return #report.errors == 0
end

return MapScan
