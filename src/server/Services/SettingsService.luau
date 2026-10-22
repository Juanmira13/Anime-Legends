--!strict
-- Player options (music and effects on or off), saved in Data.Settings.
-- Clients call Remotes.SetSetting(name, value); each option is replicated as
-- the player attribute "Setting<Name>" (boolean).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage:WaitForChild("Shared").Config.Sounds)

local Server = script.Parent.Parent
local Remotes = require(Server.Remotes)
local SettingsOps = require(Server.Settings.SettingsOps)
local DataService = require(script.Parent.DataService)

type Data = DataService.Data

local MIN_TIME_BETWEEN_CHANGES = 0.2

local setRemote = Remotes.event("SetSetting")
local lastChange: { [Player]: number } = {}

local SettingsService = {}

local function replicate(player: Player, data: Data)
	for _, name in Sounds.Settings do
		player:SetAttribute(`Setting{name}`, SettingsOps.get(data, name))
	end
end

local function onSet(player: Player, name: unknown, value: unknown)
	local now = time()
	if now - (lastChange[player] or -math.huge) < MIN_TIME_BETWEEN_CHANGES then
		return
	end
	lastChange[player] = now
	local data = DataService.getData(player)
	if data and SettingsOps.set(data, name, value) then
		replicate(player, data)
	end
end

function SettingsService.start()
	setRemote.OnServerEvent:Connect(onSet)
	DataService.Loaded:Connect(replicate)
	Players.PlayerRemoving:Connect(function(player)
		lastChange[player] = nil
	end)
end

return SettingsService
