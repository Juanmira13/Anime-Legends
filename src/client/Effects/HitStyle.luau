--!strict
-- How hit effects look and move: damage numbers that pop, rise and fade over
-- the enemy when a character's lunge connects, an impact flash, and limits so a
-- crowded fight stays readable and cheap. Plain numbers only (no Roblox types),
-- so it can be unit tested; HitEffectController draws them.

local HitStyle = {}

-- Timing. A number appears when the lunge connects (FollowerMotion.LUNGE_IN_TIME).
HitStyle.LIFETIME = 0.9 -- seconds a damage number lives
HitStyle.POP_TIME = 0.12 -- seconds of the pop at the start
HitStyle.POP_SCALE = 1.5 -- size at the very start of the pop
HitStyle.FADE_START = 0.55 -- seconds before it starts fading
HitStyle.RISE = 3.5 -- studs it rises over its life

-- Size of a number, in studs of height (BillboardGui sized in the world).
HitStyle.OWN_HEIGHT = 2.2
HitStyle.OTHER_SCALE = 0.6 -- other players' hits are smaller...
HitStyle.OTHER_TRANSPARENCY = 0.35 -- ...and fainter
HitStyle.RARE_SCALE = 1.25 -- Legendary and up hit with bigger numbers
HitStyle.JITTER = 1.6 -- studs of sideways spread so stacked hits do not overlap

-- Limits.
HitStyle.MAX_NUMBERS = 60 -- damage numbers alive at once
HitStyle.MAX_OTHER_NUMBERS = 25 -- of those, from other players
HitStyle.OTHER_DISTANCE = 80 -- studs from the camera to show other players' hits
HitStyle.OWN_DISTANCE = 200

-- Impact flash.
HitStyle.FLASH_TIME = 0.18 -- seconds
HitStyle.FLASH_SIZE = { 1, 4 } -- studs, from start to end

local BIG_RARITIES: { [string]: boolean } = { Legendary = true, Mythic = true, Secret = true }

-- Whether a hit should get a damage number, given who hit, the distance from
-- the camera and how many numbers (total and from others) are already shown.
function HitStyle.shouldShow(isOwn: boolean, distance: number, active: number, activeOthers: number): boolean
	if active >= HitStyle.MAX_NUMBERS then
		return false
	end
	if isOwn then
		return distance <= HitStyle.OWN_DISTANCE
	end
	return distance <= HitStyle.OTHER_DISTANCE and activeOthers < HitStyle.MAX_OTHER_NUMBERS
end

-- Height in studs and base transparency of a number.
function HitStyle.size(isOwn: boolean, rarityId: string?): (number, number)
	local height = HitStyle.OWN_HEIGHT
	if rarityId and BIG_RARITIES[rarityId] then
		height *= HitStyle.RARE_SCALE
	end
	if isOwn then
		return height, 0
	end
	return height * HitStyle.OTHER_SCALE, HitStyle.OTHER_TRANSPARENCY
end

-- State of a number `age` seconds after it appeared: how far it has risen
-- (studs), its scale and how transparent it is (0 = solid, 1 = gone).
function HitStyle.numberAt(age: number): (number, number, number)
	local t = math.clamp(age / HitStyle.LIFETIME, 0, 1)
	-- Ease out: fast at first, then floats.
	local rise = HitStyle.RISE * (1 - (1 - t) ^ 2)
	local scale = 1
	if age < HitStyle.POP_TIME then
		scale = HitStyle.POP_SCALE - (HitStyle.POP_SCALE - 1) * (age / HitStyle.POP_TIME)
	end
	local fade = 0
	if age > HitStyle.FADE_START then
		fade = math.clamp((age - HitStyle.FADE_START) / (HitStyle.LIFETIME - HitStyle.FADE_START), 0, 1)
	end
	return rise, scale, fade
end

-- Sideways offset (studs) of the n-th number on an enemy, so consecutive hits
-- spread left and right instead of stacking: 0, +j, -j, +j/2, -j/2, ...
function HitStyle.jitter(index: number): number
	local pattern = { 0, 1, -1, 0.5, -0.5, 0.75, -0.75, 0.25, -0.25 }
	return pattern[(index - 1) % #pattern + 1] * HitStyle.JITTER
end

-- Impact flash `age` seconds after the hit: diameter (studs) and transparency.
function HitStyle.flashAt(age: number): (number, number)
	local t = math.clamp(age / HitStyle.FLASH_TIME, 0, 1)
	local size = HitStyle.FLASH_SIZE[1] + (HitStyle.FLASH_SIZE[2] - HitStyle.FLASH_SIZE[1]) * t
	return size, 0.2 + 0.8 * t
end

return HitStyle
