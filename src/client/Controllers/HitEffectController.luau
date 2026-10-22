--!strict
-- Damage numbers and hit effects, from Remotes.CharacterHit (owner, enemyId,
-- hits). When a character's lunge connects (FollowerMotion.LUNGE_IN_TIME after
-- the hit), its damage pops over the enemy in the color of that character's
-- rarity, rises and fades, with a flash and sparks at the impact. The local
-- player's hits are big; other players' hits are smaller, fainter and only
-- shown nearby (limits in HitStyle). An enemy that dies bursts in a puff of
-- smoke, each with its sound. Purely visual: damage is decided by the server.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Data.Characters)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Format)

local Client = script.Parent.Parent
local FollowerMotion = require(Client.Followers.FollowerMotion)
local HitStyle = require(Client.Effects.HitStyle)
local SoundMix = require(Client.Effects.SoundMix)
local SoundController = require(script.Parent.SoundController)
local Theme = require(Client.UI.Theme)

local ENEMY_TAG = "Enemy"
local NUMBER_ASPECT = 3 -- width over height of a number's box
local STROKE = Color3.new(0, 0, 0)
local SECRET_TEXT = Color3.new(1, 1, 1) -- the Secret rarity color is near black
local SECRET_STROKE = Color3.fromRGB(255, 200, 60)
local IMPACT_SPREAD = 1.5 -- studs of random offset around the enemy's center
local SPARK_COUNT = 6
local POOF_COUNT = 14

type DamageNumber = {
	attachment: Attachment,
	gui: BillboardGui,
	label: TextLabel,
	stroke: UIStroke,
	base: Vector3,
	height: number,
	transparency: number,
	own: boolean,
	born: number,
}

type Flash = {
	part: Part,
	born: number,
	sizeScale: number,
}

type EnemyShape = {
	center: Vector3,
	top: Vector3,
	size: number,
}

local player = Players.LocalPlayer
local random = Random.new()
local shapes: { [string]: EnemyShape } = {} -- by EnemyId, measured when the enemy appears
local hitCounts: { [string]: number } = {} -- by EnemyId, to spread consecutive numbers
local numbers: { DamageNumber } = {}
local flashes: { Flash } = {}
local folder: Folder
local emitterAttachment: Attachment
local sparks: ParticleEmitter
local smoke: ParticleEmitter

local HitEffectController = {}

local function rarityOf(owner: Player, slot: number): string?
	local ids = owner:GetAttribute("EquippedCharacters")
	if type(ids) ~= "string" then
		return nil
	end
	local characterId = string.split(ids, ",")[slot]
	local ok, character = pcall(Characters.get, characterId)
	return if ok then character.rarity else nil
end

local function measure(model: Model): EnemyShape
	local boxCFrame, boxSize = model:GetBoundingBox()
	return {
		center = boxCFrame.Position,
		top = boxCFrame.Position + Vector3.new(0, boxSize.Y / 2, 0),
		size = math.max(boxSize.X, boxSize.Y, boxSize.Z),
	}
end

local function emitAt(emitter: ParticleEmitter, position: Vector3, color: Color3, count: number)
	emitterAttachment.WorldPosition = position
	emitter.Color = ColorSequence.new(color)
	emitter:Emit(count)
end

local function addFlash(position: Vector3, color: Color3, sizeScale: number)
	local part = Instance.new("Part")
	part.Name = "HitFlash"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = Vector3.one * HitStyle.FLASH_SIZE[1] * sizeScale
	part.Position = position
	part.Parent = folder
	table.insert(flashes, { part = part, born = os.clock(), sizeScale = sizeScale })
end

local function addNumber(position: Vector3, damage: number, rarityId: string?, own: boolean)
	local height, transparency = HitStyle.size(own, rarityId)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(height * NUMBER_ASPECT, height)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = HitStyle.OWN_DISTANCE
	gui.Parent = attachment

	local isSecret = rarityId == "Secret"
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = Format.number(damage)
	label.TextColor3 = if isSecret then SECRET_TEXT elseif rarityId then Theme.rarityColor(rarityId) else Theme.Text
	label.TextTransparency = transparency
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = if isSecret then SECRET_STROKE else STROKE
	stroke.Thickness = if own then 2.5 else 1.5
	stroke.Transparency = transparency
	stroke.Parent = label

	table.insert(numbers, {
		attachment = attachment,
		gui = gui,
		label = label,
		stroke = stroke,
		base = position,
		height = height,
		transparency = transparency,
		own = own,
		born = os.clock(),
	})
end

local function countNumbers(): (number, number)
	local others = 0
	for _, number in numbers do
		if not number.own then
			others += 1
		end
	end
	return #numbers, others
end

local function showHit(shape: EnemyShape, enemyId: string, damage: number, rarityId: string?, own: boolean)
	local camera = workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - shape.center).Magnitude else 0
	local color = if rarityId and rarityId ~= "Secret" then Theme.rarityColor(rarityId) else SECRET_STROKE
	local impact = shape.center
		+ Vector3.new(
			random:NextNumber(-IMPACT_SPREAD, IMPACT_SPREAD),
			random:NextNumber(-IMPACT_SPREAD, IMPACT_SPREAD),
			random:NextNumber(-IMPACT_SPREAD, IMPACT_SPREAD)
		)
	if own or distance <= HitStyle.OTHER_DISTANCE then
		addFlash(impact, color, if own then 1 else HitStyle.OTHER_SCALE)
		emitAt(sparks, impact, color, if own then SPARK_COUNT else SPARK_COUNT // 2)
		local order = if rarityId then Rarities.get(rarityId).order else 1
		SoundController.playAt("Hit", impact, { pitch = SoundMix.hitPitch(order), volume = SoundMix.hitVolume(own) })
	end

	local active, activeOthers = countNumbers()
	if not HitStyle.shouldShow(own, distance, active, activeOthers) then
		return
	end
	local index = (hitCounts[enemyId] or 0) + 1
	hitCounts[enemyId] = index
	local offset = Vector3.new(HitStyle.jitter(index), 1, 0)
	if camera then
		-- Spread along the camera's right, so the jitter is always sideways on screen.
		offset = camera.CFrame.RightVector * HitStyle.jitter(index) + Vector3.new(0, 1, 0)
	end
	addNumber(shape.top + offset, damage, rarityId, own)
end

local function onHit(owner: Player, enemyId: string, hits: { { slot: number, damage: number } })
	local shape = shapes[enemyId]
	if shape == nil or type(hits) ~= "table" then
		return
	end
	local own = owner == player
	for _, hit in hits do
		local rarityId = rarityOf(owner, hit.slot)
		-- Show it when the lunge reaches the enemy (the shape is kept even if this hit killed it).
		task.delay(FollowerMotion.LUNGE_IN_TIME, showHit, shape, enemyId, hit.damage, rarityId, own)
	end
end

local function step()
	local now = os.clock()
	for index = #numbers, 1, -1 do
		local number = numbers[index]
		local age = now - number.born
		if age >= HitStyle.LIFETIME then
			number.attachment:Destroy()
			table.remove(numbers, index)
			continue
		end
		local rise, scale, fade = HitStyle.numberAt(age)
		number.attachment.WorldPosition = number.base + Vector3.new(0, rise, 0)
		number.gui.Size = UDim2.fromScale(number.height * NUMBER_ASPECT * scale, number.height * scale)
		local transparency = number.transparency + (1 - number.transparency) * fade
		number.label.TextTransparency = transparency
		number.stroke.Transparency = transparency
	end
	for index = #flashes, 1, -1 do
		local flash = flashes[index]
		local age = now - flash.born
		if age >= HitStyle.FLASH_TIME then
			flash.part:Destroy()
			table.remove(flashes, index)
			continue
		end
		local size, transparency = HitStyle.flashAt(age)
		flash.part.Size = Vector3.one * size * flash.sizeScale
		flash.part.Transparency = transparency
	end
end

local function trackEnemy(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local id = instance:GetAttribute("EnemyId")
	if type(id) == "string" then
		-- Enemies stand still, so measuring once is enough.
		shapes[id] = measure(instance)
	end
end

local function untrackEnemy(instance: Instance)
	local id = instance:GetAttribute("EnemyId")
	if type(id) ~= "string" then
		return
	end
	local shape = shapes[id]
	shapes[id] = nil
	hitCounts[id] = nil
	-- Killed (not streamed out or removed at the end of a raid): burst into smoke.
	if shape and instance:GetAttribute("Health") == 0 then
		addFlash(shape.center, Color3.new(1, 1, 1), shape.size / HitStyle.FLASH_SIZE[2])
		emitAt(smoke, shape.center, Color3.fromRGB(235, 235, 240), POOF_COUNT)
		SoundController.playAt("EnemyDeath", shape.center)
	end
end

local function makeEmitter(
	texture: string,
	speed: NumberRange,
	lifetime: NumberRange,
	size: NumberSequence
): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Rate = 0 -- only bursts through :Emit()
	emitter.Speed = speed
	emitter.Lifetime = lifetime
	emitter.Size = size
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 0.8
	emitter.Parent = emitterAttachment
	return emitter
end

function HitEffectController.start()
	folder = Instance.new("Folder")
	folder.Name = "HitEffects"
	folder.Parent = workspace
	emitterAttachment = Instance.new("Attachment")
	emitterAttachment.Name = "HitEffectEmitter"
	emitterAttachment.Parent = workspace.Terrain
	sparks = makeEmitter(
		"rbxasset://textures/particles/sparkles_main.dds",
		NumberRange.new(10, 18),
		NumberRange.new(0.2, 0.4),
		NumberSequence.new(0.8, 0)
	)
	smoke = makeEmitter(
		"rbxasset://textures/particles/smoke_main.dds",
		NumberRange.new(4, 9),
		NumberRange.new(0.5, 0.9),
		NumberSequence.new(3, 7)
	)
	smoke.LightEmission = 0.2
	smoke.Transparency = NumberSequence.new(0.2, 1)

	for _, instance in CollectionService:GetTagged(ENEMY_TAG) do
		trackEnemy(instance)
	end
	CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(trackEnemy)
	CollectionService:GetInstanceRemovedSignal(ENEMY_TAG):Connect(untrackEnemy)

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CharacterHit") :: RemoteEvent
	remote.OnClientEvent:Connect(onHit)
	RunService.Heartbeat:Connect(step)
end

return HitEffectController
