--!strict
-- Where equipped characters stand and how they move: they walk on the ground
-- to a formation behind their owner or to an arc around the owner's target,
-- all at the same speed, swing their limbs while walking, and lunge on each
-- server hit. Plain numbers only (no Roblox types), so it can be unit tested.

local FollowerMotion = {}

-- Formation behind the owner, in rows.
FollowerMotion.ROW_SIZE = 3
FollowerMotion.SPACING = 5 -- studs between characters in a row (R6 rigs are 4 wide)
FollowerMotion.FIRST_ROW_DISTANCE = 6 -- studs behind the owner
FollowerMotion.ROW_GAP = 5 -- studs between rows

-- Arc around the target, centered on the side facing the owner.
FollowerMotion.ATTACK_ARC = math.rad(150)
FollowerMotion.ATTACK_GAP = 3 -- studs between the target's surface and the characters

-- Lunge toward the target on each hit. It must end before the fastest cooldown
-- so every hit plays a full lunge.
FollowerMotion.LUNGE_IN_TIME = 0.12 -- seconds
FollowerMotion.LUNGE_OUT_TIME = 0.3 -- seconds

-- Walking. Every character moves at the owner's walk speed times this factor,
-- slightly faster so they catch up after the owner stops.
FollowerMotion.SPEED_FACTOR = 1.25
FollowerMotion.STRIDE_LENGTH = 6 -- studs per full walk cycle (two steps)
FollowerMotion.MAX_SWING = math.rad(50) -- arm and leg swing at full speed

-- Offset of a character from its owner, as (right, back) in studs.
-- `index` is the slot (1-based) and `count` the team size; rows are centered.
function FollowerMotion.formationOffset(index: number, count: number): (number, number)
	local row = (index - 1) // FollowerMotion.ROW_SIZE
	local column = (index - 1) % FollowerMotion.ROW_SIZE
	local rowCount = math.min(FollowerMotion.ROW_SIZE, count - row * FollowerMotion.ROW_SIZE)
	local right = (column - (rowCount - 1) / 2) * FollowerMotion.SPACING
	local back = FollowerMotion.FIRST_ROW_DISTANCE + row * FollowerMotion.ROW_GAP
	return right, back
end

-- Angle (radians) of a character around its target, relative to the direction
-- from the target to the owner. Characters spread evenly over the attack arc.
function FollowerMotion.attackAngle(index: number, count: number): number
	if count <= 1 then
		return 0
	end
	local t = (index - 1) / (count - 1)
	return (t - 0.5) * FollowerMotion.ATTACK_ARC
end

-- Distance from the target's center at which characters stand.
function FollowerMotion.attackRadius(targetHalfWidth: number): number
	return targetHalfWidth + FollowerMotion.ATTACK_GAP
end

-- How far into the lunge a character is (0 = resting, 1 = touching the target),
-- `sinceHit` seconds after its last hit.
function FollowerMotion.lungeAmount(sinceHit: number): number
	if sinceHit < 0 then
		return 0
	end
	if sinceHit < FollowerMotion.LUNGE_IN_TIME then
		return sinceHit / FollowerMotion.LUNGE_IN_TIME
	end
	local out = (sinceHit - FollowerMotion.LUNGE_IN_TIME) / FollowerMotion.LUNGE_OUT_TIME
	return math.max(0, 1 - out)
end

function FollowerMotion.lungeDuration(): number
	return FollowerMotion.LUNGE_IN_TIME + FollowerMotion.LUNGE_OUT_TIME
end

-- Walking speed of every character of an owner who walks at `ownerSpeed`.
function FollowerMotion.walkSpeed(ownerSpeed: number): number
	return ownerSpeed * FollowerMotion.SPEED_FACTOR
end

-- Studs to move this frame toward a goal `distance` studs away: constant
-- speed, without overshooting.
function FollowerMotion.stepDistance(distance: number, speed: number, dt: number): number
	return math.clamp(speed * dt, 0, math.max(0, distance))
end

-- Walk cycle phase (radians) after moving `moved` studs.
function FollowerMotion.advanceWalk(phase: number, moved: number): number
	return (phase + moved * 2 * math.pi / FollowerMotion.STRIDE_LENGTH) % (2 * math.pi)
end

-- Limb swing angle for a walk phase. `amount` is 0 standing still and 1 at
-- full speed, so limbs settle at rest when the character stops.
function FollowerMotion.walkSwing(phase: number, amount: number): number
	return math.sin(phase) * FollowerMotion.MAX_SWING * math.clamp(amount, 0, 1)
end

-- Turns a yaw angle toward `goal` by the fraction `alpha`, the short way round.
function FollowerMotion.turnToward(current: number, goal: number, alpha: number): number
	local difference = (goal - current + math.pi) % (2 * math.pi) - math.pi
	return current + difference * alpha
end

-- Fraction to move toward the goal this frame for frame-rate independent
-- smoothing. `rate` is how quickly it catches up (higher is faster).
function FollowerMotion.smoothing(dt: number, rate: number): number
	return 1 - math.exp(-rate * dt)
end

return FollowerMotion
