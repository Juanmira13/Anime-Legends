--!strict
-- The gacha. Every machine's golden star spins and bobs (locally). Next to a
-- machine, a panel in the official UI style opens at the bottom of the HUD with the island's
-- seven characters in 3D, their chances (with the Luck boost if active) and two
-- buttons: roll once and roll Balance.GachaMultiRoll times (also E and R, or X
-- and Y on a gamepad). The roll goes to the server through Remotes.GachaRoll;
-- its answer (Remotes.GachaResult) plays the full-screen reveal in
-- UI/GachaRevealView, or shows why it failed.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared.Config.Balance)
local Characters = require(Shared.Data.Characters)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Islands = require(Shared.Data.Islands)
local Rarities = require(Shared.Config.Rarities)

local UI = script.Parent.Parent.UI
local CharacterViewport = require(UI.CharacterViewport)
local CheckUI = require(UI.CheckUI)
local GachaRevealView = require(UI.GachaRevealView)
local Notify = require(UI.Notify)
local Theme = require(UI.Theme)

local STAND_TAG = "GachaStand"
local OPEN_DISTANCE = 14 -- studs (flat) from the star to open the panel...
local CLOSE_DISTANCE = 18 -- ...and to close it again
local CHECK_INTERVAL = 0.2 -- seconds between distance checks
local REQUEST_TIMEOUT = 5 -- seconds without an answer before the buttons work again
local SPIN_SPEED = 0.8 -- radians per second the stars turn
local REVEAL_SPIN_SPEED = 5 -- the star of the machine being rolled, during its reveal
local BOB_HEIGHT = 0.4 -- studs
local BOB_SPEED = 1.6 -- radians per second
local SPIN_DISTANCE = 300 -- studs from the camera to animate a star

local WINDOW_SIZE = Vector2.new(700, 334)
local CARD_SIZE = Vector2.new(88, 150)
local CARD_GAP = 8
local CARD_TOP = 78
local BUTTON_SIZE = Vector2.new(300, 64)
local BUTTON_Y = 280
local SECRET_STROKE = Color3.fromRGB(255, 200, 60)

local FAILURE_MESSAGES: { [string]: string } = {
	IslandLocked = "Esta isla está bloqueada",
	NotEnoughYen = "No tienes suficientes Yenes",
	TooFar = "Acércate a la estrella del gacha",
}

type Slot = { view: CharacterViewport.CharacterView, chance: TextLabel, rarityId: string }

local player = Players.LocalPlayer
local window: Frame
local windowScale: UIScale
local title: TextLabel
local luckBadge: Frame
local cardRow: Frame
local singleButton: ImageButton
local singleLabel: TextLabel
local singleCost: TextLabel
local multiButton: ImageButton
local multiLabel: TextLabel
local multiCost: TextLabel
local slots: { Slot } = {}

local nearStand: BasePart? = nil -- the machine whose panel is open (or would be)
local panelIsland: string? = nil -- island the cards were built for
local dismissed: BasePart? = nil -- closed with [X]; stays closed until the player walks away
local shown = false
local waiting = false
local requestToken = 0
local spinningStand: BasePart? = nil
local basePivots: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local GachaController = {}

local function placeWindow()
	local scale = CheckUI.deviceScale()
	window.Position = UDim2.new(0.5, 0, 1, -(WINDOW_SIZE.Y / 2 * scale + 16))
	if shown then
		windowScale.Scale = scale
	end
end

local function formatChance(percent: number): string
	return `{string.format("%g", math.round(percent * 100) / 100)}%`
end

local function luckActive(): boolean
	local time = player:GetAttribute("BoostTime_Luck")
	return type(time) == "number" and time > 0
end

-- Button colors and texts from the player's yen, the island lock and the Luck boost.
local function refresh()
	local islandId = panelIsland
	if islandId == nil then
		return
	end
	local locked = player:GetAttribute(`Unlocked_{islandId}`) ~= true
	local yen = player:GetAttribute("Yen")
	local money = if type(yen) == "number" then yen else 0
	local single, multi = Formulas.gachaCost(islandId), Formulas.gachaCost(islandId, Balance.GachaMultiRoll)

	singleLabel.Text = if locked then "BLOQUEADA" else "TIRAR x1"
	multiLabel.Text = if locked then "BLOQUEADA" else `TIRAR x{Balance.GachaMultiRoll}`
	singleCost.Text = `¥ {Format.number(single)}`
	multiCost.Text = `¥ {Format.number(multi)}`
	CheckUI.setPalette(
		singleButton,
		if locked then CheckUI.Buttons.Gray elseif money < single then CheckUI.Buttons.Red else CheckUI.Buttons.Purple
	)
	CheckUI.setPalette(
		multiButton,
		if locked then CheckUI.Buttons.Gray elseif money < multi then CheckUI.Buttons.Red else CheckUI.Buttons.Gold
	)

	local lucky = luckActive()
	luckBadge.Visible = lucky
	local chances = Formulas.gachaChances(lucky)
	for _, slot in slots do
		slot.chance.Text = formatChance(chances[slot.rarityId])
	end
end

local function buildSlot(characterId: string, index: number): Slot
	local character = Characters.get(characterId)
	local rarity = Rarities.get(character.rarity)
	local color = Theme.rarityColor(rarity.id)
	local isSecret = rarity.id == "Secret"

	local card = CheckUI.rarityCard({
		name = `Card_{character.id}`,
		size = CARD_SIZE,
		position = UDim2.fromOffset((index - 1) * (CARD_SIZE.X + CARD_GAP), 0),
		color = color,
		secret = isSecret,
		zIndex = 22,
		parent = cardRow,
	})

	local ribbon = CheckUI.text({
		text = string.upper(rarity.displayName),
		size = UDim2.fromOffset(CARD_SIZE.X - 8, 16),
		position = UDim2.fromOffset(CARD_SIZE.X / 2, 12),
		textSize = 13,
		color = if isSecret then Color3.new(1, 1, 1) else color:Lerp(Color3.new(1, 1, 1), 0.3),
		stroke = 2,
		zIndex = 24,
		parent = card,
	})
	ribbon.TextScaled = true

	local view = CharacterViewport.new(character.id, {
		size = UDim2.fromOffset(CARD_SIZE.X - 6, 78),
		position = UDim2.fromOffset(CARD_SIZE.X / 2, 62),
		zIndex = 24,
		parent = card,
	})

	local name = CheckUI.text({
		text = character.displayName,
		size = UDim2.fromOffset(CARD_SIZE.X - 8, 16),
		position = UDim2.fromOffset(CARD_SIZE.X / 2, 112),
		textSize = 13,
		stroke = 2,
		zIndex = 24,
		parent = card,
	})
	name.TextScaled = true

	local chance = CheckUI.text({
		text = "",
		size = UDim2.fromOffset(CARD_SIZE.X - 8, 22),
		position = UDim2.fromOffset(CARD_SIZE.X / 2, 134),
		textSize = 19,
		color = if isSecret then Color3.new(1, 1, 1) else color,
		stroke = 2.5,
		zIndex = 24,
		parent = card,
	})
	if isSecret then
		(chance:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = SECRET_STROKE
	end
	return { view = view, chance = chance, rarityId = rarity.id }
end

-- Fills the panel with an island's characters (once per island).
local function buildCards(islandId: string)
	if panelIsland == islandId then
		return
	end
	panelIsland = islandId
	for _, child in cardRow:GetChildren() do
		child:Destroy()
	end
	slots = {}
	for index, rarity in Rarities.List do
		slots[index] = buildSlot(Characters.forIslandAndRarity(islandId, rarity.id).id, index)
	end
	title.Text = `GACHA · {string.upper(Islands.get(islandId).displayName)}`
	refresh()
end

local function show()
	if shown then
		return
	end
	shown = true
	window.Visible = true
	windowScale.Scale = 0
	TweenService:Create(
		windowScale,
		TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = CheckUI.deviceScale() }
	):Play()
end

local function hide()
	if not shown then
		return
	end
	shown = false
	local tween = TweenService:Create(
		windowScale,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Scale = 0 }
	)
	tween.Completed:Connect(function()
		if not shown then
			window.Visible = false
		end
	end)
	tween:Play()
end

-- The machine nearest to the player, by flat distance, if within `range`.
local function nearestStand(range: number): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local best: BasePart? = nil
	local bestDistance = range
	for _, stand in CollectionService:GetTagged(STAND_TAG) do
		if stand:IsA("BasePart") then
			local offset = stand.Position - root.Position
			local distance = Vector2.new(offset.X, offset.Z).Magnitude
			if distance <= bestDistance then
				best, bestDistance = stand, distance
			end
		end
	end
	return best
end

local function updateProximity()
	local stand = nearestStand(if nearStand then CLOSE_DISTANCE else OPEN_DISTANCE)
	if stand ~= nearStand then
		nearStand = stand
		if stand == nil then
			dismissed = nil
		end
	end
	local islandId = stand and stand:GetAttribute("Island")
	if stand == nil or type(islandId) ~= "string" or dismissed == stand or GachaRevealView.isPlaying() then
		hide()
		return
	end
	buildCards(islandId)
	show()
end

local function request(count: number)
	if waiting or not shown or GachaRevealView.isPlaying() or panelIsland == nil then
		return
	end
	waiting = true
	requestToken += 1
	local token = requestToken
	task.delay(REQUEST_TIMEOUT, function()
		if requestToken == token then
			waiting = false
		end
	end)
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GachaRoll") :: RemoteEvent
	remote:FireServer(panelIsland, count)
end

local function reveal(results: { GachaRevealView.Result })
	spinningStand = nearStand
	hide()
	GachaRevealView.play(results)
	spinningStand = nil
	updateProximity()
end

local function onResult(result: any)
	requestToken += 1
	waiting = false
	if result.ok then
		task.spawn(reveal, result.results)
	elseif result.reason == "InventoryFull" then
		local count = result.count or 1
		Notify.error(if count > 1 then `Necesitas {count} espacios libres en el inventario` else "Inventario lleno")
	elseif FAILURE_MESSAGES[result.reason] then
		Notify.error(FAILURE_MESSAGES[result.reason])
	end
end

-- Spins and bobs every nearby star; the one being rolled spins fast.
local function animateStars()
	local camera = workspace.CurrentCamera
	if camera == nil then
		return
	end
	local now = os.clock()
	for _, stand in CollectionService:GetTagged(STAND_TAG) do
		local model = stand.Parent
		if not (model and model:IsA("Model") and model.Name == "GachaStar") then
			continue
		end
		local base: CFrame? = basePivots[model]
		if not base then
			base = model:GetPivot()
			basePivots[model] = base
		end
		assert(base, "unreachable")
		if (base.Position - camera.CFrame.Position).Magnitude > SPIN_DISTANCE then
			continue
		end
		local speed = if stand == spinningStand then REVEAL_SPIN_SPEED else SPIN_SPEED
		local yaw = (now * speed) % (2 * math.pi)
		model:PivotTo(base * CFrame.new(0, math.sin(now * BOB_SPEED) * BOB_HEIGHT, 0) * CFrame.Angles(0, yaw, 0))
	end
	if shown then
		for index, slot in slots do
			CharacterViewport.setYaw(slot.view, math.sin(now * 0.8 + index) * 0.6)
		end
	end
end

local function rollButton(name: string, x: number, palette: CheckUI.ButtonPalette, key: string, count: number)
	local button, label, cost = CheckUI.button({
		name = name,
		size = BUTTON_SIZE,
		position = UDim2.fromOffset(x, BUTTON_Y),
		text = "",
		textSize = 30,
		subText = "",
		palette = palette,
		parent = window,
	})
	local hint = CheckUI.text({
		text = key,
		size = UDim2.fromOffset(40, 22),
		position = UDim2.fromOffset(28, 16),
		textSize = 16,
		color = Color3.fromRGB(255, 255, 210),
		stroke = 2,
		zIndex = button.ZIndex + 4,
		parent = button,
	})
	hint.Visible = UserInputService.KeyboardEnabled
	CheckUI.bind(button, function()
		request(count)
	end)
	return button, label, cost :: TextLabel
end

local function buildPanel()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GachaPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 8
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	window, windowScale = CheckUI.window("Gacha", WINDOW_SIZE, gui)
	local header, close, titleLabel = CheckUI.header(window, "GACHA", CheckUI.Accents.Gold)
	title = titleLabel
	CheckUI.bind(close, function()
		dismissed = nearStand
		hide()
	end)

	-- "SUERTE x2" pill while the Luck boost is active.
	luckBadge = Instance.new("Frame")
	luckBadge.Name = "LuckBadge"
	luckBadge.Size = UDim2.fromOffset(150, 32)
	luckBadge.Position = UDim2.new(1, -150, 0.5, -2)
	luckBadge.AnchorPoint = Vector2.new(0.5, 0.5)
	luckBadge.BackgroundColor3 = Color3.new(1, 1, 1)
	luckBadge.ZIndex = header.ZIndex + 4
	luckBadge.Visible = false
	luckBadge.Parent = header
	CheckUI.corner(luckBadge, 16)
	CheckUI.stroke(luckBadge, Color3.new(0, 0, 0), 2.5, true)
	CheckUI.gradient(luckBadge, CheckUI.Buttons.Green.top, CheckUI.Buttons.Green.bottom)
	CheckUI.text({
		text = "SUERTE x2",
		size = UDim2.fromScale(1, 1),
		textSize = 20,
		stroke = 2.5,
		zIndex = luckBadge.ZIndex + 1,
		parent = luckBadge,
	})

	local rowWidth = #Rarities.List * CARD_SIZE.X + (#Rarities.List - 1) * CARD_GAP
	CheckUI.well({
		name = "CardWell",
		size = UDim2.fromOffset(rowWidth + 16, CARD_SIZE.Y + 20),
		position = UDim2.fromOffset((WINDOW_SIZE.X - rowWidth) / 2 - 8, CARD_TOP - 8),
		parent = window,
	})
	cardRow = Instance.new("Frame")
	cardRow.Name = "Cards"
	cardRow.Size = UDim2.fromOffset(rowWidth, CARD_SIZE.Y)
	cardRow.Position = UDim2.fromOffset((WINDOW_SIZE.X - rowWidth) / 2, CARD_TOP)
	cardRow.BackgroundTransparency = 1
	cardRow.ZIndex = 21
	cardRow.Parent = window

	singleButton, singleLabel, singleCost =
		rollButton("RollOnce", WINDOW_SIZE.X / 2 - 162, CheckUI.Buttons.Purple, "[E]", 1)
	multiButton, multiLabel, multiCost =
		rollButton("RollMany", WINDOW_SIZE.X / 2 + 162, CheckUI.Buttons.Gold, "[R]", Balance.GachaMultiRoll)

	CheckUI.onScaleChanged(function()
		placeWindow()
	end)
end

-- Plays a reveal of the given rarities without rolling (Studio testing from
-- Dev/RevealPreview; nothing is charged or added to the inventory).
function GachaController.preview(rarities: { string })
	if GachaRevealView.isPlaying() then
		return
	end
	local stand = nearestStand(math.huge)
	local standIsland = stand and stand:GetAttribute("Island")
	local islandId = panelIsland or (if type(standIsland) == "string" then standIsland else Islands.List[1].id)
	local results = {}
	for index, rarityId in rarities do
		results[index] = { characterId = Characters.forIslandAndRarity(islandId, rarityId).id, rarity = rarityId }
	end
	task.spawn(reveal, results)
end

function GachaController.start()
	buildPanel()

	for _, attribute in { "Yen", "BoostTime_Luck" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	player.AttributeChanged:Connect(function(name: string)
		if string.sub(name, 1, 9) == "Unlocked_" then
			refresh()
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
			request(1)
		elseif input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonY then
			request(Balance.GachaMultiRoll)
		end
	end)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= CHECK_INTERVAL then
			elapsed = 0
			updateProximity()
		end
	end)
	RunService.RenderStepped:Connect(animateStars)

	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GachaResult") :: RemoteEvent
	remote.OnClientEvent:Connect(onResult)
end

return GachaController
