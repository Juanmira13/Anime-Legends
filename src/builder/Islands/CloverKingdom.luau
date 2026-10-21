--!strict
-- Clover Kingdom (Black Clover): a magic medieval kingdom. A humble village of
-- timber cottages with a windmill and wheat fields, a stone bridge over the
-- river, a white castle with blue cone roofs on its hill, lamp posts along
-- the castle road, a haunted forest with glowing mushrooms and violet mist,
-- and the grimoire altar on its cliff: an open book floating under a
-- four-leaf clover of light.

local Root = script.Parent.Parent
local PathWalk = require(Root.Gen.PathWalk)
local Rng = require(Root.Gen.Rng)
local Scatter = require(Root.Gen.Scatter)
local Shape = require(Root.Gen.Shape)
local Buildings = require(Root.Kit.Buildings)
local Nature = require(Root.Kit.Nature)
local Parts = require(Root.Kit.Parts)
local IslandBuilder = require(Root.IslandBuilder)
local CloverKingdomLayout = require(script.Parent.CloverKingdomLayout)

local layout = CloverKingdomLayout
local rgb = Parts.rgb

local PLASTER = { rgb({ 240, 230, 205 }), rgb({ 232, 218, 190 }), rgb({ 245, 238, 222 }) }
local ROOFS = { rgb({ 196, 156, 84 }), rgb({ 172, 74, 52 }), rgb({ 92, 104, 138 }) } -- thatch, tiles, slate
local TIMBER = rgb({ 96, 66, 44 })
local STONE = rgb({ 168, 164, 156 })
local CASTLE_STONE = rgb({ 236, 236, 230 })
local CASTLE_ROOF = rgb({ 72, 112, 204 })
local WINDOW = rgb({ 58, 64, 84 })
local WHEAT = rgb({ 232, 200, 92 })
local LAMP = rgb({ 255, 214, 130 })
local MAGIC = rgb({ 190, 140, 255 })
local CLOVER = rgb({ 90, 230, 120 })
local MEADOW = {
	trunk = rgb({ 112, 82, 60 }),
	leaves = { rgb({ 84, 164, 72 }), rgb({ 104, 180, 80 }), rgb({ 70, 146, 66 }) },
}
local HAUNTED = {
	trunk = rgb({ 58, 48, 56 }),
	leaves = { rgb({ 92, 64, 140 }), rgb({ 64, 88, 110 }), rgb({ 110, 70, 150 }) },
}
local BUSHES = { rgb({ 80, 150, 70 }), rgb({ 96, 166, 76 }) }
local FLOWERS = { rgb({ 200, 160, 255 }), rgb({ 255, 255, 255 }), rgb({ 255, 210, 110 }), rgb({ 255, 140, 170 }) }
local MUSHROOM_CAPS = { rgb({ 170, 110, 255 }), rgb({ 90, 220, 255 }), rgb({ 255, 120, 220 }) }

local function pick<T>(list: { T }, t: number): T
	return list[math.clamp(math.floor(t * #list) + 1, 1, #list)]
end

-- Timber-framed cottage with a steep roof and a chimney.
local function cottage(ground: Vector3, yaw: number, t: number, parent: Instance)
	local model = Parts.model("Cottage", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	local width, depth, height = 12 + t * 6, 9 + t * 3, 9
	Buildings.foundation(base, width, depth, STONE, model)
	Parts.block(
		Vector3.new(width + 0.4, 3, depth + 0.4),
		base * CFrame.new(0, 1.5, 0),
		STONE,
		model,
		{ collide = true }
	)
	Buildings.walls(base * CFrame.new(0, 3, 0), width, depth, height - 3, pick(PLASTER, t), model)
	for _, x in { -width / 2, 0, width / 2 } do
		for _, z in { -depth / 2, depth / 2 } do
			Parts.block(
				Vector3.new(0.8, height - 3, 0.8),
				base * CFrame.new(x, 3 + (height - 3) / 2, z),
				TIMBER,
				model,
				{ shadow = false }
			)
		end
	end
	Parts.block(
		Vector3.new(width + 0.6, 0.7, depth + 0.6),
		base * CFrame.new(0, height - 0.3, 0),
		TIMBER,
		model,
		{ shadow = false }
	)
	Buildings.windows(base, width, depth, 5.5, 2, Vector2.new(2, 2.4), WINDOW, model)
	Buildings.door(base, depth, 2.8, 5.2, TIMBER, model)
	local roof = pick(ROOFS, (t * 2.3) % 1)
	Buildings.gableRoof(base * CFrame.new(0, height, 0), width, depth, depth * 0.75, roof, model, 1.4)
	Parts.block(
		Vector3.new(2, 6, 2),
		base * CFrame.new(width * 0.3, height + depth * 0.45, depth * 0.15),
		STONE,
		model,
		{ shadow = false }
	)
end

local function windmill(ground: Vector3, yaw: number, parent: Instance)
	local model = Parts.model("Windmill", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	Parts.column(12, 2, base * CFrame.new(0, -1, 0), STONE, model, { collide = true })
	Parts.column(9, 22, base * CFrame.new(0, 1, 0), rgb({ 232, 222, 200 }), model, { collide = true })
	Buildings.coneRoof(base * CFrame.new(0, 23, 0), 11, 8, rgb({ 172, 74, 52 }), model)
	Buildings.door(base, 9, 3, 5.5, TIMBER, model)
	local hub = (base * CFrame.new(0, 19, -5.2)).Position
	Parts.cylinder(
		2,
		1.6,
		hub,
		(base * CFrame.new(0, 0, -1)).Position - base.Position,
		TIMBER,
		model,
		{ shadow = false }
	)
	for index = 0, 3 do
		local blade = base
			* CFrame.new(0, 19, -5.8)
			* CFrame.Angles(0, 0, index * math.pi / 2 + math.rad(20))
			* CFrame.new(0, 8, 0)
		Parts.block(Vector3.new(0.6, 16, 0.4), blade, TIMBER, model, { shadow = false })
		Parts.block(
			Vector3.new(3.4, 12, 0.2),
			blade * CFrame.new(1.8, 1, 0),
			rgb({ 244, 240, 226 }),
			model,
			{ shadow = false }
		)
	end
end

-- Field of wheat rows inside a fence, aligned with `yaw`.
local function wheatField(
	center: Vector3,
	yaw: number,
	width: number,
	depth: number,
	context: IslandBuilder.Context,
	parent: Instance
)
	local model = Parts.model("WheatField", parent)
	local frame = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	for row = -depth / 2 + 1.5, depth / 2 - 1.5, 2.6 do
		local mid = (frame * CFrame.new(0, 0, row)).Position
		local ground = context.ground(mid.X - context.cx, mid.Z - context.cz)
		Parts.block(
			Vector3.new(width - 2, 1.4, 1.3),
			CFrame.new(ground + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, yaw, 0),
			Parts.vary(WHEAT, 0.12, (row % 3) / 3),
			model,
			{ shadow = false }
		)
	end
	local corners = {}
	for _, corner in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local point = (frame * CFrame.new(corner[1] * width / 2, 0, corner[2] * depth / 2)).Position
		table.insert(corners, context.ground(point.X - context.cx, point.Z - context.cz))
	end
	for index = 1, 3 do
		Buildings.fence(corners[index], corners[index + 1], TIMBER, model)
	end
end

-- Stone bridge carrying the road over the river.
local function bridge(sample: PathWalk.Sample, height: number, context: IslandBuilder.Context, parent: Instance)
	local model = Parts.model("StoneBridge", parent)
	local position = Vector3.new(context.cx + sample.x, height, context.cz + sample.z)
	local frame = CFrame.lookAt(position, position + Vector3.new(sample.dx, 0, sample.dz))
	Parts.block(
		Vector3.new(14, 1.6, 36),
		frame * CFrame.new(0, -0.8, 0),
		STONE,
		model,
		{ collide = true, name = "Deck" }
	)
	for _, side in { -1, 1 } do
		Parts.block(
			Vector3.new(1.4, 2.6, 36),
			frame * CFrame.new(side * 6.6, 1.3, 0),
			Parts.vary(STONE, 0.15, 0.7),
			model,
			{ collide = true }
		)
		for _, along in { -18, 18 } do
			Parts.block(
				Vector3.new(2.2, 4, 2.2),
				frame * CFrame.new(side * 6.6, 2, along),
				Parts.vary(STONE, 0.2, 0.3),
				model,
				{ collide = true }
			)
		end
	end
	for _, along in { -9, 9 } do
		Parts.block(
			Vector3.new(10, 10, 3),
			frame * CFrame.new(0, -6.5, along),
			Parts.vary(STONE, 0.2, 0.5),
			model,
			{ collide = true }
		)
	end
end

local function lampPost(ground: Vector3, parent: Instance)
	local model = Parts.model("LampPost", parent)
	Parts.column(0.7, 9, CFrame.new(ground - Vector3.new(0, 0.5, 0)), rgb({ 50, 50, 56 }), model, { shadow = false })
	local lamp = Parts.block(
		Vector3.new(1.6, 1.8, 1.6),
		CFrame.new(ground + Vector3.new(0, 9.2, 0)),
		LAMP,
		model,
		{ material = Enum.Material.Neon, shadow = false }
	)
	Parts.light(lamp, LAMP, 14, 1)
	Parts.block(
		Vector3.new(2.2, 0.4, 2.2),
		CFrame.new(ground + Vector3.new(0, 10.3, 0)),
		rgb({ 50, 50, 56 }),
		model,
		{ shadow = false }
	)
end

-- White castle: curtain wall with a gate, round corner towers and a keep.
local function castle(center: Vector3, gateYaw: number, parent: Instance)
	local model = Parts.model("Castle", parent)
	local radius = 50
	local gateDirection = Vector3.new(-math.sin(gateYaw), 0, -math.cos(gateYaw))
	for _, sample in PathWalk.circle(center.X, center.Z, radius, 8) do
		local out = Vector3.new(sample.x - center.X, 0, sample.z - center.Z).Unit
		if out:Dot(gateDirection) < 0.97 then
			local base = CFrame.lookAt(
				Vector3.new(sample.x, center.Y, sample.z),
				Vector3.new(sample.x, center.Y, sample.z) + Vector3.new(sample.dx, 0, sample.dz)
			)
			Parts.block(Vector3.new(4, 16, 8.6), base * CFrame.new(0, 6, 0), CASTLE_STONE, model, { collide = true })
			Parts.block(
				Vector3.new(4.6, 2.4, 3),
				base * CFrame.new(0, 15.2, 0),
				Parts.vary(CASTLE_STONE, 0.08, 0.3),
				model,
				{ shadow = false }
			)
		end
	end
	-- Gatehouse towers.
	local gate = center + gateDirection * radius
	local side = Vector3.new(-gateDirection.Z, 0, gateDirection.X)
	for _, offset in { -1, 1 } do
		local base = CFrame.new(gate + side * offset * 9)
		Parts.column(9, 24, base * CFrame.new(0, -2, 0), CASTLE_STONE, model, { collide = true })
		Buildings.coneRoof(base * CFrame.new(0, 22, 0), 11, 9, CASTLE_ROOF, model)
	end
	-- Corner towers.
	for index = 0, 3 do
		local angle = math.atan2(gateDirection.Z, gateDirection.X) + math.pi / 4 + index * math.pi / 2
		local base = CFrame.new(center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius)
		Parts.column(13, 30, base * CFrame.new(0, -2, 0), CASTLE_STONE, model, { collide = true })
		Parts.column(
			14.5,
			2.2,
			base * CFrame.new(0, 27, 0),
			Parts.vary(CASTLE_STONE, 0.08, 0.4),
			model,
			{ shadow = false }
		)
		Buildings.coneRoof(base * CFrame.new(0, 29, 0), 15, 12, CASTLE_ROOF, model)
	end
	-- Keep with turrets and the great tower.
	local keep = CFrame.new(center) * CFrame.Angles(0, gateYaw, 0)
	Parts.block(Vector3.new(30, 34, 26), keep * CFrame.new(0, 15, 0), CASTLE_STONE, model, { collide = true })
	Buildings.windows(keep * CFrame.new(0, 0, 0), 30, 26, 14, 5, Vector2.new(2.2, 4), WINDOW, model)
	Buildings.windows(keep * CFrame.new(0, 0, 0), 30, 26, 24, 5, Vector2.new(2.2, 4), WINDOW, model)
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local turret = keep * CFrame.new(corner[1] * 15, 32, corner[2] * 13)
		Parts.column(6, 6, turret, CASTLE_STONE, model, { shadow = false })
		Buildings.coneRoof(turret * CFrame.new(0, 6, 0), 7.4, 7, CASTLE_ROOF, model)
	end
	local tower = keep * CFrame.new(0, 32, 0)
	Parts.column(12, 22, tower, CASTLE_STONE, model, { collide = true })
	Buildings.coneRoof(tower * CFrame.new(0, 22, 0), 15, 16, CASTLE_ROOF, model)
	Parts.column(0.4, 8, tower * CFrame.new(0, 37, 0), rgb({ 60, 60, 60 }), model, { shadow = false })
	Parts.block(
		Vector3.new(0.2, 2.6, 4.4),
		tower * CFrame.new(0, 43.6, 2.2),
		rgb({ 200, 50, 60 }),
		model,
		{ shadow = false }
	)
end

local function mushroom(ground: Vector3, size: number, t: number, parent: Instance)
	local model = Parts.model("GlowMushroom", parent)
	Parts.column(
		size * 0.3,
		size,
		CFrame.new(ground - Vector3.new(0, 0.3, 0)),
		rgb({ 232, 226, 214 }),
		model,
		{ shadow = false }
	)
	local cap = Parts.ball(
		size * 1.1,
		ground + Vector3.new(0, size, 0),
		pick(MUSHROOM_CAPS, t),
		model,
		{ material = Enum.Material.Neon, shadow = false }
	)
	if t > 0.6 then
		Parts.light(cap, cap.Color, 12, 1)
	end
end

local function mist(ground: Vector3, parent: Instance)
	local anchor = Parts.block(
		Vector3.new(30, 2, 30),
		CFrame.new(ground + Vector3.new(0, 2, 0)),
		rgb({ 160, 120, 220 }),
		parent,
		{ transparency = 1, shadow = false, name = "VioletMist" }
	)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(rgb({ 170, 120, 230 }))
	emitter.Size = NumberSequence.new(8, 16)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Rate = 3
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 10)
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = anchor
end

-- Open grimoire floating over a pedestal, crowned by a four-leaf clover of light.
local function grimoireAltar(ground: Vector3, facing: number, parent: Instance)
	local model = Parts.model("GrimoireAltar", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, facing, 0)
	Parts.column(18, 1.2, base * CFrame.new(0, -0.4, 0), STONE, model, { collide = true })
	Parts.column(13, 1.2, base * CFrame.new(0, 0.8, 0), Parts.vary(STONE, 0.15, 0.7), model, { collide = true })
	Parts.block(Vector3.new(4, 6, 3), base * CFrame.new(0, 5, 0), STONE, model, { collide = true })
	local book = base * CFrame.new(0, 11, 0)
	for _, side in { -1, 1 } do
		local page = book * CFrame.new(side * 2.4, 0, 0) * CFrame.Angles(0, 0, side * math.rad(-12))
		Parts.block(Vector3.new(4.8, 0.5, 6), page, rgb({ 40, 30, 46 }), model, { shadow = false })
		Parts.block(
			Vector3.new(4.4, 0.3, 5.6),
			page * CFrame.new(0, 0.4, 0),
			rgb({ 250, 244, 226 }),
			model,
			{ shadow = false }
		)
	end
	local glow = Parts.block(
		Vector3.new(0.6, 0.6, 6),
		book * CFrame.new(0, 0.2, 0),
		rgb({ 240, 200, 90 }),
		model,
		{ material = Enum.Material.Neon, shadow = false }
	)
	Parts.light(glow, MAGIC, 30, 2)
	local clover = book * CFrame.new(0, 9, 0)
	for index = 0, 3 do
		local leaf = clover * CFrame.Angles(0, 0, index * math.pi / 2 + math.pi / 4) * CFrame.new(0, 2.2, 0)
		Parts.ball(3.6, leaf.Position, CLOVER, model, { material = Enum.Material.Neon, shadow = false })
	end
	Parts.block(
		Vector3.new(0.5, 4, 0.5),
		clover * CFrame.new(0, -3.5, 0),
		CLOVER,
		model,
		{ material = Enum.Material.Neon, shadow = false }
	)
	local beam = Parts.column(
		3,
		60,
		book * CFrame.new(0, 1, 0),
		MAGIC,
		model,
		{ material = Enum.Material.Neon, transparency = 0.7, shadow = false }
	)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(MAGIC)
	sparkles.Size = NumberSequence.new(0.6)
	sparkles.Rate = 20
	sparkles.Lifetime = NumberRange.new(2, 4)
	sparkles.Speed = NumberRange.new(2, 5)
	sparkles.LightEmission = 1
	sparkles.Parent = beam
	-- Ring of stones with floating crystals.
	for index = 0, 5 do
		local angle = index / 6 * 2 * math.pi
		local pillar = base * CFrame.new(math.cos(angle) * 15, 0, math.sin(angle) * 15)
		Parts.block(
			Vector3.new(3, 9, 3),
			pillar * CFrame.new(0, 3.5, 0),
			Parts.vary(STONE, 0.2, index / 6),
			model,
			{ collide = true }
		)
		Parts.block(
			Vector3.new(1.6, 3, 1.6),
			pillar * CFrame.new(0, 11.5, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			MAGIC,
			model,
			{ material = Enum.Material.Neon, shadow = false }
		)
	end
end

local function decorate(context: IslandBuilder.Context)
	local rng = context.rng
	local decor = context.decor
	local nature = Parts.folder("Nature", decor)
	local village = Parts.folder("Village", decor)
	local landmarks = Parts.folder("Landmarks", decor)
	local easy, hard, boss = layout.zones[1], layout.zones[3], layout.zones[4]
	local plaza = layout.plaza

	-- Village: cottages around the square, a windmill and wheat fields.
	for index = 1, 12 do
		local angle = index / 12 * 2 * math.pi + Rng.range(rng, -0.15, 0.15)
		local distance = easy.radius + Rng.range(rng, 18, 38)
		local x, z = easy.x + math.cos(angle) * distance, easy.z + math.sin(angle) * distance
		-- Gentle ground only: on steep slopes the uphill wall sinks into the hill.
		if context.isFree(x, z, 4) and Shape.slope(layout, x, z) < 0.3 then
			cottage(context.groundMin(x, z, 7), IslandBuilder.yawToward(x, z, easy.x, easy.z), Rng.next(rng), village)
		end
	end
	windmill(context.ground(easy.x - 90, easy.z + 40), math.rad(30), landmarks)
	for _, field in { { -330, 170, 0.3 }, { -190, 210, -0.2 }, { -350, 100, 0.5 } } do
		local x, z = field[1], field[2]
		if context.isFree(x, z, 2) then
			wheatField(context.ground(x, z), field[3], 26, 18, context, village)
		end
	end
	for _, point in
		Scatter.inCircle(rng, easy.x, easy.z, 110, 10, 12, function(x, z)
			return context.isFree(x, z, 3)
		end)
	do
		Parts.ball(
			Rng.range(rng, 3, 4.5),
			context.ground(point.x, point.z) + Vector3.new(0, 1, 0),
			Parts.vary(WHEAT, 0.15, Rng.next(rng)),
			village,
			{ shadow = false }
		)
	end

	-- Stone bridge where the road crosses the river.
	local road = layout.paths[1]
	for _, sample in PathWalk.samples(road.points, 2) do
		local level = Shape.waterLevel(layout, sample.x, sample.z, -math.huge)
		if level > -math.huge then
			-- First sample over the river: center the bridge on the crossing.
			local crossing = PathWalk.samples(road.points, 1000, sample.distance + 8)[1]
			local a, b = road.points[4], road.points[5]
			bridge(crossing, (a[3] + b[3]) / 2 + 1, context, landmarks)
			break
		end
	end

	-- Castle on the hill, gate toward the castle road.
	local castleRoad = layout.paths[2].points
	local gateEnd = castleRoad[#castleRoad]
	local castleCenter = context.ground(80, -90)
	castle(castleCenter, IslandBuilder.yawToward(80, -90, gateEnd[1], gateEnd[2]), landmarks)
	for _, sample in PathWalk.samples(castleRoad, 16, 8) do
		for _, side in { -1, 1 } do
			local x, z = sample.x + sample.dz * side * 7, sample.z - sample.dx * side * 7
			lampPost(context.ground(x, z), village)
		end
	end

	-- Meadow trees away from the haunted forest.
	for _, point in
		Scatter.inCircle(rng, 0, 0, 480, 170, 15, function(x, z)
			return x < 150 and context.isFree(x, z, 6) and Shape.height(layout, x, z) < 44
		end)
	do
		Nature.roundTree(context.ground(point.x, point.z), Rng.range(rng, 15, 26), Rng.next(rng), MEADOW, nature)
	end
	for _, sample in PathWalk.samples(road.points, 16, 8) do
		local side = if math.floor(sample.distance / 16) % 2 == 0 then 1 else -1
		local x, z = sample.x + sample.dz * side * 10, sample.z - sample.dx * side * 10
		if context.isFree(x, z, 1) then
			Nature.bush(context.ground(x, z), Rng.range(rng, 3, 4.5), Rng.next(rng), BUSHES, nature)
		end
	end
	for _, point in
		Scatter.inCircle(rng, -100, 60, 380, 110, 9, function(x, z)
			return x < 150 and context.isFree(x, z, 3)
		end)
	do
		Nature.flowers(context.ground(point.x, point.z), Rng.next(rng), FLOWERS, nature)
	end

	-- Haunted forest: dark trees, glowing mushrooms and violet mist.
	for _, point in
		Scatter.inCircle(rng, hard.x, hard.z, 190, 120, 11, function(x, z)
			return x > 150 and context.isFree(x, z, 5)
		end)
	do
		Nature.roundTree(context.ground(point.x, point.z), Rng.range(rng, 18, 32), Rng.next(rng), HAUNTED, nature)
	end
	for _, point in
		Scatter.inCircle(rng, hard.x, hard.z, 150, 40, 8, function(x, z)
			return x > 150 and context.isFree(x, z, 2)
		end)
	do
		mushroom(context.ground(point.x, point.z), Rng.range(rng, 1.5, 4), Rng.next(rng), nature)
	end
	for index = 0, 5 do
		local angle = index / 6 * 2 * math.pi
		mist(context.ground(hard.x + math.cos(angle) * 70, hard.z + math.sin(angle) * 70), nature)
	end

	-- Grimoire altar behind the boss, as seen from the road.
	local approach = road.points[#road.points - 1]
	local dx, dz = boss.x - approach[1], boss.z - approach[2]
	local length = math.sqrt(dx * dx + dz * dz)
	local ax, az = boss.x + dx / length * 24, boss.z + dz / length * 24
	grimoireAltar(context.ground(ax, az), IslandBuilder.yawToward(ax, az, approach[1], approach[2]), landmarks)

	-- Heraldic banners around the plaza.
	for _, degrees in { 230, 310 } do
		local angle = math.rad(degrees)
		local ground = context.ground(
			plaza.x + math.cos(angle) * (plaza.radius - 3),
			plaza.z + math.sin(angle) * (plaza.radius - 3)
		)
		Parts.column(0.6, 14, CFrame.new(ground), rgb({ 70, 70, 76 }), village, { shadow = false })
		Parts.block(
			Vector3.new(0.3, 7, 4),
			CFrame.new(ground + Vector3.new(0, 10, 2.1)),
			CASTLE_ROOF,
			village,
			{ shadow = false }
		)
		Parts.block(
			Vector3.new(0.35, 2, 2),
			CFrame.new(ground + Vector3.new(0, 10.5, 2.1)),
			CLOVER,
			village,
			{ material = Enum.Material.Neon, shadow = false }
		)
	end
end

local definition: IslandBuilder.Definition = {
	layout = layout,
	decorate = decorate,
	photoSpots = {
		{ from = { 0, 60, 330 }, to = { 0, 15, 120 } }, -- arriving: plaza and the castle ahead
		{ from = { -580, 290, 480 }, to = { 0, 20, -40 } }, -- whole island from the sky
		{ from = { -40, 75, 40 }, to = { 80, 55, -90 } }, -- the castle
		{ from = { -190, 42, 210 }, to = { -260, 12, 130 } }, -- humble village
		{ from = { 175, 80, 150 }, to = { 260, 14, 40 } }, -- haunted forest
		{ from = { 310, 72, -80 }, to = { 230, 42, -175 } }, -- grimoire altar
	},
}

return definition
