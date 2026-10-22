--!strict
-- Shows each portal's prompt as "Viajar" or "Desbloquear (cost ¥)" for the
-- local player, and reports portal results. Unlocked islands come from the
-- player attributes "Unlocked_<IslandId>" set by the server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Islands = require(Shared.Data.Islands)
local UI = script.Parent.Parent.UI
local Notify = require(UI.Notify)
local Theme = require(UI.Theme)
local SoundController = require(script.Parent.SoundController)

local PORTAL_TAG = "Portal"

local player = Players.LocalPlayer
local prompts: { [ProximityPrompt]: string } = {} -- prompt -> target island id

local PortalController = {}

local function isUnlocked(islandId: string): boolean
	return player:GetAttribute(`Unlocked_{islandId}`) == true
end

local function updatePrompt(prompt: ProximityPrompt, islandId: string)
	prompt.ActionText = if isUnlocked(islandId)
		then "Viajar"
		else `Desbloquear ({Format.number(Formulas.portalCost(islandId))} ¥)`
end

local function updateAll()
	for prompt, islandId in prompts do
		updatePrompt(prompt, islandId)
	end
end

local function track(portal: Instance)
	local islandId = portal:GetAttribute("TargetIsland")
	if type(islandId) ~= "string" or not (pcall(Islands.get, islandId)) then
		return
	end
	local prompt = portal:WaitForChild("ProximityPrompt", 10)
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		return
	end
	prompts[prompt] = islandId
	updatePrompt(prompt, islandId)
	prompt.Destroying:Connect(function()
		prompts[prompt] = nil
	end)
end

local function onResult(result: any)
	local island = if type(result.island) == "string" then Islands.get(result.island) else nil
	if result.unlocked and island then
		Notify.show(`¡Desbloqueaste {island.displayName}!`, Theme.Accent)
		SoundController.play("PortalUnlock")
	elseif result.ok then
		return
	elseif result.reason == "NotEnoughYen" then
		Notify.error("No tienes suficientes Yenes")
	elseif result.reason == "PreviousLocked" and island then
		local previous = Islands.getPrevious(island.id)
		Notify.error(`Primero desbloquea {if previous then previous.displayName else "la isla anterior"}`)
	end
end

function PortalController.start()
	CollectionService:GetInstanceAddedSignal(PORTAL_TAG):Connect(function(portal)
		task.spawn(track, portal)
	end)
	for _, portal in CollectionService:GetTagged(PORTAL_TAG) do
		task.spawn(track, portal)
	end
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 9) == "Unlocked_" then
			updateAll()
		end
	end)

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PortalResult") :: RemoteEvent
	remote.OnClientEvent:Connect(onResult)
end

return PortalController
