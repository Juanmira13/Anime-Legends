--!strict
-- Characters window ("PERSONAJES": the character inventory), in the official
-- UI style (Figma screen "02 · Inventario",
-- 880 x 560 at the 1050 x 620 base). A toolbar with the equipped count,
-- "Equip best" and the upgrade with its price; a scrolling grid of character
-- cards (equipped first, then by rarity and damage); and a detail panel for
-- the selected card with its stats, Equip/Unequip and Delete (with a
-- confirm). A tap selects a card; the actions are in the detail panel. All
-- changes go through Remotes.InventoryAction; the server is the authority.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Data.Characters)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Islands = require(Shared.Data.Islands)
local Rarities = require(Shared.Config.Rarities)
local UI = script.Parent.Parent.UI
local CharacterViewport = require(UI.CharacterViewport)
local CheckUI = require(UI.CheckUI)
local Icons = require(UI.Icons)
local Notify = require(UI.Notify)
local Theme = require(UI.Theme)
local HudController = require(script.Parent.HudController)
local SoundController = require(script.Parent.SoundController)

type Entry = { uid: string, id: string }

type Snapshot = {
	characters: { Entry },
	equipped: { string },
	capacity: number,
	equipSlots: number,
	upgrades: number,
	nextUpgradeCost: number?,
}

type CardSlot = { cell: Frame, card: CheckUI.CharacterCard, id: string }

-- Layout in base pixels (window coordinates), from the approved design. The
-- whole window is drawn at CheckUI.WindowFactor of that size, so it keeps its
-- proportions.
local WINDOW_SIZE = Vector2.new(880, 560)
local TOOLBAR_Y = 95 -- center line of the toolbar
local GRID_POSITION = Vector2.new(24, 136)
local GRID_SIZE = Vector2.new(644, 352)
local DETAIL_POSITION = Vector2.new(680, 136)
local DETAIL_SIZE = Vector2.new(176, 352)
local CARD_SIZE = Vector2.new(112, 136)
local CARD_GAP = Vector2.new(12, 18)
local GRID_PADDING = 14
local FOOTER_Y = 522

local DELETE_CONFIRM_TIME = 3
local SECRET_TEXT_STROKE = Color3.fromRGB(255, 200, 60)

local FAILURE_MESSAGES: { [string]: string } = {
	NoEquipSlots = "No tienes ranuras libres",
	Equipped = "Desequípalo antes de eliminarlo",
	LastCharacter = "No puedes eliminar tu último personaje",
	NotEnoughYen = "No tienes suficientes Yenes",
	MaxUpgrades = "El inventario ya está al máximo",
}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRemote = remotes:WaitForChild("InventoryAction") :: RemoteFunction
local changedRemote = remotes:WaitForChild("InventoryChanged") :: RemoteEvent

local InventoryController = {}

local window: Frame
local windowScale: UIScale
local grid: ScrollingFrame
local equippedLabel: TextLabel
local countLabel: TextLabel
local upgradeButton: ImageButton
local upgradeLabel: TextLabel
local detailContent: Frame
local detailEmpty: TextLabel
local detailCard: CheckUI.CharacterCard? = nil
local rarityLabel: TextLabel
local statLabels: { TextLabel } = {}
local equipButton: ImageButton
local equipLabel: TextLabel
local deleteButton: ImageButton
local deleteLabel: TextLabel

local snapshot: Snapshot? = nil
local slots: { [string]: CardSlot } = {}
local equippedSet: { [string]: boolean } = {}
local selected: string? = nil
local pendingDelete: string? = nil

local render: () -> ()

local function request(action: string, uid: string?)
	local ok, result = pcall(function()
		return actionRemote:InvokeServer(action, uid)
	end)
	if not ok or type(result) ~= "table" then
		return
	end
	if result.snapshot then
		snapshot = result.snapshot
		render()
	end
	if result.ok and action == "Upgrade" then
		SoundController.play("Purchase")
	elseif not result.ok and FAILURE_MESSAGES[result.reason] then
		Notify.error(FAILURE_MESSAGES[result.reason])
	end
end

-- Equipped first, then by rarity (highest first), then by damage.
local function sortedCharacters(current: Snapshot): { Entry }
	local list = table.clone(current.characters)
	table.sort(list, function(a, b)
		if equippedSet[a.uid] ~= equippedSet[b.uid] then
			return equippedSet[a.uid] == true
		end
		local rarityA = Rarities.get(Characters.get(a.id).rarity).order
		local rarityB = Rarities.get(Characters.get(b.id).rarity).order
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		local damageA, damageB = Formulas.characterDamage(a.id), Formulas.characterDamage(b.id)
		if damageA ~= damageB then
			return damageA > damageB
		end
		return (tonumber(a.uid) :: number) < (tonumber(b.uid) :: number)
	end)
	return list
end

local function selectCard(uid: string?)
	if selected == uid then
		return
	end
	if selected and slots[selected] then
		slots[selected].card.setSelected(false)
	end
	selected = uid
	pendingDelete = nil
	if uid and slots[uid] then
		slots[uid].card.setSelected(true)
	end
	render()
end

local function newCard(id: string, parent: Instance, position: UDim2?, zIndex: number?): CheckUI.CharacterCard
	local character = Characters.get(id)
	return CheckUI.characterCard({
		name = "Card",
		characterId = id,
		displayName = character.displayName,
		damage = Format.number(Formulas.characterDamage(id)),
		color = Theme.rarityColor(character.rarity),
		secret = character.rarity == "Secret",
		size = CARD_SIZE,
		position = position,
		zIndex = zIndex,
		parent = parent,
	})
end

-- One grid cell per owned character, kept between snapshots so their 3D
-- views are built once.
local function slotFor(entry: Entry): CardSlot
	local existing = slots[entry.uid]
	if existing then
		return existing
	end
	local cell = CheckUI.box({
		name = `Cell_{entry.uid}`,
		size = UDim2.fromOffset(CARD_SIZE.X, CARD_SIZE.Y),
		transparency = 1,
		parent = grid,
	})
	local card = newCard(entry.id, cell)
	CheckUI.bind(card.button, function()
		selectCard(entry.uid)
	end)
	local slot = { cell = cell, card = card, id = entry.id }
	slots[entry.uid] = slot
	return slot
end

local function renderDetail(current: Snapshot)
	local uid = selected
	local id = uid and slots[uid] and slots[uid].id
	detailEmpty.Visible = id == nil
	detailContent.Visible = id ~= nil
	if detailCard and (id == nil or detailCard.button:GetAttribute("CharacterId") ~= id) then
		detailCard.button:Destroy()
		detailCard = nil
	end
	if uid == nil or id == nil then
		return
	end
	if detailCard == nil then
		local card = newCard(id, detailContent, UDim2.fromOffset(DETAIL_SIZE.X / 2, 14 + CARD_SIZE.Y / 2), 12)
		card.button:SetAttribute("CharacterId", id)
		card.button.Active = false
		detailCard = card
	end
	local isEquipped = equippedSet[uid] == true
	assert(detailCard, "unreachable").setEquipped(isEquipped)

	local character = Characters.get(id)
	local rarity = Rarities.get(character.rarity)
	local isSecret = rarity.id == "Secret"
	rarityLabel.Text = string.upper(rarity.displayName)
	rarityLabel.TextColor3 = if isSecret then Color3.new(1, 1, 1) else Theme.rarityColor(rarity.id)
	local outline = rarityLabel:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Color = if isSecret then SECRET_TEXT_STROKE else Color3.new(0, 0, 0)
	end
	statLabels[1].Text = `DAÑO {Format.number(Formulas.characterDamage(id))}`
	statLabels[2].Text = `GOLPE CADA {Formulas.characterCooldown(id)} s`
	statLabels[3].Text = `ISLA {string.upper(Islands.get(character.island).displayName)}`

	equipLabel.Text = if isEquipped then "DESEQUIPAR" else "EQUIPAR"
	local canDelete = not isEquipped and #current.characters > 1
	deleteLabel.Text = if pendingDelete == uid then "¿SEGURO?" else "ELIMINAR"
	CheckUI.setPalette(deleteButton, if canDelete then CheckUI.Buttons.Red else CheckUI.Buttons.Gray)
end

render = function()
	local current = snapshot
	if current == nil then
		return
	end
	equippedSet = {}
	for _, uid in current.equipped do
		equippedSet[uid] = true
	end

	local owned: { [string]: boolean } = {}
	for order, entry in sortedCharacters(current) do
		owned[entry.uid] = true
		local slot = slotFor(entry)
		slot.cell.LayoutOrder = order
		slot.card.setEquipped(equippedSet[entry.uid] == true)
		slot.card.setSelected(entry.uid == selected)
	end
	for uid, slot in slots do
		if not owned[uid] then
			slot.cell:Destroy()
			slots[uid] = nil
		end
	end
	if selected and not owned[selected] then
		selected = nil
	end

	equippedLabel.Text = `EQUIPADOS {#current.equipped} / {current.equipSlots}`
	countLabel.Text = `{#current.characters} / {current.capacity}`
	local cost = current.nextUpgradeCost
	upgradeLabel.Text = if cost then `AMPLIAR · {Format.number(cost)} ¥` else "AL MÁXIMO"
	CheckUI.setPalette(upgradeButton, if cost then CheckUI.Buttons.Gold else CheckUI.Buttons.Gray)
	renderDetail(current)
end

local function toolbarButton(name: string, palette: CheckUI.ButtonPalette, size: Vector2, centerX: number, text: string)
	local button, label = CheckUI.button({
		name = name,
		size = size,
		position = UDim2.fromOffset(centerX, TOOLBAR_Y),
		text = text,
		textSize = 18,
		palette = palette,
		zIndex = 12,
		parent = window,
	})
	return button, label
end

local function buildDetail()
	local detail = CheckUI.well({
		name = "Detail",
		size = UDim2.fromOffset(DETAIL_SIZE.X, DETAIL_SIZE.Y),
		position = UDim2.fromOffset(DETAIL_POSITION.X, DETAIL_POSITION.Y),
		parent = window,
	})
	detailEmpty = CheckUI.text({
		text = "TOCA UN PERSONAJE PARA VER SUS DATOS",
		size = UDim2.new(1, -24, 0, 80),
		textSize = 15,
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
	rarityLabel = CheckUI.text({
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
		local stat = CheckUI.text({
			text = "",
			size = UDim2.new(1, -12, 0, 18),
			position = UDim2.fromOffset(DETAIL_SIZE.X / 2, 192 + (index - 1) * 20),
			textSize = 13,
			color = if index == 1 then Color3.new(1, 1, 1) else CheckUI.Colors.Muted,
			stroke = 2.5,
			zIndex = 12,
			parent = detailContent,
		})
		stat.TextScaled = true
		local maxSize = Instance.new("UITextSizeConstraint")
		maxSize.MaxTextSize = 13
		maxSize.Parent = stat
		statLabels[index] = stat
	end

	equipButton, equipLabel = CheckUI.button({
		name = "Equip",
		size = Vector2.new(156, 44),
		position = UDim2.fromOffset(DETAIL_SIZE.X / 2, 270),
		text = "EQUIPAR",
		textSize = 16,
		palette = CheckUI.Buttons.Purple,
		zIndex = 12,
		parent = detailContent,
	})
	CheckUI.bind(equipButton, function()
		local uid = selected
		if uid then
			request(if equippedSet[uid] then "Unequip" else "Equip", uid)
		end
	end)

	deleteButton, deleteLabel = CheckUI.button({
		name = "Delete",
		size = Vector2.new(156, 44),
		position = UDim2.fromOffset(DETAIL_SIZE.X / 2, 320),
		text = "ELIMINAR",
		textSize = 16,
		palette = CheckUI.Buttons.Red,
		zIndex = 12,
		parent = detailContent,
	})
	CheckUI.bind(deleteButton, function()
		local uid = selected
		if uid == nil then
			return
		end
		if pendingDelete == uid then
			pendingDelete = nil
			request("Delete", uid)
			return
		end
		pendingDelete = uid
		render()
		task.delay(DELETE_CONFIRM_TIME, function()
			if pendingDelete == uid then
				pendingDelete = nil
				render()
			end
		end)
	end)
end

local function buildWindow(gui: ScreenGui)
	window, windowScale = CheckUI.window("Inventory", WINDOW_SIZE, gui)
	local _, close = CheckUI.header(window, "PERSONAJES", CheckUI.Accents.Purple)
	CheckUI.bind(close, function()
		CheckUI.closeWindow(window, windowScale)
	end)

	equippedLabel = CheckUI.text({
		text = "",
		size = UDim2.fromOffset(330, 50),
		position = UDim2.fromOffset(28, TOOLBAR_Y),
		anchor = Vector2.new(0, 0.5),
		textSize = 22,
		stroke = 3,
		align = Enum.TextXAlignment.Left,
		zIndex = 12,
		parent = window,
	})
	local equipBest = toolbarButton("EquipBest", CheckUI.Buttons.Purple, Vector2.new(224, 50), 532, "EQUIPAR MEJORES")
	CheckUI.bind(equipBest, function()
		request("EquipBest")
	end)
	upgradeButton, upgradeLabel = toolbarButton("Upgrade", CheckUI.Buttons.Gold, Vector2.new(196, 50), 754, "")
	CheckUI.bind(upgradeButton, function()
		request("Upgrade")
	end)

	local well = CheckUI.well({
		name = "Grid",
		size = UDim2.fromOffset(GRID_SIZE.X, GRID_SIZE.Y),
		position = UDim2.fromOffset(GRID_POSITION.X, GRID_POSITION.Y),
		parent = window,
	})
	grid = Instance.new("ScrollingFrame")
	grid.Name = "Cards"
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

	buildDetail()

	CheckUI.text({
		text = "PERSONAJES:",
		size = UDim2.fromOffset(150, 30),
		position = UDim2.fromOffset(28, FOOTER_Y),
		anchor = Vector2.new(0, 0.5),
		textSize = 18,
		stroke = 3,
		align = Enum.TextXAlignment.Left,
		zIndex = 12,
		parent = window,
	})
	countLabel = CheckUI.text({
		text = "",
		size = UDim2.fromOffset(150, 30),
		position = UDim2.fromOffset(160, FOOTER_Y),
		anchor = Vector2.new(0, 0.5),
		textSize = 18,
		color = CheckUI.Colors.Gold,
		stroke = 3,
		align = Enum.TextXAlignment.Left,
		zIndex = 12,
		parent = window,
	})

	CheckUI.keepScaled(window, windowScale)
end

function InventoryController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Characters"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	buildWindow(gui)
	HudController.addSideButton({
		name = "Characters",
		text = "PERSONAJES",
		icon = Icons.get("Bag").icon,
		glyph = Icons.get("Bag").glyph,
		onActivated = function()
			CheckUI.toggleWindow(window, windowScale)
		end,
	})

	-- The selected character turns slowly in the detail panel.
	RunService.RenderStepped:Connect(function()
		local card = detailCard
		if card and card.view and CheckUI.isOpen(window) then
			CharacterViewport.setYaw(card.view, math.sin(os.clock() * 0.8) * 0.6)
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")

	changedRemote.OnClientEvent:Connect(function(newSnapshot: Snapshot)
		snapshot = newSnapshot
		render()
	end)
	task.spawn(request, "Refresh")
end

return InventoryController
