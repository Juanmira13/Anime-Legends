-- Client entry point.

local Controllers = script.Parent.Controllers
local EnemyController = require(Controllers.EnemyController)
local GachaController = require(Controllers.GachaController)

EnemyController.start()
GachaController.start()

print("[AnimeLegends] Client started")
