--!strict
-- Finds a character or enemy model by path (e.g. { "Nameku", "Krilin" }). An
-- imported avatar wins over the Rojo-synced placeholder: imported avatars are
-- inserted in Studio from file (Rojo cannot sync their meshes) into folders
-- Rojo never touches, ReplicatedStorage.ImportedCharacters and
-- ServerStorage.ImportedEnemies (see tools/import_avatars.py).
--
-- A model whose PrimaryPart reference was lost (live sync and file inserts do
-- not always keep Ref properties) gets its HumanoidRootPart as PrimaryPart.
-- When nothing is found, the reason of each root is warned once per path, so
-- the Output shows why a placeholder block is used.

local ModelLookup = {}

local warned: { [string]: boolean } = {}

-- The model at `path` under `root`, with a PrimaryPart, or nil and why not.
local function lookIn(root: Instance?, rootName: string, path: { string }): (Model?, string)
	if root == nil then
		return nil, `{rootName} does not exist`
	end
	local node: Instance = root
	for _, name in path do
		local child = node:FindFirstChild(name)
		if child == nil then
			return nil, `{node:GetFullName()} has no "{name}"`
		end
		node = child
	end
	if not node:IsA("Model") then
		return nil, `{node:GetFullName()} is a {node.ClassName}, not a Model`
	end
	if node.PrimaryPart == nil then
		local rootPart = node:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			node.PrimaryPart = rootPart
		else
			return nil, `{node:GetFullName()} has no PrimaryPart nor HumanoidRootPart`
		end
	end
	return node, ""
end

-- The first model at `path` under `roots` (pairs of root and its name, in order).
function ModelLookup.find(roots: { { root: Instance?, name: string } }, path: { string }): Model?
	local reasons = {}
	for _, entry in roots do
		local model, reason = lookIn(entry.root, entry.name, path)
		if model then
			return model
		end
		table.insert(reasons, reason)
	end
	local key = table.concat(path, ".")
	if not warned[key] then
		warned[key] = true
		warn(`[ModelLookup] No model for {key}, using a placeholder: {table.concat(reasons, "; ")}`)
	end
	return nil
end

return ModelLookup
