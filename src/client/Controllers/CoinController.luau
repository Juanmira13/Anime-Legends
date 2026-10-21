--!strict
-- Floating yen coins (see CoinService). Each drop bursts into gold coins around
-- the defeated enemy; they bob and spin until the player comes within
-- Balance.Coins.magnetRadius, then fly to them and are collected (the server
-- adds that coin's yen, and the HUD shows it at once). When the server pays a
-- drop by itself (coins left too long), its remaining coins fly over just for
-- show. Coins are local parts: only their owner sees them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage:WaitForChild("Shared").Config.Balance)

local COIN_COLOR = Color3.fromRGB(255, 200, 40)
local COIN_SIZE = Vector3.new(0.35, 2, 2) -- a cylinder on its side: a coin standing up
local HOVER_HEIGHT = 2.5
local BURST_TIME = 0.35 -- seconds to fly out to its spot
local BURST_RADIUS = { 2.5, 6 }
local FLY_SPEED = 70 -- studs per second toward the player
local PICKUP_DISTANCE = 2.5
local SPIN_SPEED = 3 -- radians per second
local FAR_AWAY = 150 -- studs: auto-collected coins farther than this vanish instead of flying

type Coin = {
	part: Part,
	from: Vector3,
	home: Vector3,
	born: number,
	phase: number,
	flying: boolean,
	paid: boolean, -- the server already paid it (auto-collect): do not report
}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local collectRemote = remotes:WaitForChild("CoinCollect") :: RemoteEvent
local random = Random.new()
local drops: { [string]: { [number]: Coin } } = {}
local folder: Folder

local CoinController = {}

local function onDrop(dropId: string, position: Vector3, values: { number })
	local coins = {}
	local start = position + Vector3.new(0, HOVER_HEIGHT, 0)
	for index in values do
		local angle = (index / #values + random:NextNumber(-0.08, 0.08)) * 2 * math.pi
		local distance = random:NextNumber(BURST_RADIUS[1], BURST_RADIUS[2])
		local part = Instance.new("Part")
		part.Name = "Coin"
		part.Shape = Enum.PartType.Cylinder
		part.Size = COIN_SIZE
		part.Color = COIN_COLOR
		part.Material = Enum.Material.Neon
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.CFrame = CFrame.new(start)
		part.Parent = folder
		coins[index] = {
			part = part,
			from = start,
			home = start + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance),
			born = os.clock(),
			phase = random:NextNumber(0, 2 * math.pi),
			flying = false,
			paid = false,
		}
	end
	drops[dropId] = coins
end

local function onAutoCollect(dropId: string)
	local coins = drops[dropId]
	if coins == nil then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for index, coin in coins do
		coin.paid = true
		-- Coins the player left behind (another island, the end of a raid) just vanish.
		if root and root:IsA("BasePart") and (root.Position - coin.part.Position).Magnitude <= FAR_AWAY then
			coin.flying = true
		else
			coin.part:Destroy()
			coins[index] = nil
		end
	end
end

local function step(deltaTime: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local target = if root and root:IsA("BasePart") then root.Position else nil
	local now = os.clock()
	for dropId, coins in drops do
		for index, coin in coins do
			local position: Vector3
			if coin.flying and target then
				local offset = target - coin.part.Position
				if offset.Magnitude <= PICKUP_DISTANCE then
					if not coin.paid then
						collectRemote:FireServer(dropId, index)
					end
					coin.part:Destroy()
					coins[index] = nil
					continue
				end
				position = coin.part.Position + offset.Unit * math.min(offset.Magnitude, FLY_SPEED * deltaTime)
			else
				local burst = math.clamp((now - coin.born) / BURST_TIME, 0, 1)
				local arc = Vector3.new(0, math.sin(burst * math.pi) * 2, 0)
				local bob = Vector3.new(0, math.sin(now * 3 + coin.phase) * 0.35, 0)
				position = coin.from:Lerp(coin.home, burst) + arc + bob
				if burst >= 1 and target and (target - coin.home).Magnitude <= Balance.Coins.magnetRadius then
					coin.flying = true
				end
			end
			coin.part.CFrame = CFrame.new(position) * CFrame.Angles(0, now * SPIN_SPEED + coin.phase, 0)
		end
		if next(coins) == nil then
			drops[dropId] = nil
		end
	end
end

function CoinController.start()
	folder = Instance.new("Folder")
	folder.Name = "Coins"
	folder.Parent = workspace
	local dropRemote = remotes:WaitForChild("CoinDrop") :: RemoteEvent
	local autoCollectRemote = remotes:WaitForChild("CoinAutoCollect") :: RemoteEvent
	dropRemote.OnClientEvent:Connect(onDrop)
	autoCollectRemote.OnClientEvent:Connect(onAutoCollect)
	RunService.Heartbeat:Connect(step)
end

return CoinController
