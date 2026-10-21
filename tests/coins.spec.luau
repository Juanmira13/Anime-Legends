-- Checks how yen rewards split into floating coins.
local CoinOps = require(Server.Coins.CoinOps)
local Balance = require(Shared.Config.Balance)
local Formulas = require(Shared.Formulas)
local Islands = require(Shared.Data.Islands)

local failures = 0
local function check(label, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end
local function sum(values)
	local total = 0
	for _, value in values do
		total += value
	end
	return total
end

local MAX = Balance.Coins.maxPerDrop

-- Coin counts grow with the reward and stay within limits.
check("no coins for nothing", #CoinOps.split(0, MAX), 0)
check("one yen is one coin", #CoinOps.split(1, MAX), 1)
check("5 yen in 2 coins", #CoinOps.split(5, MAX), 2)
check("45 yen in 3 coins", #CoinOps.split(45, MAX), 3)
check("huge rewards capped", #CoinOps.split(2_300_000_000, MAX), MAX)

-- Values add up exactly and differ by at most one yen.
check("fraction adds up", math.abs(sum(CoinOps.split(7.5, MAX)) - 7.5) < 1e-9, true)
for _, amount in { 1, 2, 5, 7, 10, 45, 99, 101, 1234, 2_300_000 } do
	local values = CoinOps.split(amount, MAX)
	check(`split {amount} adds up`, sum(values), amount)
	local low, high = math.huge, -math.huge
	for _, value in values do
		low, high = math.min(low, value), math.max(high, value)
	end
	check(`split {amount} even`, high - low <= 1, true)
end

-- Every island enemy reward, with and without the Money boost, splits exactly.
for _, island in Islands.List do
	for _, rank in Balance.EnemyRanks do
		for _, boost in { false, true } do
			local reward = Formulas.killReward(island.id, rank.id, boost)
			check(`{island.id} {rank.id} {boost} coins`, sum(CoinOps.split(reward, MAX)), reward)
		end
	end
end

-- Pickup rules are sane: coins fly in before the server's range check.
check("magnet inside collect range", Balance.Coins.magnetRadius < Balance.Coins.collectRange, true)
check("coins last a while", Balance.Coins.lifetime >= 10, true)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
