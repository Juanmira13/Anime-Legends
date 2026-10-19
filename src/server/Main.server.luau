-- Server entry point.

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local EnemyService = require(Services.EnemyService)
local CombatService = require(Services.CombatService)
local GachaService = require(Services.GachaService)
local InventoryService = require(Services.InventoryService)
local TestArena = require(script.Parent.Dev.TestArena)
local DevCheats = require(script.Parent.Dev.DevCheats) -- TEMPORARY: remove before release

DevCheats.start() -- connect before players load
InventoryService.start() -- connect before players load so it sends their first snapshot
DataService.start()
TestArena.buildIfNeeded()
EnemyService.start()
CombatService.start()
GachaService.start()

print("[AnimeLegends] Server started")
