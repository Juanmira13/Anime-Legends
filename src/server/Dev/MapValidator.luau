--!strict
-- Studio-only: checks the built map (Workspace.Map) on server start and prints
-- what is missing or wrong, so map edits never silently break a system.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapScan = require(ReplicatedStorage:WaitForChild("Shared").Map.MapScan)

local MapValidator = {}

function MapValidator.runInStudio()
	if not RunService:IsStudio() or workspace:FindFirstChild("Map") == nil then
		return -- the test world (TestArena) is not a full map
	end
	MapScan.validate("[MapValidator]")
end

return MapValidator
