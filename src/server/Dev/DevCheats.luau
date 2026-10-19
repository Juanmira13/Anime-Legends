--!strict
-- TEMPORARY: Studio-only shortcuts for testing. Remove this module and its
-- call in Main.server.luau before release.
--   * Gives every player yen and gems when their data loads (test the gacha and
--     the boost shop without farming).
--   * Raids play only waves 1, 10 and 20 (test the mini boss, boss and rewards quickly).
-- Note: with Studio Access to API Services enabled, this yen and gems are saved.

local RunService = game:GetService("RunService")

local Services = script.Parent.Parent.Services
local DataService = require(Services.DataService)
local RaidService = require(Services.RaidService)

local DEV_YEN = 5_000
local DEV_GEMS = 1_000
local DEV_RAID_WAVES = { 1, 10, 20 }

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
	RaidService.setWaveSequence(DEV_RAID_WAVES)
	print(`[DevCheats] TEMPORARY: raids play only waves {table.concat(DEV_RAID_WAVES, ", ")}.`)
end

return DevCheats
