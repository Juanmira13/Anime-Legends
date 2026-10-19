-- Client entry point.

local Controllers = script.Parent.Controllers
local EnemyController = require(Controllers.EnemyController)

EnemyController.start()

print("[AnimeLegends] Client started")
