-- Client entry point.

local Controllers = script.Parent.Controllers
local EnemyController = require(Controllers.EnemyController)
local GachaController = require(Controllers.GachaController)
local HudController = require(Controllers.HudController)
local InventoryController = require(Controllers.InventoryController)
local PortalController = require(Controllers.PortalController)
local RaidController = require(Controllers.RaidController)
local BoostController = require(Controllers.BoostController)
local FollowerController = require(Controllers.FollowerController)
local AmbienceController = require(Controllers.AmbienceController)
local SeaController = require(Controllers.SeaController)
local CoinController = require(Controllers.CoinController)
local HitEffectController = require(Controllers.HitEffectController)
local RevealPreview = require(script.Parent.Dev.RevealPreview) -- TEMPORARY: remove before release

HudController.start()
EnemyController.start()
GachaController.start()
InventoryController.start()
PortalController.start()
RaidController.start()
BoostController.start()
FollowerController.start()
AmbienceController.start()
SeaController.start()
CoinController.start()
HitEffectController.start()
RevealPreview.start()

print("[AnimeLegends] Client started")
