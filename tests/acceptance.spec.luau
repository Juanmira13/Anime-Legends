-- Acceptance criteria of docs/spec.md (R1..R9) that can be checked outside
-- Studio, one block per requirement. If the spec changes, update this file.
local Formulas = require(Shared.Formulas)
local Balance = require(Shared.Config.Balance)
local Boosts = require(Shared.Config.Boosts)
local Raids = require(Shared.Config.Raids)
local Islands = require(Shared.Data.Islands)
local Characters = require(Shared.Data.Characters)
local PlayerRecord = require(Server.Data.PlayerRecord)
local AttackClock = require(Server.Combat.AttackClock)
local GachaRoll = require(Server.Gacha.GachaRoll)
local InventoryOps = require(Server.Inventory.InventoryOps)
local PortalOps = require(Server.Portals.PortalOps)
local RaidOps = require(Server.Raids.RaidOps)
local BoostOps = require(Server.Boosts.BoostOps)
local CoinOps = require(Server.Coins.CoinOps)

local failures = 0
local function check(label, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end

-- R1. A new player starts with 0 Yen, 0 Gems and Kurilin equipped.
local fresh = PlayerRecord.newData()
check("R1 starting yen", fresh.Yen, 0)
check("R1 starting gems", fresh.Gems, 0)
local team = InventoryOps.activeTeam(fresh)
check("R1 one character equipped", #team, 1)
check("R1 Kurilin equipped", Characters.get(team[1].id).displayName, "Kurilin")

-- R2. With Kurilin an Easy enemy of Nameku (170 health) loses 10 every 2 s,
-- gives 5 yen (10 with the Money boost) and respawns in 20 s (bosses 60 s);
-- attacks reach 60 studs.
check("R2 Nameku Easy health", Formulas.enemyHealth("Nameku", "Easy"), 170)
check("R2 Kurilin damage", Formulas.characterDamage("Krilin"), 10)
check("R2 Kurilin cooldown", Formulas.characterCooldown("Krilin"), 2)
local clock = AttackClock.new()
local attackers = { { uid = "1", cooldown = Formulas.characterCooldown("Krilin") } }
local hits = 0
for step = 0, 100 do -- 10 seconds in 0.1 s steps
	hits += #AttackClock.collectHits(clock, attackers, step / 10)
end
check("R2 Kurilin hits in 10 s", hits, 6) -- at 0, 2, 4, 6, 8 and 10 s
check("R2 Nameku Easy yen", Formulas.killReward("Nameku", "Easy", false), 5)
local coins = CoinOps.split(Formulas.killReward("Nameku", "Easy", false), Balance.Coins.maxPerDrop)
check("R2 the 5 yen drop as coins", #coins > 1 and coins[1] + coins[2] == 5, true)
check("R2 respawn normal", Formulas.enemyRespawnTime("Easy"), 20)
check("R2 respawn boss", Formulas.enemyRespawnTime("Boss"), 60)
check("R2 attack range", Balance.Combat.range, 60)

-- R3. A roll in Nameku costs 50 yen; pity at 500 / 5,000 / 1,000,000; Luck
-- doubles Legendary, Mythic and Secret, taken from Common.
check("R3 Nameku roll cost", Formulas.gachaCost("Nameku"), 50)
check("R3 pity Legendary", Balance.Pity.Legendary, 500)
check("R3 pity Mythic", Balance.Pity.Mythic, 5000)
check("R3 pity Secret", Balance.Pity.Secret, 1000000)
local normal, lucky = GachaRoll.getChances(false), GachaRoll.getChances(true)
for _, rarity in { "Legendary", "Mythic", "Secret" } do
	check(`R3 luck doubles {rarity}`, math.abs(lucky[rarity] - normal[rarity] * 2) < 1e-9, true)
end
local extra = normal.Legendary + normal.Mythic + normal.Secret
check("R3 luck taken from Common", math.abs(lucky.Common - (normal.Common - extra)) < 1e-9, true)

-- R4. 50 slots, +10 per upgrade costing x1.5 each, up to 250; 3 equip slots,
-- 6 at most.
check("R4 starting capacity", InventoryOps.capacity(fresh), 50)
check("R4 slots per upgrade", Formulas.inventorySlots(1) - Formulas.inventorySlots(0), 10)
check("R4 max capacity", Formulas.inventorySlots(Formulas.maxInventoryUpgrades()), 250)
check("R4 upgrade cost growth", Formulas.inventoryUpgradeCost(2) / Formulas.inventoryUpgradeCost(1), 1.5)
check("R4 starting equip slots", InventoryOps.equipSlots(fresh), 3)
check("R4 max equip slots", Formulas.equipSlots({ Easy = 15, Medium = 25, Hard = 50 }), 6)
local snapshot = InventoryOps.snapshot(fresh)
check(
	"R4 panel counts",
	`{#snapshot.characters}/{snapshot.capacity} {#snapshot.equipped}/{snapshot.equipSlots}`,
	"1/50 1/3"
)

-- R5. Six islands in order; Kono costs 2,700 yen; skipping an island fails.
local order = {}
for _, island in Islands.List do
	table.insert(order, island.id)
end
check("R5 island order", table.concat(order, ","), "Nameku,Kono,CloverKingdom,TitanVillage,HeroAcademy,DemonCorps")
check("R5 unlock Kono", PortalOps.unlockCost("Kono"), 2700)
local canSkip, skipReason = PortalOps.canUnlock(fresh, "CloverKingdom")
check("R5 cannot skip an island", canSkip, false)
check("R5 skip reason", skipReason, "PreviousLocked")

-- R6. Cooldowns 1 h / 1 h 30 / 2 h, up to 20 players, 20 waves (mini boss in
-- 10, boss in 20), 30 minutes; achievements 15 / 25 / 50 give +1 slot each.
check("R6 cooldown Easy", Raids.getDifficulty("Easy").cooldown, 3600)
check("R6 cooldown Medium", Raids.getDifficulty("Medium").cooldown, 5400)
check("R6 cooldown Hard", Raids.getDifficulty("Hard").cooldown, 7200)
check("R6 max players", Raids.MaxPlayers, 20)
check("R6 waves", Raids.WaveCount, 20)
check("R6 time limit", Raids.TimeLimit, 30 * 60)
local function has(list, typeId)
	return table.find(list, typeId) ~= nil
end
check("R6 mini boss in wave 10", has(RaidOps.waveEnemies(10), "MiniBoss"), true)
check("R6 boss in wave 20", has(RaidOps.waveEnemies(20), "Boss"), true)
for wave = 1, Raids.WaveCount do
	if wave ~= 10 and wave ~= 20 then
		local list = RaidOps.waveEnemies(wave)
		check(`R6 no boss in wave {wave}`, has(list, "Boss") or has(list, "MiniBoss"), false)
	end
end
local raider = PlayerRecord.newData()
RaidOps.markStarted(raider, "Easy", 1000)
check("R6 Easy ready an hour later", RaidOps.readyAt(raider, "Easy"), 1000 + 3600)
local slotsFor = { Easy = 15, Medium = 25, Hard = 50 }
for difficultyId, completions in slotsFor do
	local counts = { Easy = 0, Medium = 0, Hard = 0 }
	counts[difficultyId] = completions - 1
	check(`R6 {difficultyId} one short`, Formulas.equipSlots(counts), 3)
	counts[difficultyId] = completions
	check(`R6 {difficultyId} achievement`, Formulas.equipSlots(counts), 4)
end

-- R7. Luck, Money and Gems for 15 minutes, 125 / 200 / 300 gems; activating
-- adds 15 minutes; the Money boost doubles an Easy Nameku kill to 10 yen.
check("R7 Money price", Boosts.get("Money").gemPrice, 125)
check("R7 Luck price", Boosts.get("Luck").gemPrice, 200)
check("R7 Gems price", Boosts.get("Gems").gemPrice, 300)
local boosted = PlayerRecord.newData()
BoostOps.grant(boosted, "Money", 2)
BoostOps.activate(boosted, "Money")
check("R7 lasts 15 minutes", BoostOps.remaining(boosted, "Money"), 15 * 60)
BoostOps.activate(boosted, "Money")
check("R7 activating adds 15 minutes", BoostOps.remaining(boosted, "Money"), 30 * 60)
check("R7 Money boost kill", Formulas.killReward("Nameku", "Easy", true), 10)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
