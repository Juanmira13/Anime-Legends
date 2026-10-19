--!strict
-- Boosts: activation, the gem shop and the online-only timer.
-- Clients call Remotes.BoostAction(action, boostId) with "Activate" or "Buy".
-- Stock and time left are replicated as player attributes
-- "BoostOwned_<BoostId>" and "BoostTime_<BoostId>" (seconds).

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

local actionRemote = Remotes.func("BoostAction")
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

local function buy(player: Player, data: Data, boostId: string): (boolean, string?)
	local ok, boost = pcall(Boosts.get, boostId)
	if not ok then
		return false, "UnknownBoost"
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

function BoostService.start()
	actionRemote.OnServerInvoke = handleAction
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
