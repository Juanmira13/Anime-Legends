-- Checks raid cooldowns, completions and achievements, rewards, boost drops
-- and wave composition.
local RaidOps = require(Server.Raids.RaidOps)
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
local yen, gems = RaidOps.reward("Easy", "Weak", false, false)
check("easy weak yen", yen, 30)
check("easy weak gems", gems, 1)
yen, gems = RaidOps.reward("Hard", "Boss", false, false)
check("hard boss yen", yen, 7000000)
check("hard boss gems", gems, 400)
yen, gems = RaidOps.reward("Medium", "MiniBoss", true, true)
check("boosted yen", yen, 98000)
check("boosted gems", gems, 100)

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
	return `{counts.Boss or 0}/{counts.MiniBoss or 0}/{counts.Medium or 0}/{counts.Weak or 0}`
end
check("wave 1", waveText(1), "0/0/0/10")
check("wave 7", waveText(7), "0/0/4/6")
check("wave 10 mini boss", waveText(10), "0/1/4/0")
check("wave 12", waveText(12), "0/0/6/4")
check("wave 18", waveText(18), "0/0/10/0")
check("wave 20 boss", waveText(20), "1/0/6/0")
check("boss spawns first", RaidOps.waveEnemies(20)[1], "Boss")
check("mini boss spawns first", RaidOps.waveEnemies(10)[1], "MiniBoss")

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
