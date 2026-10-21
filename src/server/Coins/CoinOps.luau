--!strict
-- Coin drops: how a yen reward is split into floating coins. Pure, so it can be
-- unit tested; CoinService keeps the drops and validates pickups.

local CoinOps = {}

-- Number of coins for a reward: more for bigger rewards (2 for single-digit
-- rewards, one more per digit), at most `maxCoins`, never more than whole yen.
function CoinOps.coinCount(amount: number, maxCoins: number): number
	if amount <= 0 then
		return 0
	end
	local count = math.clamp(math.floor(math.log10(amount)) + 2, 1, maxCoins)
	return math.max(1, math.min(count, math.floor(amount)))
end

-- Splits `amount` into coin values that add up to exactly `amount`: equal
-- whole shares, the leftover yen spread one by one over the first coins (and
-- any fraction on the first coin).
function CoinOps.split(amount: number, maxCoins: number): { number }
	local count = CoinOps.coinCount(amount, maxCoins)
	if count == 0 then
		return {}
	end
	local base = math.floor(amount / count)
	local values = table.create(count, base)
	local leftover = amount - base * count
	local extra = math.floor(leftover)
	for index = 1, extra do
		values[index] += 1
	end
	values[1] += leftover - extra
	return values
end

return CoinOps
