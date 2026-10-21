--!strict
-- Timing and motion of the gacha reveal, drawn full screen over the HUD by
-- UI/GachaRevealView. A reveal goes:
--   intro  : the screen darkens and a golden star flies in;
--   charge : the star pulses, wobbles and shakes, climbing through the rarity
--            colors (Common, Uncommon, ...) up to the best rarity rolled;
--   burst  : white flash, shockwave ring and confetti; the star blows up;
--   reveal : one roll pops its card in with its rarity stars; ten rolls lay ten
--            face-down cards and flip them one by one, worst first, pausing
--            before each Legendary or better;
--   hold   : until a click or a few seconds pass; then the outro.
-- Rarer rolls charge longer and add more: shine on Legendary and up, double
-- light rays on Mythic and Secret, rainbow on Secret. A click skips ahead.
-- Plain numbers only (no Roblox types), so it can be unit tested. Distances are
-- in pixels of the 1050 x 620 base stage (Check-UI), scaled to the screen.

local GachaReveal = {}

export type Style = {
	order: number, -- 1 (Common) to 7 (Secret)
	charge: number, -- seconds the star charges
	hold: number, -- seconds a single card stays before closing by itself
	shake: number, -- pixels of screen shake at the end of the charge
	confetti: number, -- confetti pieces in the burst
	flash: number, -- strength of the white flash (0 to 1)
	shine: boolean, -- a light sweeps across the card
	rays: number, -- light ray layers behind the card (1 or 2)
	rainbow: boolean, -- colors cycle through the rainbow
}

export type Schedule = {
	order: { number }, -- result index shown in each slot (worst first, best last)
	starts: { number }, -- seconds after the reveal starts when each slot flips
	finish: number, -- seconds until the last card has flipped
}

local STYLES: { [string]: Style } = {
	Common = {
		order = 1,
		charge = 0.9,
		hold = 2.2,
		shake = 2,
		confetti = 16,
		flash = 0.35,
		shine = false,
		rays = 1,
		rainbow = false,
	},
	Uncommon = {
		order = 2,
		charge = 1.1,
		hold = 2.4,
		shake = 3,
		confetti = 20,
		flash = 0.45,
		shine = false,
		rays = 1,
		rainbow = false,
	},
	Rare = {
		order = 3,
		charge = 1.4,
		hold = 2.6,
		shake = 4,
		confetti = 26,
		flash = 0.55,
		shine = false,
		rays = 1,
		rainbow = false,
	},
	Epic = {
		order = 4,
		charge = 1.7,
		hold = 2.8,
		shake = 6,
		confetti = 32,
		flash = 0.65,
		shine = false,
		rays = 1,
		rainbow = false,
	},
	Legendary = {
		order = 5,
		charge = 2.1,
		hold = 3.4,
		shake = 8,
		confetti = 40,
		flash = 0.8,
		shine = true,
		rays = 1,
		rainbow = false,
	},
	Mythic = {
		order = 6,
		charge = 2.5,
		hold = 3.8,
		shake = 11,
		confetti = 48,
		flash = 0.9,
		shine = true,
		rays = 2,
		rainbow = false,
	},
	Secret = {
		order = 7,
		charge = 3.0,
		hold = 4.5,
		shake = 14,
		confetti = 60,
		flash = 1,
		shine = true,
		rays = 2,
		rainbow = true,
	},
}

GachaReveal.INTRO = 0.45 -- seconds
GachaReveal.BURST = 0.55
GachaReveal.OUTRO = 0.3
GachaReveal.REVEAL_DELAY = 0.12 -- cards appear this long into the burst, under the flash
GachaReveal.MIN_SKIP_AGE = 0.25 -- seconds before a click can skip (the roll button press is not a skip)

GachaReveal.STAR_START_Y = 260 -- pixels below the center where the star flies in from
GachaReveal.CHARGE_GROWTH = 0.25 -- the star grows by this fraction while charging
GachaReveal.TICK_TIME = 0.4 -- seconds a climb ring lasts

GachaReveal.CARD_POP = 0.45 -- seconds a card takes to pop in
GachaReveal.STAR_GAP = 0.08 -- seconds between the rarity stars on a card
GachaReveal.MULTI_HOLD = 5 -- seconds ten cards stay before closing by themselves
GachaReveal.BACK_GAP = 0.04 -- seconds between face-down cards landing
GachaReveal.FLIP_TIME = 0.24 -- seconds a card takes to flip
GachaReveal.FLIP_GAP = 0.16 -- seconds between flips
GachaReveal.RARE_PAUSE = 0.45 -- extra suspense before a Legendary or better flips
GachaReveal.RARE_ORDER = 5 -- Legendary

GachaReveal.CONFETTI_LIFE = 1.3 -- seconds
GachaReveal.CONFETTI_SPEED = 620 -- pixels per second at launch
GachaReveal.CONFETTI_GRAVITY = 420 -- pixels per second squared

GachaReveal.COLUMNS = 5 -- cards per row for ten rolls
GachaReveal.MULTI_SCALE = 0.5 -- size of each card for ten rolls
GachaReveal.CARD_SIZE = { 300, 420 } -- pixels of a single card
GachaReveal.CARD_GAP = 18

GachaReveal.SHINE_PERIOD = 1.8 -- seconds per light sweep
GachaReveal.RAINBOW_SPEED = 0.35 -- rainbow cycles per second

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

-- Ease out with a small overshoot (like Enum.EasingStyle.Back).
local function backOut(t: number): number
	local c = 1.70158
	t = clamp01(t) - 1
	return 1 + (c + 1) * t ^ 3 + c * t ^ 2
end

-- Look and timing of a rarity (unknown ids look Common).
function GachaReveal.style(rarityId: string): Style
	return STYLES[rarityId] or STYLES.Common
end

-- The best rarity among `rarities` (the one the charge climbs to).
function GachaReveal.best(rarities: { string }): string
	local best = "Common"
	for _, id in rarities do
		if GachaReveal.style(id).order > GachaReveal.style(best).order then
			best = id
		end
	end
	return best
end

-- Intro `t` seconds in: backdrop transparency, star scale and star height
-- (pixels below the center).
function GachaReveal.introAt(t: number): (number, number, number)
	local p = clamp01(t / GachaReveal.INTRO)
	local eased = backOut(p)
	return 1 - 0.75 * p, eased, GachaReveal.STAR_START_Y * (1 - eased)
end

-- How many rarity colors the charge has climbed `age` seconds in (1 at the
-- start, the rarity's order at the end, one step per equal slice).
function GachaReveal.climbAt(rarityId: string, age: number): number
	local style = GachaReveal.style(rarityId)
	local p = clamp01(age / style.charge)
	return math.min(style.order, 1 + math.floor(p * style.order))
end

-- Star during the charge, `age` seconds in: scale, wobble (degrees) and screen
-- shake amplitude (pixels). The pulse quickens and everything grows toward the burst.
function GachaReveal.chargeAt(rarityId: string, age: number): (number, number, number)
	local style = GachaReveal.style(rarityId)
	local p = clamp01(age / style.charge)
	local frequency = 2 + 7 * p -- pulses per second
	local pulse = 0.06 * math.sin(age * frequency * 2 * math.pi)
	local scale = 1 + GachaReveal.CHARGE_GROWTH * p + pulse
	local wobble = math.sin(age * 23) * (3 + 12 * p)
	return scale, wobble, style.shake * p * p
end

-- A climb ring `t` seconds after its step: scale and transparency.
function GachaReveal.tickAt(t: number): (number, number)
	local p = clamp01(t / GachaReveal.TICK_TIME)
	return 0.7 + 1.3 * (1 - (1 - p) ^ 2), p
end

-- Burst, `t` seconds in: flash transparency, ring scale, ring transparency,
-- star scale and star transparency.
function GachaReveal.burstAt(rarityId: string, t: number): (number, number, number, number, number)
	local p = clamp01(t / GachaReveal.BURST)
	local eased = 1 - (1 - p) ^ 3
	local flash = 1 - GachaReveal.style(rarityId).flash * (1 - p) ^ 2
	return flash, 0.3 + 3.2 * eased, p, 1.25 + 1.6 * eased, clamp01(p * 1.6)
end

-- Screen shake offset (pixels, x and y) for an amplitude at a moment in time,
-- never beyond the amplitude.
function GachaReveal.shakeOffset(amplitude: number, age: number): (number, number)
	local x = (math.sin(age * 61) * 0.6 + math.sin(age * 37) * 0.4) * amplitude
	local y = (math.cos(age * 53) * 0.6 + math.sin(age * 29) * 0.4) * amplitude
	return x, y
end

-- Confetti piece `index` of `count`, `t` seconds after the burst: position
-- (pixels from the center), rotation (degrees) and transparency. Pieces fly out
-- in a ring with some spread, slow down, fall and fade.
function GachaReveal.confettiAt(index: number, count: number, t: number): (number, number, number, number)
	local spread = (index * 0.618034) % 1 -- golden ratio: evenly mixed, no randomness
	local angle = (index - 1) / count * 2 * math.pi + (spread - 0.5) * 0.5
	local speed = GachaReveal.CONFETTI_SPEED * (0.55 + 0.45 * spread)
	local drag = 3
	local distance = speed * (1 - math.exp(-drag * t)) / drag
	local x = math.cos(angle) * distance
	local y = math.sin(angle) * distance + 0.5 * GachaReveal.CONFETTI_GRAVITY * t * t
	local fadeStart = GachaReveal.CONFETTI_LIFE * 0.5
	local transparency = clamp01((t - fadeStart) / (GachaReveal.CONFETTI_LIFE - fadeStart))
	return x, y, 45 + t * 360 * (spread - 0.5) * 2, transparency
end

-- Scale of a card `t` seconds after it starts popping in.
function GachaReveal.popAt(t: number): number
	if t <= 0 then
		return 0
	end
	return backOut(t / GachaReveal.CARD_POP)
end

-- Scale of rarity star `index` on a single card, `t` seconds after the card started popping.
function GachaReveal.starPopAt(index: number, t: number): number
	return GachaReveal.popAt(t - GachaReveal.CARD_POP * 0.6 - (index - 1) * GachaReveal.STAR_GAP)
end

-- Seconds a single card takes to finish popping, stars included.
function GachaReveal.singleRevealTime(rarityId: string): number
	return GachaReveal.CARD_POP * 1.6 + (GachaReveal.style(rarityId).order - 1) * GachaReveal.STAR_GAP
end

-- A card flipping, `t` seconds after its flip starts: width factor (1 = flat
-- face on, 0 = edge on) and whether its front shows.
function GachaReveal.flipAt(t: number): (number, boolean)
	if t <= 0 then
		return 1, false
	end
	local p = clamp01(t / GachaReveal.FLIP_TIME)
	if p < 0.5 then
		return 1 - p * 2, false
	end
	return (p - 0.5) * 2, true
end

-- Order and timing of ten (or any number of) cards: worst first so the best
-- flips last, with a pause before each Legendary or better. Equal rarities
-- keep their roll order.
function GachaReveal.schedule(rarities: { string }): Schedule
	local order = {}
	for index in rarities do
		order[index] = index
	end
	table.sort(order, function(a, b)
		local orderA, orderB = GachaReveal.style(rarities[a]).order, GachaReveal.style(rarities[b]).order
		if orderA ~= orderB then
			return orderA < orderB
		end
		return a < b
	end)
	-- The face-down cards land first, then the flips begin.
	local time = GachaReveal.BACK_GAP * #rarities + GachaReveal.CARD_POP * 0.6
	local starts = {}
	for slot, index in order do
		if GachaReveal.style(rarities[index]).order >= GachaReveal.RARE_ORDER then
			time += GachaReveal.RARE_PAUSE
		end
		starts[slot] = time
		time += GachaReveal.FLIP_GAP
	end
	local last = starts[#starts] or 0
	return { order = order, starts = starts, finish = last + GachaReveal.FLIP_TIME }
end

-- Where card `slot` of `count` sits (pixels from the center) and its scale.
function GachaReveal.layout(slot: number, count: number): (number, number, number)
	if count <= 1 then
		return 0, 0, 1
	end
	local scale = GachaReveal.MULTI_SCALE
	local columns = math.min(count, GachaReveal.COLUMNS)
	local rows = math.ceil(count / columns)
	local stepX = GachaReveal.CARD_SIZE[1] * scale + GachaReveal.CARD_GAP
	local stepY = GachaReveal.CARD_SIZE[2] * scale + GachaReveal.CARD_GAP
	local column = (slot - 1) % columns
	local row = (slot - 1) // columns
	return (column - (columns - 1) / 2) * stepX, (row - (rows - 1) / 2) * stepY, scale
end

-- Seconds the cards stay before closing by themselves.
function GachaReveal.holdTime(rarities: { string }): number
	if #rarities > 1 then
		return GachaReveal.MULTI_HOLD
	end
	return GachaReveal.style(rarities[1] or "Common").hold
end

-- Offset (-1 to 1) of the light sweeping across a card at a moment.
function GachaReveal.shineAt(age: number): number
	return ((age / GachaReveal.SHINE_PERIOD) % 1) * 2 - 1
end

-- Rainbow hue (0 to 1) at a moment, for Color3.fromHSV.
function GachaReveal.rainbowHue(age: number): number
	return (age * GachaReveal.RAINBOW_SPEED) % 1
end

-- Whether a click skips ahead `age` seconds after the reveal started.
function GachaReveal.canSkip(age: number): boolean
	return age >= GachaReveal.MIN_SKIP_AGE
end

return GachaReveal
