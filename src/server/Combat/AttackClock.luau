--!strict
-- Per-player attack timing: decides which equipped characters hit this frame
-- based on each one's cooldown. Pure logic, so it can be unit tested.

export type Attacker = {
	uid: string, -- owned character unique id
	cooldown: number, -- seconds between hits
}

export type Clock = {
	-- Time each character can hit again. Entries are kept after unequipping so
	-- re-equipping a character does not reset its cooldown.
	nextHit: { [string]: number },
}

local AttackClock = {}

function AttackClock.new(): Clock
	return { nextHit = {} }
end

-- Returns the uids that hit at time `now` and schedules their next hit.
-- A character that has never attacked hits immediately.
function AttackClock.collectHits(clock: Clock, attackers: { Attacker }, now: number): { string }
	local hits = {}
	for _, attacker in attackers do
		local nextHit = clock.nextHit[attacker.uid]
		if nextHit == nil or now >= nextHit then
			table.insert(hits, attacker.uid)
			clock.nextHit[attacker.uid] = now + attacker.cooldown
		end
	end
	return hits
end

return AttackClock
