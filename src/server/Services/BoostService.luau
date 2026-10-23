--!strict
-- Boosts: activation, the gem shop and the online-only timer.
-- Clients call Remotes.BoostAction(action, boostId) with "Activate" or "Buy".
-- The shop is an NPC in the raid lobby (a part tagged "BoostShop"): its
-- ProximityPrompt tells the client to open the shop window
-- (Remotes.OpenBoostShop), and "Buy" is only accepted within Boosts.ShopRange
-- studs of a shop NPC.
-- Stock and time left are replicated as player attributes
-- "BoostOwned_<BoostId>" and "BoostTime_<BoostId>" (seconds).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)

local Server = script.Parent.Parent
local BoostOps = require(Server.Boosts.BoostOps)
local Remotes = require(Server.Remotes)
local DataService = require(script.Parent.DataService)

type Data = DataService.Data

export type ActionResult = {
	ok: boolean,
	reason: string?,
}

local TICK_INTERVAL = 1
local MIN_TIME_BETWEEN_ACTIONS = 0.2
local SHOP_TAG = "BoostShop"
local PROMPT_DISTANCE = 10

local actionRemote = Remotes.func("BoostAction")
local openShopRemote = Remotes.event("OpenBoostShop")
local lastActionTime: { [Player]: number } = {}

local BoostService = {}

local function replicate(player: Player, data: Data)
	for _, boost in Boosts.List do
		player:SetAttribute(`BoostOwned_{boost.id}`, BoostOps.owned(data, boost.id))
		player:SetAttribute(`BoostTime_{boost.id}`, math.ceil(BoostOps.remaining(data, boost.id)))
	end
end

-- Adds stored boosts to a loaded player (e.g. a raid drop).
function BoostService.grant(player: Player, boostId: string, amount: number?)
	local data = DataService.getData(player)
	if data and BoostOps.grant(data, boostId, amount) then
		replicate(player, data)
	end
end

-- Whether the player stands within Boosts.ShopRange of a shop NPC.
local function nearShop(player: Player): boolean
	local character = player.Character
	local root = character and character.PrimaryPart
	if root == nil then
		return false
	end
	for _, shop in CollectionService:GetTagged(SHOP_TAG) do
		if shop:IsA("BasePart") and (shop.Position - root.Position).Magnitude <= Boosts.ShopRange then
			return true
		end
	end
	return false
end

local function buy(player: Player, data: Data, boostId: string): (boolean, string?)
	local ok, boost = pcall(Boosts.get, boostId)
	if not ok then
		return false, "UnknownBoost"
	end
	if not nearShop(player) then
		return false, "NotAtShop"
	end
	if not DataService.spendCurrency(player, "Gems", boost.gemPrice) then
		return false, "NotEnoughGems"
	end
	BoostOps.grant(data, boostId)
	return true, nil
end

local function handleAction(player: Player, action: unknown, boostId: unknown): ActionResult
	if type(action) ~= "string" or type(boostId) ~= "string" then
		return { ok = false, reason = "BadRequest" }
	end
	local now = time()
	if now - (lastActionTime[player] or -math.huge) < MIN_TIME_BETWEEN_ACTIONS then
		return { ok = false, reason = "TooFast" }
	end
	lastActionTime[player] = now

	local data = DataService.getData(player)
	if data == nil then
		return { ok = false, reason = "NotLoaded" }
	end

	local ok, reason
	if action == "Activate" then
		ok, reason = BoostOps.activate(data, boostId)
	elseif action == "Buy" then
		ok, reason = buy(player, data, boostId)
	else
		return { ok = false, reason = "BadRequest" }
	end
	replicate(player, data)
	return { ok = ok, reason = reason }
end

local function setupShop(shop: Instance)
	if not shop:IsA("BasePart") or shop:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Tendero"
	prompt.ActionText = "Tienda"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		openShopRemote:FireClient(player)
	end)
	prompt.Parent = shop
end

function BoostService.start()
	actionRemote.OnServerInvoke = handleAction
	for _, shop in CollectionService:GetTagged(SHOP_TAG) do
		setupShop(shop)
	end
	CollectionService:GetInstanceAddedSignal(SHOP_TAG):Connect(setupShop)
	DataService.Loaded:Connect(replicate)
	Players.PlayerRemoving:Connect(function(player)
		lastActionTime[player] = nil
	end)

	-- Active boosts only run down while the player is online and loaded.
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK_INTERVAL)
			local current = os.clock()
			local elapsed = current - last
			last = current
			for _, player in Players:GetPlayers() do
				local data = DataService.getData(player)
				if data then
					BoostOps.tick(data, elapsed)
					replicate(player, data)
				end
			end
		end
	end)
end

return BoostService
