--!strict
-- The HUD, in the official UI style: Yen and Gems counters (bottom left, at
-- 75% size), the timers of the active boosts (bottom right, stacked upwards),
-- the current area (top right, at 80% size), the side buttons (left edge,
-- vertically centered; charcoal with a bright purple border) and the round
-- Attack button (bottom center; also F and the gamepad's right trigger). Each
-- group scales with the screen. Other controllers add their side button with
-- HudController.addSideButton. An Attack click only asks the server
-- (Remotes.AttackClick), which decides the damage and caps clicks per second.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Boosts = require(Shared.Config.Boosts)
local Format = require(Shared.Format)
local Islands = require(Shared.Data.Islands)
local CheckUI = require(script.Parent.Parent.UI.CheckUI)
local Icons = require(script.Parent.Parent.UI.Icons)

local GOLD = Color3.fromRGB(255, 194, 26)
local CYAN = Color3.fromRGB(63, 216, 255)
local GREEN = Color3.fromRGB(82, 224, 74)

-- Icon (UI/Icons) and glyph color of each boost.
local BOOST_ICONS: { [string]: { icon: string, color: Color3 } } = {
	Luck = { icon = "Clover", color = GREEN },
	Money = { icon = "Yen", color = GOLD },
	Gems = { icon = "Gem", color = CYAN },
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
		icon = Icons.get("Yen").icon,
		glyph = Icons.get("Yen").glyph,
		glyphColor = GOLD,
		position = UDim2.fromOffset(0, 0),
		parent = group,
	})
	bindNumber(yen, "Yen")
	local _, gems = CheckUI.counter({
		name = "Gems",
		icon = Icons.get("Gem").icon,
		glyph = Icons.get("Gem").glyph,
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
		local style = BOOST_ICONS[boost.id]
		local boostIcon = Icons.get(style.icon)
		local chip, time = CheckUI.boostChip({
			name = boost.id,
			icon = boostIcon.icon,
			glyph = boostIcon.glyph,
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
		color = Color3.new(0, 0, 0),
		stroke = 2,
		strokeColor = Color3.new(1, 1, 1),
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

-- Round Attack button at the bottom center. Clicks without a target are not
-- sent; the client never sends faster than the server would count.
local function buildAttack()
	local group = anchored("Attack", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -16), Vector2.new(124, 124))
	local button = CheckUI.attackButton({
		name = "AttackButton",
		position = UDim2.fromOffset(62, 62),
		keyHint = if UserInputService.KeyboardEnabled then "F" else nil,
		parent = group,
	})
	local scale = button:FindFirstChild("ButtonScale") :: UIScale
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AttackClick") :: RemoteEvent
	local minGap = 1 / Balance.Combat.maxClicksPerSecond
	local lastClick = -math.huge

	local function attack()
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		local now = os.clock()
		if player:GetAttribute("TargetEnemyId") == nil or now - lastClick < minGap then
			return
		end
		lastClick = now
		remote:FireServer()
	end
	button.Activated:Connect(attack)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and (input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2) then
			attack()
		end
	end)
end

function HudController.start()
	gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	buildCounters()
	buildBoosts()
	buildArea()
	buildAttack()
	-- Centered on the left edge, a little above the middle.
	sideColumn = anchored("SideButtons", Vector2.new(0, 0.5), UDim2.new(0, 16, 0.5, -30), Vector2.new(SIDE_WIDTH, 0))

	gui.Parent = player:WaitForChild("PlayerGui")
end

return HudController
