--!strict
-- Inventory panel: lists owned characters, equips/unequips them on click,
-- deletes with a two-step confirm, "Equip best" and inventory upgrades.
-- All changes go through Remotes.InventoryAction; the server is the authority.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Characters = require(Shared.Data.Characters)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Rarities = require(Shared.Config.Rarities)
local Theme = require(script.Parent.Parent.UI.Theme)
local SoundController = require(script.Parent.SoundController)

type Snapshot = {
	characters: { { uid: string, id: string } },
	equipped: { string },
	capacity: number,
	equipSlots: number,
	upgrades: number,
	nextUpgradeCost: number?,
}

local DELETE_CONFIRM_TIME = 3
local MESSAGE_TIME = 2.5

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

local panel: Frame
local grid: ScrollingFrame
local countsLabel: TextLabel
local upgradeButton: TextButton
local messageLabel: TextLabel
local snapshot: Snapshot? = nil
local pendingDelete: string? = nil
local messageToken = 0

local render: () -> ()

local function showMessage(text: string)
	messageLabel.Text = text
	messageLabel.Visible = true
	messageToken += 1
	local token = messageToken
	task.delay(MESSAGE_TIME, function()
		if messageToken == token then
			messageLabel.Visible = false
		end
	end)
end

local function applySnapshot(newSnapshot: Snapshot)
	snapshot = newSnapshot
	render()
end

local function request(action: string, uid: string?)
	local ok, result = pcall(function()
		return actionRemote:InvokeServer(action, uid)
	end)
	if not ok or type(result) ~= "table" then
		return
	end
	if result.snapshot then
		applySnapshot(result.snapshot)
	end
	if result.ok and action == "Upgrade" then
		SoundController.play("Purchase")
	elseif not result.ok and FAILURE_MESSAGES[result.reason] then
		showMessage(FAILURE_MESSAGES[result.reason])
		SoundController.play("Error")
	end
end

-- Equipped first, then by rarity (highest first), then by damage.
local function sortedCharacters(current: Snapshot): ({ { uid: string, id: string } }, { [string]: boolean })
	local equipped: { [string]: boolean } = {}
	for _, uid in current.equipped do
		equipped[uid] = true
	end
	local list = table.clone(current.characters)
	table.sort(list, function(a, b)
		if equipped[a.uid] ~= equipped[b.uid] then
			return equipped[a.uid] == true
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
	return list, equipped
end

local function createCard(entry: { uid: string, id: string }, isEquipped: boolean, order: number)
	local character = Characters.get(entry.id)
	local rarity = Rarities.get(character.rarity)
	local color = Theme.rarityColor(rarity.id)

	local card = Instance.new("TextButton")
	card.Text = ""
	card.AutoButtonColor = true
	card.BackgroundColor3 = Theme.Surface
	card.LayoutOrder = order
	Theme.corner(card)

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = if isEquipped then Theme.Accent else color
	stroke.Thickness = if isEquipped then 3 else 1.5
	stroke.Parent = card

	local name = Theme.label({
		text = character.displayName,
		size = UDim2.new(1, -12, 0, 22),
		position = UDim2.fromOffset(6, 22),
	})
	name.Parent = card

	local rarityLabel = Theme.label({
		text = rarity.displayName,
		size = UDim2.new(1, -12, 0, 16),
		position = UDim2.fromOffset(6, 46),
		color = if rarity.id == "Secret" then Theme.Text else color,
		bold = false,
	})
	rarityLabel.Parent = card

	local stats = Theme.label({
		text = `⚔ {Format.number(Formulas.characterDamage(entry.id))}  ⏱ {Formulas.characterCooldown(entry.id)}s`,
		size = UDim2.new(1, -12, 0, 16),
		position = UDim2.fromOffset(6, 66),
		color = Theme.MutedText,
		bold = false,
	})
	stats.Parent = card

	if isEquipped then
		local badge = Theme.label({
			text = "EQUIPADO",
			size = UDim2.new(1, -12, 0, 16),
			position = UDim2.new(0, 6, 1, -22),
			color = Theme.Accent,
		})
		badge.Parent = card
	end

	local deleteButton = Theme.button(if pendingDelete == entry.uid then "¿Seguro?" else "🗑", Theme.Danger)
	deleteButton.AnchorPoint = Vector2.new(1, 0)
	deleteButton.Position = UDim2.new(1, -4, 0, 4)
	deleteButton.Size = if pendingDelete == entry.uid then UDim2.fromOffset(70, 18) else UDim2.fromOffset(24, 18)
	deleteButton.Visible = not isEquipped
	deleteButton.Parent = card
	deleteButton.Activated:Connect(function()
		if pendingDelete == entry.uid then
			pendingDelete = nil
			request("Delete", entry.uid)
			return
		end
		pendingDelete = entry.uid
		render()
		task.delay(DELETE_CONFIRM_TIME, function()
			if pendingDelete == entry.uid then
				pendingDelete = nil
				render()
			end
		end)
	end)

	card.Activated:Connect(function()
		request(if isEquipped then "Unequip" else "Equip", entry.uid)
	end)

	card.Parent = grid
end

render = function()
	local current = snapshot
	if current == nil then
		return
	end

	for _, child in grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local list, equipped = sortedCharacters(current)
	for order, entry in list do
		createCard(entry, equipped[entry.uid] == true, order)
	end

	countsLabel.Text =
		`Personajes {#current.characters}/{current.capacity}  ·  Equipados {#current.equipped}/{current.equipSlots}`
	local cost = current.nextUpgradeCost
	upgradeButton.Text = if cost
		then `Ampliar +{Balance.Inventory.slotsPerUpgrade} ({Format.number(cost)} ¥)`
		else "Inventario al máximo"
	upgradeButton.Active = cost ~= nil
	upgradeButton.AutoButtonColor = cost ~= nil
end

local function createPanel(gui: ScreenGui)
	panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.75)
	panel.BackgroundColor3 = Theme.Background
	panel.Visible = false
	panel.Parent = gui
	Theme.corner(panel, 12)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(760, 540)
	sizeLimit.Parent = panel

	local title =
		Theme.label({ text = "Inventario", size = UDim2.new(0.5, 0, 0, 32), position = UDim2.fromOffset(16, 12) })
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local close = Theme.button("X", Theme.Danger)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(36, 32)
	close.Parent = panel
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	countsLabel = Theme.label({
		size = UDim2.new(1, -32, 0, 20),
		position = UDim2.fromOffset(16, 48),
		color = Theme.MutedText,
		bold = false,
	})
	countsLabel.TextXAlignment = Enum.TextXAlignment.Left
	countsLabel.Parent = panel

	local equipBest = Theme.button("Equipar mejores", Color3.fromRGB(60, 140, 90))
	equipBest.Position = UDim2.fromOffset(16, 76)
	equipBest.Size = UDim2.new(0.4, -20, 0, 34)
	equipBest.Parent = panel
	equipBest.Activated:Connect(function()
		request("EquipBest")
	end)

	upgradeButton = Theme.button("", Color3.fromRGB(70, 100, 170))
	upgradeButton.AnchorPoint = Vector2.new(1, 0)
	upgradeButton.Position = UDim2.new(1, -16, 0, 76)
	upgradeButton.Size = UDim2.new(0.6, -20, 0, 34)
	upgradeButton.Parent = panel
	upgradeButton.Activated:Connect(function()
		request("Upgrade")
	end)

	grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(16, 120)
	grid.Size = UDim2.new(1, -32, 1, -136)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = panel

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(130, 112)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	messageLabel =
		Theme.label({ size = UDim2.new(1, -32, 0, 24), position = UDim2.new(0, 16, 1, -32), color = Theme.Error })
	messageLabel.Visible = false
	messageLabel.ZIndex = 5
	messageLabel.Parent = panel
end

function InventoryController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Inventory"
	gui.ResetOnSpawn = false

	-- Left edge, vertically centered: the bottom-left corner is the mobile thumbstick.
	local toggle = Theme.button("Inventario", Theme.Surface)
	toggle.AnchorPoint = Vector2.new(0, 0.5)
	toggle.Position = UDim2.new(0, 12, 0.5, 0)
	toggle.Size = UDim2.fromOffset(140, 44)
	toggle.Parent = gui

	createPanel(gui)
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	gui.Parent = player:WaitForChild("PlayerGui")

	changedRemote.OnClientEvent:Connect(applySnapshot)
	task.spawn(request, "Refresh")
end

return InventoryController
