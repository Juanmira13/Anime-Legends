--!strict
-- Raid UI: lobby pad prompts (Entrar / Salir / cooldown), a status bar for the
-- queue and the running raid, and messages for raid events.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local Raids = require(Shared.Config.Raids)
local UI = script.Parent.Parent.UI
local Notify = require(UI.Notify)
local Theme = require(UI.Theme)

local PAD_TAG = "RaidPad"

local player = Players.LocalPlayer
local pads: { [ProximityPrompt]: string } = {} -- prompt -> difficulty id

local RaidController = {}

local statusLabel: TextLabel

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

local function difficultyName(id: string): string
	return Raids.getDifficulty(id).displayName
end

local function updatePads(serverNow: number)
	local queued = player:GetAttribute("RaidQueue")
	for prompt, difficultyId in pads do
		local readyAt = tonumber(player:GetAttribute(`RaidReady_{difficultyId}`)) or 0
		if queued == difficultyId then
			prompt.ActionText = "Salir de la fila"
		elseif serverNow < readyAt then
			prompt.ActionText = `Disponible en {clock(readyAt - serverNow)}`
		else
			prompt.ActionText = "Entrar"
		end
	end
end

local function updateStatus(serverNow: number)
	local difficulty = player:GetAttribute("RaidDifficulty")
	local queued = player:GetAttribute("RaidQueue")
	if type(difficulty) == "string" then
		local wave = player:GetAttribute("RaidWave") or 0
		local endsAt = tonumber(player:GetAttribute("RaidEndsAt")) or serverNow
		statusLabel.Text =
			`Raid {difficultyName(difficulty)}  ·  Oleada {wave}/{Raids.WaveCount}  ·  {clock(endsAt - serverNow)}`
		statusLabel.Visible = true
	elseif type(queued) == "string" then
		local startsAt = tonumber(player:GetAttribute("RaidQueueStartsAt")) or serverNow
		statusLabel.Text = `En fila: Raid {difficultyName(queued)}  ·  empieza en {clock(startsAt - serverNow)}`
		statusLabel.Visible = true
	else
		statusLabel.Visible = false
	end
end

local function trackPad(pad: Instance)
	local difficultyId = pad:GetAttribute("Difficulty")
	if type(difficultyId) ~= "string" or not (pcall(Raids.getDifficulty, difficultyId)) then
		return
	end
	local prompt = pad:WaitForChild("ProximityPrompt", 10)
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		return
	end
	pads[prompt] = difficultyId
	prompt.Destroying:Connect(function()
		pads[prompt] = nil
	end)
end

local function onEvent(event: any)
	local kind = event.kind
	if kind == "Queued" then
		Notify.show(`Entraste a la fila del Raid {difficultyName(event.difficulty)}`, Theme.Accent)
	elseif kind == "LeftQueue" then
		Notify.show("Saliste de la fila", Theme.MutedText)
	elseif kind == "Cooldown" then
		local wait = (tonumber(event.readyAt) or 0) - workspace:GetServerTimeNow()
		Notify.error(`Raid {difficultyName(event.difficulty)} disponible en {clock(wait)}`)
	elseif kind == "Full" then
		Notify.error("Este Raid está lleno")
	elseif kind == "Started" then
		Notify.show(`¡Comienza el Raid {difficultyName(event.difficulty)}!`, Theme.Accent)
	elseif kind == "Wave" then
		if event.wave == 10 then
			Notify.show("¡Oleada 10: Mini jefe!", Theme.rarityColor("Mythic"))
		elseif event.wave == Raids.WaveCount then
			Notify.show(`¡Oleada {Raids.WaveCount}: Jefe final!`, Theme.rarityColor("Epic"))
		end
	elseif kind == "BoostDrop" then
		Notify.show(`Obtuviste un Boost de {Boosts.get(event.boost).displayName}`, Color3.fromRGB(120, 220, 255))
	elseif kind == "Achievement" then
		Notify.show(
			`¡Nueva ranura! Ahora puedes equipar {event.equipSlots} personajes`,
			Theme.rarityColor("Legendary")
		)
	elseif kind == "Completed" then
		Notify.show("¡Raid completado!", Theme.rarityColor("Uncommon"))
	elseif kind == "Failed" then
		Notify.error("Raid fallido")
	elseif kind == "Left" then
		Notify.show("Abandonaste el Raid", Theme.MutedText)
	end
end

local function createStatus()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RaidStatus"
	gui.ResetOnSpawn = false

	statusLabel = Theme.label({ size = UDim2.fromOffset(460, 34), position = UDim2.new(0.5, 0, 0, 12) })
	statusLabel.AnchorPoint = Vector2.new(0.5, 0)
	statusLabel.BackgroundColor3 = Theme.Background
	statusLabel.BackgroundTransparency = 0.2
	statusLabel.Visible = false
	statusLabel.Parent = gui
	Theme.corner(statusLabel)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = statusLabel

	gui.Parent = player:WaitForChild("PlayerGui")
end

function RaidController.start()
	createStatus()

	CollectionService:GetInstanceAddedSignal(PAD_TAG):Connect(function(pad)
		task.spawn(trackPad, pad)
	end)
	for _, pad in CollectionService:GetTagged(PAD_TAG) do
		task.spawn(trackPad, pad)
	end

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RaidEvent") :: RemoteEvent
	remote.OnClientEvent:Connect(onEvent)

	-- Countdowns tick every second.
	task.spawn(function()
		while true do
			local serverNow = workspace:GetServerTimeNow()
			updatePads(serverNow)
			updateStatus(serverNow)
			task.wait(0.5)
		end
	end)
end

return RaidController
