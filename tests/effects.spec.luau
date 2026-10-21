-- Checks how damage numbers and hit flashes look and move (HitStyle), and how
-- gacha rolls are revealed (GachaReveal).
local GachaReveal = require(Client.Effects.GachaReveal)
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

-- Gacha reveal: every rarity has a style, and rarer rolls charge longer and are showier.
local previousStyle = nil
for _, rarity in Rarities.List do
	local style = GachaReveal.style(rarity.id)
	check(`{rarity.id} order`, style.order, rarity.order)
	if previousStyle then
		check(`{rarity.id} charges longer`, style.charge > previousStyle.charge, true)
		check(`{rarity.id} stays longer`, style.hold > previousStyle.hold, true)
		check(`{rarity.id} shakes more`, style.shake > previousStyle.shake, true)
		check(`{rarity.id} more confetti`, style.confetti > previousStyle.confetti, true)
		check(`{rarity.id} flashes brighter`, style.flash > previousStyle.flash, true)
	end
	check(`{rarity.id} shine`, style.shine, rarity.order >= GachaReveal.RARE_ORDER)
	check(`{rarity.id} double rays`, style.rays == 2, rarity.id == "Mythic" or rarity.id == "Secret")
	check(`{rarity.id} rainbow`, style.rainbow, rarity.id == "Secret")
	check(
		`{rarity.id} whole reveal under 10 s`,
		GachaReveal.INTRO + style.charge + GachaReveal.BURST + style.hold < 10,
		true
	)
	previousStyle = style
end
check("unknown rarity looks Common", GachaReveal.style("Nope"), GachaReveal.style("Common"))
check("best of a mix", GachaReveal.best({ "Common", "Epic", "Rare" }), "Epic")
check("best of nothing", GachaReveal.best({}), "Common")

-- Intro: the backdrop darkens and the star flies in from below.
local backdrop0, star0, drop0 = GachaReveal.introAt(0)
local backdrop1, star1, drop1 = GachaReveal.introAt(GachaReveal.INTRO)
near("backdrop starts clear", backdrop0, 1)
check("backdrop darkens", backdrop1 < 0.5, true)
near("star starts tiny", star0, 0)
near("star arrives full size", star1, 1)
near("star starts below", drop0, GachaReveal.STAR_START_Y)
near("star ends centered", drop1, 0)

-- Charge: climbs one rarity color per slice up to the result, faster and bigger.
for _, rarity in Rarities.List do
	local charge = GachaReveal.style(rarity.id).charge
	check(`{rarity.id} climb starts at Common`, GachaReveal.climbAt(rarity.id, 0), 1)
	check(`{rarity.id} climb ends at its color`, GachaReveal.climbAt(rarity.id, charge), rarity.order)
	local climbing = true
	local last = 0
	for step = 0, 40 do
		local value = GachaReveal.climbAt(rarity.id, step / 40 * charge)
		climbing = climbing and value >= last and value - last <= 1
		last = value
	end
	check(`{rarity.id} climbs one step at a time`, climbing, true)
end
local _, _, shakeStart = GachaReveal.chargeAt("Secret", 0)
local secretCharge = GachaReveal.style("Secret").charge
local scaleEnd, _, shakeEnd = GachaReveal.chargeAt("Secret", secretCharge)
near("no shake at first", shakeStart, 0)
near("full shake at the burst", shakeEnd, GachaReveal.style("Secret").shake)
check("star grows while charging", scaleEnd > 1.1, true)
local tickScale0, tickFade0 = GachaReveal.tickAt(0)
local tickScale1, tickFade1 = GachaReveal.tickAt(GachaReveal.TICK_TIME)
check("climb ring grows", tickScale1 > tickScale0, true)
near("climb ring starts solid", tickFade0, 0)
near("climb ring fades", tickFade1, 1)

-- Burst: strong flash at first, ring grows and fades, star blows up and vanishes.
local flash0, ring0, ringFade0, burstStar0 = GachaReveal.burstAt("Secret", 0)
local flash1, ring1, ringFade1, burstStar1, burstFade1 = GachaReveal.burstAt("Secret", GachaReveal.BURST)
near("Secret flash is full white", flash0, 0)
near("flash clears", flash1, 1)
check("Common flash is softer", (GachaReveal.burstAt("Common", 0)) > flash0, true)
check("ring grows", ring1 > ring0, true)
near("ring starts solid", ringFade0, 0)
near("ring fades", ringFade1, 1)
check("star blows up", burstStar1 > burstStar0, true)
near("star gone", burstFade1, 1)

-- Shake stays within its amplitude.
local bounded = true
for step = 0, 200 do
	local x, y = GachaReveal.shakeOffset(10, step / 60)
	bounded = bounded and math.abs(x) <= 10 + 1e-9 and math.abs(y) <= 10 + 1e-9
end
check("shake bounded", bounded, true)

-- Confetti flies out in every direction, falls and fades.
local pieces = 40
local sumX = 0
for index = 1, pieces do
	local x, _, _, pieceFade = GachaReveal.confettiAt(index, pieces, 0.3)
	sumX += x
	near(`confetti {index} solid early`, pieceFade, 0)
end
check("confetti spreads both ways", math.abs(sumX / pieces) < 60, true)
local _, yEarly = GachaReveal.confettiAt(1, pieces, 0.2)
local _, yLate = GachaReveal.confettiAt(1, pieces, 1.2)
check("confetti falls", yLate > yEarly, true)
local x0, y0 = GachaReveal.confettiAt(5, pieces, 0)
near("confetti starts at the star x", x0, 0)
near("confetti starts at the star y", y0, 0)
local _, _, _, fadeEnd = GachaReveal.confettiAt(5, pieces, GachaReveal.CONFETTI_LIFE)
near("confetti gone", fadeEnd, 1)

-- One card pops in with overshoot, then its stars one by one.
near("card hidden before", GachaReveal.popAt(0), 0)
near("card full size after the pop", GachaReveal.popAt(GachaReveal.CARD_POP), 1)
local overshoot = false
for step = 1, 20 do
	overshoot = overshoot or GachaReveal.popAt(step / 20 * GachaReveal.CARD_POP) > 1
end
check("card overshoots", overshoot, true)
check("first star after the card starts", GachaReveal.starPopAt(1, 0), 0)
check("stars in order", GachaReveal.starPopAt(1, 0.4) >= GachaReveal.starPopAt(2, 0.4), true)
near("last Secret star in place", GachaReveal.starPopAt(7, GachaReveal.singleRevealTime("Secret")), 1)

-- Flip: the back shrinks to the edge, then the front grows.
local width0, front0 = GachaReveal.flipAt(0)
local widthMid = GachaReveal.flipAt(GachaReveal.FLIP_TIME / 2)
local width1, front1 = GachaReveal.flipAt(GachaReveal.FLIP_TIME)
near("flat before the flip", width0, 1)
check("back first", front0, false)
near("edge on halfway", widthMid, 0)
near("flat after the flip", width1, 1)
check("front after", front1, true)

-- Ten cards: worst first, best last, a pause before each Legendary or better.
local ten = { "Rare", "Common", "Secret", "Common", "Legendary", "Uncommon", "Common", "Epic", "Common", "Mythic" }
local plan = GachaReveal.schedule(ten)
check("ten slots", #plan.order, 10)
check("best last", ten[plan.order[10]], "Secret")
check("worst first", ten[plan.order[1]], "Common")
check("equal rarities keep roll order", plan.order[1] < plan.order[2], true)
local sorted = true
local used = {}
for slot = 2, 10 do
	local current = GachaReveal.style(ten[plan.order[slot]]).order
	sorted = sorted and current >= GachaReveal.style(ten[plan.order[slot - 1]]).order
end
for _, index in plan.order do
	used[index] = true
end
check("sorted by rarity", sorted, true)
local all = true
for index = 1, 10 do
	all = all and used[index] == true
end
check("every roll shown once", all, true)
for slot = 2, 10 do
	local gap = plan.starts[slot] - plan.starts[slot - 1]
	local rare = GachaReveal.style(ten[plan.order[slot]]).order >= GachaReveal.RARE_ORDER
	near(`slot {slot} gap`, gap, GachaReveal.FLIP_GAP + (if rare then GachaReveal.RARE_PAUSE else 0))
end
check("flips start after the backs land", plan.starts[1] >= GachaReveal.BACK_GAP * 10, true)
near("finish after the last flip", plan.finish, plan.starts[10] + GachaReveal.FLIP_TIME)
check("ten cards reveal in under 5 s", plan.finish < 5, true)
check("one card: one slot", #GachaReveal.schedule({ "Rare" }).order, 1)

-- Layout: one card in the middle; ten in two rows of five, centered, inside the stage.
local x1, y1, s1 = GachaReveal.layout(1, 1)
near("single centered x", x1, 0)
near("single centered y", y1, 0)
near("single full size", s1, 1)
local sumLayoutX, sumLayoutY = 0, 0
local inside = true
for slot = 1, 10 do
	local x, y, s = GachaReveal.layout(slot, 10)
	sumLayoutX += x
	sumLayoutY += y
	near(`slot {slot} half size`, s, GachaReveal.MULTI_SCALE)
	local halfW, halfH = GachaReveal.CARD_SIZE[1] * s / 2, GachaReveal.CARD_SIZE[2] * s / 2
	inside = inside and math.abs(x) + halfW <= 525 and math.abs(y) + halfH <= 260
end
near("ten centered x", sumLayoutX, 0)
near("ten centered y", sumLayoutY, 0)
check("ten cards fit the stage", inside, true)
local ax, ay = GachaReveal.layout(1, 10)
local bx, by = GachaReveal.layout(2, 10)
local cx, cy = GachaReveal.layout(6, 10)
check("same row", ay, by)
check("next column to the right", bx > ax, true)
check("second row below", cy > ay, true)
near("second row lines up", cx, ax)
check("cards do not overlap", bx - ax >= GachaReveal.CARD_SIZE[1] * GachaReveal.MULTI_SCALE, true)

-- Hold, shine, rainbow and skip.
near("single hold", GachaReveal.holdTime({ "Epic" }), GachaReveal.style("Epic").hold)
near("ten hold", GachaReveal.holdTime(ten), GachaReveal.MULTI_HOLD)
local shines = true
for step = 0, 40 do
	local offset = GachaReveal.shineAt(step / 10)
	shines = shines and offset >= -1 and offset <= 1
end
check("shine in range", shines, true)
local hues = true
for step = 0, 50 do
	local hue = GachaReveal.rainbowHue(step / 7)
	hues = hues and hue >= 0 and hue < 1
end
check("rainbow hue in range", hues, true)
check("no skip at once", GachaReveal.canSkip(0), false)
check("skip later", GachaReveal.canSkip(GachaReveal.MIN_SKIP_AGE), true)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
