--!strict
-- The HUD, in the official UI style: Yen and Gems counters (bottom left, at
-- 75% size), the timers of the active boosts (bottom right, stacked upwards),
-- the current area (top right, at 80% size) and the purple side buttons (left
-- edge, vertically centered). Each group scales with the screen. Other
-- controllers add their side button with HudController.addSideButton.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local Format = require(Shared.Format)
local Islands = require(Shared.Data.Islands)
local CheckUI = require(script.Parent.Parent.UI.CheckUI)

local GOLD = Color3.fromRGB(255, 194, 26)
local CYAN = Color3.fromRGB(63, 216, 255)
local GREEN = Color3.fromRGB(82, 224, 74)

-- Text glyphs until the design's icons are uploaded to Roblox.
local BOOST_GLYPHS: { [string]: { glyph: string, color: Color3 } } = {
	Luck = { glyph = "🍀", color = GREEN },
	Money = { glyph = "¥", color = GOLD },
	Gems = { glyph = "💎", color = CYAN },
}
local AREA_NAMES: { [string]: string } = {
	RaidLobby = "LOBBY DE RAIDS",
	Raid = "RAID",
}
local SIDE_STEP = 100 -- px between side buttons
local SIDE_WIDTH = 90
local COUNTER_SCALE = 0.75 -- of the design size
local AREA_SCALE = 0.8
local BOOST_ROW = 56 -- px per active boost timer

local player = Players.LocalPlayer
local gui: ScreenGui
local sideColumn: Frame
local sideCount = 0

local HudController = {}

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- A transparent group pinned to a screen corner or edge, scaled with the
-- screen (times `factor`).
local function anchored(name: string, anchor: Vector2, position: UDim2, size: Vector2, factor: number?): Frame
	local frame = CheckUI.box({
		name = name,
		size = UDim2.fromOffset(size.X, size.Y),
		position = position,
		anchor = anchor,
		transparency = 1,
		parent = gui,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	CheckUI.onScaleChanged(function(value: number)
		scale.Scale = value * (factor or 1)
	end)
	return frame
end

local function bindNumber(label: TextLabel, attribute: string)
	local function update()
		label.Text = Format.number(tonumber(player:GetAttribute(attribute)) or 0)
	end
	update()
	player:GetAttributeChangedSignal(attribute):Connect(update)
end

local function buildCounters()
	local group =
		anchored("Currencies", Vector2.new(0, 1), UDim2.new(0, 16, 1, -16), Vector2.new(260, 116), COUNTER_SCALE)
	local _, yen = CheckUI.counter({
		name = "Yen",
		glyph = "¥",
		glyphColor = GOLD,
		position = UDim2.fromOffset(0, 0),
		parent = group,
	})
	bindNumber(yen, "Yen")
	local _, gems = CheckUI.counter({
		name = "Gems",
		glyph = "💎",
		glyphColor = CYAN,
		position = UDim2.fromOffset(0, 62),
		parent = group,
	})
	bindNumber(gems, "Gems")
end

local function buildBoosts()
	local group = anchored(
		"ActiveBoosts",
		Vector2.new(1, 1),
		UDim2.new(1, -16, 1, -16),
		Vector2.new(170, #Boosts.List * BOOST_ROW)
	)
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, BOOST_ROW - 46)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = group
	for order, boost in Boosts.List do
		local style = BOOST_GLYPHS[boost.id]
		local chip, time = CheckUI.boostChip({
			name = boost.id,
			glyph = style.glyph,
			glyphColor = style.color,
			multiplier = `x{boost.multiplier}`,
			parent = group,
		})
		chip.LayoutOrder = order
		local attribute = `BoostTime_{boost.id}`
		local function update()
			local left = tonumber(player:GetAttribute(attribute)) or 0
			chip.Visible = left > 0
			time.Text = clock(left)
		end
		update()
		player:GetAttributeChangedSignal(attribute):Connect(update)
	end
end

local function areaName(area: any): string?
	if type(area) ~= "string" then
		return nil
	end
	if AREA_NAMES[area] then
		return AREA_NAMES[area]
	end
	local ok, island = pcall(Islands.get, area)
	return if ok then string.upper(island.displayName) else nil
end

local function buildArea()
	local group = anchored("Area", Vector2.new(1, 0), UDim2.new(1, -16, 0, 10), Vector2.new(220, 62), AREA_SCALE)
	local panel, body = CheckUI.hudPanel({ name = "AreaPanel", size = Vector2.new(220, 62), parent = group })
	local label = CheckUI.text({
		text = "",
		size = UDim2.new(1, -16, 1, 0),
		textSize = 22,
		color = GOLD,
		stroke = 3,
		italic = true,
		zIndex = 10,
		parent = body,
	})
	label.TextScaled = true
	local maxSize = Instance.new("UITextSizeConstraint")
	maxSize.MaxTextSize = 22
	maxSize.Parent = label
	local function update()
		local name = areaName(player:GetAttribute("CurrentArea"))
		panel.Visible = name ~= nil
		label.Text = name or ""
	end
	update()
	player:GetAttributeChangedSignal("CurrentArea"):Connect(update)
end

-- Adds a purple button to the left column (in call order) that runs `onActivated`.
function HudController.addSideButton(props: {
	name: string,
	text: string,
	icon: string?,
	glyph: string?,
	glyphColor: Color3?,
	onActivated: () -> (),
}): ImageButton
	sideCount += 1
	local button = CheckUI.sideButton({
		name = props.name,
		text = props.text,
		icon = props.icon,
		glyph = props.glyph,
		glyphColor = props.glyphColor,
		position = UDim2.fromOffset(SIDE_WIDTH / 2, SIDE_STEP / 2 + (sideCount - 1) * SIDE_STEP),
		parent = sideColumn,
	})
	sideColumn.Size = UDim2.fromOffset(SIDE_WIDTH, sideCount * SIDE_STEP)
	CheckUI.bind(button, props.onActivated)
	return button
end

function HudController.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	buildCounters()
	buildBoosts()
	buildArea()
	-- Centered on the left edge, a little above the middle.
	sideColumn = anchored("SideButtons", Vector2.new(0, 0.5), UDim2.new(0, 16, 0.5, -30), Vector2.new(SIDE_WIDTH, 0))

	gui.Parent = player:WaitForChild("PlayerGui")
end

return HudController
