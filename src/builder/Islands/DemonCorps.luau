--!strict
-- Demon Corps (Demon Slayer): traditional Japan at night under a full moon.
-- A lantern village of dark-wood houses with a three-story pagoda, wisteria
-- trees with hanging blossoms, a red arched bridge over the pond, a bamboo
-- forest on the eastern terrace, a tunnel of torii gates climbing to the
-- mountain shrine, stone lanterns along the road, the train standing on the
-- moonlit railway where the boss waits, and a torii rising from the sea.

local Root = script.Parent.Parent
local PathWalk = require(Root.Gen.PathWalk)
local Rng = require(Root.Gen.Rng)
local Scatter = require(Root.Gen.Scatter)
local Shape = require(Root.Gen.Shape)
local Buildings = require(Root.Kit.Buildings)
local Nature = require(Root.Kit.Nature)
local Parts = require(Root.Kit.Parts)
local IslandBuilder = require(Root.IslandBuilder)
local DemonCorpsLayout = require(script.Parent.DemonCorpsLayout)

local layout = DemonCorpsLayout
local rgb = Parts.rgb

local DARK_WOOD = rgb({ 62, 44, 36 })
local WOOD = rgb({ 96, 68, 50 })
local PAPER = rgb({ 238, 228, 204 })
local ROOF_TILE = rgb({ 52, 54, 64 })
local TORII_RED = rgb({ 206, 50, 40 })
local LANTERN = rgb({ 255, 150, 70 })
local STONE = rgb({ 140, 138, 146 })
local WISTERIA = { rgb({ 186, 120, 236 }), rgb({ 214, 156, 246 }), rgb({ 160, 100, 214 }) }
local BAMBOO = rgb({ 104, 168, 88 })
local TRAIN_BLACK = rgb({ 36, 36, 42 })
local TRAIN_GREEN = rgb({ 40, 74, 62 })
local WINDOW_GLOW = rgb({ 255, 210, 140 })
local PINES = {
	trunk = rgb({ 80, 60, 54 }),
	leaves = { rgb({ 46, 70, 62 }), rgb({ 56, 82, 70 }), rgb({ 40, 62, 58 }) },
}
local BUSHES = { rgb({ 60, 96, 78 }), rgb({ 150, 104, 196 }) }
local ROCK = rgb({ 110, 105, 120 })

local function pick<T>(list: { T }, t: number): T
	return list[math.clamp(math.floor(t * #list) + 1, 1, #list)]
end

local function lanternLight(position: Vector3, size: number, parent: Instance, withLight: boolean)
	local lantern = Parts.ball(size, position, LANTERN, parent, { material = Enum.Material.Neon, shadow = false })
	if withLight then
		Parts.light(lantern, LANTERN, 16, 1.6)
	end
end

-- Low dark-wood house with paper walls, a tiled roof and hanging lanterns.
local function edoHouse(ground: Vector3, yaw: number, t: number, parent: Instance)
	local model = Parts.model("EdoHouse", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	local width, depth = 14 + t * 6, 10 + t * 3
	Buildings.foundation(base, width, depth, STONE, model)
	Buildings.walls(base, width, depth, 7, PAPER, model)
	for x = -width / 2, width / 2, width / 4 do
		Parts.block(
			Vector3.new(0.7, 7, depth + 0.3),
			base * CFrame.new(x, 3.5, 0),
			DARK_WOOD,
			model,
			{ shadow = false }
		)
	end
	Parts.block(
		Vector3.new(width + 0.3, 0.7, depth + 0.3),
		base * CFrame.new(0, 3.5, 0),
		DARK_WOOD,
		model,
		{ shadow = false }
	)
	Buildings.gableRoof(base * CFrame.new(0, 7, 0), width, depth, 4, ROOF_TILE, model, 2.6)
	-- Upturned ridge ends.
	for _, side in { -1, 1 } do
		Parts.block(
			Vector3.new(1.2, 1.8, 1.2),
			base * CFrame.new(side * (width / 2 + 2), 11.2, 0),
			ROOF_TILE,
			model,
			{ shadow = false }
		)
	end
	for _, x in { -width / 3, width / 3 } do
		lanternLight((base * CFrame.new(x, 6, -depth / 2 - 2.2)).Position, 1.6, model, x < 0)
	end
end

-- Three-story pagoda with stacked roofs.
local function pagoda(ground: Vector3, parent: Instance)
	local model = Parts.model("Pagoda", parent)
	local base = CFrame.new(ground)
	Buildings.foundation(base, 18, 18, STONE, model)
	Parts.block(Vector3.new(20, 2, 20), base * CFrame.new(0, 1, 0), STONE, model, { collide = true })
	local y = 2
	for floor = 0, 2 do
		local size = 14 - floor * 3
		Parts.block(
			Vector3.new(size, 7, size),
			base * CFrame.new(0, y + 3.5, 0),
			if floor % 2 == 0 then rgb({ 150, 40, 36 }) else PAPER,
			model,
			{ collide = true }
		)
		y += 7
		Parts.block(
			Vector3.new(size + 7, 1, size + 7),
			base * CFrame.new(0, y + 0.5, 0),
			ROOF_TILE,
			model,
			{ collide = true }
		)
		Parts.block(
			Vector3.new(size + 3, 1.6, size + 3),
			base * CFrame.new(0, y + 1.6, 0),
			ROOF_TILE,
			model,
			{ shadow = false }
		)
		for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			lanternLight(
				(base * CFrame.new(corner[1] * (size / 2 + 3), y - 1, corner[2] * (size / 2 + 3))).Position,
				1.2,
				model,
				floor == 0
			)
		end
		y += 2.4
	end
	Parts.column(0.8, 10, base * CFrame.new(0, y, 0), rgb({ 200, 170, 80 }), model, { shadow = false })
	for ring = 1, 4 do
		Parts.disc(
			2.6 - ring * 0.3,
			0.5,
			(base * CFrame.new(0, y + ring * 2, 0)).Position,
			rgb({ 200, 170, 80 }),
			model,
			{ shadow = false }
		)
	end
end

-- Wisteria: twisted trunk, purple canopy and strands of blossoms hanging below.
local function wisteria(ground: Vector3, height: number, t: number, parent: Instance)
	local model = Parts.model("Wisteria", parent)
	local lean = CFrame.new(ground) * CFrame.Angles(math.rad((t - 0.5) * 16), t * 6.28, 0)
	Parts.column(height * 0.12, height, lean * CFrame.new(0, -1, 0), WOOD, model, { collide = true })
	local top = (lean * CFrame.new(0, height, 0)).Position
	local color = pick(WISTERIA, t)
	Parts.ball(height * 0.75, top, Parts.vary(color, 0.25, t), model)
	Parts.ball(
		height * 0.5,
		top + Vector3.new(height * 0.25, height * 0.08, 0),
		Parts.vary(color, 0.3, 1 - t),
		model,
		{ shadow = false }
	)
	for index = 0, 9 do
		local angle = index / 10 * 2 * math.pi + t
		local reach = height * 0.32
		local hang = top + Vector3.new(math.cos(angle) * reach, -height * 0.2, math.sin(angle) * reach)
		for drop = 0, 3 do
			Parts.ball(
				height * (0.13 - drop * 0.02),
				hang - Vector3.new(0, drop * height * 0.09, 0),
				Parts.vary(color, 0.15, (index + drop) / 13),
				model,
				{ shadow = false }
			)
		end
	end
end

local function bambooClump(ground: Vector3, t: number, rng: Rng.Rng, parent: Instance)
	local model = Parts.model("Bamboo", parent)
	for _ = 1, 5 do
		local offset = Vector3.new(Rng.range(rng, -3, 3), 0, Rng.range(rng, -3, 3))
		local height = Rng.range(rng, 22, 36)
		local tilt = CFrame.new(ground + offset)
			* CFrame.Angles(Rng.range(rng, -0.08, 0.08), 0, Rng.range(rng, -0.08, 0.08))
		Parts.column(
			1.1,
			height,
			tilt * CFrame.new(0, -1, 0),
			Parts.vary(BAMBOO, 0.2, Rng.next(rng)),
			model,
			{ shadow = false }
		)
		for node = 6, height - 4, 7 do
			Parts.disc(
				1.4,
				0.35,
				(tilt * CFrame.new(0, node, 0)).Position,
				rgb({ 140, 180, 100 }),
				model,
				{ shadow = false }
			)
		end
		Parts.ball(
			4,
			(tilt * CFrame.new(0, height, 0)).Position,
			Parts.vary(rgb({ 90, 150, 80 }), 0.2, t),
			model,
			{ shadow = false }
		)
	end
end

local function torii(ground: Vector3, yaw: number, width: number, height: number, parent: Instance)
	local model = Parts.model("Torii", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	for _, side in { -1, 1 } do
		Parts.column(1.8, height + 2, base * CFrame.new(side * width / 2, -2, 0), TORII_RED, model, { collide = true })
		Parts.column(
			2.4,
			1.4,
			base * CFrame.new(side * width / 2, -0.6, 0),
			rgb({ 30, 30, 34 }),
			model,
			{ shadow = false }
		)
	end
	Parts.block(
		Vector3.new(width + 2.4, 1.2, 1.6),
		base * CFrame.new(0, height * 0.78, 0),
		TORII_RED,
		model,
		{ shadow = false }
	)
	Parts.block(
		Vector3.new(width + 6, 1.4, 2.2),
		base * CFrame.new(0, height + 0.4, 0),
		TORII_RED,
		model,
		{ shadow = false }
	)
	Parts.block(
		Vector3.new(width + 7, 0.8, 2.6),
		base * CFrame.new(0, height + 1.4, 0),
		rgb({ 30, 30, 34 }),
		model,
		{ shadow = false }
	)
end

local function stoneLantern(ground: Vector3, parent: Instance, withLight: boolean)
	local model = Parts.model("StoneLantern", parent)
	Parts.block(
		Vector3.new(2.4, 0.8, 2.4),
		CFrame.new(ground + Vector3.new(0, 0.4, 0)),
		STONE,
		model,
		{ shadow = false }
	)
	Parts.column(1, 3, CFrame.new(ground + Vector3.new(0, 0.8, 0)), STONE, model, { shadow = false })
	local box = Parts.block(
		Vector3.new(1.8, 1.6, 1.8),
		CFrame.new(ground + Vector3.new(0, 4.6, 0)),
		LANTERN,
		model,
		{ material = Enum.Material.Neon, shadow = false }
	)
	if withLight then
		Parts.light(box, LANTERN, 14, 1.2)
	end
	Parts.block(Vector3.new(3, 0.6, 3), CFrame.new(ground + Vector3.new(0, 5.7, 0)), STONE, model, { shadow = false })
end

local function shrine(ground: Vector3, yaw: number, parent: Instance)
	local model = Parts.model("Shrine", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	Buildings.foundation(base, 22, 16, STONE, model)
	Parts.block(Vector3.new(24, 2, 18), base * CFrame.new(0, 1, 0), STONE, model, { collide = true })
	Buildings.walls(base * CFrame.new(0, 2, 0), 18, 12, 9, PAPER, model)
	for _, x in { -9, -3, 3, 9 } do
		Parts.block(Vector3.new(1, 9, 1), base * CFrame.new(x, 6.5, -6.3), TORII_RED, model, { shadow = false })
	end
	Buildings.gableRoof(base * CFrame.new(0, 11, 0), 18, 12, 6, ROOF_TILE, model, 3.4)
	lanternLight((base * CFrame.new(0, 9, -9)).Position, 2.2, model, true)
end

-- Red arched bridge over the pond.
local function archBridge(from: Vector3, to: Vector3, parent: Instance)
	local model = Parts.model("ArchBridge", parent)
	local segments = 8
	for index = 0, segments - 1 do
		local t0, t1 = index / segments, (index + 1) / segments
		local function point(t: number): Vector3
			return from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * 5, 0)
		end
		local a, b = point(t0), point(t1)
		Parts.block(
			Vector3.new(7, 0.8, (b - a).Magnitude + 0.3),
			CFrame.lookAt((a + b) / 2, b),
			WOOD,
			model,
			{ collide = true }
		)
		for _, side in { -1, 1 } do
			local offset = CFrame.lookAt((a + b) / 2, b) * CFrame.new(side * 3.4, 1.6, 0)
			Parts.block(Vector3.new(0.4, 0.4, (b - a).Magnitude + 0.3), offset, TORII_RED, model, { shadow = false })
			if index % 2 == 0 then
				Parts.block(
					Vector3.new(0.5, 2, 0.5),
					CFrame.lookAt(a, b) * CFrame.new(side * 3.4, 1, 0),
					TORII_RED,
					model,
					{ shadow = false }
				)
			end
		end
	end
end

-- Railway along a line of ground points, and a train standing on it.
local function railway(points: { Vector3 }, parent: Instance)
	local model = Parts.model("Railway", parent)
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local frame = CFrame.lookAt((a + b) / 2, b)
		Parts.block(Vector3.new(7, 0.5, 1.4), frame * CFrame.new(0, 0.3, 0), DARK_WOOD, model, { shadow = false })
		for _, side in { -1, 1 } do
			Parts.block(
				Vector3.new(0.5, 0.6, (b - a).Magnitude + 0.2),
				frame * CFrame.new(side * 2.4, 0.8, 0),
				rgb({ 150, 150, 160 }),
				model,
				{ shadow = false }
			)
		end
	end
end

local function trainCar(base: CFrame, length: number, locomotive: boolean, parent: Instance)
	local model = Parts.model(if locomotive then "Locomotive" else "Carriage", parent)
	for _, along in { -length / 2 + 3, length / 2 - 3 } do
		for _, side in { -1, 1 } do
			Parts.cylinder(
				2.6,
				0.8,
				(base * CFrame.new(side * 2.6, 1.6, along)).Position,
				(base * CFrame.new(1, 0, 0)).Position - base.Position,
				rgb({ 28, 28, 30 }),
				model,
				{ shadow = false }
			)
		end
	end
	if locomotive then
		Parts.block(Vector3.new(6.4, 4, length), base * CFrame.new(0, 3.8, 0), TRAIN_BLACK, model, { collide = true })
		Parts.cylinder(
			5.6,
			length * 0.62,
			(base * CFrame.new(0, 7.6, -length * 0.15)).Position,
			(base * CFrame.new(0, 0, -1)).Position - base.Position,
			TRAIN_BLACK,
			model,
			{ collide = true }
		)
		Parts.block(
			Vector3.new(6.4, 7, length * 0.34),
			base * CFrame.new(0, 8.6, length * 0.33),
			TRAIN_BLACK,
			model,
			{ collide = true }
		)
		Parts.column(2, 4.5, base * CFrame.new(0, 10, -length * 0.36), TRAIN_BLACK, model, { shadow = false })
		Parts.block(
			Vector3.new(6.6, 0.8, length + 0.2),
			base * CFrame.new(0, 2.2, 0),
			rgb({ 180, 40, 40 }),
			model,
			{ shadow = false }
		)
		local headlight = Parts.cylinder(
			2,
			0.6,
			(base * CFrame.new(0, 7.6, -length / 2 - 0.2)).Position,
			(base * CFrame.new(0, 0, -1)).Position - base.Position,
			WINDOW_GLOW,
			model,
			{ material = Enum.Material.Neon, shadow = false }
		)
		Parts.light(headlight, WINDOW_GLOW, 30, 2)
		local steam = Instance.new("ParticleEmitter")
		steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
		steam.Color = ColorSequence.new(rgb({ 220, 220, 230 }))
		steam.Size = NumberSequence.new(3, 10)
		steam.Transparency = NumberSequence.new(0.5, 1)
		steam.Lifetime = NumberRange.new(3, 5)
		steam.Rate = 6
		steam.Speed = NumberRange.new(4, 7)
		steam.SpreadAngle = Vector2.new(10, 10)
		steam.Parent = headlight
	else
		Parts.block(Vector3.new(6.4, 7.5, length), base * CFrame.new(0, 5.6, 0), TRAIN_GREEN, model, { collide = true })
		Parts.block(
			Vector3.new(6.8, 0.8, length + 0.4),
			base * CFrame.new(0, 9.7, 0),
			TRAIN_BLACK,
			model,
			{ collide = true }
		)
		for along = -length / 2 + 3, length / 2 - 3, 3.6 do
			for _, side in { -1, 1 } do
				Parts.block(
					Vector3.new(0.2, 2.2, 2.4),
					base * CFrame.new(side * 3.25, 6.4, along),
					WINDOW_GLOW,
					model,
					{ material = Enum.Material.Neon, shadow = false }
				)
			end
		end
	end
end

local function decorate(context: IslandBuilder.Context)
	local rng = context.rng
	local decor = context.decor
	local nature = Parts.folder("Nature", decor)
	local village = Parts.folder("Village", decor)
	local landmarks = Parts.folder("Landmarks", decor)
	local easy, medium, hard, boss = layout.zones[1], layout.zones[2], layout.zones[3], layout.zones[4]
	local road = layout.paths[1].points

	-- Lantern village around the first zone, with the pagoda behind it.
	for index = 1, 12 do
		local angle = index / 12 * 2 * math.pi + Rng.range(rng, -0.12, 0.12)
		local distance = easy.radius + Rng.range(rng, 16, 34)
		local x, z = easy.x + math.cos(angle) * distance, easy.z + math.sin(angle) * distance
		if context.isFree(x, z, 4) then
			edoHouse(context.groundMin(x, z, 8), IslandBuilder.yawToward(x, z, easy.x, easy.z), Rng.next(rng), village)
		end
	end
	pagoda(context.groundMin(easy.x - 40, easy.z - 75, 11), landmarks)

	-- Pond with its arched bridge.
	local pond = layout.lakes and layout.lakes[1]
	if pond then
		local from = context.ground(pond.x - pond.radius - 6, pond.z) + Vector3.new(0, 0.6, 0)
		local to = context.ground(pond.x + pond.radius + 6, pond.z) + Vector3.new(0, 0.6, 0)
		archBridge(from, to, landmarks)
	end

	-- On land and outside the plaza, combat zones and water.
	local function clearOfAreas(x: number, z: number): boolean
		if
			Shape.coastFraction(layout, x, z) > 0.88
			or Shape.waterLevel(layout, x, z, 0) > Shape.height(layout, x, z)
		then
			return false
		end
		local plaza = layout.plaza
		if (x - plaza.x) ^ 2 + (z - plaza.z) ^ 2 < (plaza.radius + 2) ^ 2 then
			return false
		end
		for _, zone in layout.zones do
			if (x - zone.x) ^ 2 + (z - zone.z) ^ 2 < (zone.radius + 2) ^ 2 then
				return false
			end
		end
		return true
	end

	-- Stone lanterns along the whole road.
	for _, sample in PathWalk.samples(road, 22, 30) do
		for _, side in { -1, 1 } do
			local x, z = sample.x + sample.dz * side * 8.5, sample.z - sample.dx * side * 8.5
			if clearOfAreas(x, z) then
				stoneLantern(context.ground(x, z), village, side == 1 and math.floor(sample.distance / 22) % 3 == 0)
			end
		end
	end

	-- Torii tunnel from the bamboo terrace up to the shrine.
	local climb = { road[6], road[7], road[8], road[9], road[10] }
	for _, sample in PathWalk.samples(climb, 13, 50) do
		local distanceToHard = math.sqrt((sample.x - hard.x) ^ 2 + (sample.z - hard.z) ^ 2)
		local distanceToMedium = math.sqrt((sample.x - medium.x) ^ 2 + (sample.z - medium.z) ^ 2)
		if distanceToHard > hard.radius + 4 and distanceToMedium > medium.radius + 4 then
			torii(context.ground(sample.x, sample.z), math.atan2(-sample.dx, -sample.dz), 14, 13, landmarks)
		end
	end
	local dx, dz = hard.x - road[9][1], hard.z - road[9][2]
	local length = math.sqrt(dx * dx + dz * dz)
	local sx, sz = hard.x + dx / length * (hard.radius + 16), hard.z + dz / length * (hard.radius + 16)
	shrine(context.groundMin(sx, sz, 12), IslandBuilder.yawToward(sx, sz, hard.x, hard.z), landmarks)

	-- Bamboo forest around the bamboo terrace.
	for _, point in
		Scatter.inCircle(rng, medium.x, medium.z, 140, 46, 10, function(x, z)
			return math.sqrt((x - medium.x) ^ 2 + (z - medium.z) ^ 2) > medium.radius + 8 and context.isFree(x, z, 4)
		end)
	do
		bambooClump(context.ground(point.x, point.z), Rng.next(rng), rng, nature)
	end

	-- Wisteria around the village and the plaza; dark pines up the mountain.
	for _, point in
		Scatter.inCircle(rng, -100, 190, 170, 30, 16, function(x, z)
			return context.isFree(x, z, 6)
		end)
	do
		wisteria(context.ground(point.x, point.z), Rng.range(rng, 14, 22), Rng.next(rng), nature)
	end
	for _, point in
		Scatter.inCircle(rng, 0, -60, 330, 150, 15, function(x, z)
			local height = Shape.height(layout, x, z)
			return height > 25 and height < 140 and context.isFree(x, z, 6)
		end)
	do
		Nature.pineTree(context.ground(point.x, point.z), Rng.range(rng, 16, 28), Rng.next(rng), PINES, nature)
	end
	for _, point in
		Scatter.inCircle(rng, 0, 0, 420, 60, 12, function(x, z)
			return context.isFree(x, z, 2)
		end)
	do
		Nature.bush(context.ground(point.x, point.z), Rng.range(rng, 3, 4.5), Rng.next(rng), BUSHES, nature)
	end
	for _, point in
		Scatter.inCircle(rng, -20, -70, 250, 40, 22, function(x, z)
			return Shape.height(layout, x, z) > 60 and Shape.pathInside(layout, x, z) < -5
		end)
	do
		Nature.rock(context.ground(point.x, point.z), Rng.range(rng, 5, 11), Rng.next(rng), ROCK, nature)
	end

	-- Railway on the western flat beside the boss, with the train on it.
	local railX = boss.x - 34
	local railPoints = {}
	for z = boss.z + 120, boss.z - 120, -8 do
		if Shape.coastFraction(layout, railX, z) < 0.92 then
			table.insert(railPoints, context.ground(railX, z) + Vector3.new(0, 0.2, 0))
		end
	end
	railway(railPoints, landmarks)
	local trainBase = CFrame.lookAt(context.ground(railX, boss.z - 14), context.ground(railX, boss.z - 40))
		* CFrame.new(0, 0.6, 0)
	trainCar(trainBase, 18, true, landmarks)
	for index = 1, 2 do
		trainCar(trainBase * CFrame.new(0, 0, index * 20), 18, false, landmarks)
	end

	-- Torii rising from the sea, lit by the moon.
	torii(context.ground(180, 400) - Vector3.new(0, 2, 0), math.rad(200), 18, 26, landmarks)
end

local definition: IslandBuilder.Definition = {
	layout = layout,
	decorate = decorate,
	photoSpots = {
		{ from = { 0, 55, 400 }, to = { -20, 60, 0 } }, -- arriving: village and the peak
		{ from = { -620, 340, 520 }, to = { -20, 50, -60 } }, -- whole island from the sky
		{ from = { -95, 70, 245 }, to = { -170, 12, 160 } }, -- lantern village
		{ from = { 280, 80, 40 }, to = { 180, 50, -60 } }, -- torii tunnel
		{ from = { -150, 70, -40 }, to = { -264, 35, -130 } }, -- train under the moon
		{ from = { 120, 20, 470 }, to = { 180, 16, 400 } }, -- torii in the sea
	},
}

return definition
