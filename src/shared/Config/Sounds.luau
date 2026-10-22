--!strict
-- Sound effects and music. Each entry holds a Roblox audio id
-- ("rbxassetid://123..."); an empty id stays silent, so every hook is already
-- wired and an id can be filled in later without touching code.
-- SoundController plays them on the client; SoundMix (pure) limits and pitches.

export type Effect = {
	id: string,
	volume: number,
	spatial: boolean?, -- plays at a world position (3D) instead of on the screen (2D)
	maxAtOnce: number?, -- copies of this effect playing at the same time
	minGap: number?, -- seconds between two starts of this effect
}

export type Track = {
	id: string,
	volume: number,
}

local Effects: { [string]: Effect } = {
	-- Interface
	UiClick = { id = "", volume = 0.5, maxAtOnce = 2 },
	UiHover = { id = "", volume = 0.25, maxAtOnce = 1, minGap = 0.05 },
	Error = { id = "", volume = 0.5, maxAtOnce = 1, minGap = 0.2 },
	Purchase = { id = "", volume = 0.6, maxAtOnce = 1 },

	-- Combat (3D, at the enemy). Hit is pitched by the rarity of the character that hits.
	Hit = { id = "", volume = 0.45, spatial = true, maxAtOnce = 5, minGap = 0.03 },
	EnemyDeath = { id = "", volume = 0.6, spatial = true, maxAtOnce = 3, minGap = 0.05 },

	-- Coins: the pitch climbs while pickups chain together.
	CoinPickup = { id = "", volume = 0.4, maxAtOnce = 4, minGap = 0.03 },

	-- Gacha reveal
	GachaWhoosh = { id = "", volume = 0.6, maxAtOnce = 1 },
	GachaClimb = { id = "", volume = 0.5, maxAtOnce = 2 }, -- one per rarity color, pitch rising
	GachaBurst = { id = "", volume = 0.8, maxAtOnce = 1 },
	CardFlip = { id = "", volume = 0.5, maxAtOnce = 3, minGap = 0.03 },
	StarPop = { id = "", volume = 0.45, maxAtOnce = 3 }, -- one per rarity star, pitch rising
	Reveal = { id = "", volume = 0.6, maxAtOnce = 2 }, -- Common to Epic
	RevealRare = { id = "", volume = 0.8, maxAtOnce = 1 }, -- Legendary, Mythic and Secret

	-- Portals
	PortalUnlock = { id = "", volume = 0.7, maxAtOnce = 1 },
	Travel = { id = "", volume = 0.6, maxAtOnce = 1 },

	-- Raids
	RaidStart = { id = "", volume = 0.7, maxAtOnce = 1 },
	RaidWave = { id = "", volume = 0.5, maxAtOnce = 1 },
	RaidBossWave = { id = "", volume = 0.8, maxAtOnce = 1 }, -- mini boss (wave 10) and final boss
	RaidComplete = { id = "", volume = 0.8, maxAtOnce = 1 },
	RaidFail = { id = "", volume = 0.7, maxAtOnce = 1 },
	Achievement = { id = "", volume = 0.8, maxAtOnce = 1 },

	-- Boosts
	BoostActivate = { id = "", volume = 0.6, maxAtOnce = 1 },
}

-- One looping track per area (Ambience area ids), plus RaidBoss for the final wave.
local Music: { [string]: Track } = {
	Nameku = { id = "", volume = 0.35 },
	Kono = { id = "", volume = 0.35 },
	CloverKingdom = { id = "", volume = 0.35 },
	TitanVillage = { id = "", volume = 0.35 },
	HeroAcademy = { id = "", volume = 0.35 },
	DemonCorps = { id = "", volume = 0.35 },
	RaidLobby = { id = "", volume = 0.35 },
	Raid = { id = "", volume = 0.4 },
	RaidBoss = { id = "", volume = 0.45 },
}

local Sounds = {
	Effects = Effects,
	Music = Music,
	MusicFade = 1.5, -- seconds to cross-fade between tracks
	MaxEffects = 16, -- effects playing at the same time, all kinds together
	SpatialRange = 140, -- studs where 3D effects fade out
	-- Player options (saved in Data.Settings, replicated as "Setting<Name>").
	Settings = { "Music", "Effects" },
}

return Sounds
