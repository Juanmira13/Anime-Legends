-- Server entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Intangible = require(ReplicatedStorage:WaitForChild("Shared").Intangible)

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local EnemyService = require(Services.EnemyService)
local CombatService = require(Services.CombatService)
local GachaService = require(Services.GachaService)
local InventoryService = require(Services.InventoryService)
local PortalService = require(Services.PortalService)
local RaidService = require(Services.RaidService)
local BoostService = require(Services.BoostService)
local CoinService = require(Services.CoinService)
local TestArena = require(script.Parent.Dev.TestArena)
local MapValidator = require(script.Parent.Dev.MapValidator)
local DevCheats = require(script.Parent.Dev.DevCheats) -- TEMPORARY: remove before release

Intangible.start() -- collision groups, and players' characters in "Players", before anyone joins
DevCheats.start() -- connect before players load
InventoryService.start() -- connect before players load so it sends their first snapshot
TestArena.buildIfNeeded() -- before PortalService so arrival points exist when players load
MapValidator.runInStudio()
PortalService.start() -- connect before players load to place them on their last island
RaidService.start() -- connect before players load to replicate raid cooldowns
BoostService.start() -- connect before players load to replicate boosts
CoinService.start()
DataService.start()
EnemyService.start()
CombatService.start()
GachaService.start()

print("[AnimeLegends] Server started")
