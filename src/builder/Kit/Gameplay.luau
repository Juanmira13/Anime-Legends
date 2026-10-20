--!strict
-- Gameplay pieces of a map, tagged as CLAUDE.md describes: arrival point,
-- gacha machine, portals, raid portal and pads, enemy spawn points, plus the
-- signs that name each zone. Placed from the island layout so they always
-- match the terrain.

local CollectionService = game:GetService("CollectionService")

local Root = script.Parent.Parent
local Shared = Root.Shared
local Balance = require(Shared.Config.Balance)
local Islands = require(Shared.Data.Islands)
local World = require(Shared.Config.World)
local Parts = require(script.Parent.Parts)

local STONE = Color3.fromRGB(215, 210, 200)
local WOOD = Color3.fromRGB(125, 90, 60)
local DARK = Color3.fromRGB(40, 40, 50)

local Gameplay = {}

local function tag(part: BasePart, tagName: string, attributes: { [string]: any })
	for name, value in attributes do
		part:SetAttribute(name, value)
	end
	CollectionService:AddTag(part, tagName)
end

-- Invisible marker whose top face is at `ground`.
local function marker(name: string, x: number, ground: number, z: number, parent: Instance): Part
	local part = Parts.block(Vector3.new(4, 1, 4), CFrame.new(x, ground - 0.4, z), Color3.new(1, 1, 1), parent, {
		transparency = 1,
		shadow = false,
		name = name,
	})
	return part
end

local function label(parent: BasePart, text: string, color: Color3, offset: number, maxDistance: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(220, 46)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	billboard.MaxDistance = maxDistance
	billboard.LightInfluence = 0
	billboard.Parent = parent

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.TextColor3 = color
	textLabel.TextStrokeColor3 = DARK
	textLabel.TextStrokeTransparency = 0
	textLabel.Text = text
	textLabel.Parent = billboard
end

function Gameplay.arrival(islandId: string, x: number, ground: number, z: number, parent: Instance)
	tag(marker("Arrival", x, ground, z, parent), "IslandSpawn", { Island = islandId })
end

function Gameplay.raidLobbyArrival(x: number, ground: number, z: number, parent: Instance)
	tag(marker("Arrival", x, ground, z, parent), "RaidLobbySpawn", {})
end

-- Gacha machine: stone pedestal, glowing orb (the tagged part) and a ring.
function Gameplay.gacha(islandId: string, x: number, ground: number, z: number, accent: Color3, parent: Instance)
	local model = Parts.model("GachaMachine", parent)
	local base = CFrame.new(x, ground, z)
	Parts.column(12, 1.2, base, STONE, model, { collide = true })
	Parts.column(8, 4, base * CFrame.new(0, 1.2, 0), Parts.vary(STONE, 0.2, 0.3), model, { collide = true })
	Parts.column(9.5, 0.8, base * CFrame.new(0, 5.2, 0), accent, model, { material = Enum.Material.Neon, shadow = false })
	local orb = Parts.ball(6, Vector3.new(x, ground + 9.2, z), accent, model, { material = Enum.Material.Neon, transparency = 0.15, name = `GachaStand_{islandId}` })
	orb.CanQuery = true -- the prompt lives here
	Parts.light(orb, accent, 18, 2)
	tag(orb, "GachaStand", { Island = islandId })
	label(orb, "Gacha", Color3.new(1, 1, 1), 6, 90)
end

-- Portal: glowing pad (tagged) under a column of light, framed by an arch.
local function portal(name: string, tagName: string, attributes: { [string]: any }, title: string, x: number, ground: number, z: number, facing: number, color: Color3, parent: Instance)
	local model = Parts.model(name, parent)
	local base = CFrame.new(x, ground, z) * CFrame.Angles(0, facing, 0)
	local pad = Parts.disc(11, 0.8, Vector3.new(x, ground + 0.4, z), color, model, { material = Enum.Material.Neon, shadow = false, name = name })
	pad.CanQuery = true
	tag(pad, tagName, attributes)
	Parts.disc(13, 0.6, Vector3.new(x, ground + 0.2, z), STONE, model, { collide = true })

	local beam = Parts.column(7, 38, CFrame.new(x, ground + 0.8, z), color, model, { material = Enum.Material.Neon, transparency = 0.55, shadow = false, name = "LightBeam" })
	Parts.light(beam, color, 24, 2.5)

	for _, side in { -1, 1 } do
		Parts.block(Vector3.new(2.4, 16, 2.4), base * CFrame.new(side * 7.5, 8, 0), STONE, model, { collide = true })
		Parts.block(Vector3.new(3.2, 1.2, 3.2), base * CFrame.new(side * 7.5, 16.6, 0), color, model, { material = Enum.Material.Neon, shadow = false })
	end
	local top = Parts.block(Vector3.new(19, 2, 3), base * CFrame.new(0, 17.6, 0), STONE, model, { collide = true })
	label(top, title, color, 4, 120)
end

function Gameplay.islandPortal(targetIslandId: string, x: number, ground: number, z: number, facing: number, parent: Instance)
	local island = Islands.get(targetIslandId)
	local color = Parts.rgb(World.AccentColors[targetIslandId])
	portal(`Portal_{targetIslandId}`, "Portal", { TargetIsland = targetIslandId }, island.displayName, x, ground, z, facing, color, parent)
end

function Gameplay.raidPortal(x: number, ground: number, z: number, facing: number, parent: Instance)
	portal("RaidPortal", "RaidPortal", {}, "Raids", x, ground, z, facing, Parts.rgb(World.RaidAccentColor), parent)
end

-- Raid pad: altar platform the player stands on to queue.
function Gameplay.raidPad(difficultyId: string, title: string, x: number, ground: number, z: number, color: Color3, parent: Instance)
	local model = Parts.model(`RaidPad_{difficultyId}`, parent)
	Parts.column(16, 1.5, CFrame.new(x, ground, z), STONE, model, { collide = true })
	local pad = Parts.block(Vector3.new(11, 1, 11), CFrame.new(x, ground + 1.8, z), color, model, { material = Enum.Material.Neon, collide = true, shadow = false, name = `RaidPad_{difficultyId}` })
	pad.CanQuery = true
	tag(pad, "RaidPad", { Difficulty = difficultyId })
	Parts.light(pad, color, 20, 2)
	label(pad, title, color, 7, 100)
end

function Gameplay.enemySpawn(islandId: string, rankId: string, x: number, ground: number, z: number, parent: Instance)
	tag(marker(`Spawn_{rankId}`, x, ground, z, parent), "EnemySpawn", { Island = islandId, Rank = rankId })
end

-- Wooden sign with the zone name and its rank, facing `facing` (yaw).
function Gameplay.zoneSign(title: string, rankId: string, x: number, ground: number, z: number, facing: number, accent: Color3, parent: Instance)
	local model = Parts.model(`Sign_{rankId}`, parent)
	local base = CFrame.new(x, ground, z) * CFrame.Angles(0, facing, 0)
	for _, side in { -1, 1 } do
		Parts.block(Vector3.new(0.8, 7, 0.8), base * CFrame.new(side * 4.2, 3.5, 0), WOOD, model, { shadow = false })
	end
	local board = Parts.block(Vector3.new(10, 3.6, 0.6), base * CFrame.new(0, 6, 0), Parts.vary(WOOD, 0.3, 0.8), model, { name = "Board" })
	Parts.block(Vector3.new(10.4, 0.5, 0.8), base * CFrame.new(0, 8, 0), accent, model, { shadow = false })

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		gui.Parent = board
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(255, 245, 225)
		text.TextStrokeTransparency = 0.4
		text.Text = `{title}\n{Balance.getEnemyRank(rankId).displayName}`
		text.Parent = gui
	end
end

return Gameplay
