--!strict
-- Shows the result of a gacha roll (or why it failed).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Data.Characters)
local Rarities = require(Shared.Config.Rarities)
local UI = script.Parent.Parent.UI
local Notify = require(UI.Notify)
local Theme = require(UI.Theme)

-- Silent reasons are not shown (spam guard, data still loading).
local FAILURE_MESSAGES: { [string]: string } = {
	IslandLocked = "Esta isla está bloqueada",
	InventoryFull = "Inventario lleno",
	NotEnoughYen = "No tienes suficientes Yenes",
}

local GachaController = {}

local function onResult(result: any)
	if result.ok then
		local character = Characters.get(result.characterId)
		local rarity = Rarities.get(result.rarity)
		-- Secret is drawn dark, so give its text a white outline to stay readable.
		local outline = if rarity.id == "Secret" then Color3.new(1, 1, 1) else nil
		Notify.show(`¡{character.displayName}! ({rarity.displayName})`, Theme.rarityColor(rarity.id), outline)
	elseif FAILURE_MESSAGES[result.reason] then
		Notify.error(FAILURE_MESSAGES[result.reason])
	end
end

function GachaController.start()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GachaResult") :: RemoteEvent
	remote.OnClientEvent:Connect(onResult)
end

return GachaController
