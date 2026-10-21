--!strict
-- Hero Academy (My Hero Academia): a modern hero city. Glass skyscrapers in
-- the center and offices and apartments around them along an asphalt grid,
-- the H-shaped glass campus building on its terrace, traffic lights, street
-- lamps and parked cars, a hill park with a radio mast, a lighthouse, the
-- ruined simulation city (tilted towers, fires, rubble) and the great stadium
-- where the boss waits.

local Root = script.Parent.Parent
local PathWalk = require(Root.Gen.PathWalk)
local Rng = require(Root.Gen.Rng)
local Scatter = require(Root.Gen.Scatter)
local Shape = require(Root.Gen.Shape)
local Buildings = require(Root.Kit.Buildings)
local Nature = require(Root.Kit.Nature)
local Parts = require(Root.Kit.Parts)
local IslandBuilder = require(Root.IslandBuilder)
local HeroAcademyLayout = require(script.Parent.HeroAcademyLayout)

local layout = HeroAcademyLayout
local rgb = Parts.rgb

local GLASS = { rgb({ 118, 170, 222 }), rgb({ 92, 142, 204 }), rgb({ 168, 202, 232 }), rgb({ 110, 190, 200 }) }
local CONCRETE = { rgb({ 212, 208, 200 }), rgb({ 182, 186, 194 }), rgb({ 200, 192, 178 }) }
local PASTEL = { rgb({ 240, 200, 170 }), rgb({ 200, 220, 240 }), rgb({ 236, 226, 170 }), rgb({ 210, 236, 210 }) }
local DARK_GLASS = rgb({ 44, 60, 82 })
local HERO_RED = rgb({ 222, 54, 62 })
local WHITE = rgb({ 244, 244, 246 })
local METAL = rgb({ 70, 72, 80 })
local FIRE = rgb({ 255, 140, 50 })
local CAR_COLORS =
	{ rgb({ 222, 54, 62 }), rgb({ 60, 120, 220 }), rgb({ 250, 210, 60 }), rgb({ 240, 240, 240 }), rgb({ 40, 40, 46 }) }
local PARK = {
	trunk = rgb({ 112, 88, 66 }),
	leaves = { rgb({ 90, 176, 76 }), rgb({ 112, 190, 90 }), rgb({ 76, 160, 70 }) },
}
local BUSHES = { rgb({ 86, 164, 72 }), rgb({ 100, 180, 82 }) }

local function pick<T>(list: { T }, t: number): T
	return list[math.clamp(math.floor(t * #list) + 1, 1, #list)]
end

-- Glass tower with floor lines, glowing corner strips and a rooftop.
local function glassTower(ground: Vector3, width: number, depth: number, height: number, t: number, parent: Instance)
	local model = Parts.model("GlassTower", parent)
	local base = CFrame.new(ground)
	Buildings.foundation(base, width, depth, rgb({ 150, 150, 156 }), model)
	local body = Parts.block(
		Vector3.new(width, height, depth),
		base * CFrame.new(0, height / 2, 0),
		pick(GLASS, t),
		model,
		{ collide = true }
	)
	body.Material = Enum.Material.Glass
	body.Reflectance = 0.15
	for y = 8, height - 4, 8 do
		Parts.block(
			Vector3.new(width + 0.3, 0.5, depth + 0.3),
			base * CFrame.new(0, y, 0),
			WHITE,
			model,
			{ shadow = false }
		)
	end
	for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		Parts.block(
			Vector3.new(0.8, height, 0.8),
			base * CFrame.new(corner[1] * width / 2, height / 2, corner[2] * depth / 2),
			if t > 0.5 then rgb({ 140, 230, 255 }) else WHITE,
			model,
			{ material = Enum.Material.Neon, shadow = false }
		)
	end
	Parts.block(
		Vector3.new(width * 0.6, 4, depth * 0.6),
		base * CFrame.new(0, height + 2, 0),
		rgb({ 200, 200, 206 }),
		model,
		{ shadow = false }
	)
	if height > 70 then
		Parts.column(0.8, 18, base * CFrame.new(0, height + 4, 0), METAL, model, { shadow = false })
		Parts.ball(
			1.4,
			(base * CFrame.new(0, height + 22, 0)).Position,
			HERO_RED,
			model,
			{ material = Enum.Material.Neon, shadow = false }
		)
	end
end

-- Office block with ribbon windows and rooftop units.
local function office(ground: Vector3, width: number, depth: number, height: number, t: number, parent: Instance)
	local model = Parts.model("Office", parent)
	local base = CFrame.new(ground)
	Buildings.foundation(base, width, depth, rgb({ 150, 150, 156 }), model)
	Buildings.walls(base, width, depth, height, pick(CONCRETE, t), model)
	local glass = rgb({ 110, 150, 190 })
	for y = 4.5, height - 3, 6 do
		Parts.block(
			Vector3.new(width + 0.3, 1.5, depth + 0.3),
			base * CFrame.new(0, y, 0),
			glass,
			model,
			{ shadow = false }
		)
	end
	-- Lobby: a glass ground floor under a canopy.
	Parts.block(
		Vector3.new(width + 0.3, 3, depth + 0.3),
		base * CFrame.new(0, 1.5, 0),
		glass,
		model,
		{ shadow = false }
	)
	Parts.block(
		Vector3.new(width * 0.5, 0.5, 3),
		base * CFrame.new(0, 3.6, -depth / 2 - 1.5),
		WHITE,
		model,
		{ shadow = false }
	)
	for index = 0, 2 do
		Parts.block(
			Vector3.new(4, 2.4, 3),
			base * CFrame.new(-width / 3 + index * width / 3, height + 1.2, depth * 0.2),
			METAL,
			model,
			{ shadow = false }
		)
	end
end

-- Apartment building: pastel walls, windows per floor and balconies.
local function apartment(ground: Vector3, width: number, depth: number, height: number, t: number, parent: Instance)
	local model = Parts.model("Apartment", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, if t > 0.5 then math.pi / 2 else 0, 0)
	Buildings.foundation(base, width, depth, rgb({ 150, 150, 156 }), model)
	Buildings.walls(base, width, depth, height, pick(PASTEL, t), model)
	for floor = 0, math.floor(height / 6) - 1 do
		Buildings.windows(
			base * CFrame.new(0, floor * 6, 0),
			width,
			depth,
			3.4,
			math.max(2, math.floor(width / 5)),
			Vector2.new(2.2, 2.4),
			DARK_GLASS,
			model
		)
		if floor > 0 then
			Parts.block(
				Vector3.new(width * 0.8, 0.4, 1.6),
				base * CFrame.new(0, floor * 6, -depth / 2 - 0.8),
				WHITE,
				model,
				{ shadow = false }
			)
		end
	end
	Parts.block(
		Vector3.new(width + 1, 1, depth + 1),
		base * CFrame.new(0, height + 0.5, 0),
		WHITE,
		model,
		{ shadow = false }
	)
end

-- The campus: two glass towers joined by a sky bridge (an H), red trims.
local function campus(ground: Vector3, yaw: number, parent: Instance)
	local model = Parts.model("CampusH", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	for _, side in { -1, 1 } do
		local tower = base * CFrame.new(side * 24, 0, 0)
		Buildings.foundation(tower, 18, 22, rgb({ 160, 160, 166 }), model)
		local body = Parts.block(
			Vector3.new(18, 66, 22),
			tower * CFrame.new(0, 33, 0),
			rgb({ 150, 196, 232 }),
			model,
			{ collide = true }
		)
		body.Material = Enum.Material.Glass
		body.Reflectance = 0.2
		for y = 10, 60, 10 do
			Parts.block(Vector3.new(18.4, 0.8, 22.4), tower * CFrame.new(0, y, 0), WHITE, model, { shadow = false })
		end
		Parts.block(Vector3.new(19, 3, 23), tower * CFrame.new(0, 67.5, 0), HERO_RED, model, { shadow = false })
	end
	local bridge = Parts.block(
		Vector3.new(30, 16, 16),
		base * CFrame.new(0, 40, 0),
		rgb({ 170, 210, 240 }),
		model,
		{ collide = true }
	)
	bridge.Material = Enum.Material.Glass
	Parts.block(Vector3.new(30.4, 1.2, 16.4), base * CFrame.new(0, 48.6, 0), HERO_RED, model, { shadow = false })
	Parts.block(Vector3.new(30.4, 1.2, 16.4), base * CFrame.new(0, 31.4, 0), WHITE, model, { shadow = false })
	-- Gate posts and a plaque facing the approach.
	for _, side in { -1, 1 } do
		Parts.block(Vector3.new(3, 10, 3), base * CFrame.new(side * 9, 5, -24), WHITE, model, { collide = true })
	end
	Parts.block(Vector3.new(21, 3.4, 1.2), base * CFrame.new(0, 11, -24), HERO_RED, model, { collide = true })
end

local function streetLamp(ground: Vector3, facing: Vector3, parent: Instance)
	local model = Parts.model("StreetLamp", parent)
	Parts.column(0.6, 12, CFrame.new(ground - Vector3.new(0, 0.5, 0)), METAL, model, { shadow = false })
	local head = ground + Vector3.new(0, 11.5, 0) + facing * 2
	Parts.beam(ground + Vector3.new(0, 11.5, 0), head, 0.4, METAL, model, { shadow = false })
	local lamp = Parts.block(
		Vector3.new(1.6, 0.5, 2.4),
		CFrame.new(head - Vector3.new(0, 0.4, 0)),
		rgb({ 255, 244, 214 }),
		model,
		{ material = Enum.Material.Neon, shadow = false }
	)
	Parts.light(lamp, rgb({ 255, 236, 200 }), 16, 0.8)
end

local function trafficLight(ground: Vector3, facing: Vector3, parent: Instance)
	local model = Parts.model("TrafficLight", parent)
	Parts.column(0.7, 10, CFrame.new(ground - Vector3.new(0, 0.5, 0)), METAL, model, { shadow = false })
	local head = ground + Vector3.new(0, 9, 0) + facing * 5
	Parts.beam(ground + Vector3.new(0, 9.4, 0), head + Vector3.new(0, 0.4, 0), 0.4, METAL, model, { shadow = false })
	Parts.block(
		Vector3.new(1.4, 4, 1.4),
		CFrame.new(head - Vector3.new(0, 1.6, 0)),
		rgb({ 30, 30, 34 }),
		model,
		{ shadow = false }
	)
	for index, color in { rgb({ 255, 60, 60 }), rgb({ 255, 200, 60 }), rgb({ 60, 230, 110 }) } do
		Parts.ball(
			0.9,
			head - Vector3.new(0, index * 1.15 - 0.4, 0) - facing * 0.75,
			color,
			model,
			{ material = Enum.Material.Neon, shadow = false }
		)
	end
end

local function car(ground: Vector3, yaw: number, t: number, parent: Instance)
	local model = Parts.model("Car", parent)
	local base = CFrame.new(ground) * CFrame.Angles(0, yaw, 0)
	local color = pick(CAR_COLORS, t)
	Parts.block(Vector3.new(4.4, 1.8, 8.6), base * CFrame.new(0, 1.6, 0), color, model, { collide = true })
	Parts.block(Vector3.new(3.9, 1.6, 4.6), base * CFrame.new(0, 3.3, 0.4), DARK_GLASS, model, { shadow = false })
	Parts.block(Vector3.new(4, 0.3, 4.4), base * CFrame.new(0, 4.15, 0.4), color, model, { shadow = false })
	for _, wheel in { { -2.2, -2.8 }, { 2.2, -2.8 }, { -2.2, 2.8 }, { 2.2, 2.8 } } do
		Parts.cylinder(
			1.8,
			0.8,
			(base * CFrame.new(wheel[1], 0.9, wheel[2])).Position,
			(base * CFrame.new(1, 0, 0)).Position - base.Position,
			rgb({ 28, 28, 30 }),
			model,
			{ shadow = false }
		)
	end
end

-- Ruined building: tilted, broken top, exposed beams, sometimes on fire.
local function ruin(ground: Vector3, size: number, t: number, rng: Rng.Rng, parent: Instance)
	local model = Parts.model("Ruin", parent)
	local tilt = CFrame.Angles(Rng.range(rng, -0.18, 0.18), Rng.range(rng, 0, 6.28), Rng.range(rng, -0.18, 0.18))
	local height = size * Rng.range(rng, 1.4, 2.6)
	local base = CFrame.new(ground) * tilt
	Parts.block(
		Vector3.new(size, height, size * 0.9),
		base * CFrame.new(0, height / 2 - 2, 0),
		Parts.vary(pick(CONCRETE, t), 0.25, t),
		model,
		{ collide = true }
	)
	for index = 0, 3 do
		Parts.block(
			Vector3.new(size * Rng.range(rng, 0.2, 0.45), Rng.range(rng, 2, 7), size * 0.9),
			base * CFrame.new(-size / 2 + index * size / 3.5, height - 2 + 1.5, 0),
			Parts.vary(pick(CONCRETE, t), 0.25, Rng.next(rng)),
			model,
			{ shadow = false }
		)
	end
	for index = 0, 2 do
		Parts.block(
			Vector3.new(0.6, Rng.range(rng, 4, 9), 0.6),
			base
				* CFrame.new(-size / 3 + index * size / 3, height + 1, size * 0.3)
				* CFrame.Angles(Rng.range(rng, -0.4, 0.4), 0, Rng.range(rng, -0.4, 0.4)),
			METAL,
			model,
			{ shadow = false }
		)
	end
	-- Broken windows per floor (dark stripes read as a striped box from afar).
	for y = 4, height - 6, 6 do
		Buildings.windows(
			base * CFrame.new(0, -2, 0),
			size,
			size * 0.9,
			y,
			math.max(2, math.floor(size / 5)),
			Vector2.new(2, 2.4),
			rgb({ 58, 62, 72 }),
			model
		)
	end
	if t > 0.55 then
		local fire = Parts.ball(
			3,
			(base * CFrame.new(0, height - 1, -size * 0.45)).Position,
			FIRE,
			model,
			{ material = Enum.Material.Neon, shadow = false }
		)
		Parts.light(fire, FIRE, 24, 2)
		local smoke = Instance.new("ParticleEmitter")
		smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
		smoke.Color = ColorSequence.new(rgb({ 60, 60, 66 }))
		smoke.Size = NumberSequence.new(4, 12)
		smoke.Transparency = NumberSequence.new(0.4, 1)
		smoke.Lifetime = NumberRange.new(4, 6)
		smoke.Rate = 5
		smoke.Speed = NumberRange.new(4, 7)
		smoke.SpreadAngle = Vector2.new(15, 15)
		smoke.Parent = fire
	end
end

-- Stadium: a ring of sloped stands around the boss, with an entrance gap.
local function stadium(context: IslandBuilder.Context, center: Vector3, entranceAngle: number, parent: Instance)
	local model = Parts.model("Stadium", parent)
	local inner, outer, height = 60, 84, 24
	local step = math.rad(6)
	for angle = 0, 2 * math.pi - step / 2, step do
		local gap = math.abs((angle - entranceAngle + math.pi) % (2 * math.pi) - math.pi)
		if gap > math.rad(16) then
			local mid = (inner + outer) / 2
			local x, z = center.X - context.cx + math.cos(angle) * mid, center.Z - context.cz + math.sin(angle) * mid
			local ground = context.groundMin(x, z, 8)
			local position = Vector3.new(context.cx + x, math.min(ground.Y, center.Y) + height / 2 - 1, context.cz + z)
			local look = CFrame.lookAt(position, Vector3.new(center.X, position.Y, center.Z))
			local band = if math.floor(angle / step) % 2 == 0 then HERO_RED else rgb({ 236, 236, 240 })
			-- Wedge: tall at its back (+Z), which faces away from the field.
			Parts.wedge(Vector3.new(mid * step + 0.6, height, outer - inner), look, band, model, { collide = true })
			Parts.block(
				Vector3.new(mid * step + 0.6, 4, 2),
				look * CFrame.new(0, height / 2 + 2, (outer - inner) / 2 - 1),
				rgb({ 210, 210, 216 }),
				model,
				{ collide = true }
			)
		end
	end
	for index = 0, 3 do
		local angle = entranceAngle + math.pi / 4 + index * math.pi / 2
		local x, z = center.X + math.cos(angle) * (outer + 6), center.Z + math.sin(angle) * (outer + 6)
		local ground = context.ground(x - context.cx, z - context.cz)
		Parts.column(2, 60, CFrame.new(ground - Vector3.new(0, 1, 0)), METAL, model, { shadow = false })
		local panel = Parts.block(
			Vector3.new(10, 6, 1),
			CFrame.lookAt(ground + Vector3.new(0, 60, 0), Vector3.new(center.X, center.Y, center.Z)),
			rgb({ 255, 250, 230 }),
			model,
			{ material = Enum.Material.Neon, shadow = false }
		)
		Parts.light(panel, rgb({ 255, 250, 230 }), 40, 1.5)
	end
end

local function radioMast(ground: Vector3, parent: Instance)
	local model = Parts.model("RadioMast", parent)
	for index = 0, 3 do
		local angle = index * math.pi / 2 + math.pi / 4
		local foot = ground + Vector3.new(math.cos(angle) * 5, -1, math.sin(angle) * 5)
		Parts.beam(
			foot,
			ground + Vector3.new(0, 70, 0),
			0.8,
			if index % 2 == 0 then HERO_RED else WHITE,
			model,
			{ shadow = false }
		)
	end
	local light = Parts.ball(
		2.4,
		ground + Vector3.new(0, 72, 0),
		HERO_RED,
		model,
		{ material = Enum.Material.Neon, shadow = false }
	)
	Parts.light(light, HERO_RED, 30, 2)
end

local function lighthouse(ground: Vector3, parent: Instance)
	local model = Parts.model("Lighthouse", parent)
	for index = 0, 5 do
		Parts.column(
			9 - index * 0.5,
			6,
			CFrame.new(ground + Vector3.new(0, index * 6 - 1, 0)),
			if index % 2 == 0 then WHITE else HERO_RED,
			model,
			{ collide = true }
		)
	end
	local lamp = Parts.column(
		5,
		4,
		CFrame.new(ground + Vector3.new(0, 35, 0)),
		rgb({ 255, 240, 180 }),
		model,
		{ material = Enum.Material.Neon, shadow = false }
	)
	Parts.light(lamp, rgb({ 255, 240, 180 }), 60, 3)
	Buildings.coneRoof(CFrame.new(ground + Vector3.new(0, 39, 0)), 7, 4, HERO_RED, model, 4)
end

local function decorate(context: IslandBuilder.Context)
	local rng = context.rng
	local decor = context.decor
	local city = Parts.folder("City", decor)
	local nature = Parts.folder("Nature", decor)
	local landmarks = Parts.folder("Landmarks", decor)
	local easy, hard, boss = layout.zones[1], layout.zones[3], layout.zones[4]
	local avenue = layout.paths[1].points

	-- Buildings on a grid aligned with the streets; taller toward the center.
	for gx = -320, 320, 34 do
		for gz = -320, 320, 34 do
			local x, z = gx + Rng.range(rng, -4, 4), gz + Rng.range(rng, -4, 4)
			local hardDistance = math.sqrt((x - hard.x) ^ 2 + (z - hard.z) ^ 2)
			local stadiumDistance = math.sqrt((x - boss.x) ^ 2 + (z - boss.z) ^ 2)
			local fits = context.isFree(x, z, 15)
				and Shape.coastFraction(layout, x, z) < 0.8
				and Shape.slope(layout, x, z) < 0.35
				and Shape.height(layout, x, z) < 24
				and hardDistance > hard.radius + 50
				and stadiumDistance > 100
			if fits and Rng.next(rng) < 0.8 then
				local t = Rng.next(rng)
				local ground = context.groundMin(x, z, 12)
				local central = math.sqrt(x * x + z * z) < 210
				local width, depth = Rng.range(rng, 16, 24), Rng.range(rng, 16, 24)
				if central and t > 0.35 then
					glassTower(ground, width, depth, Rng.range(rng, 50, 120), t, city)
				elseif t > 0.55 then
					office(ground, width, depth, Rng.range(rng, 22, 46), t, city)
				else
					apartment(ground, width, depth, Rng.range(rng, 3, 6) * 6, t, city)
				end
			end
		end
	end

	-- Campus building behind the campus zone.
	local dx, dz = easy.x - avenue[3][1], easy.z - avenue[3][2]
	local length = math.sqrt(dx * dx + dz * dz)
	local cx, cz = easy.x + dx / length * (easy.radius + 26), easy.z + dz / length * (easy.radius + 26)
	campus(context.groundMin(cx, cz, 20), IslandBuilder.yawToward(cx, cz, easy.x, easy.z), landmarks)

	-- On land and outside the plaza and combat zones (street furniture may touch roads).
	local function clearOfAreas(x: number, z: number): boolean
		if Shape.coastFraction(layout, x, z) > 0.85 then
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

	-- Street furniture: lamps along every street (none in the ruins), traffic
	-- lights at crossings, parked cars.
	local LAMP_SPACING = 50
	for _, street in layout.paths do
		for _, sample in PathWalk.samples(street.points, LAMP_SPACING, 10) do
			local side = if math.floor(sample.distance / LAMP_SPACING) % 2 == 0 then 1 else -1
			local x, z =
				sample.x + sample.dz * side * (street.width / 2 + 2),
				sample.z - sample.dx * side * (street.width / 2 + 2)
			local inRuins = (x - hard.x) ^ 2 + (z - hard.z) ^ 2 < (hard.radius + 60) ^ 2
			if clearOfAreas(x, z) and not inRuins then
				streetLamp(context.ground(x, z), Vector3.new(-sample.dz * side, 0, sample.dx * side), city)
			end
		end
	end
	for _, crossing in { { -20, -60 }, { 150, -60 }, { 150, 130 }, { -20, 130 } } do
		for _, corner in { { 1, 1 }, { -1, -1 } } do
			local x, z = crossing[1] + corner[1] * 9, crossing[2] + corner[2] * 9
			trafficLight(context.ground(x, z), Vector3.new(-corner[1], 0, 0), city)
		end
		for index = -2, 2 do
			Parts.block(
				Vector3.new(1.4, 0.2, 9),
				CFrame.new(context.ground(crossing[1] + index * 2.4, crossing[2] + 11) + Vector3.new(0, 0.15, 0)),
				WHITE,
				city,
				{ shadow = false }
			)
		end
	end
	for _, sample in PathWalk.samples(layout.paths[2].points, 47, 20) do
		local x, z = sample.x + sample.dz * 4.2, sample.z - sample.dx * 4.2
		if clearOfAreas(x, z) then
			car(context.ground(x, z), math.atan2(-sample.dx, -sample.dz), Rng.next(rng), city)
		end
	end
	for _, sample in PathWalk.samples(layout.paths[4].points, 53, 30) do
		local x, z = sample.x + sample.dz * 4.2, sample.z - sample.dx * 4.2
		if clearOfAreas(x, z) then
			car(context.ground(x, z), math.atan2(-sample.dx, -sample.dz), Rng.next(rng), city)
		end
	end

	-- Ruined simulation city around the hard zone.
	for _, point in
		Scatter.inCircle(rng, hard.x, hard.z, hard.radius + 55, 14, 20, function(x, z)
			return math.sqrt((x - hard.x) ^ 2 + (z - hard.z) ^ 2) > hard.radius + 8
				and Shape.pathInside(layout, x, z) < -8
				and Shape.coastFraction(layout, x, z) < 0.85
		end)
	do
		ruin(context.ground(point.x, point.z), Rng.range(rng, 10, 18), Rng.next(rng), rng, landmarks)
	end
	for _, point in
		Scatter.inCircle(rng, hard.x, hard.z, hard.radius + 30, 18, 6, function(x, z)
			return Shape.pathInside(layout, x, z) < -2
		end)
	do
		local size = Rng.range(rng, 2, 5)
		Parts.block(
			Vector3.new(size, size * 0.6, size),
			CFrame.new(context.ground(point.x, point.z))
				* CFrame.Angles(Rng.next(rng), Rng.range(rng, 0, 6), Rng.next(rng)),
			pick(CONCRETE, Rng.next(rng)),
			landmarks,
			{ shadow = false }
		)
	end

	-- Stadium around the boss, open toward the avenue.
	local approach = avenue[#avenue - 1]
	local stadiumCenter = context.ground(boss.x, boss.z)
	stadium(context, stadiumCenter, math.atan2(approach[2] - boss.z, approach[1] - boss.x), landmarks)

	-- Park on the hill, a radio mast on top, a lighthouse on the coast.
	for _, point in
		Scatter.inCircle(rng, 200, 180, 120, 45, 12, function(x, z)
			return context.isFree(x, z, 5)
		end)
	do
		Nature.roundTree(context.ground(point.x, point.z), Rng.range(rng, 14, 24), Rng.next(rng), PARK, nature)
	end
	for _, point in
		Scatter.inCircle(rng, 0, 0, 400, 50, 14, function(x, z)
			return context.isFree(x, z, 2) and Shape.coastFraction(layout, x, z) < 0.85
		end)
	do
		Nature.bush(context.ground(point.x, point.z), Rng.range(rng, 3, 4.5), Rng.next(rng), BUSHES, nature)
	end
	radioMast(context.ground(200, 180), landmarks)
	lighthouse(context.ground(-250, 300), landmarks)
end

local definition: IslandBuilder.Definition = {
	layout = layout,
	decorate = decorate,
	photoSpots = {
		{ from = { 0, 55, 400 }, to = { 0, 30, 150 } }, -- arriving: the skyline
		{ from = { -600, 320, 520 }, to = { 0, 30, -40 } }, -- whole island from the sky
		{ from = { -110, 60, 220 }, to = { -200, 45, 100 } }, -- campus
		{ from = { -20, 30, 120 }, to = { 60, 40, 30 } }, -- central avenue
		{ from = { 150, 50, -40 }, to = { 240, 20, -120 } }, -- simulation city
		{ from = { 10, 70, -150 }, to = { -110, 20, -215 } }, -- stadium
	},
}

return definition
