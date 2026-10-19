-- Client entry point.

local Controllers = script.Parent.Controllers
local EnemyController = require(Controllers.EnemyController)
local GachaController = require(Controllers.GachaController)
local HudController = require(Controllers.HudController)
local InventoryController = require(Controllers.InventoryController)
local PortalController = require(Controllers.PortalController)
local RaidController = require(Controllers.RaidController)

HudController.start()
EnemyController.start()
GachaController.start()
InventoryController.start()
PortalController.start()
RaidController.start()

print("[AnimeLegends] Client started")
