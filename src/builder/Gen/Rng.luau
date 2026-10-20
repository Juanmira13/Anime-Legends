--!strict
-- Seeded random numbers (xorshift32). Same seed, same island, everywhere:
-- unlike Roblox's Random, it also runs in the standalone Luau tests.

export type Rng = { state: number }

local Rng = {}

function Rng.new(seed: number): Rng
	local state = math.floor(seed) % 4294967296
	if state == 0 then
		state = 2463534242
	end
	return { state = state }
end

-- Next float in [0, 1).
function Rng.next(rng: Rng): number
	local x = rng.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	rng.state = x
	return x / 4294967296
end

-- Float in [min, max).
function Rng.range(rng: Rng, min: number, max: number): number
	return min + (max - min) * Rng.next(rng)
end

-- Integer in [min, max].
function Rng.int(rng: Rng, min: number, max: number): number
	return math.min(max, min + math.floor((max - min + 1) * Rng.next(rng)))
end

-- Random element of a non-empty list.
function Rng.pick<T>(rng: Rng, list: { T }): T
	return list[Rng.int(rng, 1, #list)]
end

return Rng
