--!strict
-- HUD and window icons. The images are the Figma design's drawings, built by
-- tools/build_icons.py as assets/Icons/<Name>.png (160 x 160, transparent);
-- upload each one to Roblox and put its id here ("rbxassetid://..."). An empty
-- id shows the text glyph instead, so every icon works before its upload.

export type Icon = { icon: string?, glyph: string }

local Icons = {}

Icons.Ids = {
	Yen = "rbxassetid://99476155626606",
	Gem = "rbxassetid://137173202749263",
	Clover = "rbxassetid://82227866917402",
	Bolt = "rbxassetid://84125190187477",
	Bag = "rbxassetid://102863769795425",
	Gear = "rbxassetid://94330675565298",
	Sword = "rbxassetid://136296151733624",
	Music = "rbxassetid://133308623323803",
	Speaker = "rbxassetid://101491125508806",
	Clock = "rbxassetid://84474712856288",
	Check = "rbxassetid://107261592367036",
} :: { [string]: string }

-- Placeholder glyphs shown while an id is empty.
local GLYPHS: { [string]: string } = {
	Yen = "¥",
	Gem = "💎",
	Clover = "🍀",
	Bolt = "⚡",
	Bag = "🎒",
	Gear = "⚙️",
	Sword = "⚔️",
	Music = "🎵",
	Speaker = "🔊",
	Clock = "⏱️",
	Check = "✔️",
}

-- The image id of an icon (nil while it is not uploaded) and its glyph.
function Icons.get(name: string): Icon
	local id = Icons.Ids[name]
	return { icon = if id and id ~= "" then id else nil, glyph = GLYPHS[name] or "?" }
end

return Icons
