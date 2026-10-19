--!strict
-- Shows the result of a gacha roll (or why it failed) as a short popup.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Data.Characters)
local Rarities = require(Shared.Config.Rarities)

local POPUP_TIME = 2.5

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(110, 210, 110),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 70, 70),
	Secret = Color3.fromRGB(20, 20, 20),
}

-- Silent reasons are not shown (spam guard, data still loading).
local FAILURE_MESSAGES: { [string]: string } = {
	IslandLocked = "Esta isla está bloqueada",
	InventoryFull = "Inventario lleno",
	NotEnoughYen = "No tienes suficientes Yenes",
}

local player = Players.LocalPlayer

local GachaController = {}

local popup: TextLabel
local hideToken = 0

local function createPopup(): TextLabel
	local gui = Instance.new("ScreenGui")
	gui.Name = "GachaPopup"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0.12, 0)
	label.Size = UDim2.fromOffset(420, 56)
	label.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.5
	label.Visible = false
	label.Parent = gui
	Instance.new("UICorner").Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = label

	return label
end

local function show(text: string, color: Color3)
	popup.Text = text
	popup.TextColor3 = color
	local stroke = popup:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	popup.Visible = true
	popup.Size = UDim2.fromOffset(380, 50)
	TweenService:Create(popup, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(420, 56) }):Play()

	hideToken += 1
	local token = hideToken
	task.delay(POPUP_TIME, function()
		if hideToken == token then
			popup.Visible = false
		end
	end)
end

local function onResult(result: any)
	if result.ok then
		local character = Characters.get(result.characterId)
		local rarity = Rarities.get(result.rarity)
		local color = RARITY_COLORS[rarity.id] or Color3.new(1, 1, 1)
		-- Secret is drawn dark, so make its text readable with a white outline.
		show(`¡{character.displayName}! ({rarity.displayName})`, color)
		if rarity.id == "Secret" then
			popup.TextStrokeColor3 = Color3.new(1, 1, 1)
		else
			popup.TextStrokeColor3 = Color3.new(0, 0, 0)
		end
	else
		local message = FAILURE_MESSAGES[result.reason]
		if message then
			popup.TextStrokeColor3 = Color3.new(0, 0, 0)
			show(message, Color3.fromRGB(255, 120, 120))
		end
	end
end

function GachaController.start()
	popup = createPopup()
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GachaResult") :: RemoteEvent
	remote.OnClientEvent:Connect(onResult)
end

return GachaController
