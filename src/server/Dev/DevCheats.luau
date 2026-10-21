--!strict
-- TEMPORARY: Studio-only shortcuts for testing. Remove this module and its
-- call in Main.server.luau before release.
--   * Gives every player yen and gems when their data loads (test the gacha and
--     the boost shop without farming).
-- Note: with Studio Access to API Services enabled, this yen and gems are saved.

local RunService = game:GetService("RunService")

local Services = script.Parent.Parent.Services
local DataService = require(Services.DataService)

local DEV_YEN = 5_000
local DEV_GEMS = 1_000

local DevCheats = {}

function DevCheats.start()
	if not RunService:IsStudio() then
		return
	end
	DataService.Loaded:Connect(function(player: Player)
		DataService.addCurrency(player, "Yen", DEV_YEN)
		DataService.addCurrency(player, "Gems", DEV_GEMS)
		print(`[DevCheats] TEMPORARY: gave {player.Name} {DEV_YEN} yen and {DEV_GEMS} gems for testing.`)
	end)
end

return DevCheats
