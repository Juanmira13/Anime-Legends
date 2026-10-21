--!strict
-- Nameku (Dragon Ball): a calm alien planet. Blue-green meadows with thin
-- round-canopy trees, a village of white domes, rock mesas rising from the
-- turquoise sea and a crashed spherical ship where the boss waits. The look
-- (sky, water, grass colors) is in Shared/Config/Ambience.

local Root = script.Parent.Parent
local Rng = require(Root.Gen.Rng)
local Scatter = require(Root.Gen.Scatter)
local Shape = require(Root.Gen.Shape)
local Nature = require(Root.Kit.Nature)
local Parts = require(Root.Kit.Parts)
local IslandBuilder = require(Root.IslandBuilder)
local NamekuLayout = require(script.Parent.NamekuLayout)

local rgb = Parts.rgb

local TREE = {
	trunk = rgb({ 190, 175, 140 }),
	leaves = { rgb({ 140, 215, 105 }), rgb({ 60, 175, 150 }), rgb({ 110, 210, 160 }), rgb({ 80, 165, 205 }) },
}
local BUSHES = { rgb({ 60, 170, 130 }), rgb({ 85, 190, 140 }), rgb({ 105, 200, 120 }) }
local FLOWERS = { rgb({ 255, 236, 120 }), rgb({ 255, 170, 215 }), rgb({ 170, 240, 255 }), rgb({ 255, 255, 255 }) }
local ROCK = rgb({ 125, 145, 155 })
local DOME = rgb({ 238, 242, 232 })
local DOME_TRIM = rgb({ 120, 200, 165 })
local WINDOW = rgb({ 45, 75, 105 })
local SHIP = rgb({ 226, 229, 236 })
local SHIP_DARK = rgb({ 140, 146, 162 })
local SHIP_GLOW = rgb({ 120, 235, 255 })
local STONE = rgb({ 215, 220, 210 })

local layout = NamekuLayout

-- Point on a sphere's surface at elevation `e` (radians) along a horizontal direction.
local function onSphere(center: Vector3, radius: number, horizontal: Vector3, e: number): (Vector3, Vector3)
	local normal = (horizontal * math.cos(e) + Vector3.yAxis * math.sin(e)).Unit
	return center + normal * radius, normal
end

-- White dome house with round windows, a door and a little spire.
local function domeHouse(ground: Vector3, size: number, facing: Vector3, t: number, parent: Instance)
	local model = Parts.model("DomeHouse", parent)
	local radius = size / 2
	-- Sunk a little so it sits on uneven ground.
	local center = ground + Vector3.new(0, size * 0.08, 0)
	Parts.ball(size, center, Parts.vary(DOME, 0.06, t), model, { collide = true })
	Parts.disc(size * 1.04, 1.2, ground + Vector3.new(0, 0.3, 0), DOME_TRIM, model, { collide = true })

	local front = Vector3.new(facing.X, 0, facing.Z).Unit
	local right = Vector3.new(-front.Z, 0, front.X)
	-- Door: dark arch facing the path.
	local doorPosition, doorNormal = onSphere(center, radius, front, math.rad(14))
	Parts.cylinder(
		size * 0.24,
		0.8,
		doorPosition - Vector3.new(0, size * 0.02, 0),
		doorNormal,
		WINDOW,
		model,
		{ shadow = false }
	)
	-- Round windows around the dome.
	for index = 1, 5 do
		local angle = math.rad(-130 + index * 52)
		local horizontal = front * math.cos(angle) + right * math.sin(angle)
		if index ~= 3 then
			local position, normal = onSphere(center, radius, horizontal, math.rad(32))
			Parts.cylinder(size * 0.13, 0.5, position, normal, WINDOW, model, { shadow = false })
			Parts.cylinder(size * 0.17, 0.4, position - normal * 0.15, normal, DOME_TRIM, model, { shadow = false })
		end
	end
	-- Spire with a small ball on top.
	local top = center + Vector3.new(0, radius, 0)
	Parts.column(
		size * 0.08,
		size * 0.18,
		CFrame.new(top - Vector3.new(0, 0.5, 0)),
		DOME_TRIM,
		model,
		{ shadow = false }
	)
	Parts.ball(size * 0.12, top + Vector3.new(0, size * 0.2, 0), DOME, model, { shadow = false })
	-- Smaller annex dome on one side.
	if t > 0.4 then
		local annex = center + right * radius * 0.85 - Vector3.new(0, size * 0.18, 0)
		Parts.ball(size * 0.55, annex, Parts.vary(DOME, 0.08, 1 - t), model, { collide = true })
	end
end

-- Crashed spherical ship on four legs, its ramp toward the boss.
local function spaceship(ground: Vector3, towardBoss: Vector3, parent: Instance)
	local model = Parts.model("Spaceship", parent)
	local diameter = 54
	local radius = diameter / 2
	local center = ground + Vector3.new(0, radius + 6, 0)
	local front = Vector3.new(towardBoss.X, 0, towardBoss.Z).Unit

	Parts.ball(diameter, center, SHIP, model, { collide = true })
	Parts.disc(diameter * 1.14, 2.6, center, SHIP_DARK, model, { collide = true })
	Parts.disc(
		diameter * 1.18,
		0.8,
		center + Vector3.new(0, 1.6, 0),
		SHIP_GLOW,
		model,
		{ material = Enum.Material.Neon, shadow = false }
	)

	-- Row of glowing windows above the ring.
	for index = 0, 17 do
		local angle = index / 18 * 2 * math.pi
		local horizontal = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local position = onSphere(center, radius - 0.4, horizontal, math.rad(12))
		local window = Parts.ball(2.6, position, SHIP_GLOW, model, { material = Enum.Material.Neon, shadow = false })
		if index % 6 == 0 then
			Parts.light(window, SHIP_GLOW, 26, 1.6)
		end
	end

	-- Hatch and antenna on top.
	local top = center + Vector3.new(0, radius, 0)
	Parts.ball(diameter * 0.2, top - Vector3.new(0, 1.5, 0), SHIP_DARK, model, { collide = true })
	Parts.column(0.8, 10, CFrame.new(top + Vector3.new(0, 2, 0)), SHIP_DARK, model, { shadow = false })
	Parts.ball(1.8, top + Vector3.new(0, 12.5, 0), SHIP_GLOW, model, { material = Enum.Material.Neon, shadow = false })

	-- Four legs with round feet.
	for index = 0, 3 do
		local angle = index * math.pi / 2 + math.pi / 4
		local horizontal = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local hip = center + horizontal * radius * 0.6 - Vector3.new(0, radius * 0.6, 0)
		local foot = ground + horizontal * radius * 1.1 + Vector3.new(0, 0.6, 0)
		Parts.beam(hip, foot, 2.6, SHIP_DARK, model, { collide = true })
		Parts.disc(7, 1.2, foot, SHIP_DARK, model, { collide = true })
	end

	-- Open door and ramp down to the ground.
	local doorPosition, doorNormal = onSphere(center, radius, front, math.rad(-28))
	Parts.cylinder(12, 0.8, doorPosition, doorNormal, rgb({ 30, 40, 55 }), model, { shadow = false })
	local rampTop = doorPosition + front * 1 - Vector3.new(0, 4, 0)
	local rampBottom = ground + front * (radius + 16) + Vector3.new(0, 0.4, 0)
	local length = (rampBottom - rampTop).Magnitude
	Parts.block(
		Vector3.new(9, 0.8, length),
		CFrame.lookAt((rampTop + rampBottom) / 2, rampBottom),
		SHIP_DARK,
		model,
		{ collide = true }
	)
	for _, side in { -1, 1 } do
		local offset = Vector3.new(-front.Z, 0, front.X) * side * 4.8
		Parts.beam(
			rampTop + offset + Vector3.new(0, 0.8, 0),
			rampBottom + offset + Vector3.new(0, 0.8, 0),
			0.6,
			SHIP_GLOW,
			model,
			{ material = Enum.Material.Neon, shadow = false }
		)
	end
end

-- Glowing crystal on a stone base, lining the plaza.
local function crystalPylon(ground: Vector3, accent: Color3, withLight: boolean, parent: Instance)
	local model = Parts.model("Pylon", parent)
	Parts.column(3.4, 1, CFrame.new(ground), STONE, model, { shadow = false })
	Parts.column(
		2.2,
		4.5,
		CFrame.new(ground + Vector3.new(0, 1, 0)),
		Parts.vary(STONE, 0.15, 0.3),
		model,
		{ shadow = false }
	)
	local crystal = Parts.block(
		Vector3.new(1.6, 3.2, 1.6),
		CFrame.new(ground + Vector3.new(0, 7.4, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		accent,
		model,
		{ material = Enum.Material.Neon, shadow = false }
	)
	if withLight then
		Parts.light(crystal, accent, 14, 1.4)
	end
end

local function decorate(context: IslandBuilder.Context)
	local rng = context.rng
	local decor = context.decor
	local nature = Parts.folder("Nature", decor)
	local village = Parts.folder("Village", decor)
	local landmarks = Parts.folder("Landmarks", decor)

	-- Trees across the open meadows.
	for _, point in
		Scatter.inCircle(rng, 0, 0, layout.radius, 150, 14, function(x, z)
			return context.isFree(x, z, 7)
		end)
	do
		Nature.roundTree(context.ground(point.x, point.z), Rng.range(rng, 16, 30), Rng.next(rng), TREE, nature)
	end

	-- A tree or two on top of each mesa.
	for _, mesa in layout.mesas do
		Nature.roundTree(context.ground(mesa.x, mesa.z), Rng.range(rng, 14, 22), Rng.next(rng), TREE, nature)
		if mesa.radius > 34 then
			local x, z = mesa.x + mesa.radius * 0.35, mesa.z - mesa.radius * 0.2
			Nature.roundTree(context.ground(x, z), Rng.range(rng, 12, 18), Rng.next(rng), TREE, nature)
		end
	end

	-- Bushes and border stones along the path.
	for _, path in layout.paths do
		for index = 1, #path.points - 1 do
			local a, b = path.points[index], path.points[index + 1]
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local length = math.sqrt(dx * dx + dz * dz)
			local nx, nz = -dz / length, dx / length
			local steps = math.floor(length / 10)
			for step = 0, steps - 1 do
				local s = step / steps
				local x, z = a[1] + dx * s, a[2] + dz * s
				for _, side in { -1, 1 } do
					local stoneX, stoneZ =
						x + nx * side * (path.width / 2 + 1.2), z + nz * side * (path.width / 2 + 1.2)
					if context.isFree(stoneX, stoneZ, 0.5) then
						Nature.rock(
							context.ground(stoneX, stoneZ),
							Rng.range(rng, 1.2, 1.8),
							Rng.next(rng),
							STONE,
							nature
						)
					end
					if (step + (if side > 0 then 1 else 0)) % 2 == 0 then
						local bushX, bushZ =
							x + nx * side * (path.width / 2 + 4.5), z + nz * side * (path.width / 2 + 4.5)
						if context.isFree(bushX, bushZ, 2) then
							Nature.bush(
								context.ground(bushX, bushZ),
								Rng.range(rng, 3, 5),
								Rng.next(rng),
								BUSHES,
								nature
							)
						end
					end
				end
			end
		end
	end

	-- Rocks and flowers.
	for _, point in
		Scatter.inCircle(rng, 0, 0, layout.radius, 40, 18, function(x, z)
			return context.isFree(x, z, 4)
		end)
	do
		Nature.rock(context.ground(point.x, point.z), Rng.range(rng, 3, 7), Rng.next(rng), ROCK, nature)
	end
	for _, point in
		Scatter.inCircle(rng, 0, 0, layout.radius, 130, 9, function(x, z)
			return context.isFree(x, z, 3)
		end)
	do
		Nature.flowers(context.ground(point.x, point.z), Rng.next(rng), FLOWERS, nature)
	end

	-- Rocky zone: boulders around the combat area.
	local hard = layout.zones[3]
	for index = 1, 14 do
		local angle = index / 14 * 2 * math.pi + Rng.range(rng, -0.15, 0.15)
		local distance = hard.radius + Rng.range(rng, 6, 18)
		local x, z = hard.x + math.cos(angle) * distance, hard.z + math.sin(angle) * distance
		if Shape.pathInside(layout, x, z) < -3 then
			Nature.rock(context.ground(x, z), Rng.range(rng, 4, 9), Rng.next(rng), ROCK, nature)
		end
	end

	-- Village of domes around the medium zone and near the plaza.
	local medium = layout.zones[2]
	local function placeHouses(
		cx: number,
		cz: number,
		ringRadius: number,
		count: number,
		sizeMin: number,
		sizeMax: number
	)
		for index = 1, count do
			local angle = index / count * 2 * math.pi + Rng.range(rng, -0.2, 0.2)
			local distance = ringRadius + Rng.range(rng, -4, 8)
			local x, z = cx + math.cos(angle) * distance, cz + math.sin(angle) * distance
			if context.isFree(x, z, 6) then
				local facing = Vector3.new(cx - x, 0, cz - z)
				domeHouse(context.ground(x, z), Rng.range(rng, sizeMin, sizeMax), facing, Rng.next(rng), village)
			end
		end
	end
	placeHouses(medium.x, medium.z, medium.radius + 26, 10, 18, 26)
	placeHouses(layout.plaza.x, layout.plaza.z, layout.plaza.radius + 30, 5, 14, 20)
	placeHouses(layout.zones[1].x, layout.zones[1].z, layout.zones[1].radius + 28, 3, 14, 18)

	-- Plaza: ring of glowing crystals.
	local plaza = layout.plaza
	for index = 0, 9 do
		local angle = index / 10 * 2 * math.pi + math.pi / 10
		local x, z = plaza.x + math.cos(angle) * (plaza.radius + 3), plaza.z + math.sin(angle) * (plaza.radius + 3)
		crystalPylon(context.ground(x, z), context.accent, index % 2 == 0, landmarks)
	end

	-- Boss landmark: the ship, behind the boss as seen from the plaza.
	local boss = layout.zones[4]
	local dx, dz = boss.x - plaza.x, boss.z - plaza.z
	local length = math.sqrt(dx * dx + dz * dz)
	local shipX, shipZ = boss.x + dx / length * (boss.radius + 18), boss.z + dz / length * (boss.radius + 18)
	spaceship(context.ground(shipX, shipZ), Vector3.new(-dx, 0, -dz), landmarks)
end

local definition: IslandBuilder.Definition = {
	layout = layout,
	decorate = decorate,
	photoSpots = {
		{ from = { 0, 62, 430 }, to = { 0, 10, 150 } }, -- arriving: plaza and the island ahead
		{ from = { -470, 230, 470 }, to = { 0, 0, -20 } }, -- whole island from the sky
		{ from = { 205, 38, 95 }, to = { 115, 12, 20 } }, -- dome village
		{ from = { 125, 78, -110 }, to = { 30, 32, -280 } }, -- the ship
		{ from = { 640, 24, 300 }, to = { 494, 40, 175 } }, -- mesas from the sea
		{ from = { -225, 62, -25 }, to = { -95, 18, -115 } }, -- rocky zone
	},
}

return definition
