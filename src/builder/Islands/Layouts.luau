--!strict
-- Every island's layout by island id. Pure data (no Roblox APIs), so the tests
-- check all of them with LayoutCheck.

local Shape = require(script.Parent.Parent.Gen.Shape)

local Layouts: { [string]: Shape.Layout } = {
	Nameku = require(script.Parent.NamekuLayout),
	Kono = require(script.Parent.KonoLayout),
	CloverKingdom = require(script.Parent.CloverKingdomLayout),
	TitanVillage = require(script.Parent.TitanVillageLayout),
	HeroAcademy = require(script.Parent.HeroAcademyLayout),
	DemonCorps = require(script.Parent.DemonCorpsLayout),
}

return Layouts
