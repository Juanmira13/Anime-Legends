--!strict
-- Pure sound logic for SoundController (tested in sound.spec): how many effects
-- may play at once, pitches that climb (coins in a chain, gacha colors and
-- stars), the pitch of a hit by rarity, which music plays where, and the
-- cross-fade between tracks.

local SoundMix = {}

SoundMix.DEFAULT_MAX_AT_ONCE = 4
SoundMix.DEFAULT_MIN_GAP = 0
SoundMix.CHAIN_RESET = 0.6 -- seconds without a pickup that end a coin chain
SoundMix.CHAIN_STEPS = 12 -- semitones the coin pitch can climb
SoundMix.SEMITONE = 2 ^ (1 / 12)

export type Limits = {
	active: { [string]: number }, -- copies playing, by effect name
	lastStart: { [string]: number }, -- clock of the last start, by effect name
	total: number, -- all effects playing
}

function SoundMix.newLimits(): Limits
	return { active = {}, lastStart = {}, total = 0 }
end

-- Whether `name` may start now; when it may, the start is counted (call
-- `finished` when it ends).
function SoundMix.tryStart(
	limits: Limits,
	name: string,
	now: number,
	maxAtOnce: number?,
	minGap: number?,
	maxTotal: number
): boolean
	local active = limits.active[name] or 0
	if limits.total >= maxTotal or active >= (maxAtOnce or SoundMix.DEFAULT_MAX_AT_ONCE) then
		return false
	end
	local last = limits.lastStart[name]
	if last and now - last < (minGap or SoundMix.DEFAULT_MIN_GAP) then
		return false
	end
	limits.active[name] = active + 1
	limits.lastStart[name] = now
	limits.total += 1
	return true
end

function SoundMix.finished(limits: Limits, name: string)
	local active = limits.active[name] or 0
	if active > 0 then
		limits.active[name] = active - 1
		limits.total = math.max(limits.total - 1, 0)
	end
end

-- Pitch `steps` semitones up.
function SoundMix.semitones(steps: number): number
	return SoundMix.SEMITONE ^ steps
end

-- Length of the coin chain after a pickup at `now` (the previous one at `last`).
function SoundMix.chainAfter(count: number, last: number?, now: number): number
	if last == nil or now - last > SoundMix.CHAIN_RESET then
		return 1
	end
	return count + 1
end

-- Coin pickup pitch: one semitone per coin in the chain, up to CHAIN_STEPS.
function SoundMix.coinPitch(chain: number): number
	return SoundMix.semitones(math.clamp(chain - 1, 0, SoundMix.CHAIN_STEPS))
end

-- Gacha climb and star pops: two semitones per step (1 = first).
function SoundMix.stepPitch(step: number): number
	return SoundMix.semitones((math.max(step, 1) - 1) * 2)
end

-- Hit pitch by rarity order (1 Common .. 7 Secret): rarer hits sound heavier.
function SoundMix.hitPitch(order: number): number
	return SoundMix.semitones(-(math.clamp(order, 1, 7) - 1))
end

-- Hits from other players are quieter.
function SoundMix.hitVolume(own: boolean): number
	return if own then 1 else 0.45
end

-- Music for an area: the raid switches to the boss track on the final wave.
function SoundMix.musicKey(area: string, raidWave: number?, waveCount: number): string
	if area == "Raid" and raidWave ~= nil and raidWave >= waveCount then
		return "RaidBoss"
	end
	return area
end

-- Cross-fade at `t` seconds of `duration`: (outgoing, incoming) volume factors.
function SoundMix.fade(t: number, duration: number): (number, number)
	local p = if duration <= 0 then 1 else math.clamp(t / duration, 0, 1)
	return 1 - p, p
end

return SoundMix
