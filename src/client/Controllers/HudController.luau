--!strict
-- Always-visible currency display, fed by the Yen and Gems player attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Format"))
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local HudController = {}

local function createCounter(parent: Instance, order: number, icon: string, color: Color3): TextLabel
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(150, 36)
	frame.BackgroundColor3 = Theme.Background
	frame.BackgroundTransparency = 0.2
	frame.LayoutOrder = order
	frame.Parent = parent
	Theme.corner(frame)

	local iconLabel =
		Theme.label({ text = icon, size = UDim2.new(0, 30, 1, -8), position = UDim2.fromOffset(6, 4), color = color })
	iconLabel.Parent = frame

	local value = Theme.label({ size = UDim2.new(1, -44, 1, -10), position = UDim2.fromOffset(38, 5) })
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.Parent = frame
	return value
end

local function bind(label: TextLabel, attribute: string)
	local function update()
		label.Text = Format.number(tonumber(player:GetAttribute(attribute)) or 0)
	end
	update()
	player:GetAttributeChangedSignal(attribute):Connect(update)
end

function HudController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false

	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Position = UDim2.fromOffset(12, 12)
	container.Size = UDim2.fromOffset(150, 80)
	container.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	bind(createCounter(container, 1, "¥", Theme.Accent), "Yen")
	bind(createCounter(container, 2, "💎", Color3.fromRGB(120, 220, 255)), "Gems")

	gui.Parent = player:WaitForChild("PlayerGui")
end

return HudController
