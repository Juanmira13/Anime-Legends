-- Checks the map rules (MapCheck) and the world and ambience config.
local MapCheck = require(Shared.Map.MapCheck)
local Islands = require(Shared.Data.Islands)
local Balance = require(Shared.Config.Balance)
local Raids = require(Shared.Config.Raids)
local World = require(Shared.Config.World)
local Ambience = require(Shared.Config.Ambience)

local failures = 0
local function check(label, actual, expected)
	if actual ~= expected then
		failures += 1
		print(`FAIL {label}: expected {expected}, got {actual}`)
	end
end
local function contains(list, text)
	for _, item in list do
		if string.find(item, text, 1, true) then
			return true
		end
	end
	return false
end

-- A complete map passes
local function completeMap()
	local entries = {}
	local function add(tag, area, attributes)
		table.insert(entries, { tag = tag, name = `{area}.{tag}`, area = area, attributes = attributes })
	end
	for index, island in Islands.List do
		add("IslandSpawn", island.id, { Island = island.id })
		add("GachaStand", island.id, { Island = island.id })
		for _, rank in Balance.EnemyRanks do
			add("EnemySpawn", island.id, { Island = island.id, Rank = rank.id })
		end
		for _, neighbor in { Islands.List[index - 1], Islands.List[index + 1] } do
			add("Portal", island.id, { TargetIsland = neighbor.id })
		end
	end
	add("RaidPortal", Islands.List[1].id, {})
	add("RaidLobbySpawn", "RaidLobby", {})
	add("Portal", "RaidLobby", { TargetIsland = Islands.List[1].id })
	for _, difficulty in Raids.Difficulties do
		add("RaidPad", "RaidLobby", { Difficulty = difficulty.id })
	end
	return entries
end

local report = MapCheck.run(completeMap())
check("complete map has no errors", #report.errors, 0)
for _, message in report.errors do
	print(`  unexpected: {message}`)
end

local function without(predicate)
	local entries = {}
	for _, entry in completeMap() do
		if not predicate(entry) then
			table.insert(entries, entry)
		end
	end
	return MapCheck.run(entries).errors
end
local function withExtra(entry)
	local entries = completeMap()
	table.insert(entries, entry)
	return MapCheck.run(entries).errors
end

check(
	"missing arrival",
	contains(
		without(function(e)
			return e.tag == "IslandSpawn" and e.area == "Kono"
		end),
		"Kono: needs exactly one IslandSpawn (found 0)"
	),
	true
)
check(
	"two arrivals",
	contains(
		withExtra({ tag = "IslandSpawn", name = "x", area = "Kono", attributes = { Island = "Kono" } }),
		"Kono: needs exactly one IslandSpawn (found 2)"
	),
	true
)
check(
	"missing boss",
	contains(
		without(function(e)
			return e.tag == "EnemySpawn" and e.area == "Nameku" and e.attributes.Rank == "Boss"
		end),
		"Nameku: no EnemySpawn with Rank Boss"
	),
	true
)
check(
	"bad rank",
	contains(
		withExtra({ tag = "EnemySpawn", name = "bad", area = "Kono", attributes = { Island = "Kono", Rank = "Huge" } }),
		'bad: EnemySpawn has unknown Rank "Huge"'
	),
	true
)
check(
	"bad island",
	contains(
		withExtra({ tag = "GachaStand", name = "g", attributes = { Island = "Atlantis" } }),
		'g: GachaStand has unknown Island "Atlantis"'
	),
	true
)
check(
	"missing gacha",
	contains(
		without(function(e)
			return e.tag == "GachaStand" and e.area == "DemonCorps"
		end),
		"DemonCorps: no GachaStand"
	),
	true
)
check(
	"missing forward portal",
	contains(
		without(function(e)
			return e.tag == "Portal" and e.area == "Kono" and e.attributes.TargetIsland == "CloverKingdom"
		end),
		"Kono: no Portal to CloverKingdom"
	),
	true
)
check(
	"missing back portal",
	contains(
		without(function(e)
			return e.tag == "Portal" and e.area == "Kono" and e.attributes.TargetIsland == "Nameku"
		end),
		"Kono: no Portal to Nameku"
	),
	true
)
check(
	"bad portal target",
	contains(
		withExtra({ tag = "Portal", name = "p", area = "Kono", attributes = { TargetIsland = "Mars" } }),
		'p: Portal has unknown TargetIsland "Mars"'
	),
	true
)
check(
	"missing raid portal",
	contains(
		without(function(e)
			return e.tag == "RaidPortal"
		end),
		"No RaidPortal"
	),
	true
)
check(
	"missing pad",
	contains(
		without(function(e)
			return e.tag == "RaidPad" and e.attributes.Difficulty == "Hard"
		end),
		"exactly one RaidPad for Hard (found 0)"
	),
	true
)
check(
	"bad difficulty",
	contains(
		withExtra({ tag = "RaidPad", name = "pad", area = "RaidLobby", attributes = { Difficulty = "Insane" } }),
		'pad: RaidPad has unknown Difficulty "Insane"'
	),
	true
)
check(
	"missing lobby portal",
	contains(
		without(function(e)
			return e.tag == "Portal" and e.area == "RaidLobby"
		end),
		"RaidLobby: no Portal back to Nameku"
	),
	true
)

-- Part budget
local budget = MapCheck.run(completeMap(), { Nameku = MapCheck.PartBudget + 1, Kono = 10 })
check("over budget warns", #budget.warnings, 1)
check("budget warning names the area", contains(budget.warnings, "Nameku"), true)

-- World config: every island has an accent color and a center in order
for _, island in Islands.List do
	check(`accent color {island.id}`, World.AccentColors[island.id] ~= nil, true)
	local x, z = World.islandCenter(island.order)
	check(`center {island.id}`, x == (island.order - 1) * World.IslandSpacing and z == 0, true)
end
check("islands do not overlap their sea squares", World.IslandSpacing >= World.AreaSize, true)

-- Ambience: every island and raid area is defined with valid colors
local function validColor(rgb)
	if type(rgb) ~= "table" or #rgb ~= 3 then
		return false
	end
	for _, channel in rgb do
		if channel < 0 or channel > 255 then
			return false
		end
	end
	return true
end
local areas = { "RaidLobby", "Raid" }
for _, island in Islands.List do
	table.insert(areas, island.id)
end
for _, area in areas do
	local ambience = Ambience.Areas[area]
	check(`ambience for {area}`, ambience ~= nil, true)
	if ambience then
		local colors = {
			ambience.ambient,
			ambience.outdoorAmbient,
			ambience.colorShiftTop,
			ambience.atmosphere.color,
			ambience.atmosphere.decay,
			ambience.colorCorrection.tint,
			ambience.water.color,
		}
		for _, rgb in ambience.terrain do
			table.insert(colors, rgb)
		end
		local valid = true
		for _, rgb in colors do
			valid = valid and validColor(rgb)
		end
		check(`ambience colors {area}`, valid, true)
		check(`clock time {area}`, ambience.clockTime >= 0 and ambience.clockTime < 24, true)
	end
end
check("unknown area falls back", Ambience.get("Nowhere") == Ambience.Areas[Ambience.DefaultArea], true)

-- Raid arena: arrival point and exit portal on the field and apart, room left
-- for enemies, and the coliseum (with its clouds) fits between neighbouring
-- arenas. Random enemy spots are checked in raid.spec.
local RaidArenaLayout = require(Builder.RaidArenaLayout)
local function distance(a, b)
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
end
local fieldEdge = RaidArenaLayout.floorRadius - 8
local spawn, exit = RaidArenaLayout.playerSpawn, RaidArenaLayout.exitPortal
check("arena player spawn inside the field", distance(spawn, { 0, 0 }) <= fieldEdge, true)
check("arena exit portal inside the field", distance(exit, { 0, 0 }) <= fieldEdge, true)
check("arena exit apart from the arrival point", distance(spawn, exit) >= 20, true)
check("arena exit closer to the players' gate than the arrival point", exit[2] > spawn[2], true)
-- Clouds reach 1.3 x the outer radius plus a puff; RaidService spaces arenas 400 studs apart.
check("arena fits between raid slots", (RaidArenaLayout.outerRadius() * 1.3 + 30) * 2 < 400, true)

if failures == 0 then
	print("OK: all checks passed")
else
	error(`{failures} checks failed`)
end
