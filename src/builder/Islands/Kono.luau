--!strict
-- Kono (Naruto): a ninja village in the forest at sunset. Japanese houses with
-- colored roofs and rooftop water tanks along the streets, a great entrance
-- gate on the road from the plaza, the village water tower and market stalls,
-- a training field with wooden posts, power poles along the road, a dense
-- forest, giant trees on the eastern terrace and a waterfall falling from the
-- northern ridge between two guardian statues (provisional, for Blender).

local Root = script.Parent.Parent
local PathWalk = require(Root.Gen.PathWalk)
local Rng = require(Root.Gen.Rng)
local Scatter = require(Root.Gen.Scatter)
local Shape = require(Root.Gen.Shape)
local Buildings = require(Root.Kit.Buildings)
local Nature = require(Root.Kit.Nature)
local Parts = require(Root.Kit.Parts)
local IslandBuilder = require(Root.IslandBuilder)
local KonoLayout = require(script.Parent.KonoLayout)

local layout = KonoLayout
local rgb = Parts.rgb

local WALLS = { rgb({ 242, 234, 214 }), rgb({ 236, 222, 192 }), rgb({ 228, 216, 200 }) }
local ROOFS = { rgb({ 196, 72, 52 }), rgb({ 226, 122, 52 }), rgb({ 70, 140, 120 }), rgb({ 150, 62, 50 }) }
local WOOD = rgb({ 128, 88, 56 })
local DARK_WOOD = rgb({ 82, 56, 40 })
local STONE = rgb({ 165, 156, 146 })
local WINDOW = rgb({ 60, 62, 74 })
local GATE_GREEN = rgb({ 62, 132, 84 })
local LANTERN = rgb({ 228, 72, 44 })
local WATER = rgb({ 120, 200, 235 })
local FOREST = {
	trunk = rgb({ 112, 80, 52 }),
	leaves = { rgb({ 72, 142, 48 }), rgb({ 98, 166, 56 }), rgb({ 56, 120, 44 }), rgb({ 120, 176, 62 }) },
}
local GIANT = {
	trunk = rgb({ 96, 68, 46 }),
	leaves = { rgb({ 50, 112, 48 }), rgb({ 64, 128, 52 }), rgb({ 44, 100, 46 }) },
}
local BUSHES = { rgb({ 70, 140, 50 }), rgb({ 95, 160, 60 }), rgb({ 84, 150, 58 }) }
local FLOWERS = { rgb({ 255, 200, 90 }), rgb({ 255, 130, 90 }), rgb({ 255, 236, 200 }) }
local ROCK = rgb({ 140, 128, 116 })

local function pick<T>(list: { T }, t: number): T
	return list[math.clamp(math.floor(t * #list) + 1, 1, #list)]
end

-- Japanese house: stone foundation, plaster walls with a timber band, colored
-- gable roof, sometimes a second floor, a rooftop water tank and a lantern.
local function house(ground: Vector3, yaw: number, t: number, parent: Instance)
	local model = Parts.model("House", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	local width, depth = 13 + t * 7, 10 + (t * 7 % 1) * 4
	local floors = if t > 0.55 then 2 else 1
	local height = 8 * floors
	local wall = pick(WALLS, t)
	local roof = pick(ROOFS, (t * 3.7) % 1)

	Buildings.foundation(base, width, depth, STONE, model)
	Buildings.walls(base, width, depth, height, wall, model)
	for floor = 1, floors do
		Parts.block(Vector3.new(width + 0.4, 0.8, depth + 0.4), base * CFrame.new(0, floor * 8 - 0.4, 0), DARK_WOOD, model, { shadow = false })
		Buildings.windows(base * CFrame.new(0, (floor - 1) * 8, 0), width, depth, 4.5, math.max(2, math.floor(width / 5)), Vector2.new(2.2, 2.2), WINDOW, model)
	end
	Buildings.door(base, depth, 3, 5.5, DARK_WOOD, model)
	Buildings.gableRoof(base * CFrame.new(0, height, 0), width, depth, 4.5, roof, model, 2.2)
	Parts.block(Vector3.new(width + 4.6, 0.7, 1), base * CFrame.new(0, height + 4.6, 0), Parts.vary(roof, 0.3, 0.2), model, { shadow = false })

	if t > 0.35 then
		-- Rooftop water tank, a village signature.
		local tank = base * CFrame.new(width * 0.25, height + 3, depth * 0.1)
		Parts.column(3.2, 3.6, tank, rgb({ 205, 205, 196 }), model, { shadow = false })
		Parts.disc(3.6, 0.5, (tank * CFrame.new(0, 3.8, 0)).Position, roof, model, { shadow = false })
	end
	if t < 0.6 then
		local lantern = Parts.ball(1.3, (base * CFrame.new(2.6, 5.4, -depth / 2 - 0.9)).Position, LANTERN, model, { material = Enum.Material.Neon, shadow = false })
		Parts.light(lantern, rgb({ 255, 170, 110 }), 12, 1.2)
	end
end

-- Village water tower: four legs, a round tank and a red cone roof.
local function waterTower(ground: Vector3, parent: Instance)
	local model = Parts.model("WaterTower", parent)
	for index = 0, 3 do
		local angle = index * math.pi / 2 + math.pi / 4
		local foot = ground + Vector3.new(math.cos(angle) * 5, 0, math.sin(angle) * 5)
		Parts.column(1.4, 24, CFrame.new(foot - Vector3.new(0, 1, 0)), DARK_WOOD, model, { collide = true })
	end
	Parts.disc(14, 1, ground + Vector3.new(0, 23.5, 0), WOOD, model, { collide = true })
	Parts.column(12, 11, CFrame.new(ground + Vector3.new(0, 24, 0)), rgb({ 214, 206, 188 }), model, { collide = true })
	Parts.disc(12.4, 1, ground + Vector3.new(0, 29.5, 0), LANTERN, model, { shadow = false })
	Buildings.coneRoof(CFrame.new(ground + Vector3.new(0, 35, 0)), 14, 7, rgb({ 196, 72, 52 }), model)
end

-- Great gate across the road: two pillars, a green roofed crossbeam.
local function gate(sample: PathWalk.Sample, context: IslandBuilder.Context, parent: Instance)
	local model = Parts.model("VillageGate", parent)
	local ground = context.ground(sample.x, sample.z)
	local yaw = math.atan2(-sample.dx, -sample.dz)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	for _, side in { -1, 1 } do
		Parts.block(Vector3.new(3.4, 22, 3.4), base * CFrame.new(side * 11, 9, 0), rgb({ 230, 222, 200 }), model, { collide = true })
		Parts.block(Vector3.new(4.4, 1.2, 4.4), base * CFrame.new(side * 11, 0.2, 0), STONE, model, { collide = true })
	end
	Parts.block(Vector3.new(28, 3, 4), base * CFrame.new(0, 20.5, 0), DARK_WOOD, model, { collide = true })
	Buildings.gableRoof(base * CFrame.new(0, 22, 0) * CFrame.Angles(0, 0, 0), 30, 5, 3.2, GATE_GREEN, model, 1.5)
	Parts.block(Vector3.new(9, 4, 0.6), base * CFrame.new(0, 16.5, -2.2), rgb({ 240, 236, 220 }), model, { shadow = false })
end

local function trainingPost(ground: Vector3, t: number, parent: Instance)
	local model = Parts.model("TrainingPost", parent)
	Parts.column(1.8, 6.5, CFrame.new(ground - Vector3.new(0, 0.5, 0)), WOOD, model, { collide = true })
	for _, y in { 2.4, 4.6 } do
		Parts.disc(2.1, 0.5, ground + Vector3.new(0, y, 0), rgb({ 214, 196, 150 }), model, { shadow = false })
	end
	if t > 0.5 then
		local target = Parts.cylinder(3, 0.4, ground + Vector3.new(0, 5, -1.1), Vector3.new(0, 0, -1), rgb({ 230, 230, 220 }), model, { shadow = false })
		target.Name = "Target"
		Parts.cylinder(1.4, 0.45, ground + Vector3.new(0, 5, -1.15), Vector3.new(0, 0, -1), LANTERN, model, { shadow = false })
	end
end

local function marketStall(ground: Vector3, yaw: number, t: number, parent: Instance)
	local model = Parts.model("Stall", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	Parts.block(Vector3.new(7, 2.4, 3.5), base * CFrame.new(0, 1.2, 0), WOOD, model, { collide = true })
	for _, corner in { { -3.2, -1.6 }, { 3.2, -1.6 }, { -3.2, 1.6 }, { 3.2, 1.6 } } do
		Parts.block(Vector3.new(0.4, 6, 0.4), base * CFrame.new(corner[1], 3, corner[2]), DARK_WOOD, model, { shadow = false })
	end
	Buildings.gableRoof(base * CFrame.new(0, 6, 0), 7.4, 4, 1.8, pick(ROOFS, t), model, 0.8)
	for index = 0, 2 do
		Parts.ball(1.2, (base * CFrame.new(-2 + index * 2, 2.9, -0.6)).Position, pick(FLOWERS, (t + index * 0.3) % 1), model, { shadow = false })
	end
end

-- Power poles along the road, linked by wires.
local function powerLine(points: { { number } }, context: IslandBuilder.Context, parent: Instance)
	local model = Parts.model("PowerLine", parent)
	local previous: Vector3? = nil
	for _, sample in PathWalk.samples(points, 38, 12) do
		local x, z = sample.x + sample.dz * 9, sample.z - sample.dx * 9
		local ground = context.ground(x, z)
		Parts.column(1, 16, CFrame.new(ground - Vector3.new(0, 1, 0)), DARK_WOOD, model, { shadow = false })
		local top = ground + Vector3.new(0, 14.5, 0)
		Parts.beam(top - Vector3.new(sample.dz, 0, -sample.dx) * 2.5, top + Vector3.new(sample.dz, 0, -sample.dx) * 2.5, 0.5, DARK_WOOD, model, { shadow = false })
		if previous then
			Parts.beam(previous, top, 0.15, rgb({ 40, 40, 44 }), model, { shadow = false })
		end
		previous = top
	end
end

-- Stone guardian figure facing `facing` (provisional, to remake in Blender).
local function statue(ground: Vector3, yaw: number, parent: Instance)
	local model = Parts.model("GuardianStatue", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	local stone = rgb({ 150, 146, 140 })
	Parts.block(Vector3.new(16, 6, 12), base * CFrame.new(0, 1, 0), Parts.vary(stone, 0.2, 0.2), model, { collide = true })
	for _, side in { -1, 1 } do
		Parts.block(Vector3.new(4.5, 14, 5), base * CFrame.new(side * 3, 11, 0), stone, model, { collide = true })
	end
	Parts.block(Vector3.new(13, 14, 7), base * CFrame.new(0, 25, 0), Parts.vary(stone, 0.15, 0.6), model, { collide = true })
	Parts.block(Vector3.new(4, 13, 4.5), base * CFrame.new(-8.5, 26, 0) * CFrame.Angles(0, 0, math.rad(-8)), stone, model, { collide = true })
	Parts.block(Vector3.new(4, 13, 4.5), base * CFrame.new(8.5, 27, -2) * CFrame.Angles(math.rad(35), 0, math.rad(8)), stone, model, { collide = true })
	Parts.ball(8, (base * CFrame.new(0, 36, 0)).Position, Parts.vary(stone, 0.1, 0.8), model, { collide = true })
end

local function waterfall(context: IslandBuilder.Context, parent: Instance)
	local model = Parts.model("Waterfall", parent)
	local top = context.ground(75, -232) + Vector3.new(0, 4, 0)
	local bottom = context.ground(76, -222) + Vector3.new(0, 1, 0)
	local mid = (top + bottom) / 2
	-- Sheet along the drop: its Y axis runs from the pool up to the lip.
	local up = (top - bottom).Unit
	local back = Vector3.xAxis:Cross(up).Unit
	local frame = CFrame.fromMatrix(mid, up:Cross(back), up, back)
	local sheet = Parts.block(Vector3.new(14, (top - bottom).Magnitude + 6, 1.2), frame, WATER, model, { transparency = 0.35, shadow = false, name = "FallingWater" })
	sheet.Material = Enum.Material.Glass
	-- Foam where the fall meets the water below.
	local level = Shape.waterLevel(layout, 72, -212, 0)
	local foamAt = context.ground(72, -212)
	local foam = Parts.disc(18, 0.4, Vector3.new(foamAt.X, level + 0.2, foamAt.Z), rgb({ 245, 252, 255 }), model, { transparency = 0.25, shadow = false, name = "Foam" })
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.new(1, 1, 1))
	mist.Size = NumberSequence.new(4, 9)
	mist.Transparency = NumberSequence.new(0.6, 1)
	mist.Lifetime = NumberRange.new(2, 3)
	mist.Rate = 12
	mist.Speed = NumberRange.new(2, 4)
	mist.SpreadAngle = Vector2.new(60, 60)
	mist.Parent = foam
end

local function decorate(context: IslandBuilder.Context)
	local rng = context.rng
	local decor = context.decor
	local nature = Parts.folder("Nature", decor)
	local village = Parts.folder("Village", decor)
	local landmarks = Parts.folder("Landmarks", decor)
	local medium, hard, easy = layout.zones[2], layout.zones[3], layout.zones[1]

	-- Village houses along the streets and the main road through the village.
	local function lineWithHouses(points: { { number } }, spacing: number, offset: number)
		for _, sample in PathWalk.samples(points, spacing, spacing / 2) do
			for _, side in { -1, 1 } do
				local x, z = sample.x + sample.dz * side * offset, sample.z - sample.dx * side * offset
				if context.isFree(x, z, 3) then
					house(context.groundMin(x, z, 8), context.facePath(x, z), Rng.next(rng), village)
				end
			end
		end
	end
	lineWithHouses(layout.paths[2].points, 21, 16)
	lineWithHouses(layout.paths[3].points, 21, 16)
	lineWithHouses({ { -150, 60 }, { 20, 40 }, { 140, 20 } }, 24, 19)
	waterTower(context.ground(medium.x + 58, medium.z + 30), landmarks)

	-- Entrance gate on the road, just past the plaza.
	for _, sample in PathWalk.samples(layout.paths[1].points, 1000, 52) do
		gate(sample, context, landmarks)
	end

	-- Market stalls around the plaza, clear of the road, gacha and portals.
	local plaza = layout.plaza
	for _, degrees in { 225, 245, 295, 315 } do
		local angle = math.rad(degrees)
		local x, z = plaza.x + math.cos(angle) * (plaza.radius - 4), plaza.z + math.sin(angle) * (plaza.radius - 4)
		marketStall(context.ground(x, z), IslandBuilder.yawToward(x, z, plaza.x, plaza.z), Rng.next(rng), village)
	end

	-- Training field: posts around the combat area.
	for index = 0, 13 do
		local angle = index / 14 * 2 * math.pi
		local x, z = easy.x + math.cos(angle) * (easy.radius + 5), easy.z + math.sin(angle) * (easy.radius + 5)
		if Shape.pathInside(layout, x, z) < -2 then
			trainingPost(context.ground(x, z), Rng.next(rng), village)
		end
	end

	powerLine({ { -120, 170 }, { -250, 90 }, { -150, 60 }, { 20, 40 }, { 140, 20 } }, context, village)

	-- Forest everywhere outside the village, thinning out up the mountains.
	for _, point in Scatter.inCircle(rng, 0, 0, 470, 300, 13, function(x, z)
		local villageDistance = math.sqrt((x - medium.x) ^ 2 + (z - medium.z) ^ 2)
		return villageDistance > 125 and context.isFree(x, z, 6) and Shape.height(layout, x, z) < 70
	end) do
		Nature.roundTree(context.ground(point.x, point.z), Rng.range(rng, 16, 30), Rng.next(rng), FOREST, nature)
	end

	-- Giant trees on the forest terrace.
	for index = 1, 12 do
		local angle = index / 12 * 2 * math.pi + Rng.range(rng, -0.2, 0.2)
		local distance = hard.radius + Rng.range(rng, 18, 55)
		local x, z = hard.x + math.cos(angle) * distance, hard.z + math.sin(angle) * distance
		if context.isFree(x, z, 4) then
			Nature.giantTree(context.ground(x, z), Rng.range(rng, 48, 66), Rng.next(rng), GIANT, nature)
		end
	end

	-- Bushes along the road, rocks on the slopes, flowers in the meadows.
	for _, sample in PathWalk.samples(layout.paths[1].points, 14, 7) do
		local side = if math.floor(sample.distance / 14) % 2 == 0 then 1 else -1
		local x, z = sample.x + sample.dz * side * 10, sample.z - sample.dx * side * 10
		if context.isFree(x, z, 1) then
			Nature.bush(context.ground(x, z), Rng.range(rng, 3, 5), Rng.next(rng), BUSHES, nature)
		end
	end
	for _, point in Scatter.inCircle(rng, 0, -200, 300, 45, 20, function(x, z)
		return Shape.height(layout, x, z) > 30 and Shape.slope(layout, x, z) < 1.4 and Shape.pathInside(layout, x, z) < -4
	end) do
		Nature.rock(context.ground(point.x, point.z), Rng.range(rng, 4, 9), Rng.next(rng), ROCK, nature)
	end
	for _, point in Scatter.inCircle(rng, 0, 0, 470, 80, 9, function(x, z)
		return context.isFree(x, z, 3)
	end) do
		Nature.flowers(context.ground(point.x, point.z), Rng.next(rng), FLOWERS, nature)
	end

	-- The waterfall and its guardians.
	waterfall(context, landmarks)
	statue(context.ground(48, -238), math.rad(200), landmarks)
	statue(context.ground(104, -238), math.rad(160), landmarks)
end

local definition: IslandBuilder.Definition = {
	layout = layout,
	decorate = decorate,
	photoSpots = {
		{ from = { 0, 60, 335 }, to = { 0, 14, 140 } }, -- arriving: plaza, gate and village
		{ from = { -560, 280, 520 }, to = { 0, 20, -40 } }, -- whole island from the sky
		{ from = { -70, 45, 130 }, to = { 20, 16, 40 } }, -- village streets
		{ from = { 80, 75, -130 }, to = { 75, 35, -225 } }, -- waterfall valley
		{ from = { 200, 60, 50 }, to = { 290, 32, -10 } }, -- giant forest terrace
		{ from = { -175, 32, 150 }, to = { -250, 10, 90 } }, -- training field
	},
}

return definition
