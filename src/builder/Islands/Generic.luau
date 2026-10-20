--!strict
-- First version (v0) of an island that has no detailed builder yet: its
-- layout from GenericLayout, decorated with its own palette and trees, and a
-- provisional landmark behind the boss. Each island gets its own detailed
-- module, like Nameku, in turn.

local Root = script.Parent.Parent
local Rng = require(Root.Gen.Rng)
local Scatter = require(Root.Gen.Scatter)
local Nature = require(Root.Kit.Nature)
local Parts = require(Root.Kit.Parts)
local IslandBuilder = require(Root.IslandBuilder)
local GenericLayout = require(script.Parent.GenericLayout)

export type Style = {
	id: string,
	treeKind: "round" | "pine",
	tree: Nature.TreePalette,
	treeCount: number,
	bushes: { Color3 },
	flowers: { Color3 },
	rock: Color3,
}

local Generic = {}

-- Provisional landmark: a tall obelisk with a glowing top.
local function obelisk(ground: Vector3, accent: Color3, stone: Color3, parent: Instance)
	local model = Parts.model("Landmark", parent)
	Parts.column(16, 3, CFrame.new(ground), stone, model, { collide = true })
	Parts.block(Vector3.new(7, 34, 7), CFrame.new(ground + Vector3.new(0, 20, 0)), Parts.vary(stone, 0.15, 0.6), model, { collide = true })
	Parts.wedge(Vector3.new(7, 6, 3.5), CFrame.new(ground + Vector3.new(0, 40, -1.75)), stone, model)
	Parts.wedge(Vector3.new(7, 6, 3.5), CFrame.new(ground + Vector3.new(0, 40, 1.75)) * CFrame.Angles(0, math.pi, 0), stone, model)
	local crystal = Parts.ball(6, ground + Vector3.new(0, 47, 0), accent, model, { material = Enum.Material.Neon, shadow = false })
	Parts.light(crystal, accent, 40, 2)
end

function Generic.define(style: Style): IslandBuilder.Definition
	local layout = GenericLayout.layoutFor(style.id)

	local function decorate(context: IslandBuilder.Context)
		local rng = context.rng
		local nature = Parts.folder("Nature", context.decor)
		local landmarks = Parts.folder("Landmarks", context.decor)
		local plant: (Vector3, number, number, Nature.TreePalette, Instance) -> Model = if style.treeKind == "pine" then Nature.pineTree else Nature.roundTree

		for _, point in Scatter.inCircle(rng, 0, 0, layout.radius, style.treeCount, 13, function(x, z)
			return context.isFree(x, z, 7)
		end) do
			plant(context.ground(point.x, point.z), Rng.range(rng, 16, 30), Rng.next(rng), style.tree, nature)
		end
		for _, mesa in layout.mesas do
			plant(context.ground(mesa.x, mesa.z), Rng.range(rng, 14, 22), Rng.next(rng), style.tree, nature)
		end
		for _, point in Scatter.inCircle(rng, 0, 0, layout.radius, 70, 10, function(x, z)
			return context.isFree(x, z, 2)
		end) do
			Nature.bush(context.ground(point.x, point.z), Rng.range(rng, 3, 5), Rng.next(rng), style.bushes, nature)
		end
		for _, point in Scatter.inCircle(rng, 0, 0, layout.radius, 35, 18, function(x, z)
			return context.isFree(x, z, 4)
		end) do
			Nature.rock(context.ground(point.x, point.z), Rng.range(rng, 3, 7), Rng.next(rng), style.rock, nature)
		end
		for _, point in Scatter.inCircle(rng, 0, 0, layout.radius, 50, 9, function(x, z)
			return context.isFree(x, z, 3)
		end) do
			Nature.flowers(context.ground(point.x, point.z), Rng.next(rng), style.flowers, nature)
		end

		local plaza, boss = layout.plaza, layout.zones[4]
		local dx, dz = boss.x - plaza.x, boss.z - plaza.z
		local length = math.sqrt(dx * dx + dz * dz)
		local x, z = boss.x + dx / length * (boss.radius + 12), boss.z + dz / length * (boss.radius + 12)
		obelisk(context.ground(x, z), context.accent, style.rock, landmarks)
	end

	return {
		layout = layout,
		decorate = decorate,
		photoSpots = {
			{ from = { 0, 62, 430 }, to = { 0, 10, 150 } },
			{ from = { -470, 230, 470 }, to = { 0, 0, -20 } },
		},
	}
end

return Generic
