--!strict
-- Yen as floating coins. When an enemy dies, each player who hit it gets their
-- own drop of coins where it stood (only they see and collect them). The
-- client flies a coin to its owner when they come within Balance.Coins
-- magnetRadius and reports the pickup; the server checks it (the drop is theirs,
-- the coin is not taken yet and they are near it) and adds that coin's yen at
-- once. Coins still on the ground after `lifetime` seconds fly to their owner
-- and are paid then, so nothing is lost by leaving an island or a raid.
--
-- Remotes: CoinDrop (server -> client: dropId, position, values),
-- CoinCollect (client -> server: dropId, coinIndex),
-- CoinAutoCollect (server -> client: dropId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)

local Server = script.Parent.Parent
local CoinOps = require(Server.Coins.CoinOps)
local Remotes = require(Server.Remotes)
local DataService = require(script.Parent.DataService)

type Drop = {
	position: Vector3,
	values: { number },
	collected: { [number]: boolean },
	expiresAt: number,
}

local CHECK_INTERVAL = 1

local dropRemote = Remotes.event("CoinDrop")
local collectRemote = Remotes.event("CoinCollect")
local autoCollectRemote = Remotes.event("CoinAutoCollect")
local drops: { [Player]: { [string]: Drop } } = {}
local nextDropId = 0

local CoinService = {}

-- Pays the coins of a drop nobody collected and forgets it.
local function payRemaining(player: Player, dropId: string, drop: Drop)
	local total = 0
	for index, value in drop.values do
		if not drop.collected[index] then
			total += value
		end
	end
	local playerDrops = drops[player]
	if playerDrops then
		playerDrops[dropId] = nil
	end
	if total > 0 then
		DataService.addCurrency(player, "Yen", total)
	end
end

-- Drops `amount` yen as coins for `player` at `position` (ground level).
function CoinService.drop(player: Player, position: Vector3, amount: number)
	local values = CoinOps.split(amount, Balance.Coins.maxPerDrop)
	if #values == 0 or player.Parent == nil then
		return
	end
	nextDropId += 1
	local dropId = tostring(nextDropId)
	local playerDrops = drops[player] or {}
	drops[player] = playerDrops
	playerDrops[dropId] = {
		position = position,
		values = values,
		collected = {},
		expiresAt = time() + Balance.Coins.lifetime,
	}
	dropRemote:FireClient(player, dropId, position, values)
end

local function onCollect(player: Player, dropId: unknown, index: unknown)
	if type(dropId) ~= "string" or type(index) ~= "number" then
		return
	end
	local drop = drops[player] and drops[player][dropId]
	if drop == nil or index ~= math.floor(index) or drop.values[index] == nil or drop.collected[index] then
		return
	end
	local character = player.Character
	local root = character and character.PrimaryPart
	if root == nil or (root.Position - drop.position).Magnitude > Balance.Coins.collectRange then
		return
	end
	drop.collected[index] = true
	DataService.addCurrency(player, "Yen", drop.values[index])
	for coin in drop.values do
		if not drop.collected[coin] then
			return
		end
	end
	drops[player][dropId] = nil
end

function CoinService.start()
	collectRemote.OnServerEvent:Connect(onCollect)
	-- Pay what is left before the final save, then forget the player's drops.
	DataService.Releasing:Connect(function(player: Player)
		local playerDrops = drops[player]
		if playerDrops then
			for dropId, drop in playerDrops do
				payRemaining(player, dropId, drop)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		drops[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			local now = time()
			for player, playerDrops in drops do
				for dropId, drop in playerDrops do
					if now >= drop.expiresAt then
						payRemaining(player, dropId, drop)
						autoCollectRemote:FireClient(player, dropId)
					end
				end
			end
		end
	end)
end

return CoinService
