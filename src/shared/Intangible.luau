--!strict
-- Characters (the fighters that follow players) and enemies are intangible:
-- players walk through them. CanCollide alone is not enough, because a
-- Humanoid turns collision back on for the Torso and Head of its rig, so:
--   * their parts join the "Intangible" collision group, and
--   * player characters join the "Players" group, which never collides with it.
-- "Intangible" still collides with "Default" on purpose: mouse clicks
-- (ClickDetectors) and raycasts use the Default group and skip parts whose group
-- does not collide with it, so enemies would become unclickable. The server
-- registers the groups (they replicate to clients) and puts characters in
-- "Players".

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local GROUP = "Intangible"
local PLAYERS_GROUP = "Players"

local Intangible = {
	Group = GROUP,
	PlayersGroup = PLAYERS_GROUP,
}

local function setGroup(part: Instance, group: string)
	if part:IsA("BasePart") then
		part.CollisionGroup = group
	end
end

local function trackCharacter(character: Model)
	for _, part in character:GetDescendants() do
		setGroup(part, PLAYERS_GROUP)
	end
	-- Accessories and tools added later.
	character.DescendantAdded:Connect(function(part)
		setGroup(part, PLAYERS_GROUP)
	end)
end

-- Server, once at startup: registers the groups and puts every player
-- character in "Players".
function Intangible.start()
	for _, group in { GROUP, PLAYERS_GROUP } do
		if not PhysicsService:IsCollisionGroupRegistered(group) then
			PhysicsService:RegisterCollisionGroup(group)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(GROUP, PLAYERS_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(GROUP, GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(GROUP, "Default", true) -- keeps enemies clickable

	local function onPlayer(player: Player)
		if player.Character then
			trackCharacter(player.Character)
		end
		player.CharacterAdded:Connect(trackCharacter)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

-- Makes every part of `model` intangible (no collision with players, no
-- Touched events). CanQuery is left as it is, so enemies stay clickable.
function Intangible.apply(model: Instance)
	local registered = PhysicsService:IsCollisionGroupRegistered(GROUP)
	local parts = model:GetDescendants()
	table.insert(parts, model)
	for _, part in parts do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			if registered then
				part.CollisionGroup = GROUP
			end
		end
	end
end

return Intangible
