--!strict
-- TEMPORARY: Studio-only shortcut to test the gacha reveal of every rarity.
-- Remove this module and its call in Main.client.luau before release (along
-- with Server/Dev/DevCheats).
--   * Ctrl + 1..7 plays the reveal of one roll of that rarity (1 = Common ...
--     7 = Secret), Ctrl + 8 ten rolls up to Legendary and Ctrl + 9 ten rolls
--     with a Mythic and a Secret. Uses the nearest machine's island and does
--     not roll: nothing is charged or added.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rarities = require(ReplicatedStorage:WaitForChild("Shared").Config.Rarities)

local GachaController = require(script.Parent.Parent.Controllers.GachaController)

local KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

local MULTI_PREVIEWS: { [number]: { string } } = {
	[8] = { "Common", "Uncommon", "Common", "Rare", "Common", "Epic", "Uncommon", "Common", "Legendary", "Common" },
	[9] = { "Common", "Mythic", "Rare", "Common", "Uncommon", "Secret", "Common", "Epic", "Common", "Uncommon" },
}

local RevealPreview = {}

function RevealPreview.start()
	if not RunService:IsStudio() then
		return
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local index = KEYS[input.KeyCode]
		if processed or index == nil or not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			return
		end
		GachaController.preview(MULTI_PREVIEWS[index] or { Rarities.List[index].id })
	end)
	print("[RevealPreview] TEMPORARY: Ctrl + 1..7 previews a roll of each rarity; Ctrl + 8 and 9 preview ten rolls.")
end

return RevealPreview
