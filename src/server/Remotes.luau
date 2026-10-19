--!strict
-- Creates the RemoteEvents the client listens to, under ReplicatedStorage.Remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function getFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
	return folder
end

local folder = getFolder()

local Remotes = {}

function Remotes.event(name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

return Remotes
