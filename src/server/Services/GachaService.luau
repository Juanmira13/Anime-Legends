--!strict
-- Gacha machines. A machine is any BasePart tagged "GachaStand" with an Island
-- attribute (the core of the star). Next to one, the client shows the gacha
-- panel and asks for 1 or Balance.GachaMultiRoll rolls through
-- Remotes.GachaRoll (islandId, count). The server validates (near a machine of
-- that island, island unlocked, room for every character, yen for every roll),
-- charges, rolls with pity and the Luck boost, adds the characters and answers
-- through Remotes.GachaResult.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Characters = require(Shared.Data.Characters)
local Formulas = require(Shared.Formulas)

local Server = script.Parent.Parent
local GachaRoll = require(Server.Gacha.GachaRoll)
local Remotes = require(Server.Remotes)
local DataService = require(script.Parent.DataService)
local InventoryService = require(script.Parent.InventoryService)

export type RollResult = {
	ok: boolean,
	reason: ("NotLoaded" | "TooFast" | "BadRequest" | "TooFar" | "IslandLocked" | "InventoryFull" | "NotEnoughYen")?,
	islandId: string?,
	count: number?,
	results: { { characterId: string, rarity: string } }?,
}

local STAND_TAG = "GachaStand"
local ROLL_DISTANCE = 30 -- studs from the star; the client opens the panel closer than this
local MIN_TIME_BETWEEN_ROLLS = 0.3 -- seconds; guards against spam

local random = Random.new()
local lastRollTime: { [Player]: number } = {}
local rollRemote = Remotes.event("GachaRoll")
local resultRemote = Remotes.event("GachaResult")

local GachaService = {}

local function isNearStand(player: Player, islandId: string): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	for _, stand in CollectionService:GetTagged(STAND_TAG) do
		if
			stand:IsA("BasePart")
			and stand:GetAttribute("Island") == islandId
			and (stand.Position - root.Position).Magnitude <= ROLL_DISTANCE
		then
			return true
		end
	end
	return false
end

function GachaService.roll(player: Player, islandId: unknown, count: unknown): RollResult
	local data = DataService.getData(player)
	if data == nil then
		return { ok = false, reason = "NotLoaded" }
	end

	local now = time()
	if now - (lastRollTime[player] or -math.huge) < MIN_TIME_BETWEEN_ROLLS then
		return { ok = false, reason = "TooFast" }
	end
	lastRollTime[player] = now

	if type(islandId) ~= "string" or (count ~= 1 and count ~= Balance.GachaMultiRoll) then
		return { ok = false, reason = "BadRequest" }
	end
	local rolls = count :: number
	if not isNearStand(player, islandId) then
		return { ok = false, reason = "TooFar" }
	end
	if not data.UnlockedIslands[islandId] then
		return { ok = false, reason = "IslandLocked" }
	end
	if not InventoryService.hasSpace(player, rolls) then
		return { ok = false, reason = "InventoryFull", count = rolls }
	end
	if not DataService.spendCurrency(player, "Yen", Formulas.gachaCost(islandId, rolls)) then
		return { ok = false, reason = "NotEnoughYen", count = rolls }
	end

	local counters = data.Pity[islandId]
	if counters == nil then
		counters = {}
		data.Pity[islandId] = counters
	end
	local luckActive = data.Boosts.Remaining.Luck > 0
	local rarities = GachaRoll.rollMany(counters, luckActive, rolls, function()
		return random:NextNumber()
	end)
	local results = {}
	local ids = {}
	for index, rarity in rarities do
		local character = Characters.forIslandAndRarity(islandId, rarity)
		results[index] = { characterId = character.id, rarity = rarity }
		ids[index] = character.id
	end
	InventoryService.addCharacters(player, ids)

	return { ok = true, islandId = islandId, count = rolls, results = results }
end

function GachaService.start()
	rollRemote.OnServerEvent:Connect(function(player: Player, islandId: unknown, count: unknown)
		resultRemote:FireClient(player, GachaService.roll(player, islandId, count))
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRollTime[player] = nil
	end)
end

return GachaService
