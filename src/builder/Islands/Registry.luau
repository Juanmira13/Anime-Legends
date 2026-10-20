--!strict
-- Builder definition of every island, by island id. Detailed islands have
-- their own module; the rest use Generic (v0) until their turn comes.

local Root = script.Parent.Parent
local Parts = require(Root.Kit.Parts)
local IslandBuilder = require(Root.IslandBuilder)
local Generic = require(script.Parent.Generic)

local rgb = Parts.rgb

local Registry: { [string]: IslandBuilder.Definition } = {
	Nameku = require(script.Parent.Nameku),

	Kono = Generic.define({
		id = "Kono",
		treeKind = "round",
		tree = { trunk = rgb({ 120, 85, 55 }), leaves = { rgb({ 70, 140, 45 }), rgb({ 95, 165, 55 }), rgb({ 55, 120, 40 }) } },
		treeCount = 190,
		bushes = { rgb({ 70, 140, 50 }), rgb({ 95, 160, 60 }) },
		flowers = { rgb({ 255, 200, 90 }), rgb({ 255, 120, 80 }) },
		rock = rgb({ 140, 125, 110 }),
	}),

	CloverKingdom = Generic.define({
		id = "CloverKingdom",
		treeKind = "round",
		tree = { trunk = rgb({ 110, 80, 60 }), leaves = { rgb({ 80, 160, 70 }), rgb({ 110, 90, 170 }), rgb({ 95, 175, 80 }) } },
		treeCount = 160,
		bushes = { rgb({ 80, 150, 70 }), rgb({ 120, 100, 180 }) },
		flowers = { rgb({ 200, 160, 255 }), rgb({ 255, 255, 255 }), rgb({ 120, 220, 120 }) },
		rock = rgb({ 165, 160, 155 }),
	}),

	TitanVillage = Generic.define({
		id = "TitanVillage",
		treeKind = "pine",
		tree = { trunk = rgb({ 105, 80, 60 }), leaves = { rgb({ 70, 105, 60 }), rgb({ 85, 120, 70 }), rgb({ 60, 90, 55 }) } },
		treeCount = 170,
		bushes = { rgb({ 90, 115, 60 }), rgb({ 105, 125, 70 }) },
		flowers = { rgb({ 230, 220, 180 }), rgb({ 200, 170, 120 }) },
		rock = rgb({ 150, 140, 125 }),
	}),

	HeroAcademy = Generic.define({
		id = "HeroAcademy",
		treeKind = "round",
		tree = { trunk = rgb({ 115, 90, 70 }), leaves = { rgb({ 90, 175, 75 }), rgb({ 110, 190, 90 }) } },
		treeCount = 90,
		bushes = { rgb({ 85, 165, 70 }), rgb({ 100, 180, 80 }) },
		flowers = { rgb({ 255, 90, 90 }), rgb({ 255, 255, 255 }), rgb({ 90, 160, 255 }) },
		rock = rgb({ 150, 150, 155 }),
	}),

	DemonCorps = Generic.define({
		id = "DemonCorps",
		treeKind = "round",
		tree = { trunk = rgb({ 95, 70, 60 }), leaves = { rgb({ 190, 120, 230 }), rgb({ 215, 150, 240 }), rgb({ 160, 100, 210 }) } },
		treeCount = 150,
		bushes = { rgb({ 70, 105, 80 }), rgb({ 160, 110, 200 }) },
		flowers = { rgb({ 230, 170, 255 }), rgb({ 255, 200, 230 }) },
		rock = rgb({ 110, 105, 120 }),
	}),
}

return Registry
