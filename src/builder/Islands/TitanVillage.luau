--!strict
-- Titan Village (Attack on Titan): a town in danger behind a giant ring wall.
-- The wall stands 70 studs tall with battlements and cannons, arched gates to
-- the south and east and a collapsed breach to the north where the boss
-- waits among the rubble. Inside, stone-and-timber houses and a church with
-- a steeple; outside, farms to the west, pines, and a forest of giant trees
-- on the eastern plateau.

local Root = script.Parent.Parent
local PathWalk = require(Root.Gen.PathWalk)
local Rng = require(Root.Gen.Rng)
local Scatter = require(Root.Gen.Scatter)
local Shape = require(Root.Gen.Shape)
local Buildings = require(Root.Kit.Buildings)
local Nature = require(Root.Kit.Nature)
local Parts = require(Root.Kit.Parts)
local IslandBuilder = require(Root.IslandBuilder)
local TitanVillageLayout = require(script.Parent.TitanVillageLayout)

local layout = TitanVillageLayout
local rgb = Parts.rgb

-- The ring wall, relative to the island center.
local WALL_X, WALL_Z, WALL_RADIUS = 30, -40, 190
local WALL_HEIGHT = 70
local GATE_HALF_ANGLE = 0.075 -- radians each side of a gate's center (about 14 studs)
local BREACH_HALF_ANGLE = 0.11

local WALL_STONE = rgb({ 168, 162, 150 })
local HOUSE_STONE = rgb({ 150, 146, 138 })
local PLASTER = { rgb({ 226, 216, 196 }), rgb({ 214, 204, 184 }), rgb({ 232, 224, 206 }) }
local ROOFS = { rgb({ 126, 62, 50 }), rgb({ 96, 74, 60 }), rgb({ 90, 92, 100 }) }
local TIMBER = rgb({ 82, 60, 44 })
local WINDOW = rgb({ 54, 58, 70 })
local IRON = rgb({ 52, 52, 56 })
local CROP = rgb({ 104, 150, 70 })
local HAY = rgb({ 214, 186, 104 })
local PINES = {
	trunk = rgb({ 100, 76, 58 }),
	leaves = { rgb({ 68, 102, 60 }), rgb({ 82, 116, 68 }), rgb({ 58, 88, 54 }) },
}
local GIANT = {
	trunk = rgb({ 104, 78, 56 }),
	leaves = { rgb({ 62, 98, 56 }), rgb({ 74, 110, 62 }), rgb({ 54, 86, 50 }) },
}
local ROCK = rgb({ 150, 140, 125 })

local function pick<T>(list: { T }, t: number): T
	return list[math.clamp(math.floor(t * #list) + 1, 1, #list)]
end

local function angleDifference(a: number, b: number): number
	return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
end

local function ringAngle(x: number, z: number): number
	return math.atan2(z - WALL_Z, x - WALL_X)
end

-- Stone ground floor, timber upper floor, steep roof and a chimney.
local function townHouse(ground: Vector3, yaw: number, t: number, parent: Instance)
	local model = Parts.model("TownHouse", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	local width, depth = 10 + t * 5, 9 + (t * 5 % 1) * 3
	Buildings.foundation(base, width, depth, HOUSE_STONE, model)
	Buildings.walls(base, width, depth, 6, HOUSE_STONE, model)
	Buildings.walls(base * CFrame.new(0, 6, 0), width + 0.8, depth + 0.8, 6.5, pick(PLASTER, t), model)
	for _, x in { -width / 2 - 0.4, 0, width / 2 + 0.4 } do
		Parts.block(Vector3.new(0.7, 6.5, depth + 1), base * CFrame.new(x, 9.25, 0), TIMBER, model, { shadow = false })
	end
	Buildings.windows(
		base * CFrame.new(0, 6, 0),
		width + 0.8,
		depth + 0.8,
		3.4,
		2,
		Vector2.new(1.8, 2.2),
		WINDOW,
		model
	)
	Buildings.door(base, depth, 2.6, 4.6, TIMBER, model)
	Buildings.gableRoof(
		base * CFrame.new(0, 12.5, 0),
		width + 0.8,
		depth + 0.8,
		depth * 0.85,
		pick(ROOFS, (t * 3.1) % 1),
		model,
		1
	)
	Parts.block(
		Vector3.new(1.8, 6, 1.8),
		base * CFrame.new(-width * 0.3, 15, -depth * 0.1),
		HOUSE_STONE,
		model,
		{ shadow = false }
	)
end

local function church(ground: Vector3, yaw: number, parent: Instance)
	local model = Parts.model("Church", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	Buildings.foundation(base, 22, 34, HOUSE_STONE, model)
	Buildings.walls(base, 22, 34, 18, rgb({ 214, 208, 196 }), model)
	Buildings.gableRoof(
		base * CFrame.new(0, 18, 0) * CFrame.Angles(0, math.pi / 2, 0),
		34,
		22,
		12,
		rgb({ 88, 92, 104 }),
		model,
		1
	)
	local tower = base * CFrame.new(0, 0, -21)
	Buildings.foundation(tower, 10, 10, HOUSE_STONE, model)
	Buildings.walls(tower, 10, 10, 40, rgb({ 204, 198, 186 }), model)
	Parts.block(Vector3.new(4, 6, 10.4), tower * CFrame.new(0, 33, 0), IRON, model, { shadow = false })
	Parts.block(Vector3.new(10.4, 6, 4), tower * CFrame.new(0, 33, 0), IRON, model, { shadow = false })
	Buildings.coneRoof(tower * CFrame.new(0, 40, 0), 12, 22, rgb({ 88, 92, 104 }), model, 8)
	Parts.block(
		Vector3.new(0.6, 5, 0.6),
		tower * CFrame.new(0, 64, 0),
		rgb({ 210, 180, 90 }),
		model,
		{ shadow = false }
	)
	Parts.block(
		Vector3.new(3, 0.6, 0.6),
		tower * CFrame.new(0, 65, 0),
		rgb({ 210, 180, 90 }),
		model,
		{ shadow = false }
	)
	Buildings.windows(base, 22, 34, 10, 3, Vector2.new(2.4, 6), rgb({ 120, 150, 210 }), model)
	Buildings.door(tower, 10, 4, 8, TIMBER, model)
end

local function cannon(top: Vector3, outward: Vector3, parent: Instance)
	local model = Parts.model("Cannon", parent)
	Parts.block(
		Vector3.new(4, 1.6, 5),
		CFrame.lookAt(top + Vector3.new(0, 0.8, 0), top + Vector3.new(0, 0.8, 0) + outward),
		TIMBER,
		model,
		{ shadow = false }
	)
	Parts.cylinder(1.8, 7, top + Vector3.new(0, 2.4, 0) + outward * 2, outward, IRON, model, { shadow = false })
end

-- The ring wall: a level top all around (segments reach down to the ground),
-- textured stone with darker courses, buttresses outside, battlements and
-- cannons on top, two gatehouses and the breach.
local function ringWall(context: IslandBuilder.Context, gateAngles: { number }, breachAngle: number, parent: Instance)
	local model = Parts.model("RingWall", parent)
	local samples = PathWalk.circle(WALL_X, WALL_Z, WALL_RADIUS, 10)
	local stone = { material = Enum.Material.Slate, collide = true }
	local highest = -math.huge
	for _, sample in samples do
		highest = math.max(highest, context.ground(sample.x, sample.z).Y)
	end
	local top = highest + WALL_HEIGHT

	for index, sample in samples do
		local angle = ringAngle(sample.x, sample.z)
		local nearGate = false
		for _, gate in gateAngles do
			nearGate = nearGate or angleDifference(angle, gate) < GATE_HALF_ANGLE
		end
		local breach = angleDifference(angle, breachAngle)
		if not nearGate and breach > BREACH_HALF_ANGLE then
			local ground = context.groundMin(sample.x, sample.z, 6)
			-- Broken, lower segments at the edges of the breach.
			local segmentTop = if breach < BREACH_HALF_ANGLE * 2
				then ground.Y + WALL_HEIGHT * (0.35 + (breach - BREACH_HALF_ANGLE) / BREACH_HALF_ANGLE * 0.5)
				else top
			local bottom = ground.Y - 8
			local height = segmentTop - bottom
			local position = Vector3.new(ground.X, bottom + height / 2, ground.Z)
			local frame = CFrame.lookAt(position, position + Vector3.new(sample.dx, 0, sample.dz))
			Parts.block(
				Vector3.new(12, height, 10.6),
				frame,
				Parts.vary(WALL_STONE, 0.08, (index % 5) / 5),
				model,
				stone
			)
			-- Darker stone courses every 14 studs.
			for y = bottom + 14, segmentTop - 4, 14 do
				Parts.block(
					Vector3.new(12.05, 1.2, 10.9),
					CFrame.new(position.X, y, position.Z) * frame.Rotation,
					Parts.vary(WALL_STONE, 0.25, 0.1),
					model,
					{ shadow = false }
				)
			end
			if segmentTop == top then
				local outward = Vector3.new(sample.x - WALL_X, 0, sample.z - WALL_Z).Unit
				local crown = CFrame.new(position.X, top, position.Z) * frame.Rotation
				Parts.block(
					Vector3.new(12.4, 1.4, 11.6),
					crown * CFrame.new(0, 0.7, 0),
					Parts.vary(WALL_STONE, 0.15, 0.8),
					model,
					{ shadow = false }
				)
				if index % 2 == 0 then
					Parts.block(
						Vector3.new(2.4, 3.4, 5),
						crown * CFrame.new(-5, 3.1, 0),
						WALL_STONE,
						model,
						{ shadow = false }
					)
				end
				if index % 4 == 0 then
					-- Buttress on the outer face.
					local foot = Vector3.new(ground.X, bottom, ground.Z) + outward * 8
					Parts.block(
						Vector3.new(5, top - bottom - 6, 6),
						CFrame.lookAt(
							(foot + Vector3.new(ground.X, top - 6, ground.Z) + outward * 5.5) / 2,
							(foot + Vector3.new(ground.X, top - 6, ground.Z) + outward * 5.5) / 2 + outward
						) * CFrame.Angles(math.rad(-4), 0, 0),
						Parts.vary(WALL_STONE, 0.18, 0.4),
						model,
						stone
					)
				end
				if index % 9 == 0 then
					cannon(crown.Position + Vector3.new(0, 1.4, 0), outward, model)
				end
			end
		end
	end
	-- Gatehouses: towers on both sides and the wall above an arched opening.
	for _, gate in gateAngles do
		local center = Vector3.new(WALL_X + math.cos(gate) * WALL_RADIUS, 0, WALL_Z + math.sin(gate) * WALL_RADIUS)
		local ground = context.ground(center.X, center.Z)
		local outward = Vector3.new(math.cos(gate), 0, math.sin(gate))
		local side = Vector3.new(-outward.Z, 0, outward.X)
		local frame = CFrame.lookAt(ground, ground + side)
		local opening = ground.Y + 34
		Parts.block(
			Vector3.new(12, top - opening, 30),
			CFrame.new(ground.X, (opening + top) / 2, ground.Z) * frame.Rotation,
			Parts.vary(WALL_STONE, 0.1, 0.6),
			model,
			stone
		)
		for _, offset in { -1, 1 } do
			local towerTop = top + 8
			Parts.block(
				Vector3.new(18, towerTop - ground.Y + 8, 10),
				CFrame.new(ground.X, (ground.Y - 8 + towerTop) / 2, ground.Z)
					* frame.Rotation
					* CFrame.new(0, 0, offset * 19),
				Parts.vary(WALL_STONE, 0.12, 0.2),
				model,
				stone
			)
			Parts.block(
				Vector3.new(19, 2, 11),
				CFrame.new(ground.X, towerTop + 1, ground.Z) * frame.Rotation * CFrame.new(0, 0, offset * 19),
				Parts.vary(WALL_STONE, 0.2, 0.7),
				model,
				{ shadow = false }
			)
		end
		Parts.block(Vector3.new(2, 4, 26), frame * CFrame.new(-6.4, 32, 0), IRON, model, { shadow = false })
		Parts.block(
			Vector3.new(0.4, 14, 9),
			frame * CFrame.new(-6.6, 22, 0),
			rgb({ 70, 90, 130 }),
			model,
			{ shadow = false, name = "Banner" }
		)
	end
end

local function rubble(context: IslandBuilder.Context, breachAngle: number, rng: Rng.Rng, parent: Instance)
	local model = Parts.model("Rubble", parent)
	for _ = 1, 26 do
		local angle = breachAngle + Rng.range(rng, -BREACH_HALF_ANGLE * 1.6, BREACH_HALF_ANGLE * 1.6)
		local distance = WALL_RADIUS + Rng.range(rng, -14, 30)
		local x, z = WALL_X + math.cos(angle) * distance, WALL_Z + math.sin(angle) * distance
		local size = Rng.range(rng, 4, 13)
		local ground = context.ground(x, z)
		Parts.block(
			Vector3.new(size, size * 0.7, size * 0.9),
			CFrame.new(ground + Vector3.new(0, size * 0.2, 0))
				* CFrame.Angles(Rng.range(rng, -0.6, 0.6), Rng.range(rng, 0, 6.28), Rng.range(rng, -0.6, 0.6)),
			Parts.vary(WALL_STONE, 0.2, Rng.next(rng)),
			model,
			{ collide = size > 7 }
		)
	end
	local center =
		context.ground(WALL_X + math.cos(breachAngle) * WALL_RADIUS, WALL_Z + math.sin(breachAngle) * WALL_RADIUS)
	local anchor = Parts.block(
		Vector3.new(40, 2, 20),
		CFrame.new(center + Vector3.new(0, 2, 0)),
		WALL_STONE,
		model,
		{ transparency = 1, shadow = false, name = "Dust" }
	)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(rgb({ 200, 190, 170 }))
	dust.Size = NumberSequence.new(6, 14)
	dust.Transparency = NumberSequence.new(0.7, 1)
	dust.Lifetime = NumberRange.new(4, 7)
	dust.Rate = 4
	dust.Speed = NumberRange.new(1, 3)
	dust.Shape = Enum.ParticleEmitterShape.Box
	dust.Parent = anchor
end

local function cropField(context: IslandBuilder.Context, x: number, z: number, yaw: number, parent: Instance)
	local model = Parts.model("Crops", parent)
	local frame = CFrame.Angles(0, yaw, 0)
	for row = -9, 9, 3 do
		for column = -12, 12, 4 do
			local offset = frame * Vector3.new(column, 0, row)
			local ground = context.ground(x + offset.X, z + offset.Z)
			Parts.ball(
				2.4,
				ground + Vector3.new(0, 0.8, 0),
				Parts.vary(CROP, 0.2, ((row + column) % 7) / 7),
				model,
				{ shadow = false }
			)
		end
	end
end

local function decorate(context: IslandBuilder.Context)
	local rng = context.rng
	local decor = context.decor
	local nature = Parts.folder("Nature", decor)
	local town = Parts.folder("Town", decor)
	local landmarks = Parts.folder("Landmarks", decor)
	local easy, medium, hard, boss = layout.zones[1], layout.zones[2], layout.zones[3], layout.zones[4]
	local road = layout.paths[1].points

	local southGate = ringAngle(road[5][1], road[5][2])
	local eastGate = ringAngle(road[8][1], road[8][2])
	local breach = ringAngle(boss.x, boss.z)
	ringWall(context, { southGate, eastGate }, breach, landmarks)
	rubble(context, breach, rng, landmarks)

	local function outsideWall(x: number, z: number, margin: number): boolean
		return math.sqrt((x - WALL_X) ^ 2 + (z - WALL_Z) ^ 2) > WALL_RADIUS + margin
	end

	-- Town: houses packed inside the wall, a church near the square.
	church(
		context.groundMin(medium.x + 20, medium.z - 82, 14),
		IslandBuilder.yawToward(medium.x + 20, medium.z - 82, medium.x, medium.z),
		landmarks
	)
	for ring = 46, WALL_RADIUS - 24, 26 do
		local count = math.floor(2 * math.pi * ring / 17)
		for index = 0, count - 1 do
			local angle = index / count * 2 * math.pi + ring * 0.01
			-- Radial lanes every few houses keep the town walkable.
			if index % 7 ~= 0 then
				local x, z = WALL_X + math.cos(angle) * ring, WALL_Z + math.sin(angle) * ring
				local churchDistance = math.sqrt((x - medium.x - 20) ^ 2 + (z - medium.z + 82) ^ 2)
				if churchDistance > 30 and context.isFree(x, z, 4) and Rng.next(rng) < 0.9 then
					-- Front door toward the ring street just inside.
					local yaw = IslandBuilder.yawToward(x, z, WALL_X, WALL_Z)
					townHouse(context.groundMin(x, z, 7), yaw, Rng.next(rng), town)
				end
			end
		end
	end

	-- Farms outside the west wall.
	for index = 1, 6 do
		local angle = index / 6 * 2 * math.pi
		local x, z = easy.x + math.cos(angle) * (easy.radius + 30), easy.z + math.sin(angle) * (easy.radius + 30)
		if context.isFree(x, z, 5) then
			townHouse(context.groundMin(x, z, 7), IslandBuilder.yawToward(x, z, easy.x, easy.z), Rng.next(rng), town)
		end
	end
	for _, field in { { -330, 210, 0.2 }, { -170, 210, -0.3 }, { -330, 80, 0.6 }, { -140, 70, 0.1 } } do
		if context.isFree(field[1], field[2], 4) then
			cropField(context, field[1], field[2], field[3], town)
		end
	end
	for _, point in
		Scatter.inCircle(rng, easy.x, easy.z, 120, 12, 14, function(x, z)
			return context.isFree(x, z, 3)
		end)
	do
		Parts.ball(
			Rng.range(rng, 3, 5),
			context.ground(point.x, point.z) + Vector3.new(0, 1.2, 0),
			Parts.vary(HAY, 0.15, Rng.next(rng)),
			town,
			{ shadow = false }
		)
	end

	-- Giant forest on the eastern plateau.
	for index = 1, 14 do
		local angle = index / 14 * 2 * math.pi + Rng.range(rng, -0.15, 0.15)
		local distance = hard.radius + Rng.range(rng, 14, 50)
		local x, z = hard.x + math.cos(angle) * distance, hard.z + math.sin(angle) * distance
		if context.isFree(x, z, 4) and outsideWall(x, z, 20) then
			Nature.giantTree(context.ground(x, z), Rng.range(rng, 68, 90), Rng.next(rng), GIANT, nature)
		end
	end

	-- Pines outside the wall, rocks on the north-west hills.
	for _, point in
		Scatter.inCircle(rng, 0, 0, 440, 170, 15, function(x, z)
			return outsideWall(x, z, 22) and context.isFree(x, z, 6) and Shape.height(layout, x, z) < 50
		end)
	do
		Nature.pineTree(context.ground(point.x, point.z), Rng.range(rng, 18, 32), Rng.next(rng), PINES, nature)
	end
	for _, point in
		Scatter.inCircle(rng, -250, -150, 180, 30, 20, function(x, z)
			return Shape.height(layout, x, z) > 20 and Shape.pathInside(layout, x, z) < -4 and outsideWall(x, z, 10)
		end)
	do
		Nature.rock(context.ground(point.x, point.z), Rng.range(rng, 5, 10), Rng.next(rng), ROCK, nature)
	end
end

local definition: IslandBuilder.Definition = {
	layout = layout,
	decorate = decorate,
	photoSpots = {
		{ from = { 0, 60, 420 }, to = { 20, 30, 150 } }, -- arriving: the wall and the south gate
		{ from = { -620, 320, 520 }, to = { 30, 20, -40 } }, -- whole island from the sky
		{ from = { 30, 95, 140 }, to = { 30, 15, -50 } }, -- the town inside the wall
		{ from = { 40, 45, -390 }, to = { 30, 35, -230 } }, -- the breach
		{ from = { 190, 60, 190 }, to = { 300, 50, 90 } }, -- giant forest
		{ from = { -170, 36, 230 }, to = { -250, 10, 140 } }, -- farmland
	},
}

return definition
