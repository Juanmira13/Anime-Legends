-- Checks how damage numbers and hit flashes look and move (HitStyle).
local HitStyle = require(Client.Effects.HitStyle)
local FollowerMotion = require(Client.Followers.FollowerMotion)
local Rarities = require(Shared.Config.Rarities)

local failures = 0
local function check(label, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end
local function near(label, actual, expected)
	if math.abs(actual - expected) > 1e-6 then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end

-- Numbers pop, rise and fade.
local rise, scale, fade = HitStyle.numberAt(0)
near("starts on the enemy", rise, 0)
near("starts popped", scale, HitStyle.POP_SCALE)
near("starts solid", fade, 0)
rise, scale, fade = HitStyle.numberAt(HitStyle.POP_TIME)
near("pop settles", scale, 1)
check("solid until the fade", fade, 0)
rise, scale, fade = HitStyle.numberAt(HitStyle.LIFETIME)
near("rises all the way", rise, HitStyle.RISE)
near("gone at the end", fade, 1)
local previous = -1
local rising = true
for step = 0, 20 do
	local value = HitStyle.numberAt(step / 20 * HitStyle.LIFETIME)
	rising = rising and value >= previous
	previous = value
end
check("always rising", rising, true)
check("fades after the pop", HitStyle.FADE_START > HitStyle.POP_TIME, true)

-- Own hits are big and solid; other players' hits smaller and fainter; rare hits bigger.
local ownHeight, ownTransparency = HitStyle.size(true, "Common")
local otherHeight, otherTransparency = HitStyle.size(false, "Common")
check("own solid", ownTransparency, 0)
check("others smaller", otherHeight < ownHeight, true)
check("others fainter", otherTransparency > 0, true)
for _, rarity in Rarities.List do
	local height = HitStyle.size(true, rarity.id)
	local big = rarity.id == "Legendary" or rarity.id == "Mythic" or rarity.id == "Secret"
	check(`{rarity.id} size`, height > ownHeight, big)
end
near("unknown rarity is normal", (HitStyle.size(true, nil)), ownHeight)

-- Limits: own hits nearly always; others only nearby and within their share.
check("own hit shown", HitStyle.shouldShow(true, 50, 10, 5), true)
check("own hit too far", HitStyle.shouldShow(true, HitStyle.OWN_DISTANCE + 1, 0, 0), false)
check("too many numbers", HitStyle.shouldShow(true, 10, HitStyle.MAX_NUMBERS, 0), false)
check("other hit nearby", HitStyle.shouldShow(false, 30, 10, 5), true)
check("other hit far", HitStyle.shouldShow(false, HitStyle.OTHER_DISTANCE + 1, 0, 0), false)
check("others capped", HitStyle.shouldShow(false, 30, 30, HitStyle.MAX_OTHER_NUMBERS), false)

-- Consecutive hits spread sideways instead of stacking.
check("first hit centered", HitStyle.jitter(1), 0)
check("second right", HitStyle.jitter(2) > 0, true)
check("third left", HitStyle.jitter(3) < 0, true)
local spread = true
for index = 1, 30 do
	spread = spread and math.abs(HitStyle.jitter(index)) <= HitStyle.JITTER
end
check("jitter bounded", spread, true)

-- Impact flash grows and fades out quickly.
local size0, transparency0 = HitStyle.flashAt(0)
local size1, transparency1 = HitStyle.flashAt(HitStyle.FLASH_TIME)
near("flash starts small", size0, HitStyle.FLASH_SIZE[1])
near("flash ends big", size1, HitStyle.FLASH_SIZE[2])
check("flash fades", transparency1 > transparency0, true)
near("flash gone", transparency1, 1)

-- A number lives longer than the fastest cooldown's lunge, so every hit is seen.
check("number outlives a lunge", HitStyle.LIFETIME > FollowerMotion.lungeDuration(), true)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
