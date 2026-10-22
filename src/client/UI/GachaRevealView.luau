--!strict
-- Full-screen gacha reveal over the HUD, in the Check-UI style. The screen
-- darkens, a golden star flies in and charges up (pulsing, wobbling, shaking
-- and climbing through the rarity colors up to the best roll), then bursts in
-- a white flash with a shockwave and confetti. One roll pops a big card with
-- the character spinning in 3D, its rarity ribbon, rarity stars and damage;
-- ten rolls lay ten face-down cards and flip them one by one, best last, with
-- a pause and a shockwave for each Legendary or better. Rare cards shine;
-- Mythic and Secret add a second layer of rays; Secret cycles the rainbow.
-- A click, tap, E, Space or A skips ahead. Each stage has its sound (whoosh,
-- a rising note per color, burst, flips, stars and a fanfare). Timing and
-- motion live in Effects/GachaReveal (pure, tested); this module only draws.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared.Data.Characters)
local Format = require(Shared.Format)
local Formulas = require(Shared.Formulas)
local Rarities = require(Shared.Config.Rarities)

local Client = script.Parent.Parent
local GachaReveal = require(Client.Effects.GachaReveal)
local SoundMix = require(Client.Effects.SoundMix)
local SoundController = require(Client.Controllers.SoundController)
local CharacterViewport = require(script.Parent.CharacterViewport)
local CheckUI = require(script.Parent.CheckUI)
local Theme = require(script.Parent.Theme)

export type Result = { characterId: string, rarity: string }

type Ring = { frame: Frame, scale: UIScale, stroke: UIStroke, born: number }

type Card = {
	root: Frame,
	scale: UIScale,
	front: Frame,
	back: Frame?,
	glow: ImageLabel,
	shine: UIGradient?,
	gradient: UIGradient,
	view: CharacterViewport.CharacterView,
	stars: { UIScale },
	rarityId: string,
	x: number,
	y: number,
	size: number, -- layout scale
	flipped: boolean,
}

local STAGE_SIZE = Vector2.new(1050, 620)
local CARD_W, CARD_H = GachaReveal.CARD_SIZE[1], GachaReveal.CARD_SIZE[2]
local SECRET_STROKE = Color3.fromRGB(255, 200, 60)
local GOLD = Color3.fromRGB(255, 220, 90)
local CARD_GLOW = 640 -- pixels of the rays behind a card, at its full size
local SKIP_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.E] = true,
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.Return] = true,
	[Enum.KeyCode.ButtonA] = true,
}

local player = Players.LocalPlayer
local screen: ScreenGui? = nil
local playing = false
local skipRequested = false

local GachaRevealView = {}

-- Display color of a rarity at a moment: Secret cycles the rainbow.
local function colorOf(rarityId: string, age: number): Color3
	if GachaReveal.style(rarityId).rainbow then
		return Color3.fromHSV(GachaReveal.rainbowHue(age), 0.7, 1)
	end
	return Theme.rarityColor(rarityId)
end

local function getScreen(): ScreenGui
	if screen then
		return screen
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "GachaReveal"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if playing and SKIP_KEYS[input.KeyCode] then
			skipRequested = true
		end
	end)
	screen = gui
	return gui
end

local function image(name: string, asset: string, size: number, zIndex: number, parent: Instance): ImageLabel
	local label = Instance.new("ImageLabel")
	label.Name = name
	label.Image = asset
	label.ScaleType = Enum.ScaleType.Fit
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(size, size)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.ZIndex = zIndex
	label.Parent = parent
	return label
end

local function ring(size: number, thickness: number, color: Color3, parent: Instance): Ring
	local frame = Instance.new("Frame")
	frame.Name = "Ring"
	frame.Size = UDim2.fromOffset(size, size)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 7
	frame.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local stroke = CheckUI.stroke(frame, color, thickness, true)
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = frame
	return { frame = frame, scale = scale, stroke = stroke, born = 0 }
end

-- A card at base size (300 x 420), everything in scale units so a flip
-- (squashing its width) squashes the whole card.
local function buildCard(result: Result, x: number, y: number, size: number, faceDown: boolean, parent: Instance): Card
	local character = Characters.get(result.characterId)
	local rarity = Rarities.get(result.rarity)
	local style = GachaReveal.style(rarity.id)
	local color = Theme.rarityColor(rarity.id)
	local isSecret = rarity.id == "Secret"

	local root = Instance.new("Frame")
	root.Name = `Card_{character.id}`
	root.Size = UDim2.fromOffset(CARD_W, CARD_H)
	root.Position = UDim2.new(0.5, x, 0.5, y)
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BackgroundTransparency = 1
	root.ZIndex = 5
	root.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = root

	-- Rays behind the card, in its rarity color: on the stage under every card,
	-- so they never cover a neighbor.
	local glow = image("CardGlow", CheckUI.Assets.Sunburst, 0, 4, parent)
	glow.Position = root.Position
	glow.ImageColor3 = color
	glow.ImageTransparency = 1

	local front = Instance.new("Frame")
	front.Name = "Front"
	front.Size = UDim2.fromScale(1, 1)
	front.BackgroundColor3 = Color3.new(1, 1, 1)
	front.ZIndex = 2
	front.Visible = not faceDown
	front.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = front
	CheckUI.stroke(front, Color3.new(0, 0, 0), 4, true)
	local gradient: UIGradient
	if isSecret then
		gradient = CheckUI.gradient(front, Color3.new(), Color3.new(), 45)
		gradient.Color = CheckUI.sequence(CheckUI.Rainbow)
	else
		gradient = CheckUI.gradient(front, color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.45))
	end
	CheckUI.damier(front, Color3.new(0, 0, 0), 26, 0.93, 0.7)

	local shine: UIGradient? = nil
	if style.shine then
		local sweep = Instance.new("Frame")
		sweep.Name = "Shine"
		sweep.Size = UDim2.fromScale(1, 1)
		sweep.BackgroundColor3 = Color3.new(1, 1, 1)
		sweep.ZIndex = 3
		sweep.Parent = front
		local sweepCorner = corner:Clone()
		sweepCorner.Parent = sweep
		local band = Instance.new("UIGradient")
		band.Rotation = 20
		band.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.42, 1),
			NumberSequenceKeypoint.new(0.5, 0.45),
			NumberSequenceKeypoint.new(0.58, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		band.Parent = sweep
		shine = band
	end
	for index, transparency in { 0.4, 0.75 } do
		local inner = Instance.new("Frame")
		inner.Size = UDim2.new(1, -index * 8, 1, -index * 8)
		inner.Position = UDim2.fromScale(0.5, 0.5)
		inner.AnchorPoint = Vector2.new(0.5, 0.5)
		inner.BackgroundTransparency = 1
		inner.ZIndex = 4
		inner.Parent = front
		local innerCorner = Instance.new("UICorner")
		innerCorner.CornerRadius = UDim.new(0, 8)
		innerCorner.Parent = inner
		CheckUI.stroke(inner, Color3.new(1, 1, 1), 1.5, true).Transparency = transparency
	end

	-- Rarity ribbon.
	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.Size = UDim2.fromScale(0.86, 44 / CARD_H)
	ribbon.Position = UDim2.fromScale(0.5, 38 / CARD_H)
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.BackgroundColor3 = Color3.new(0, 0, 0)
	ribbon.BackgroundTransparency = 0.35
	ribbon.ZIndex = 5
	ribbon.Parent = front
	local ribbonCorner = Instance.new("UICorner")
	ribbonCorner.CornerRadius = UDim.new(0, 6)
	ribbonCorner.Parent = ribbon
	local ribbonText = CheckUI.text({
		text = string.upper(rarity.displayName),
		size = UDim2.fromScale(0.94, 0.8),
		textSize = 28,
		color = if isSecret then Color3.new(1, 1, 1) else color:Lerp(Color3.new(1, 1, 1), 0.25),
		stroke = 3,
		zIndex = 6,
		parent = ribbon,
	})
	ribbonText.TextScaled = true
	if isSecret then
		(ribbonText:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = SECRET_STROKE
	end

	local view = CharacterViewport.new(character.id, {
		size = UDim2.fromScale(0.9, 230 / CARD_H),
		position = UDim2.fromScale(0.5, 180 / CARD_H),
		zIndex = 5,
		parent = front,
	})

	local name = CheckUI.text({
		text = character.displayName,
		size = UDim2.fromScale(0.92, 40 / CARD_H),
		position = UDim2.fromScale(0.5, 318 / CARD_H),
		textSize = 34,
		stroke = 3,
		zIndex = 6,
		parent = front,
	})
	name.TextScaled = true

	local stars: { UIScale } = {}
	for index = 1, rarity.order do
		local star = image(`Star{index}`, CheckUI.Assets.Star, 30, 6, front)
		star.Size = UDim2.fromScale(30 / CARD_W, 30 / CARD_H)
		star.Position = UDim2.fromScale(0.5 + (index - (rarity.order + 1) / 2) * 32 / CARD_W, 362 / CARD_H)
		local starScale = Instance.new("UIScale")
		starScale.Scale = if faceDown then 1 else 0
		starScale.Parent = star
		stars[index] = starScale
	end

	local damage = CheckUI.text({
		text = `DAÑO {Format.number(Formulas.characterDamage(character.id))}`,
		size = UDim2.fromScale(0.9, 26 / CARD_H),
		position = UDim2.fromScale(0.5, 396 / CARD_H),
		textSize = 22,
		color = GOLD,
		stroke = 2.5,
		zIndex = 6,
		parent = front,
	})
	damage.TextScaled = true

	local back: Frame? = nil
	if faceDown then
		local cover = Instance.new("Frame")
		cover.Name = "Back"
		cover.Size = UDim2.fromScale(1, 1)
		cover.BackgroundColor3 = CheckUI.Colors.Card
		cover.ZIndex = 2
		cover.Parent = root
		corner:Clone().Parent = cover
		CheckUI.stroke(cover, Color3.new(0, 0, 0), 4, true)
		CheckUI.damier(cover, CheckUI.Colors.CardHighlight, 26, 0.85, 0.55)
		local icon = image("Star", CheckUI.Assets.Star, 150, 4, cover)
		icon.Size = UDim2.fromScale(150 / CARD_W, 150 / CARD_H)
		local mark = CheckUI.text({
			text = "?",
			size = UDim2.fromScale(1, 0.3),
			textSize = 96,
			stroke = 4,
			zIndex = 5,
			parent = cover,
		})
		mark.TextScaled = true
		back = cover
	end

	return {
		root = root,
		scale = scale,
		front = front,
		back = back,
		glow = glow,
		shine = shine,
		gradient = gradient,
		view = view,
		stars = stars,
		rarityId = rarity.id,
		x = x,
		y = y,
		size = size,
		flipped = not faceDown,
	}
end

function GachaRevealView.isPlaying(): boolean
	return playing
end

-- Plays the reveal of `results` (one or more rolls) and returns when it closes.
function GachaRevealView.play(results: { Result })
	if #results == 0 then
		return
	end
	local gui = getScreen()
	playing = true
	skipRequested = false

	local rarities = {}
	for index, result in results do
		rarities[index] = result.rarity
	end
	local best = GachaReveal.best(rarities)
	local style = GachaReveal.style(best)
	local multi = #results > 1
	local schedule = GachaReveal.schedule(rarities)

	local root = Instance.new("Frame")
	root.Name = "Reveal"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = gui

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(8, 12, 20)
	backdrop.BackgroundTransparency = 1
	backdrop.ZIndex = 1
	backdrop.Parent = root

	-- Catches every click and tap (also keeps them off the world behind).
	local catcher = Instance.new("TextButton")
	catcher.Name = "Catcher"
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.BackgroundTransparency = 1
	catcher.Text = ""
	catcher.AutoButtonColor = false
	catcher.ZIndex = 2
	catcher.Parent = root
	catcher.Activated:Connect(function()
		skipRequested = true
	end)

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.Size = UDim2.fromOffset(STAGE_SIZE.X, STAGE_SIZE.Y)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.BackgroundTransparency = 1
	stage.ZIndex = 3
	stage.Parent = root
	local stageScale = Instance.new("UIScale")
	stageScale.Parent = stage
	local deviceScale = CheckUI.deviceScale()
	stageScale.Scale = deviceScale

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.ZIndex = 10
	flash.Parent = root

	local raysBack = image("RaysBack", CheckUI.Assets.Sunburst, 1150, 1, stage)
	raysBack.ImageTransparency = 1
	local raysFront = image("RaysFront", CheckUI.Assets.Sunburst, 820, 2, stage)
	raysFront.ImageTransparency = 1
	local glow = image("Glow", CheckUI.Assets.Sunburst, 430, 3, stage)
	glow.ImageTransparency = 1
	local star = image("Star", CheckUI.Assets.Star, 210, 6, stage)
	local starScale = Instance.new("UIScale")
	starScale.Scale = 0
	starScale.Parent = star
	local shockwave = ring(360, 12, Color3.new(1, 1, 1), stage)
	local ticks: { Ring } = {}

	local confetti: { Frame } = {}
	for index = 1, style.confetti do
		local piece = Instance.new("Frame")
		piece.Name = "Confetti"
		piece.Size = UDim2.fromOffset(if index % 3 == 0 then 10 else 16, if index % 3 == 0 then 22 else 16)
		piece.Position = UDim2.fromScale(0.5, 0.5)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.BorderSizePixel = 0
		piece.ZIndex = 8
		piece.Visible = false
		piece.Parent = stage
		confetti[index] = piece
	end

	local cards: { Card } = {}
	for slot, index in schedule.order do
		local x, y, size = GachaReveal.layout(slot, #results)
		cards[slot] = buildCard(results[index], x, y, size, multi, stage)
	end

	local title: TextLabel? = nil
	if multi then
		title = CheckUI.text({
			text = `¡TIRADA x{#results}!`,
			size = UDim2.fromOffset(600, 50),
			position = UDim2.new(0.5, 0, 0.5, -272),
			textSize = 44,
			color = GOLD,
			stroke = 3.5,
			zIndex = 9,
			parent = stage,
		});
		(title :: TextLabel).TextTransparency = 1
	end
	local hint = CheckUI.text({
		text = "TOCA PARA SALTAR",
		size = UDim2.fromOffset(600, 30),
		position = UDim2.new(0.5, 0, 0.5, 282),
		textSize = 24,
		stroke = 2.5,
		zIndex = 9,
		parent = stage,
	})

	gui.Enabled = true
	SoundController.play("GachaWhoosh")

	local burstAt = GachaReveal.INTRO + style.charge
	local revealAt = burstAt + GachaReveal.REVEAL_DELAY
	local revealLength = if multi then schedule.finish else GachaReveal.singleRevealTime(best)
	local holdAt = revealAt + revealLength
	local closeAt = holdAt + GachaReveal.holdTime(rarities)
	local outroAt: number? = nil
	local age = 0
	local clock = 0 -- real time, for spins and colors that should not jump on a skip
	local lastClimb = 0
	local kick = 0 -- extra shake from rare cards flipping, decays
	local burstSounded = false
	local revealSounded = false
	local starsSounded = 0

	local function addTick(color: Color3, x: number, y: number, size: number)
		local tick = ring(size, 8, color, stage)
		tick.frame.Position = UDim2.new(0.5, x, 0.5, y)
		tick.born = clock
		table.insert(ticks, tick)
	end

	while true do
		local dt = RunService.RenderStepped:Wait()
		age += dt
		clock += dt
		if skipRequested and GachaReveal.canSkip(clock) then
			if age < burstAt then
				age = burstAt
			elseif age < holdAt then
				age = holdAt
			elseif outroAt == nil then
				outroAt = age
			end
		end
		skipRequested = false
		if outroAt == nil and age >= closeAt then
			outroAt = age
		end

		-- Before the burst: the star flies in and charges up.
		local shake = 0
		local climbColor = colorOf(best, clock)
		if age < burstAt then
			local chargeAge = math.max(age - GachaReveal.INTRO, 0)
			local climb = GachaReveal.climbAt(best, chargeAge)
			local climbId = Rarities.List[climb].id
			climbColor = colorOf(climbId, clock)
			if age < GachaReveal.INTRO then
				local backdropTransparency, scale, drop = GachaReveal.introAt(age)
				backdrop.BackgroundTransparency = backdropTransparency
				starScale.Scale = scale
				star.Position = UDim2.new(0.5, 0, 0.5, drop)
				star.Rotation = 0
				raysBack.ImageTransparency = 1 - 0.45 * (1 - backdropTransparency)
				glow.ImageTransparency = 1 - (1 - backdropTransparency) * 0.8
			else
				local scale, wobble, amplitude = GachaReveal.chargeAt(best, chargeAge)
				backdrop.BackgroundTransparency = 0.25
				starScale.Scale = scale
				star.Position = UDim2.fromScale(0.5, 0.5)
				star.Rotation = wobble
				shake = amplitude
				raysBack.ImageTransparency = 0.55
				glow.ImageTransparency = 0.15 + 0.15 * math.sin(clock * 12)
				glow.Size = UDim2.fromOffset(430 * scale, 430 * scale)
				if climb > lastClimb then
					SoundController.play("GachaClimb", { pitch = SoundMix.stepPitch(climb) })
					if lastClimb > 0 then
						addTick(climbColor, 0, 0, 260)
					end
					lastClimb = climb
				end
			end
			star.ImageTransparency = 0
			flash.BackgroundTransparency = 1
		else
			-- The burst.
			local t = age - burstAt
			if not burstSounded then
				burstSounded = true
				SoundController.play("GachaBurst")
			end
			local flashTransparency, ringScale, ringTransparency, burstScale, starTransparency =
				GachaReveal.burstAt(best, t)
			backdrop.BackgroundTransparency = 0.25
			flash.BackgroundTransparency = flashTransparency
			shockwave.scale.Scale = if t < GachaReveal.BURST then ringScale else 0
			shockwave.stroke.Color = climbColor
			shockwave.stroke.Transparency = ringTransparency
			starScale.Scale = if starTransparency < 1 then burstScale else 0
			star.ImageTransparency = starTransparency
			star.Rotation = 0
			glow.ImageTransparency = 1
			shake = style.shake * math.max(1 - t / GachaReveal.BURST, 0)
			for index, piece in confetti do
				local x, y, rotation, transparency = GachaReveal.confettiAt(index, #confetti, t)
				piece.Visible = transparency < 1
				piece.Position = UDim2.new(0.5, x, 0.5, y)
				piece.Rotation = rotation
				piece.BackgroundTransparency = transparency
				piece.BackgroundColor3 = if index % 3 == 1
					then climbColor
					elseif index % 3 == 2 then Color3.new(1, 1, 1)
					else GOLD
			end
			-- Rays behind the cards.
			raysBack.ImageTransparency = if multi then 0.6 else 0.3
			raysFront.ImageTransparency = if style.rays >= 2 and not multi then 0.4 else 1
		end
		raysBack.ImageColor3 = climbColor
		raysFront.ImageColor3 = climbColor:Lerp(Color3.new(1, 1, 1), 0.3)
		glow.ImageColor3 = climbColor
		raysBack.Rotation = (clock * 20) % 360
		raysFront.Rotation = (-clock * 13) % 360

		-- Cards.
		if age >= revealAt then
			local t = age - revealAt
			if not multi and not revealSounded then
				revealSounded = true
				local rare = GachaReveal.style(best).order >= GachaReveal.RARE_ORDER
				SoundController.play(if rare then "RevealRare" else "Reveal")
			end
			for slot, card in cards do
				local isRare = GachaReveal.style(card.rarityId).order >= GachaReveal.RARE_ORDER
				if multi then
					card.scale.Scale = GachaReveal.popAt(t - GachaReveal.BACK_GAP * (slot - 1)) * card.size
					local width, front = GachaReveal.flipAt(t - schedule.starts[slot])
					card.root.Size = UDim2.fromOffset(CARD_W * width, CARD_H)
					card.front.Visible = front
					if card.back then
						card.back.Visible = not front
					end
					if front and not card.flipped then
						card.flipped = true
						SoundController.play("CardFlip")
						if isRare then
							SoundController.play("RevealRare")
							addTick(colorOf(card.rarityId, clock), card.x, card.y, 220)
							kick = math.max(kick, GachaReveal.style(card.rarityId).shake)
						end
					end
				else
					card.scale.Scale = GachaReveal.popAt(t)
					for index, starPop in card.stars do
						starPop.Scale = GachaReveal.starPopAt(index, t)
						if starPop.Scale > 0 and index > starsSounded then
							starsSounded = index
							SoundController.play("StarPop", { pitch = SoundMix.stepPitch(index) })
						end
					end
				end
				if card.front.Visible then
					CharacterViewport.setYaw(card.view, clock * 1.4 + slot)
					if card.shine then
						card.shine.Offset = Vector2.new(GachaReveal.shineAt(clock + slot * 0.2), 0)
					end
					if GachaReveal.style(card.rarityId).rainbow then
						card.gradient.Rotation = (clock * 90) % 360
					end
					local showGlow = GachaReveal.style(card.rarityId).order >= 4
					card.glow.ImageTransparency = if showGlow then 0.2 else 1
					card.glow.ImageColor3 = colorOf(card.rarityId, clock)
					card.glow.Rotation = (clock * 30 + slot * 20) % 360
					local glowSize = CARD_GLOW * card.scale.Scale
					card.glow.Size = UDim2.fromOffset(glowSize, glowSize)
				end
			end
			if title then
				title.TextTransparency = math.max(1 - t * 4, 0)
			end
		end

		-- Climb and flip rings.
		for index = #ticks, 1, -1 do
			local tick = ticks[index]
			local scale, transparency = GachaReveal.tickAt(clock - tick.born)
			if transparency >= 1 then
				tick.frame:Destroy()
				table.remove(ticks, index)
			else
				tick.scale.Scale = scale
				tick.stroke.Transparency = transparency
			end
		end

		-- Screen shake (charge, burst and rare flips).
		kick = math.max(kick - dt * 30, 0)
		local x, y = GachaReveal.shakeOffset(shake + kick, clock)
		stage.Position = UDim2.new(0.5, x * deviceScale, 0.5, y * deviceScale)

		-- Hint.
		if age < burstAt then
			hint.Text = "TOCA PARA SALTAR"
		elseif age >= holdAt then
			hint.Text = "TOCA PARA CONTINUAR"
		else
			hint.Text = ""
		end
		hint.TextTransparency = 0.15 + 0.35 * math.abs(math.sin(clock * 3))

		-- Outro: everything shrinks away and the screen clears.
		if outroAt then
			local p = math.clamp((age - outroAt) / GachaReveal.OUTRO, 0, 1)
			stageScale.Scale = deviceScale * (1 - p * p)
			backdrop.BackgroundTransparency = 0.25 + 0.75 * p
			if p >= 1 then
				break
			end
		else
			deviceScale = CheckUI.deviceScale()
			stageScale.Scale = deviceScale
		end
	end

	root:Destroy()
	gui.Enabled = false
	playing = false
end

return GachaRevealView
