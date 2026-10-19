-- Server entry point.

local Services = script.Parent.Services
local DataService = require(Services.DataService)
local EnemyService = require(Services.EnemyService)
local CombatService = require(Services.CombatService)
local TestArena = require(script.Parent.Dev.TestArena)

DataService.start()
TestArena.buildIfNeeded()
EnemyService.start()
CombatService.start()

print("[AnimeLegends] Server started")
