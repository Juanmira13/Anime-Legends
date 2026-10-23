--!strict
-- Boost shop window ("TIENDA"), opened by the shopkeeper NPC in the raid lobby
-- (the server fires Remotes.OpenBoostShop from its ProximityPrompt). Official
-- UI style (Figma page "Ajustes HUD v2", screen 4; 780 x 500 at the
-- 1050 x 620 base, drawn at CheckUI.WindowFactor): gold accent, the player's
-- Gems in the header and one row per boost with its icon, effect, duration,
-- price and Buy (gold; red without enough Gems). The window closes when the
-- player walks away from the shop; the server only accepts a purchase near it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosts = require(Shared.Config.Boosts)
local Format = require(Shared.Format)
local UI = script.Parent.Parent.UI
local CheckUI = require(UI.CheckUI)
local Icons = require(UI.Icons)
local Notify = require(UI.Notify)
local SoundController = require(script.Parent.SoundController)

-- Layout in base pixels (window coordinates), from the approved design.
local WINDOW_SIZE = Vector2.new(780, 500)
local ROW_SIZE = Vector2.new(724, 110)
local ROW_LEFT = 28
local ROW_TOP = 76
local ROW_STEP = 124
local CLOSE_DISTANCE = Boosts.ShopRange + 4 -- studs from the shop before the window closes
local CHECK_INTERVAL = 0.5

local STYLES: { [string]: { name: string, icon: string, color: Color3, effect: string } } = {
	Luck = {
		name = "SUERTE",
		icon = "Clover",
		color = Color3.fromRGB(82, 224, 74),
		effect = "×2 probabilidad de Legendario, Mítico y Secreto",
	},
	Money = {
		name = "DINERO",
		icon = "Yen",
		color = Color3.fromRGB(255, 194, 26),
		effect = "×2 Yenes de los enemigos",
	},
	Gems = { name = "GEMAS", icon = "Gem", color = Color3.fromRGB(63, 216, 255), effect = "×2 Gemas en los Raids" },
}
local FAILURE_MESSAGES: { [string]: string } = {
	NotEnoughGems = "No tienes suficientes Gemas",
	NotAtShop = "Acércate al tendero para comprar",
}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRemote = remotes:WaitForChild("BoostAction") :: RemoteFunction
local openRemote = remotes:WaitForChild("OpenBoostShop") :: RemoteEvent

local BoostShopController = {}

local window: Frame
local windowScale: UIScale

local function gems(): number
	return tonumber(player:GetAttribute("Gems")) or 0
end

local function buy(boostId: string)
	local ok, result = pcall(function()
		return actionRemote:InvokeServer("Buy", boostId)
	end)
	if not ok or type(result) ~= "table" then
		return
	end
	if result.ok then
		Notify.show(`Compraste un Boost de {Boosts.get(boostId).displayName}`, STYLES[boostId].color)
		SoundController.play("Purchase")
	elseif FAILURE_MESSAGES[result.reason] then
		Notify.error(FAILURE_MESSAGES[result.reason])
	end
end

-- One row per boost; returns its refresh function.
local function buildRow(boost: Boosts.Boost, index: number): () -> ()
	local style = STYLES[boost.id]
	local row = CheckUI.well({
		name = `Boost_{boost.id}`,
		size = UDim2.fromOffset(ROW_SIZE.X, ROW_SIZE.Y),
		position = UDim2.fromOffset(ROW_LEFT, ROW_TOP + (index - 1) * ROW_STEP),
		parent = window,
	})

	-- Icon on an aura of the boost's color, and an accent bar.
	local iconBox = CheckUI.box({
		name = "IconBox",
		size = UDim2.fromOffset(90, 90),
		position = UDim2.fromOffset(12, 10),
		radius = 12,
		zIndex = 11,
		parent = row,
	})
	CheckUI.gradient(iconBox, CheckUI.Colors.HeaderTop, CheckUI.Colors.Well)
	CheckUI.box({
		name = "Aura",
		size = UDim2.fromOffset(76, 76),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		color = style.color,
		transparency = 0.75,
		radius = 38,
		zIndex = 12,
		parent = iconBox,
	})
	local boostIcon = Icons.get(style.icon)
	CheckUI.icon(iconBox, {
		icon = boostIcon.icon,
		glyph = boostIcon.glyph,
		glyphColor = style.color,
		size = 60,
		position = UDim2.fromScale(0.5, 0.5),
		zIndex = 13,
	})
	CheckUI.box({
		name = "Accent",
		size = UDim2.fromOffset(3, 82),
		position = UDim2.fromOffset(110, 14),
		color = style.color,
		radius = 2,
		zIndex = 11,
		parent = row,
	})

	local function left(text: string, y: number, height: number, size: number, props: { [string]: any }?)
		local label = CheckUI.text({
			text = text,
			size = UDim2.fromOffset(300, height),
			position = UDim2.fromOffset(126, y + height / 2),
			anchor = Vector2.new(0, 0.5),
			textSize = size,
			color = props and props.color,
			stroke = props and props.stroke or 2.5,
			italic = props and props.italic,
			align = Enum.TextXAlignment.Left,
			zIndex = 12,
			parent = row,
		})
		return label
	end
	left(style.name, 12, 32, 24, { stroke = 3.5, italic = true })
	left(style.effect, 46, 20, 13, { color = CheckUI.Colors.Muted, stroke = 2 })
	left(`{boost.duration // 60} MIN`, 70, 22, 14)

	local gem = Icons.get("Gem")
	CheckUI.icon(row, {
		icon = gem.icon,
		glyph = gem.glyph,
		size = 30,
		position = UDim2.fromOffset(522, ROW_SIZE.Y / 2),
		zIndex = 12,
	})
	CheckUI.text({
		text = Format.number(boost.gemPrice),
		size = UDim2.fromOffset(110, 40),
		position = UDim2.fromOffset(504, ROW_SIZE.Y / 2),
		anchor = Vector2.new(1, 0.5),
		textSize = 24,
		color = CheckUI.Colors.Gold,
		stroke = 3.5,
		align = Enum.TextXAlignment.Right,
		zIndex = 12,
		parent = row,
	})
	local button = CheckUI.button({
		name = "Buy",
		size = Vector2.new(160, 50),
		position = UDim2.fromOffset(628, ROW_SIZE.Y / 2),
		text = "COMPRAR",
		textSize = 20,
		palette = CheckUI.Buttons.Gold,
		zIndex = 12,
		parent = row,
	})
	CheckUI.bind(button, function()
		buy(boost.id)
	end)

	return function()
		CheckUI.setPalette(button, if gems() >= boost.gemPrice then CheckUI.Buttons.Gold else CheckUI.Buttons.Red)
	end
end

-- Distance from the player to the nearest shop NPC.
local function shopDistance(): number
	local character = player.Character
	local root = character and character.PrimaryPart
	if root == nil then
		return math.huge
	end
	local best = math.huge
	for _, shop in CollectionService:GetTagged("BoostShop") do
		if shop:IsA("BasePart") then
			best = math.min(best, (shop.Position - root.Position).Magnitude)
		end
	end
	return best
end

function BoostShopController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BoostShop"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	window, windowScale = CheckUI.window("BoostShop", WINDOW_SIZE, gui)
	local _, close = CheckUI.header(window, "TIENDA", CheckUI.Accents.Gold)
	CheckUI.bind(close, function()
		CheckUI.closeWindow(window, windowScale)
	end)
	local _, gemsValue = CheckUI.counter({
		name = "Gems",
		icon = Icons.get("Gem").icon,
		glyph = Icons.get("Gem").glyph,
		glyphColor = Color3.fromRGB(63, 216, 255),
		size = Vector2.new(180, 42),
		position = UDim2.fromOffset(520, 14),
		zIndex = 12,
		parent = window,
	})

	local rows = {}
	for index, boost in Boosts.List do
		rows[index] = buildRow(boost, index)
	end
	local function refresh()
		gemsValue.Text = Format.number(gems())
		for _, refreshRow in rows do
			refreshRow()
		end
	end
	refresh()
	player:GetAttributeChangedSignal("Gems"):Connect(refresh)
	CheckUI.keepScaled(window, windowScale)

	openRemote.OnClientEvent:Connect(function()
		if not CheckUI.isOpen(window) then
			CheckUI.openWindow(window, windowScale)
		end
	end)
	-- Close when the player walks away from the shopkeeper.
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			if CheckUI.isOpen(window) and shopDistance() > CLOSE_DISTANCE then
				CheckUI.closeWindow(window, windowScale)
			end
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

return BoostShopController
