--!strict
-- Boosts panel (activate stored boosts, buy with gems) and the list of active
-- boosts with their time left. Reads the player attributes
-- "BoostOwned_<BoostId>" and "BoostTime_<BoostId>" set by the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local UI = script.Parent.Parent.UI
local Notify = require(UI.Notify)
local Theme = require(UI.Theme)

local EFFECTS: { [string]: string } = {
	Luck = "×2 probabilidad de Legendario, Mítico y Secreto",
	Money = "×2 Yenes",
	Gems = "×2 Gemas",
}
local COLORS: { [string]: Color3 } = {
	Luck = Color3.fromRGB(110, 210, 110),
	Money = Theme.Accent,
	Gems = Color3.fromRGB(120, 220, 255),
}
local FAILURE_MESSAGES: { [string]: string } = {
	NotOwned = "No tienes ese boost",
	NotEnoughGems = "No tienes suficientes Gemas",
}

local player = Players.LocalPlayer
local actionRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BoostAction") :: RemoteFunction

local BoostController = {}

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

local function request(action: string, boostId: string)
	local ok, result = pcall(function()
		return actionRemote:InvokeServer(action, boostId)
	end)
	if not ok or type(result) ~= "table" then
		return
	end
	local boost = Boosts.get(boostId)
	if result.ok then
		if action == "Activate" then
			Notify.show(`Boost de {boost.displayName} activado`, COLORS[boostId])
		else
			Notify.show(`Compraste un Boost de {boost.displayName}`, COLORS[boostId])
		end
	elseif FAILURE_MESSAGES[result.reason] then
		Notify.error(FAILURE_MESSAGES[result.reason])
	end
end

-- One row per boost: name, effect, stock and time left, Activate and Buy buttons.
local function createRow(parent: Instance, boost: Boosts.Boost, order: number): () -> ()
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 74)
	row.BackgroundColor3 = Theme.Surface
	row.LayoutOrder = order
	row.Parent = parent
	Theme.corner(row)

	local name = Theme.label({ text = `Boost de {boost.displayName}`, size = UDim2.new(0.55, -12, 0, 24), position = UDim2.fromOffset(12, 6), color = COLORS[boost.id] })
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = row

	local effect = Theme.label({ text = EFFECTS[boost.id] or "", size = UDim2.new(0.55, -12, 0, 16), position = UDim2.fromOffset(12, 32), color = Theme.MutedText, bold = false })
	effect.TextXAlignment = Enum.TextXAlignment.Left
	effect.Parent = row

	local status = Theme.label({ size = UDim2.new(0.55, -12, 0, 16), position = UDim2.fromOffset(12, 52), color = Theme.Text, bold = false })
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = row

	local activate = Theme.button("Activar", Color3.fromRGB(60, 140, 90))
	activate.AnchorPoint = Vector2.new(1, 0)
	activate.Position = UDim2.new(1, -10, 0, 8)
	activate.Size = UDim2.new(0.4, -10, 0, 26)
	activate.Parent = row
	activate.Activated:Connect(function()
		request("Activate", boost.id)
	end)

	local buy = Theme.button(`Comprar ({boost.gemPrice} 💎)`, Color3.fromRGB(70, 100, 170))
	buy.AnchorPoint = Vector2.new(1, 0)
	buy.Position = UDim2.new(1, -10, 0, 40)
	buy.Size = UDim2.new(0.4, -10, 0, 26)
	buy.Parent = row
	buy.Activated:Connect(function()
		request("Buy", boost.id)
	end)

	return function()
		local count = owned(boost.id)
		local left = timeLeft(boost.id)
		status.Text = `Tienes: {count}` .. (if left > 0 then `  ·  Activo: {clock(left)}` else "")
		activate.Active = count > 0
		activate.AutoButtonColor = count > 0
		activate.BackgroundTransparency = if count > 0 then 0 else 0.5
	end
end

local function createPanel(gui: ScreenGui): (Frame, { () -> () })
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.9, 0.6)
	panel.BackgroundColor3 = Theme.Background
	panel.Visible = false
	panel.Parent = gui
	Theme.corner(panel, 12)

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(520, 340)
	sizeLimit.Parent = panel

	local title = Theme.label({ text = "Boosts", size = UDim2.new(0.5, 0, 0, 32), position = UDim2.fromOffset(16, 12) })
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

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(16, 56)
	list.Size = UDim2.new(1, -32, 1, -72)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local updaters = {}
	for order, boost in Boosts.List do
		table.insert(updaters, createRow(list, boost, order))
	end
	return panel, updaters
end

-- Small timers under the currency HUD for every active boost.
local function createActiveList(gui: ScreenGui): () -> ()
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Position = UDim2.fromOffset(12, 100)
	container.Size = UDim2.fromOffset(150, 90)
	container.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	local labels: { [string]: TextLabel } = {}
	for order, boost in Boosts.List do
		local label = Theme.label({ size = UDim2.fromOffset(150, 24), color = COLORS[boost.id] })
		label.BackgroundColor3 = Theme.Background
		label.BackgroundTransparency = 0.3
		label.LayoutOrder = order
		label.Visible = false
		label.Parent = container
		Theme.corner(label, 6)
		labels[boost.id] = label
	end

	return function()
		for boostId, label in labels do
			local left = timeLeft(boostId)
			label.Visible = left > 0
			label.Text = `{Boosts.get(boostId).displayName} {clock(left)}`
		end
	end
end

function BoostController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Boosts"
	gui.ResetOnSpawn = false

	local panel, rowUpdaters = createPanel(gui)
	local updateActive = createActiveList(gui)

	-- Under the Inventory button on the left edge.
	local toggle = Theme.button("Boosts", Theme.Surface)
	toggle.AnchorPoint = Vector2.new(0, 0.5)
	toggle.Position = UDim2.new(0, 12, 0.5, 52)
	toggle.Size = UDim2.fromOffset(140, 44)
	toggle.Parent = gui
	toggle.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	local function update()
		for _, updateRow in rowUpdaters do
			updateRow()
		end
		updateActive()
	end
	update()
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Boost" then
			update()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return BoostController
