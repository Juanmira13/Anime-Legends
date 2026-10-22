--!strict
-- Pure logic for the player's options (Data.Settings): only the names listed
-- in Config.Sounds.Settings, only booleans.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage:WaitForChild("Shared").Config.Sounds)

local SettingsOps = {}

function SettingsOps.isKnown(name: unknown): boolean
	return type(name) == "string" and table.find(Sounds.Settings, name) ~= nil
end

-- Current value of an option; missing options are on.
function SettingsOps.get(data: { Settings: { [string]: boolean } }, name: string): boolean
	return data.Settings[name] ~= false
end

-- Sets an option. Returns false for unknown names or non-boolean values.
function SettingsOps.set(data: { Settings: { [string]: boolean } }, name: unknown, value: unknown): boolean
	if not SettingsOps.isKnown(name) or type(value) ~= "boolean" then
		return false
	end
	data.Settings[name :: string] = value
	return true
end

return SettingsOps
