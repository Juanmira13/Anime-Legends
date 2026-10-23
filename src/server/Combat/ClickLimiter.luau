--!strict
-- Caps Attack button clicks per player: at most `max` accepted in any
-- one-second window, so an autoclicker cannot go past the limit. Pure, so it
-- can be unit tested.

export type Limiter = {
	windowStart: number,
	count: number,
}

local ClickLimiter = {}

function ClickLimiter.new(): Limiter
	return { windowStart = -math.huge, count = 0 }
end

-- Whether a click at `now` (seconds) counts; counts it if so.
function ClickLimiter.allow(limiter: Limiter, now: number, max: number): boolean
	if now - limiter.windowStart >= 1 then
		limiter.windowStart = now
		limiter.count = 0
	end
	if limiter.count >= max then
		return false
	end
	limiter.count += 1
	return true
end

return ClickLimiter
