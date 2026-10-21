--!strict
-- Builder definition of every island, by island id. Each island has its own
-- module with its own layout (Islands/<Island>Layout) and decoration.

local Root = script.Parent.Parent
local IslandBuilder = require(Root.IslandBuilder)

local Registry: { [string]: IslandBuilder.Definition } = {
	Nameku = require(script.Parent.Nameku),
	Kono = require(script.Parent.Kono),
	CloverKingdom = require(script.Parent.CloverKingdom),
	TitanVillage = require(script.Parent.TitanVillage),
	HeroAcademy = require(script.Parent.HeroAcademy),
	DemonCorps = require(script.Parent.DemonCorps),
}

return Registry
