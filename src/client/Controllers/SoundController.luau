--!strict
-- Sound effects and music from Config.Sounds. Effects play on the screen (2D)
-- or at a world position (3D, `playAt`), limited per effect and in total so a
-- crowd of hits never gets loud (SoundMix). Music loops one track per area
-- (attribute "CurrentArea"; the raid switches to RaidBoss on its final wave)
-- and cross-fades when it changes. The player's options ("SettingMusic",
-- "SettingEffects") mute each group. Entries with an empty id stay silent.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ambience = require(Shared.Config.Ambience)
local Raids = require(Shared.Config.Raids)
local Sounds = require(Shared.Config.Sounds)

local SoundMix = require(script.Parent.Parent.Effects.SoundMix)

local SPATIAL_MIN_DISTANCE = 12 -- studs at full volume
local FAILSAFE_LIFETIME = 10 -- seconds: frees a sound that never ends (bad id)

export type Options = {
	pitch: number?,
	volume: number?, -- multiplies the configured volume
}

type Playing = { sound: Sound, volume: number, born: number }

local player = Players.LocalPlayer
local limits = SoundMix.newLimits()
local coinChain = 0
local lastCoin: number? = nil

local effectsGroup = Instance.new("SoundGroup")
effectsGroup.Name = "Effects"
effectsGroup.Parent = SoundService
local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "Music"
musicGroup.Parent = SoundService

local currentKey: string? = nil
local currentTrack: Playing? = nil
local fadingTracks: { Playing } = {}

local SoundController = {}

local function start(name: string, parent: Instance, options: Options?): Sound?
	local effect = Sounds.Effects[name]
	if effect == nil then
		warn(`[Sound] unknown effect {name}`)
		return nil
	end
	if effect.id == "" or effectsGroup.Volume == 0 then
		return nil
	end
	if not SoundMix.tryStart(limits, name, os.clock(), effect.maxAtOnce, effect.minGap, Sounds.MaxEffects) then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = effect.id
	sound.Volume = effect.volume * (if options and options.volume then options.volume else 1)
	sound.PlaybackSpeed = if options and options.pitch then options.pitch else 1
	sound.SoundGroup = effectsGroup
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = SPATIAL_MIN_DISTANCE
	sound.RollOffMaxDistance = Sounds.SpatialRange
	sound.Parent = parent

	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		SoundMix.finished(limits, name)
		if parent:IsA("Attachment") then
			parent:Destroy()
		else
			sound:Destroy()
		end
	end
	sound.Ended:Connect(finish)
	task.delay(FAILSAFE_LIFETIME, finish)
	sound:Play()
	return sound
end

-- Plays an effect on the screen (2D).
function SoundController.play(name: string, options: Options?)
	start(name, SoundService, options)
end

-- Plays an effect at a world position (3D); skipped when out of hearing range.
function SoundController.playAt(name: string, position: Vector3, options: Options?)
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - position).Magnitude > Sounds.SpatialRange then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "SoundAt"
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	if start(name, attachment, options) == nil then
		attachment:Destroy()
	end
end

-- A coin pickup: the pitch climbs while pickups follow each other closely.
function SoundController.coin()
	local now = os.clock()
	coinChain = SoundMix.chainAfter(coinChain, lastCoin, now)
	lastCoin = now
	SoundController.play("CoinPickup", { pitch = SoundMix.coinPitch(coinChain) })
end

local function musicKey(): string
	local area = player:GetAttribute("CurrentArea")
	local wave = player:GetAttribute("RaidWave")
	return SoundMix.musicKey(
		if type(area) == "string" then area else Ambience.DefaultArea,
		if type(wave) == "number" then wave else nil,
		Raids.WaveCount
	)
end

local function updateMusic()
	local key = musicKey()
	if key == currentKey then
		return
	end
	currentKey = key
	if currentTrack then
		currentTrack.born = os.clock()
		table.insert(fadingTracks, currentTrack)
		currentTrack = nil
	end
	local track = Sounds.Music[key]
	if track == nil or track.id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = `Music_{key}`
	sound.SoundId = track.id
	sound.Looped = true
	sound.Volume = 0
	sound.SoundGroup = musicGroup
	sound.Parent = SoundService
	sound:Play()
	currentTrack = { sound = sound, volume = track.volume, born = os.clock() }
end

local function stepMusic()
	local now = os.clock()
	if currentTrack then
		local _, incoming = SoundMix.fade(now - currentTrack.born, Sounds.MusicFade)
		currentTrack.sound.Volume = currentTrack.volume * incoming
	end
	for index = #fadingTracks, 1, -1 do
		local track = fadingTracks[index]
		local outgoing = SoundMix.fade(now - track.born, Sounds.MusicFade)
		-- Fade out from wherever it was (it may not have finished fading in).
		track.sound.Volume = math.min(track.sound.Volume, track.volume * outgoing)
		if outgoing <= 0 then
			track.sound:Destroy()
			table.remove(fadingTracks, index)
		end
	end
end

local function applySettings()
	musicGroup.Volume = if player:GetAttribute("SettingMusic") == false then 0 else 1
	effectsGroup.Volume = if player:GetAttribute("SettingEffects") == false then 0 else 1
end

local function preload()
	local toLoad = {}
	for name, effect in Sounds.Effects do
		if effect.id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = effect.id
			table.insert(toLoad, sound)
		end
	end
	if #toLoad > 0 then
		ContentProvider:PreloadAsync(toLoad)
	end
end

function SoundController.start()
	applySettings()
	player:GetAttributeChangedSignal("SettingMusic"):Connect(applySettings)
	player:GetAttributeChangedSignal("SettingEffects"):Connect(applySettings)

	updateMusic()
	local lastArea = player:GetAttribute("CurrentArea")
	player:GetAttributeChangedSignal("CurrentArea"):Connect(function()
		-- Not on the first area set when joining.
		if lastArea ~= nil then
			SoundController.play("Travel")
		end
		lastArea = player:GetAttribute("CurrentArea")
		updateMusic()
	end)
	player:GetAttributeChangedSignal("RaidWave"):Connect(updateMusic)
	RunService.Heartbeat:Connect(stepMusic)
	task.spawn(preload)
end

return SoundController
