--!strict
-- TEMPORARY: Studio-only shortcut to test the gacha without farming.
-- Gives every player yen when their data loads. Remove this module and its
-- call in Main.server.luau before release.
-- Note: with Studio Access to API Services enabled, this yen is saved.

local RunService = game:GetService("RunService")

local DataService = require(script.Parent.Parent.Services.DataService)

local DEV_YEN = 5_000

local DevCheats = {}

function DevCheats.start()
	if not RunService:IsStudio() then
		return
	end
	DataService.Loaded:Connect(function(player: Player)
		DataService.addCurrency(player, "Yen", DEV_YEN)
		print(`[DevCheats] TEMPORARY: gave {player.Name} {DEV_YEN} yen for testing.`)
	end)
end

return DevCheats
