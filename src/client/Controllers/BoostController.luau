--!strict
-- Inventory window ("INVENTARIO"), in the official UI style (Figma section
-- "Ajustes v3", screen B1; same size and layout as the Characters window:
-- 880 x 560 at the 1050 x 620 base, drawn at CheckUI.WindowFactor). Category
-- tabs: OBJETOS and MONTURAS (coming soon) and BOOSTS. The boosts tab shows a
-- scrolling grid with one card per boost the player has (amount and "ACTIVO"
-- tag) and a detail panel for the selected one: effect, duration per unit,
-- time left and Activate (green; gray "SIN STOCK" without stock). Nothing is
-- sold here: boosts are bought from the shop NPC in the raid lobby
-- (BoostShopController). Opened from its HUD side button; the active boosts'
-- timers are drawn by HudController. Reads the player attributes
-- "BoostOwned_<BoostId>" and "BoostTime_<BoostId>".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local UI = script.Parent.Parent.UI
local CheckUI = require(UI.CheckUI)
local Icons = require(UI.Icons)
local Notify = require(UI.Notify)
local HudController = require(script.Parent.HudController)
local SoundController = require(script.Parent.SoundController)

type Tab = "Objects" | "Boosts" | "Mounts"

-- Layout in base pixels (window coordinates), from the approved design.
local WINDOW_SIZE = Vector2.new(880, 560)
local TAB_SIZE = Vector2.new(184, 48)
local TAB_Y = 96
local GRID_POSITION = Vector2.new(24, 146)
local GRID_SIZE = Vector2.new(644, 342)
local DETAIL_POSITION = Vector2.new(680, 146)
local DETAIL_SIZE = Vector2.new(176, 342)
local CARD_SIZE = Vector2.new(112, 136)
local CARD_GAP = Vector2.new(12, 18)
local GRID_PADDING = 14
local MIN_SLOTS = 10 -- empty slots shown so the grid never looks bare
local FOOTER_Y = 522

local TABS: { { id: Tab, title: string, soon: boolean, empty: string } } = {
	{ id = "Objects", title = "OBJETOS", soon = true, empty = "Aquí se guardarán los objetos." },
	{ id = "Boosts", title = "BOOSTS", soon = false, empty = "" },
	{ id = "Mounts", title = "MONTURAS", soon = true, empty = "Aquí se guardarán las monturas." },
}
local STYLES: { [string]: { name: string, icon: string, color: Color3, effect: string } } = {
	Luck = {
		name = "SUERTE",
		icon = "Clover",
		color = Color3.fromRGB(82, 224, 74),
		effect = "×2 LEGENDARIO, MÍTICO Y SECRETO",
	},
	Money = { name = "DINERO", icon = "Yen", color = Color3.fromRGB(255, 194, 26), effect = "×2 YENES" },
	Gems = { name = "GEMAS", icon = "Gem", color = Color3.fromRGB(63, 216, 255), effect = "×2 GEMAS" },
}
local FAILURE_MESSAGES: { [string]: string } = {
	NotOwned = "No tienes ese boost",
}
local ACTIVE_GREEN = Color3.fromRGB(170, 250, 40)

local player = Players.LocalPlayer
local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BoostAction") :: RemoteFunction

local BoostController = {}

local window: Frame
local windowScale: UIScale
local grid: ScrollingFrame
local comingSoon: Frame
local comingSoonText: TextLabel
local tabButtons: { [Tab]: ImageButton } = {}
local cards: { [string]: CheckUI.ItemCard } = {}
local cells: { [string]: Frame } = {}
local placeholders: { Frame } = {}
local detailEmpty: TextLabel
local detailContent: Frame
local detailCard: CheckUI.ItemCard? = nil
local detailCardId: string? = nil
local detailName: TextLabel
local detailLines: { TextLabel } = {}
local activateButton: ImageButton
local activateLabel: TextLabel
local totalLabel: TextLabel

local currentTab: Tab = "Boosts"
local selected: string? = nil

local render: () -> ()

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function owned(boostId: string): number
	return tonumber(player:GetAttribute(`BoostOwned_{boostId}`)) or 0
end

local function timeLeft(boostId: string): number
	return tonumber(player:GetAttribute(`BoostTime_{boostId}`)) or 0
end

-- A boost is in the inventory while the player has units of it or it is running.
local function isShown(boostId: string): boolean
	return owned(boostId) > 0 or timeLeft(boostId) > 0
end

local function request(boostId: string)
	local ok, result = pcall(function()
		return actionRemote:InvokeServer("Activate", boostId)
	end)
	if not ok or type(result) ~= "table" then
		return
	end
	if result.ok then
		Notify.show(`Boost de {Boosts.get(boostId).displayName} activado`, STYLES[boostId].color)
		SoundController.play("BoostActivate")
	elseif FAILURE_MESSAGES[result.reason] then
		Notify.error(FAILURE_MESSAGES[result.reason])
	end
end

local function selectBoost(boostId: string?)
	selected = boostId
	render()
end

local function renderDetail()
	local boostId = if currentTab == "Boosts" then selected else nil
	detailEmpty.Text = if currentTab == "Boosts"
		then "TOCA UN BOOST PARA VER SUS DATOS"
		else "TOCA UN OBJETO PARA VER SUS DATOS"
	detailEmpty.Visible = boostId == nil
	detailContent.Visible = boostId ~= nil
	if detailCard and detailCardId ~= boostId then
		detailCard.button:Destroy()
		detailCard, detailCardId = nil, nil
	end
	if boostId == nil then
		return
	end
	local style = STYLES[boostId]
	local boost = Boosts.get(boostId)
	if detailCard == nil then
		local card = CheckUI.itemCard({
			name = "Card",
			displayName = style.name,
			color = style.color,
			icon = Icons.get(style.icon).icon,
			glyph = Icons.get(style.icon).glyph,
			size = CARD_SIZE,
			position = UDim2.fromOffset(DETAIL_SIZE.X / 2, 14 + CARD_SIZE.Y / 2),
			zIndex = 12,
			parent = detailContent,
		})
		card.button.Active = false
		detailCard, detailCardId = card, boostId
	end
	local count, left = owned(boostId), timeLeft(boostId)
	local card = assert(detailCard, "unreachable")
	card.setCount(count)
	card.setActive(left > 0)

	detailName.Text = style.name
	detailName.TextColor3 = style.color
	detailLines[1].Text = style.effect
	detailLines[2].Text = `{boost.duration // 60} MIN POR UNIDAD`
	detailLines[3].Text = if left > 0 then `ACTIVO: {clock(left)}` else "SIN ACTIVAR"
	detailLines[3].TextColor3 = if left > 0 then ACTIVE_GREEN else CheckUI.Colors.Muted
	activateLabel.Text = if count > 0 then "ACTIVAR" else "SIN STOCK"
	CheckUI.setPalette(activateButton, if count > 0 then CheckUI.Buttons.Green else CheckUI.Buttons.Gray)
end

render = function()
	local tabInfo = TABS[2]
	for _, tab in TABS do
		CheckUI.setPalette(
			tabButtons[tab.id],
			if tab.id == currentTab then CheckUI.Buttons.Purple else CheckUI.Buttons.Gray
		)
		if tab.id == currentTab then
			tabInfo = tab
		end
	end
	comingSoon.Visible = tabInfo.soon
	comingSoonText.Text = tabInfo.empty
	grid.Visible = not tabInfo.soon

	-- Boost cards, in the Boosts list order; the selection falls back to the first one.
	local shown = 0
	local firstShown: string? = nil
	local total = 0
	for order, boost in Boosts.List do
		local visible = isShown(boost.id)
		cells[boost.id].Visible = visible
		cells[boost.id].LayoutOrder = order
		total += owned(boost.id)
		if visible then
			shown += 1
			firstShown = firstShown or boost.id
			local card = cards[boost.id]
			card.setCount(owned(boost.id))
			card.setActive(timeLeft(boost.id) > 0)
		end
	end
	if selected == nil or not isShown(selected) then
		selected = firstShown
	end
	for boostId, card in cards do
		card.setSelected(boostId == selected)
	end
	for index, placeholder in placeholders do
		placeholder.Visible = shown + index <= MIN_SLOTS
	end

	totalLabel.Text = `BOOSTS: {total}`
	renderDetail()
end

local function buildTabs()
	for index, tab in TABS do
		local centerX = 28 + TAB_SIZE.X / 2 + (index - 1) * (TAB_SIZE.X + 16)
		local button = CheckUI.button({
			name = `Tab_{tab.id}`,
			size = TAB_SIZE,
			position = UDim2.fromOffset(centerX, TAB_Y),
			text = tab.title,
			textSize = 18,
			palette = CheckUI.Buttons.Gray,
			zIndex = 12,
			parent = window,
		})
		CheckUI.bind(button, function()
			currentTab = tab.id
			render()
		end)
		tabButtons[tab.id] = button
		if tab.soon then
			CheckUI.text({
				text = "PRÓXIMAMENTE",
				size = UDim2.fromOffset(TAB_SIZE.X, 14),
				position = UDim2.fromOffset(centerX, TAB_Y + TAB_SIZE.Y / 2 + 9),
				textSize = 9,
				color = CheckUI.Colors.Muted,
				stroke = 2,
				zIndex = 12,
				parent = window,
			})
		end
	end
end

local function buildGrid()
	local well = CheckUI.well({
		name = "Grid",
		size = UDim2.fromOffset(GRID_SIZE.X, GRID_SIZE.Y),
		position = UDim2.fromOffset(GRID_POSITION.X, GRID_POSITION.Y),
		parent = window,
	})
	grid = Instance.new("ScrollingFrame")
	grid.Name = "Items"
	grid.Size = UDim2.new(1, -4, 1, -6)
	grid.Position = UDim2.fromOffset(2, 2)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = CheckUI.Colors.Lavender
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.ZIndex = 11
	grid.Parent = well
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, GRID_PADDING)
	padding.PaddingBottom = UDim.new(0, GRID_PADDING)
	padding.PaddingLeft = UDim.new(0, GRID_PADDING)
	padding.Parent = grid
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y)
	layout.CellPadding = UDim2.fromOffset(CARD_GAP.X, CARD_GAP.Y)
	layout.FillDirectionMaxCells = 5
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for _, boost in Boosts.List do
		local style = STYLES[boost.id]
		local cell = CheckUI.box({
			name = `Cell_{boost.id}`,
			size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
			transparency = 1,
			parent = grid,
		})
		local card = CheckUI.itemCard({
			name = "Card",
			displayName = style.name,
			color = style.color,
			icon = Icons.get(style.icon).icon,
			glyph = Icons.get(style.icon).glyph,
			size = CARD_SIZE,
			parent = cell,
		})
		CheckUI.bind(card.button, function()
			selectBoost(boost.id)
		end)
		cells[boost.id] = cell
		cards[boost.id] = card
	end
	-- Faint empty slots after the cards.
	for index = 1, MIN_SLOTS do
		local slot = CheckUI.box({
			name = "EmptySlot",
			size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
			color = Color3.new(1, 1, 1),
			transparency = 0.97,
			radius = 12,
			parent = grid,
		})
		slot.LayoutOrder = 100 + index
		CheckUI.stroke(slot, CheckUI.Colors.Neon, 1.5, true).Transparency = 0.75
		placeholders[index] = slot
	end

	-- "Coming soon" message over the grid area for the tabs that are not ready.
	comingSoon = CheckUI.box({
		name = "ComingSoon",
		size = UDim2.fromScale(1, 1),
		transparency = 1,
		zIndex = 11,
		parent = well,
	})
	CheckUI.text({
		text = "PRÓXIMAMENTE",
		size = UDim2.new(1, 0, 0, 40),
		position = UDim2.new(0.5, 0, 0.5, -16),
		textSize = 30,
		color = CheckUI.Colors.Muted,
		stroke = 3.5,
		italic = true,
		zIndex = 12,
		parent = comingSoon,
	})
	comingSoonText = CheckUI.text({
		text = "",
		size = UDim2.new(1, 0, 0, 24),
		position = UDim2.new(0.5, 0, 0.5, 20),
		textSize = 14,
		color = CheckUI.Colors.Muted,
		stroke = 2.5,
		zIndex = 12,
		parent = comingSoon,
	})
end

local function buildDetail()
	local detail = CheckUI.well({
		name = "Detail",
		size = UDim2.fromOffset(DETAIL_SIZE.X, DETAIL_SIZE.Y),
		position = UDim2.fromOffset(DETAIL_POSITION.X, DETAIL_POSITION.Y),
		parent = window,
	})
	detailEmpty = CheckUI.text({
		text = "",
		size = UDim2.new(1, -24, 0, 80),
		textSize = 13,
		color = CheckUI.Colors.Muted,
		stroke = 2.5,
		zIndex = 12,
		parent = detail,
	})
	detailEmpty.TextWrapped = true
	detailContent = CheckUI.box({
		name = "Content",
		size = UDim2.fromScale(1, 1),
		transparency = 1,
		zIndex = 11,
		parent = detail,
	})
	detailName = CheckUI.text({
		text = "",
		size = UDim2.new(1, -12, 0, 22),
		position = UDim2.fromOffset(DETAIL_SIZE.X / 2, 169),
		textSize = 17,
		stroke = 3,
		italic = true,
		zIndex = 12,
		parent = detailContent,
	})
	for index = 1, 3 do
		local line = CheckUI.text({
			text = "",
			size = UDim2.new(1, -12, 0, 18),
			position = UDim2.fromOffset(DETAIL_SIZE.X / 2, 194 + (index - 1) * 20),
			textSize = 12,
			color = if index == 1 then Color3.new(1, 1, 1) else CheckUI.Colors.Muted,
			stroke = 2.5,
			zIndex = 12,
			parent = detailContent,
		})
		line.TextScaled = true
		local maxSize = Instance.new("UITextSizeConstraint")
		maxSize.MaxTextSize = 12
		maxSize.Parent = line
		detailLines[index] = line
	end
	activateButton, activateLabel = CheckUI.button({
		name = "Activate",
		size = Vector2.new(156, 44),
		position = UDim2.fromOffset(DETAIL_SIZE.X / 2, 290),
		text = "ACTIVAR",
		textSize = 16,
		palette = CheckUI.Buttons.Green,
		zIndex = 12,
		parent = detailContent,
	})
	CheckUI.bind(activateButton, function()
		if selected then
			request(selected)
		end
	end)
end

local function buildWindow(gui: ScreenGui)
	window, windowScale = CheckUI.window("Inventory", WINDOW_SIZE, gui)
	local _, close = CheckUI.header(window, "INVENTARIO", CheckUI.Accents.Purple)
	CheckUI.bind(close, function()
		CheckUI.closeWindow(window, windowScale)
	end)
	buildTabs()
	buildGrid()
	buildDetail()
	totalLabel = CheckUI.text({
		text = "",
		size = UDim2.fromOffset(300, 30),
		position = UDim2.fromOffset(28, FOOTER_Y),
		anchor = Vector2.new(0, 0.5),
		textSize = 18,
		stroke = 3,
		align = Enum.TextXAlignment.Left,
		zIndex = 12,
		parent = window,
	})
	CheckUI.text({
		text = "Compra boosts en la Tienda del lobby de Raids",
		size = UDim2.fromOffset(520, 30),
		position = UDim2.fromOffset(WINDOW_SIZE.X - 28, FOOTER_Y),
		anchor = Vector2.new(1, 0.5),
		textSize = 13,
		color = CheckUI.Colors.Muted,
		stroke = 2.5,
		align = Enum.TextXAlignment.Right,
		zIndex = 12,
		parent = window,
	})
	CheckUI.keepScaled(window, windowScale)
end

function BoostController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Inventory"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	buildWindow(gui)
	HudController.addSideButton({
		name = "Inventory",
		text = "INVENTARIO",
		icon = Icons.get("Bolt").icon,
		glyph = Icons.get("Bolt").glyph,
		onActivated = function()
			CheckUI.toggleWindow(window, windowScale)
		end,
	})

	render()
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Boost" then
			render()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return BoostController
