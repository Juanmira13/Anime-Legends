--!strict
-- Draws every player's equipped characters (AFS style). They walk on the
-- ground behind their owner in formation, all at the same speed, and, while
-- the owner has a target, walk to an arc around it and lunge on each hit the
-- server reports through Remotes.CharacterHit. Purely visual: damage is
-- decided by the server.
--
-- Reads the player attributes EquippedCharacters (character ids in slot
-- order) and TargetEnemyId. The model is
-- ReplicatedStorage.ImportedCharacters.<Island>.<CharacterId> (an imported
-- avatar, inserted in Studio) or else ReplicatedStorage.CharacterModels.<Island>
-- .<CharacterId> (Rojo placeholders from tools/build_rigs.py), if it exists (a
-- Model with a PrimaryPart; R15 rigs, found with Shared.ModelLookup),
-- otherwise a placeholder block in the rarity color. Only the PrimaryPart is
-- anchored so rigs keep their limbs free to animate; rigs swing their
-- shoulders and hips while walking (R15, or R6 for older models).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Data.Characters)
local ModelLookup = require(Shared.ModelLookup)
local Intangible = require(Shared.Intangible)
local Client = script.Parent.Parent
local FollowerMotion = require(Client.Followers.FollowerMotion)
local Theme = require(Client.UI.Theme)

local ENEMY_TAG = "Enemy"
local PLACEHOLDER_SIZE = 2 -- studs
local NAME_MAX_DISTANCE = 60 -- studs from the camera to show names
local DRAW_DISTANCE = 300 -- studs from the camera; farther teams are hidden
local SNAP_DISTANCE = 100 -- studs; farther jumps (portals, raids) snap instead of walking
local DEFAULT_WALK_SPEED = 16 -- studs per second, if the owner's humanoid reports 0
local TURN_RATE = 12 -- smoothing rates (see FollowerMotion.smoothing)
local WALK_BLEND_RATE = 10
local GROUND_RAY_UP = 8 -- studs above the owner's root where the ground ray starts
local GROUND_RAY_LENGTH = 40 -- studs

type Follower = {
	characterId: string,
	model: Model,
	groundOffset: number, -- distance from the model's pivot down to its lowest point
	position: Vector3?, -- point on the ground under the character, before the lunge
	yaw: number, -- facing angle around the vertical axis
	walkPhase: number,
	walkAmount: number, -- 0 standing still, 1 at full speed
	walkJoints: WalkJoints?, -- nil if the model is not an R15 or R6 rig
	lastHit: number, -- os.clock() of the last hit
}

type WalkJoints = {
	rightShoulder: Motor6D,
	leftShoulder: Motor6D,
	rightHip: Motor6D,
	leftHip: Motor6D,
	r15: boolean, -- R15 joint frames are unrotated: the swing is about X
}

type Team = {
	owner: Player,
	followers: { Follower },
	connection: RBXScriptConnection,
}

local teams: { [Player]: Team } = {}
local enemiesById: { [string]: Model } = {}

local folder = Instance.new("Folder")
folder.Name = "Followers"
folder.Parent = workspace

-- Ground rays ignore characters, followers and anything without collision
-- (enemy rigs), so followers stand on the map.
local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Exclude
groundRay.RespectCanCollide = true

local FollowerController = {}

local function getTemplate(characterId: string): Model?
	local character = Characters.get(characterId)
	return ModelLookup.find({
		{
			root = ReplicatedStorage:FindFirstChild("ImportedCharacters"),
			name = "ReplicatedStorage.ImportedCharacters",
		},
		{ root = ReplicatedStorage:FindFirstChild("CharacterModels"), name = "ReplicatedStorage.CharacterModels" },
	}, { character.island, characterId })
end

local function buildPlaceholder(characterId: string): Model
	local character = Characters.get(characterId)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one * PLACEHOLDER_SIZE
	root.Color = Theme.rarityColor(character.rarity)
	root.Material = Enum.Material.SmoothPlastic
	root.Parent = model
	model.PrimaryPart = root
	return model
end

-- Name over the model's highest point, in the rarity color.
local function addNameLabel(model: Model, characterId: string)
	local character = Characters.get(characterId)
	local root = model.PrimaryPart :: BasePart
	local boxCFrame, boxSize = model:GetBoundingBox()
	local top = boxCFrame.Position.Y + boxSize.Y / 2 - root.Position.Y

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 20)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, top + 1, 0)
	billboard.MaxDistance = NAME_MAX_DISTANCE
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Theme.rarityColor(character.rarity)
	-- Secret is drawn dark, so give its text a white outline to stay readable.
	label.TextStrokeColor3 = if character.rarity == "Secret" then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Text = character.displayName
	label.Parent = billboard
end

-- Distance from the model's pivot down to its lowest point.
local function heightAboveGround(model: Model): number
	local boxCFrame, boxSize = model:GetBoundingBox()
	return model:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
end

local function findWalkJoints(model: Model): WalkJoints?
	local function motor(name: string): Motor6D?
		local joint = model:FindFirstChild(name, true)
		return if joint and joint:IsA("Motor6D") then joint else nil
	end
	-- R15 joints first ("RightShoulder"), then the classic R6 names ("Right Shoulder").
	for _, r15 in { true, false } do
		local space = if r15 then "" else " "
		local rightShoulder, leftShoulder = motor(`Right{space}Shoulder`), motor(`Left{space}Shoulder`)
		local rightHip, leftHip = motor(`Right{space}Hip`), motor(`Left{space}Hip`)
		if rightShoulder and leftShoulder and rightHip and leftHip then
			return {
				rightShoulder = rightShoulder,
				leftShoulder = leftShoulder,
				rightHip = rightHip,
				leftHip = leftHip,
				r15 = r15,
			}
		end
	end
	return nil
end

local function buildFollower(characterId: string): Follower
	local template = getTemplate(characterId)
	local model = if template then template:Clone() else buildPlaceholder(characterId)
	-- Visual only: intangible (players walk through) and never block clicks on enemies.
	Intangible.apply(model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanQuery = false
		end
	end
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	addNameLabel(model, characterId)
	return {
		characterId = characterId,
		model = model,
		groundOffset = heightAboveGround(model),
		position = nil,
		yaw = 0,
		walkPhase = 0,
		walkAmount = 0,
		walkJoints = findWalkJoints(model),
		lastHit = -math.huge,
	}
end

local function parseIds(value: unknown): { string }
	local ids = {}
	if type(value) ~= "string" then
		return ids
	end
	for id in string.gmatch(value, "[^,]+") do
		-- Ignore ids this client does not know (e.g. content from a newer server).
		if pcall(Characters.get, id) then
			table.insert(ids, id)
		end
	end
	return ids
end

-- Rebuilds a team after its equipped characters change, keeping the models of
-- slots that did not change so they do not jump.
local function rebuild(team: Team)
	local ids = parseIds(team.owner:GetAttribute("EquippedCharacters"))
	local followers = {}
	for slot, id in ids do
		local existing = team.followers[slot]
		if existing and existing.characterId == id then
			followers[slot] = existing
		else
			followers[slot] = buildFollower(id)
		end
	end
	for slot, follower in team.followers do
		if followers[slot] ~= follower then
			follower.model:Destroy()
		end
	end
	team.followers = followers
end

local function addTeam(owner: Player)
	if teams[owner] then
		return
	end
	local team: Team
	team = {
		owner = owner,
		followers = {},
		connection = owner:GetAttributeChangedSignal("EquippedCharacters"):Connect(function()
			rebuild(team)
		end),
	}
	teams[owner] = team
	rebuild(team)
end

local function removeTeam(owner: Player)
	local team = teams[owner]
	if team == nil then
		return
	end
	teams[owner] = nil
	team.connection:Disconnect()
	for _, follower in team.followers do
		follower.model:Destroy()
	end
end

local function onHit(owner: Player, _enemyId: string, hits: { { slot: number, damage: number } })
	local team = teams[owner]
	if team == nil then
		return
	end
	local now = os.clock()
	for _, hit in hits do
		local follower = team.followers[hit.slot]
		if follower then
			follower.lastHit = now
		end
	end
end

local function getTarget(owner: Player): Model?
	local id = owner:GetAttribute("TargetEnemyId")
	local model = if type(id) == "string" then enemiesById[id] else nil
	return if model and model.PrimaryPart then model else nil
end

local function setVisible(team: Team, visible: boolean)
	local parent = if visible then folder else nil
	for _, follower in team.followers do
		if follower.model.Parent ~= parent then
			follower.model.Parent = parent
			-- Snap into place when shown again instead of walking from where it was hidden.
			follower.position = nil
		end
	end
end

-- Yaw angle of a horizontal direction (CFrame.Angles(0, yaw, 0) looks along it).
local function yawOf(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

local function groundHeight(x: number, z: number, fromY: number): number?
	local origin = Vector3.new(x, fromY + GROUND_RAY_UP, z)
	local result = workspace:Raycast(origin, Vector3.new(0, -GROUND_RAY_LENGTH, 0), groundRay)
	return if result then result.Position.Y else nil
end

-- Where a character should stand (horizontal position), which way it faces
-- there, and the offset of a full lunge.
local function getGoal(slot: number, count: number, root: BasePart, target: Model?): (Vector3, number, Vector3)
	if target then
		-- Rigs are taller and wider than their root part, so measure the whole model.
		local targetCFrame, targetSize = target:GetBoundingBox()
		local targetPosition = targetCFrame.Position
		local toOwner = Vector3.new(root.Position.X - targetPosition.X, 0, root.Position.Z - targetPosition.Z)
		if toOwner.Magnitude < 1e-3 then
			toOwner = -root.CFrame.LookVector
		end
		local direction = CFrame.Angles(0, FollowerMotion.attackAngle(slot, count), 0):VectorToWorldSpace(toOwner.Unit)
		local radius = FollowerMotion.attackRadius(math.max(targetSize.X, targetSize.Z) / 2)
		return targetPosition + direction * radius, yawOf(-direction), -direction * FollowerMotion.ATTACK_GAP
	end
	local ownerYaw = yawOf(root.CFrame.LookVector)
	local right, back = FollowerMotion.formationOffset(slot, count)
	-- Object space looks along -Z, so +Z is behind the owner.
	local goal = (CFrame.new(root.Position) * CFrame.Angles(0, ownerYaw, 0) * CFrame.new(right, 0, back)).Position
	return goal, ownerYaw, Vector3.zero
end

-- Moves a character toward its goal at the team's speed. Returns the studs
-- moved and the direction it moved in.
local function walk(
	follower: Follower,
	goal: Vector3,
	speed: number,
	dt: number,
	ownerGround: number
): (number, Vector3)
	local position = follower.position
	if position == nil then
		follower.position = Vector3.new(goal.X, ownerGround, goal.Z)
		return 0, Vector3.zero
	end
	local offset = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
	local distance = offset.Magnitude
	if distance > SNAP_DISTANCE then
		follower.position = Vector3.new(goal.X, ownerGround, goal.Z)
		return 0, Vector3.zero
	end
	local moved = FollowerMotion.stepDistance(distance, speed, dt)
	local direction = if distance > 1e-3 then offset.Unit else Vector3.zero
	follower.position = position + direction * moved
	return moved, direction
end

local function updateTeam(team: Team, camera: Camera, dt: number, now: number)
	local character = team.owner.Character
	local root = character and character.PrimaryPart
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or (root.Position - camera.CFrame.Position).Magnitude > DRAW_DISTANCE then
		setVisible(team, false)
		return
	end
	setVisible(team, true)

	local ownerGround = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	local ownerSpeed = if humanoid.WalkSpeed > 0 then humanoid.WalkSpeed else DEFAULT_WALK_SPEED
	local speed = FollowerMotion.walkSpeed(ownerSpeed)
	local target = getTarget(team.owner)
	local count = #team.followers
	local turnAlpha = FollowerMotion.smoothing(dt, TURN_RATE)
	local walkAlpha = FollowerMotion.smoothing(dt, WALK_BLEND_RATE)

	for slot, follower in team.followers do
		local goal, goalYaw, lunge = getGoal(slot, count, root, target)
		local moved, direction = walk(follower, goal, speed, dt, ownerGround)
		local walked = follower.position :: Vector3
		local ground = groundHeight(walked.X, walked.Z, root.Position.Y) or ownerGround
		local position = Vector3.new(walked.X, ground, walked.Z)
		follower.position = position

		-- Face where it walks; once there, face the target or the owner's way.
		local wantedYaw = if moved > 1e-3 then yawOf(direction) else goalYaw
		follower.yaw = FollowerMotion.turnToward(follower.yaw, wantedYaw, turnAlpha)

		local movingAmount = if dt > 0 then math.clamp(moved / dt / ownerSpeed, 0, 1) else 0
		follower.walkAmount += (movingAmount - follower.walkAmount) * walkAlpha
		follower.walkPhase = FollowerMotion.advanceWalk(follower.walkPhase, moved)

		local lungeOffset = lunge * FollowerMotion.lungeAmount(now - follower.lastHit)
		local pivot = CFrame.new(position + Vector3.new(0, follower.groundOffset, 0) + lungeOffset)
		follower.model:PivotTo(pivot * CFrame.Angles(0, follower.yaw, 0))
	end
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local ignored: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignored, player.Character)
		end
	end
	groundRay.FilterDescendantsInstances = ignored

	local now = os.clock()
	for _, team in teams do
		updateTeam(team, camera, dt, now)
	end
end

-- Swings arms and legs like the classic walk: arms and legs in opposite
-- directions, each side opposite to the other. R15 joint frames are unrotated,
-- so the swing is about their X axis; R6 frames are turned sideways (left and
-- right mirrored), so it is about Z with the same sign on both sides. Joint
-- transforms are set before physics, as Roblox recommends for Motor6D.Transform.
local function animateWalk()
	for _, team in teams do
		for _, follower in team.followers do
			local joints = follower.walkJoints
			if joints then
				local angle = FollowerMotion.walkSwing(follower.walkPhase, follower.walkAmount)
				if joints.r15 then
					joints.rightShoulder.Transform = CFrame.Angles(angle, 0, 0)
					joints.leftShoulder.Transform = CFrame.Angles(-angle, 0, 0)
					joints.rightHip.Transform = CFrame.Angles(-angle, 0, 0)
					joints.leftHip.Transform = CFrame.Angles(angle, 0, 0)
				else
					joints.rightShoulder.Transform = CFrame.Angles(0, 0, angle)
					joints.leftShoulder.Transform = CFrame.Angles(0, 0, angle)
					joints.rightHip.Transform = CFrame.Angles(0, 0, -angle)
					joints.leftHip.Transform = CFrame.Angles(0, 0, -angle)
				end
			end
		end
	end
end

local function trackEnemy(instance: Instance)
	local id = instance:GetAttribute("EnemyId")
	if instance:IsA("Model") and type(id) == "string" then
		enemiesById[id] = instance
	end
end

local function untrackEnemy(instance: Instance)
	local id = instance:GetAttribute("EnemyId")
	if type(id) == "string" and enemiesById[id] == instance then
		enemiesById[id] = nil
	end
end

function FollowerController.start()
	CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(trackEnemy)
	CollectionService:GetInstanceRemovedSignal(ENEMY_TAG):Connect(untrackEnemy)
	for _, instance in CollectionService:GetTagged(ENEMY_TAG) do
		trackEnemy(instance)
	end

	Players.PlayerAdded:Connect(addTeam)
	Players.PlayerRemoving:Connect(removeTeam)
	for _, owner in Players:GetPlayers() do
		addTeam(owner)
	end

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CharacterHit") :: RemoteEvent
	remote.OnClientEvent:Connect(onHit)
	RunService.RenderStepped:Connect(step)
	RunService.PreSimulation:Connect(animateWalk)
end

return FollowerController
