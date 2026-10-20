-- Checks the formation, attack arc, lunge timing and walking of visible characters.
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

local function offset(index, count)
	local right, back = FollowerMotion.formationOffset(index, count)
	return `{right},{back}`
end

-- Formation: rows of 3 centered behind the owner
check("single is centered", offset(1, 1), "0,6")
check("pair left", offset(1, 2), "-2.5,6")
check("pair right", offset(2, 2), "2.5,6")
check("row of three left", offset(1, 3), "-5,6")
check("row of three middle", offset(2, 3), "0,6")
check("row of three right", offset(3, 3), "5,6")
check("second row starts behind", offset(4, 4), "0,11")
check("second row of three", offset(6, 6), "5,11")
check("second row of two", offset(4, 5), "-2.5,11")

-- Attack arc: symmetric and within the arc
near("single faces owner", FollowerMotion.attackAngle(1, 1), 0)
near("arc start", FollowerMotion.attackAngle(1, 3), -FollowerMotion.ATTACK_ARC / 2)
near("arc middle", FollowerMotion.attackAngle(2, 3), 0)
near("arc end", FollowerMotion.attackAngle(3, 3), FollowerMotion.ATTACK_ARC / 2)
near("arc symmetric", FollowerMotion.attackAngle(2, 6), -FollowerMotion.attackAngle(5, 6))
near("radius keeps a gap", FollowerMotion.attackRadius(2), 2 + FollowerMotion.ATTACK_GAP)

-- Lunge: rises to 1, falls back to 0
near("lunge rests before hit", FollowerMotion.lungeAmount(-0.1), 0)
near("lunge starts at 0", FollowerMotion.lungeAmount(0), 0)
near("lunge halfway in", FollowerMotion.lungeAmount(FollowerMotion.LUNGE_IN_TIME / 2), 0.5)
near("lunge peak", FollowerMotion.lungeAmount(FollowerMotion.LUNGE_IN_TIME), 1)
near("lunge ends", FollowerMotion.lungeAmount(FollowerMotion.lungeDuration()), 0)
near("lunge stays at rest", FollowerMotion.lungeAmount(5), 0)

-- Every hit plays a full lunge: it ends before the fastest cooldown
local fastest = math.huge
for _, rarity in Rarities.List do
	fastest = math.min(fastest, rarity.cooldown)
end
check("lunge shorter than fastest cooldown", FollowerMotion.lungeDuration() < fastest, true)

-- Walking: same constant speed for every character, no overshoot
near("walk speed", FollowerMotion.walkSpeed(16), 16 * FollowerMotion.SPEED_FACTOR)
check("faster than the owner", FollowerMotion.walkSpeed(16) > 16, true)
near("constant step", FollowerMotion.stepDistance(50, 20, 0.1), 2)
near("step stops at goal", FollowerMotion.stepDistance(0.5, 20, 0.1), 0.5)
near("no step at goal", FollowerMotion.stepDistance(0, 20, 0.1), 0)

-- Walk cycle: one full cycle per stride, limbs at rest when stopped
near("half stride is half cycle", FollowerMotion.advanceWalk(0, FollowerMotion.STRIDE_LENGTH / 2), math.pi)
near("full stride wraps", FollowerMotion.advanceWalk(0, FollowerMotion.STRIDE_LENGTH), 0)
near("standing does not advance", FollowerMotion.advanceWalk(1, 0), 1)
near("full swing", FollowerMotion.walkSwing(math.pi / 2, 1), FollowerMotion.MAX_SWING)
near("half speed half swing", FollowerMotion.walkSwing(math.pi / 2, 0.5), FollowerMotion.MAX_SWING / 2)
near("stopped is at rest", FollowerMotion.walkSwing(math.pi / 2, 0), 0)
near("swing is capped", FollowerMotion.walkSwing(math.pi / 2, 3), FollowerMotion.MAX_SWING)

-- Turning takes the short way round
near("turn halfway", FollowerMotion.turnToward(0, 1, 0.5), 0.5)
near("turn across pi", FollowerMotion.turnToward(math.rad(170), math.rad(-170), 1) % (2 * math.pi), math.rad(190))
near("turn reaches goal", FollowerMotion.turnToward(0.2, 1.2, 1), 1.2)

-- Smoothing
near("no time, no movement", FollowerMotion.smoothing(0, 10), 0)
check("smoothing below 1", FollowerMotion.smoothing(1 / 60, 10) < 1, true)
-- Frame-rate independent: two half frames move as much as one full frame.
local half = FollowerMotion.smoothing(1 / 120, 10)
near("frame-rate independent", 1 - (1 - half) * (1 - half), FollowerMotion.smoothing(1 / 60, 10))

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
