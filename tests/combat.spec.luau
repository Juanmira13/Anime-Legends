-- Checks attack timing, kill rewards and number formatting.
local AttackClock = require(Server.Combat.AttackClock)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local failures = 0
local function check(label, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end

local function hitsAt(clock, attackers, now)
	return table.concat(AttackClock.collectHits(clock, attackers, now), ",")
end

-- Attack timing
local clock = AttackClock.new()
local team = { { uid = "a", cooldown = 2 }, { uid = "b", cooldown = 1 } }
check("first hits are immediate", hitsAt(clock, team, 0), "a,b")
check("nothing before cooldown", hitsAt(clock, team, 0.5), "")
check("fast character hits at 1s", hitsAt(clock, team, 1), "b")
check("slow character hits at 2s", hitsAt(clock, team, 2), "a,b")
check("no double hit same time", hitsAt(clock, team, 2), "")

-- Re-equipping does not reset the cooldown
check("unequipped character does not hit", hitsAt(clock, { team[2] }, 3), "b")
check("re-equipped keeps cooldown", hitsAt(clock, team, 3.5), "")
check("re-equipped hits when ready", hitsAt(clock, team, 4), "a,b")

-- Damage over time matches cooldowns: a 2s cooldown hits 5 times in 0..8s.
local count = 0
local timing = AttackClock.new()
for frame = 0, 8 * 60 do
	count += #AttackClock.collectHits(timing, { { uid = "x", cooldown = 2 } }, frame / 60)
end
check("hits over 8 seconds", count, 5)

-- Kill rewards
check("reward Nameku Easy", Formulas.killReward("Nameku", "Easy", false), 5)
check("reward with money boost", Formulas.killReward("Nameku", "Easy", true), 10)
check("reward Demon Corps Boss", Formulas.killReward("DemonCorps", "Boss", false), 2300000)
check("respawn normal", Formulas.enemyRespawnTime("Hard"), 20)
check("respawn boss", Formulas.enemyRespawnTime("Boss"), 60)

-- Number formatting
check("format small", Format.number(950), "950")
check("format zero", Format.number(0), "0")
check("format thousand", Format.number(1000), "1K")
check("format decimal", Format.number(1500), "1.5K")
check("format truncates", Format.number(999999), "999.9K")
check("format 2.9K", Format.number(2900), "2.9K")
check("format million", Format.number(2300000), "2.3M")
check("format billion", Format.number(21000000000), "21B")
check("format trillion", Format.number(4e12), "4T")
check("format fraction", Format.number(12.7), "12")

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
