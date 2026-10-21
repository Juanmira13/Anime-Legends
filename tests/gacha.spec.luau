-- Checks gacha chances, the Luck boost, pity and roll distribution.
local GachaRoll = require(Server.Gacha.GachaRoll)
local Balance = require(Shared.Config.Balance)
local Formulas = require(Shared.Formulas)

local failures = 0
local function check(label, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end
local function near(label, actual, expected, tolerance)
	if math.abs(actual - expected) > tolerance then
		failures += 1
		print(`FAIL {label}: expected {expected} ± {tolerance}, got {actual}`)
	end
end
local function total(chances)
	local sum = 0
	for _, chance in chances do
		sum += chance
	end
	return sum
end
local function constant(value)
	return function()
		return value
	end
end

-- Chances
local base = GachaRoll.getChances(false)
near("base total", total(base), 100, 1e-9)
check("base common", base.Common, 50)
check("base secret", base.Secret, 0.1)
local lucky = GachaRoll.getChances(true)
near("luck total", total(lucky), 100, 1e-9)
check("luck legendary", lucky.Legendary, 4)
check("luck mythic", lucky.Mythic, 2)
near("luck secret", lucky.Secret, 0.2, 1e-12)
near("luck takes from common", lucky.Common, 46.9, 1e-9)
check("luck keeps rare", lucky.Rare, 13.9)

-- Mapping of random values to rarities. Cumulative tiers: Common < 50,
-- Uncommon < 75, Rare < 88.9, Epic < 96.9, Legendary < 98.9, Mythic < 99.9, Secret.
-- Values sit inside each range, away from the float-sensitive boundaries.
check("0 is common", GachaRoll.roll({}, false, constant(0)), "Common")
check("0.49 is common", GachaRoll.roll({}, false, constant(0.49)), "Common")
check("0.5 is uncommon", GachaRoll.roll({}, false, constant(0.5)), "Uncommon")
check("0.8 is rare", GachaRoll.roll({}, false, constant(0.8)), "Rare")
check("0.9 is epic", GachaRoll.roll({}, false, constant(0.9)), "Epic")
check("0.98 is legendary", GachaRoll.roll({}, false, constant(0.98)), "Legendary")
check("0.995 is mythic", GachaRoll.roll({}, false, constant(0.995)), "Mythic")
check("0.9995 is secret", GachaRoll.roll({}, false, constant(0.9995)), "Secret")
check("luck shifts the boundary", GachaRoll.roll({}, true, constant(0.95)), "Legendary")

-- Counters
local counters = {}
GachaRoll.roll(counters, false, constant(0))
check("roll adds to legendary counter", counters.Legendary, 1)
check("roll adds to mythic counter", counters.Mythic, 1)
check("roll adds to secret counter", counters.Secret, 1)
check("no counter for common", counters.Common, nil)
counters = { Legendary = 10, Mythic = 10, Secret = 10 }
check("natural legendary", GachaRoll.roll(counters, false, constant(0.98)), "Legendary")
check("legendary counter resets", counters.Legendary, 0)
check("mythic counter keeps counting", counters.Mythic, 11)

-- Pity guarantees on the threshold-th roll without a hit
counters = { Legendary = Balance.Pity.Legendary - 2, Mythic = 0, Secret = 0 }
check("one before pity is random", GachaRoll.roll(counters, false, constant(0)), "Common")
check("pity legendary", GachaRoll.roll(counters, false, constant(0)), "Legendary")
check("pity resets counter", counters.Legendary, 0)
counters = { Legendary = Balance.Pity.Legendary - 1, Mythic = Balance.Pity.Mythic - 1, Secret = 0 }
check("highest pity wins", GachaRoll.roll(counters, false, constant(0)), "Mythic")
check("lower pity carries over", GachaRoll.roll(counters, false, constant(0)), "Legendary")
counters = { Legendary = 0, Mythic = 0, Secret = Balance.Pity.Secret - 1 }
check("pity secret", GachaRoll.roll(counters, false, constant(0)), "Secret")

-- Distribution over many rolls with a deterministic generator (Park–Miller;
-- products stay below 2^53, so the arithmetic is exact in doubles).
local seed = 12345
local function lcg()
	seed = (seed * 16807) % 2147483647
	return seed / 2147483647
end
local rolls = 200000
local counts = {}
counters = {}
for _ = 1, rolls do
	local rarity = GachaRoll.roll(counters, false, lcg)
	counts[rarity] = (counts[rarity] or 0) + 1
end
for rarity, chance in base do
	-- Legendary pity at 500 slightly raises its rate above 2%, so allow more there.
	local tolerance = if rarity == "Legendary" then 0.3 else 0.25
	near(`distribution {rarity}`, (counts[rarity] or 0) / rolls * 100, chance, tolerance)
end

-- Ten rolls at once are exactly ten single rolls in a row (pity included).
local manyCounters, singleCounters = {}, {}
seed = 777
local many = GachaRoll.rollMany(manyCounters, true, Balance.GachaMultiRoll, lcg)
seed = 777
check("multi roll count", #many, Balance.GachaMultiRoll)
for index = 1, Balance.GachaMultiRoll do
	check(`multi roll {index} like a single roll`, many[index], GachaRoll.roll(singleCounters, true, lcg))
end
for rarity, value in manyCounters do
	check(`multi roll pity {rarity}`, value, singleCounters[rarity])
end
local almost = { Legendary = Balance.Pity.Legendary - 3 }
local pityRolls = GachaRoll.rollMany(almost, false, 10, constant(0))
check("pity reached inside a multi roll", pityRolls[3], "Legendary")
check("rolls before it are normal", pityRolls[2], "Common")
check("pity counts on after it", almost.Legendary, 7)

-- Ten rolls cost exactly ten single rolls; the client shows the server's chances.
check("multi roll is ten", Balance.GachaMultiRoll, 10)
check("one roll cost", Formulas.gachaCost("Nameku", 1), Formulas.gachaCost("Nameku"))
check("ten rolls cost", Formulas.gachaCost("Nameku", 10), Formulas.gachaCost("Nameku") * 10)
check("ten rolls on Kono", Formulas.gachaCost("Kono", 10), Formulas.gachaCost("Kono") * 10)
check("same chances as the client", GachaRoll.getChances, Formulas.gachaChances)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
