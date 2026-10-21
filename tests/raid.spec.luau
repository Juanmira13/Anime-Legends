-- Checks raid cooldowns, completions and achievements, rewards, boost drops
-- wave composition and random enemy spots on the arena field.
local RaidOps = require(Server.Raids.RaidOps)
local Raids = require(Shared.Config.Raids)
local RaidArenaLayout = require(Builder.RaidArenaLayout)
local PlayerRecord = require(Server.Data.PlayerRecord)

local failures = 0
local function check(label, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end
local function sequence(values)
	local index = 0
	return function()
		index += 1
		return values[index]
	end
end

local NOW = 1_000_000_000
local data = PlayerRecord.newData()

-- Cooldowns: 1 h, 1 h 30 min, 2 h, independent per difficulty
check("never played is ready", RaidOps.canStart(data, "Easy", NOW), true)
RaidOps.markStarted(data, "Easy", NOW)
check("easy on cooldown", RaidOps.canStart(data, "Easy", NOW + 3599), false)
check("easy ready after 1h", RaidOps.canStart(data, "Easy", NOW + 3600), true)
check("medium unaffected", RaidOps.canStart(data, "Medium", NOW + 1), true)
RaidOps.markStarted(data, "Medium", NOW)
check("medium ready at", RaidOps.readyAt(data, "Medium"), NOW + 5400)
RaidOps.markStarted(data, "Hard", NOW)
check("hard ready at", RaidOps.readyAt(data, "Hard"), NOW + 7200)

-- Completions and equip slot achievements (Easy 15, Medium 25, Hard 50)
local slots = PlayerRecord.newData()
for _ = 1, 14 do
	RaidOps.complete(slots, "Easy")
end
local before, after = RaidOps.complete(slots, "Easy")
check("15th easy completion", slots.Raids.Completions.Easy, 15)
check("slots before achievement", before, 3)
check("slots after achievement", after, 4)
before, after = RaidOps.complete(slots, "Easy")
check("16th easy gives nothing new", after - before, 0)
slots.Raids.Completions.Medium = 24
before, after = RaidOps.complete(slots, "Medium")
check("medium achievement", after, 5)
slots.Raids.Completions.Hard = 49
before, after = RaidOps.complete(slots, "Hard")
check("hard achievement reaches max", after, 6)

-- Rewards (docs/balance.md raid tables)
local yen, gems = RaidOps.reward("Easy", "Weak", 1, false, false)
check("easy weak yen", yen, 30)
check("easy weak gems", gems, 1)
yen, gems = RaidOps.reward("Hard", "Boss", 1, false, false)
check("hard boss yen", yen, 7000000)
check("hard boss gems", gems, 400)
yen, gems = RaidOps.reward("Medium", "MiniBoss", 1, true, true)
check("boosted yen", yen, 98000)
check("boosted gems", gems, 100)
yen, gems = RaidOps.reward("Easy", "Strong", 20, false, false)
check("wave 20 yen grows", yen, 320) -- 180 x 1.03^19 = 315.8, to 2 significant digits
check("wave 20 gems do not grow", gems, 5)

-- Boost drops: Easy weak 0.5%, boss always drops
check("no drop above chance", RaidOps.rollBoostDrop("Easy", "Weak", sequence({ 0.006 })), nil)
check("drop under chance", RaidOps.rollBoostDrop("Easy", "Weak", sequence({ 0.004, 0 })), "Luck")
check("drop picks second boost", RaidOps.rollBoostDrop("Easy", "Boss", sequence({ 0.99, 0.5 })), "Money")
check("drop picks last boost", RaidOps.rollBoostDrop("Hard", "Boss", sequence({ 0.5, 0.999 })), "Gems")
check("hard mini boss 50%", RaidOps.rollBoostDrop("Hard", "MiniBoss", sequence({ 0.49, 0 })), "Luck")
check("hard mini boss miss", RaidOps.rollBoostDrop("Hard", "MiniBoss", sequence({ 0.5 })), nil)

-- Waves
local function waveText(wave)
	local counts = {}
	for _, typeId in RaidOps.waveEnemies(wave) do
		counts[typeId] = (counts[typeId] or 0) + 1
	end
	return `{counts.Boss or 0}/{counts.MiniBoss or 0}/{counts.Strong or 0}/{counts.Medium or 0}/{counts.Weak or 0}`
end
for wave = 1, 20 do
	local expected = if wave == 10 then "0/1/1/2/4" elseif wave == 20 then "1/0/1/2/4" else "0/0/1/2/4"
	check(`wave {wave}`, waveText(wave), expected)
end
check("boss spawns first", RaidOps.waveEnemies(20)[1], "Boss")
check("mini boss spawns first", RaidOps.waveEnemies(10)[1], "MiniBoss")

-- Each wave a little tougher than the last: same small step, no jumps.
local Formulas = require(Shared.Formulas)
local function waveHealth(wave)
	local total = 0
	for _, typeId in RaidOps.waveEnemies(wave) do
		if typeId ~= "Boss" and typeId ~= "MiniBoss" then
			total += Raids.getEnemyType(typeId).timeToKill * Raids.waveScale(wave)
		end
	end
	return total
end
for wave = 2, Raids.WaveCount do
	local step = waveHealth(wave) / waveHealth(wave - 1)
	check(`wave {wave} grows a little`, step > 1 and step <= 1.05, true)
end
check(
	"wave 20 normal enemies tougher",
	Formulas.raidEnemyHealth("Easy", "Weak", 20) > Formulas.raidEnemyHealth("Easy", "Weak", 1),
	true
)

-- Bosses stand in the center (golden circle); the rest keep clear of it.
local function fixed(value)
	return function()
		return value
	end
end
for _, wave in { 10, 20 } do
	local typeIds = RaidOps.waveEnemies(wave)
	local spots = RaidOps.waveSpots(typeIds, RaidArenaLayout.floorRadius, {}, fixed(0.37))
	check(`wave {wave} spot count`, #spots, #typeIds)
	check(`wave {wave} boss in the center`, spots[1][1] == 0 and spots[1][2] == 0, true)
end

-- Random spots: inside the field edge, apart and clear of the arrival point
-- and the exit portal, for the biggest wave, on many seeds.
local function lcg(seed)
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end
local biggestWave = 0
for wave = 1, Raids.WaveCount do
	biggestWave = math.max(biggestWave, #RaidOps.waveEnemies(wave))
end
local layout = RaidArenaLayout
local clearances = {
	{ x = layout.playerSpawn[1], z = layout.playerSpawn[2], radius = Raids.Arena.spawnClearance },
	{ x = layout.exitPortal[1], z = layout.exitPortal[2], radius = Raids.Arena.exitClearance },
}
local inside, apart, clear, varied = true, true, true, false
local firstSpot = nil
for seed = 1, 200 do
	local spots = RaidOps.randomSpots(biggestWave, layout.floorRadius, clearances, lcg(seed))
	check(`random spots count seed {seed}`, #spots, biggestWave)
	for index, spot in spots do
		local x, z = spot[1], spot[2]
		inside = inside and math.sqrt(x * x + z * z) <= layout.floorRadius - Raids.Arena.wallMargin + 1e-6
		for _, zone in clearances do
			clear = clear and (x - zone.x) ^ 2 + (z - zone.z) ^ 2 >= zone.radius ^ 2
		end
		for other = index + 1, #spots do
			local gap = math.sqrt((x - spots[other][1]) ^ 2 + (z - spots[other][2]) ^ 2)
			apart = apart and gap >= Raids.Arena.enemyGap
		end
	end
	if firstSpot == nil then
		firstSpot = spots[1]
	elseif spots[1][1] ~= firstSpot[1] then
		varied = true
	end
end
check("random spots inside the field edge", inside, true)
check("random spots apart", apart, true)
check("random spots clear of arrival and exit", clear, true)
check("random spots change between waves", varied, true)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
