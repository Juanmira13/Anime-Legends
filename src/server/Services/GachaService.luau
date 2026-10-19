--!strict
-- Gacha machines. A machine is any BasePart tagged "GachaStand" with an Island
-- attribute; players roll it through a ProximityPrompt. The server validates
-- the roll, charges yen, applies pity and the Luck boost, adds the character
-- to the inventory and tells the client the result through Remotes.GachaResult.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Data.Characters)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Islands = require(Shared.Data.Islands)

local Server = script.Parent.Parent
local GachaRoll = require(Server.Gacha.GachaRoll)
local Remotes = require(Server.Remotes)
local DataService = require(script.Parent.DataService)

export type RollResult = {
	ok: boolean,
	reason: ("NotLoaded" | "IslandLocked" | "InventoryFull" | "NotEnoughYen" | "TooFast")?,
	characterId: string?,
	rarity: string?,
}

local STAND_TAG = "GachaStand"
local PROMPT_DISTANCE = 12
local MIN_TIME_BETWEEN_ROLLS = 0.3 -- seconds; guards against prompt spam

local random = Random.new()
local lastRollTime: { [Player]: number } = {}
local resultRemote = Remotes.event("GachaResult")

local GachaService = {}

local function countOwned(data: DataService.Data): number
	local count = 0
	for _ in data.Characters do
		count += 1
	end
	return count
end

function GachaService.roll(player: Player, islandId: string): RollResult
	local data = DataService.getData(player)
	if data == nil then
		return { ok = false, reason = "NotLoaded" }
	end

	local now = time()
	if now - (lastRollTime[player] or -math.huge) < MIN_TIME_BETWEEN_ROLLS then
		return { ok = false, reason = "TooFast" }
	end
	lastRollTime[player] = now

	if not data.UnlockedIslands[islandId] then
		return { ok = false, reason = "IslandLocked" }
	end
	if countOwned(data) >= Formulas.inventorySlots(data.InventoryUpgrades) then
		return { ok = false, reason = "InventoryFull" }
	end
	if not DataService.spendCurrency(player, "Yen", Formulas.gachaCost(islandId)) then
		return { ok = false, reason = "NotEnoughYen" }
	end

	local counters = data.Pity[islandId]
	if counters == nil then
		counters = {}
		data.Pity[islandId] = counters
	end
	local luckActive = data.Boosts.Remaining.Luck > 0
	local rarity = GachaRoll.roll(counters, luckActive, function()
		return random:NextNumber()
	end)
	local character = Characters.forIslandAndRarity(islandId, rarity)

	local uid = tostring(data.NextCharacterUid)
	data.NextCharacterUid += 1
	data.Characters[uid] = { id = character.id }

	return { ok = true, characterId = character.id, rarity = rarity }
end

local function setupStand(stand: Instance)
	if not stand:IsA("BasePart") then
		return
	end
	local islandId = stand:GetAttribute("Island")
	local ok, island = pcall(Islands.get, islandId :: any)
	if not ok or type(islandId) ~= "string" then
		warn(`[GachaService] Invalid gacha stand {stand:GetFullName()}: {island}`)
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = `Gacha de {island.displayName}`
	prompt.ActionText = `Tirar ({Format.number(Formulas.gachaCost(islandId))} ¥)`
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		resultRemote:FireClient(player, GachaService.roll(player, islandId))
	end)
	prompt.Parent = stand
end

function GachaService.start()
	for _, stand in CollectionService:GetTagged(STAND_TAG) do
		setupStand(stand)
	end
	CollectionService:GetInstanceAddedSignal(STAND_TAG):Connect(setupStand)
	Players.PlayerRemoving:Connect(function(player)
		lastRollTime[player] = nil
	end)
end

return GachaService
