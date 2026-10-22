-- Checks the sound configuration (Config.Sounds), the pure mixing logic
-- (SoundMix: limits, climbing pitches, music per area, cross-fade) and the
-- player's options (SettingsOps).
local Sounds = require(Shared.Config.Sounds)
local Ambience = require(Shared.Config.Ambience)
local Islands = require(Shared.Data.Islands)
local Raids = require(Shared.Config.Raids)
local SoundMix = require(Client.Effects.SoundMix)
local SettingsOps = require(Server.Settings.SettingsOps)
local PlayerRecord = require(Server.Data.PlayerRecord)

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

-- Config: every id is empty or an asset id, volumes in range.
local function validId(id)
	return id == "" or string.match(id, "^rbxassetid://%d+$") ~= nil
end
for name, effect in Sounds.Effects do
	check(`effect {name} id`, validId(effect.id), true)
	check(`effect {name} volume`, effect.volume > 0 and effect.volume <= 1, true)
	check(`effect {name} limit`, effect.maxAtOnce == nil or effect.maxAtOnce >= 1, true)
end
for name, track in Sounds.Music do
	check(`music {name} id`, validId(track.id), true)
	check(`music {name} volume`, track.volume > 0 and track.volume <= 1, true)
end

-- Every area with an ambience has its music, and so does the final raid wave.
for _, island in Islands.List do
	check(`music for {island.id}`, Sounds.Music[island.id] ~= nil, true)
	check(`ambience for {island.id}`, Ambience.get(island.id) ~= nil, true)
end
check("music for the raid lobby", Sounds.Music.RaidLobby ~= nil, true)
check("music for the raid", Sounds.Music.Raid ~= nil, true)
check("music for the raid boss", Sounds.Music.RaidBoss ~= nil, true)

-- Effects used by the client exist.
for _, name in
	{
		"UiClick",
		"UiHover",
		"Error",
		"Purchase",
		"Hit",
		"EnemyDeath",
		"CoinPickup",
		"GachaWhoosh",
		"GachaClimb",
		"GachaBurst",
		"CardFlip",
		"StarPop",
		"Reveal",
		"RevealRare",
		"PortalUnlock",
		"Travel",
		"RaidStart",
		"RaidWave",
		"RaidBossWave",
		"RaidComplete",
		"RaidFail",
		"Achievement",
		"BoostActivate",
	}
do
	check(`effect {name} exists`, Sounds.Effects[name] ~= nil, true)
end
check("world sounds are 3D", Sounds.Effects.Hit.spatial and Sounds.Effects.EnemyDeath.spatial, true)

-- Limits: per effect, by minimum gap and in total.
local limits = SoundMix.newLimits()
check("first hit", SoundMix.tryStart(limits, "Hit", 0, 2, 0, 10), true)
check("second hit", SoundMix.tryStart(limits, "Hit", 1, 2, 0, 10), true)
check("third hit blocked", SoundMix.tryStart(limits, "Hit", 2, 2, 0, 10), false)
SoundMix.finished(limits, "Hit")
check("hit again after one ends", SoundMix.tryStart(limits, "Hit", 3, 2, 0, 10), true)
check("too soon", SoundMix.tryStart(limits, "Coin", 0, 5, 0.1, 10), true)
check("gap blocks", SoundMix.tryStart(limits, "Coin", 0.05, 5, 0.1, 10), false)
check("gap passed", SoundMix.tryStart(limits, "Coin", 0.2, 5, 0.1, 10), true)
check("total counted", limits.total, 4)
check("total cap", SoundMix.tryStart(limits, "Other", 5, 5, 0, 4), false)
SoundMix.finished(limits, "Nothing")
check("finishing an unknown sound changes nothing", limits.total, 4)
local defaults = SoundMix.newLimits()
for _ = 1, SoundMix.DEFAULT_MAX_AT_ONCE do
	SoundMix.tryStart(defaults, "X", 0, nil, nil, 100)
end
check("default per-effect limit", SoundMix.tryStart(defaults, "X", 0, nil, nil, 100), false)

-- Coins: the chain grows while pickups follow closely, resets after a pause.
check("first coin", SoundMix.chainAfter(0, nil, 10), 1)
check("chained coin", SoundMix.chainAfter(3, 10, 10 + SoundMix.CHAIN_RESET / 2), 4)
check("chain resets", SoundMix.chainAfter(8, 10, 10 + SoundMix.CHAIN_RESET + 0.01), 1)
near("first coin plain pitch", SoundMix.coinPitch(1), 1)
check("coin pitch climbs", SoundMix.coinPitch(5) > SoundMix.coinPitch(4), true)
near("coin pitch capped", SoundMix.coinPitch(100), SoundMix.semitones(SoundMix.CHAIN_STEPS))
near("octave doubles", SoundMix.semitones(12), 2)

-- Gacha steps climb two semitones each; rarer hits sound lower.
near("first step plain", SoundMix.stepPitch(1), 1)
near("seventh step", SoundMix.stepPitch(7), SoundMix.semitones(12))
near("Common hit plain", SoundMix.hitPitch(1), 1)
local lower = true
for order = 2, 7 do
	lower = lower and SoundMix.hitPitch(order) < SoundMix.hitPitch(order - 1)
end
check("rarer hits lower", lower, true)
check("own hits louder", SoundMix.hitVolume(true) > SoundMix.hitVolume(false), true)

-- Music: area track, boss track on the raid's final wave only.
check("island music", SoundMix.musicKey("Kono", nil, Raids.WaveCount), "Kono")
check("raid music", SoundMix.musicKey("Raid", 5, Raids.WaveCount), "Raid")
check("boss music", SoundMix.musicKey("Raid", Raids.WaveCount, Raids.WaveCount), "RaidBoss")
check("wave outside a raid", SoundMix.musicKey("Nameku", Raids.WaveCount, Raids.WaveCount), "Nameku")

-- Cross-fade.
local out0, in0 = SoundMix.fade(0, 2)
local outMid, inMid = SoundMix.fade(1, 2)
local out1, in1 = SoundMix.fade(3, 2)
near("fade starts on the old track", out0, 1)
near("new track silent at first", in0, 0)
near("halfway", outMid + inMid, 1)
near("old track gone", out1, 0)
near("new track full", in1, 1)
local _, instant = SoundMix.fade(0, 0)
near("no fade time switches at once", instant, 1)

-- Options: on by default, only known names and booleans.
local data = PlayerRecord.newData()
for _, name in Sounds.Settings do
	check(`{name} on by default`, SettingsOps.get(data, name), true)
end
check("turn music off", SettingsOps.set(data, "Music", false), true)
check("music off", SettingsOps.get(data, "Music"), false)
check("effects untouched", SettingsOps.get(data, "Effects"), true)
check("unknown option", SettingsOps.set(data, "Volume", true), false)
check("not a boolean", SettingsOps.set(data, "Effects", "no"), false)
check("not a name", SettingsOps.set(data, 3, true), false)
check("effects still on", SettingsOps.get(data, "Effects"), true)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
