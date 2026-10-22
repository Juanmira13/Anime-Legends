--!strict
-- The official UI style: Check-UI (skill check-ui-clean-roblox) with the purple
-- palette and depth approved in Figma (docs/game-design.md, Interfaz). About
-- 60% dark and light purple, black and gray; color only for accents. Every
-- piece is stacked in layers Roblox can draw without blur: a hard drop shadow,
-- a darker base peeking out below as a bevel, a gradient face, a white gloss
-- on top and a light inner edge. GothamBlack text with a black outline,
-- center-anchored interactions with UIScale, and scaling from the 1050 x 620
-- base viewport. Rotated pieces (header stripes, the slanted title tab) live
-- in CanvasGroups, because ClipsDescendants does not clip rotated frames.

local TweenService = game:GetService("TweenService")

local CharacterViewport = require(script.Parent.CharacterViewport)
local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local CheckUI = {}

CheckUI.Assets = {
	Checkerboard = "rbxassetid://385956923",
	Sunburst = "rbxassetid://130563114903838",
	Star = "rbxassetid://93302981101722", -- CheckUIIcons Main/Star Golden_Star_1st
	Coin = "rbxassetid://96866635707429", -- CheckUIIcons Currency/Coin Golden_Coin_1st
}

local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

CheckUI.Colors = {
	RimTop = Color3.fromRGB(160, 105, 245),
	RimBottom = Color3.fromRGB(84, 40, 150),
	RimBevel = Color3.fromRGB(40, 14, 82),
	RimHighlight = Color3.fromRGB(235, 210, 255),
	BodyTop = Color3.fromRGB(48, 29, 82),
	BodyBottom = Color3.fromRGB(22, 13, 40),
	BodyGlow = Color3.fromRGB(150, 95, 240),
	HeaderTop = Color3.fromRGB(38, 21, 64),
	HeaderBottom = Color3.fromRGB(12, 7, 20),
	TabTop = Color3.fromRGB(46, 26, 80),
	TabBottom = Color3.fromRGB(10, 6, 18),
	Well = Color3.fromRGB(16, 9, 28),
	WellEdge = Color3.fromRGB(125, 85, 200),
	CardInner = Color3.fromRGB(26, 16, 42),
	Lavender = Color3.fromRGB(190, 140, 255),
	Gold = Color3.fromRGB(255, 194, 26),
	Muted = Color3.fromRGB(190, 172, 222),
	Outline = BLACK,
	Text = WHITE,
}

-- Header stripe and divider colors: Purple by default (inventory, settings),
-- Gold for shops, Red for warnings.
CheckUI.Accents = {
	Purple = Color3.fromRGB(185, 125, 255),
	Gold = Color3.fromRGB(255, 190, 20),
	Red = Color3.fromRGB(255, 70, 100),
}

export type ButtonPalette = { top: Color3, bottom: Color3, bevel: Color3, highlight: Color3 }

-- Purple is the main action; Green confirms, Red is destructive, Gold buys
-- and Gray is locked or disabled.
CheckUI.Buttons = {
	Purple = {
		top = Color3.fromRGB(185, 120, 255),
		bottom = Color3.fromRGB(118, 44, 226),
		bevel = Color3.fromRGB(56, 14, 118),
		highlight = Color3.fromRGB(230, 205, 255),
	},
	Green = {
		top = Color3.fromRGB(170, 250, 40),
		bottom = Color3.fromRGB(90, 200, 0),
		bevel = Color3.fromRGB(20, 100, 10),
		highlight = Color3.fromRGB(225, 255, 150),
	},
	Red = {
		top = Color3.fromRGB(255, 80, 105),
		bottom = Color3.fromRGB(205, 0, 45),
		bevel = Color3.fromRGB(100, 0, 20),
		highlight = Color3.fromRGB(255, 185, 205),
	},
	Gold = {
		top = Color3.fromRGB(255, 218, 60),
		bottom = Color3.fromRGB(255, 150, 0),
		bevel = Color3.fromRGB(140, 70, 0),
		highlight = Color3.fromRGB(255, 242, 170),
	},
	Gray = {
		top = Color3.fromRGB(112, 104, 134),
		bottom = Color3.fromRGB(70, 63, 90),
		bevel = Color3.fromRGB(36, 31, 50),
		highlight = Color3.fromRGB(196, 188, 216),
	},
} :: { [string]: ButtonPalette }

local BASE_VIEWPORT = Vector2.new(1050, 620)
local MIN_SCALE, MAX_SCALE = 0.52, 1.18

local WINDOW_RADIUS = 22
local RIM = 9 -- px of purple rim around the window body
local RIM_BEVEL = 8 -- px of dark rim base showing at the bottom
local HEADER_HEIGHT = 52
local TAB_SIZE = Vector2.new(300, 60)
local TAB_SLANT = 28 -- px the tab's right edge leans over its height
local TAB_RISE = 22 -- px the tab sticks out above the window

-- Scale for the current screen: 1 at 1050 x 620, clamped for phones and big monitors.
function CheckUI.deviceScale(): number
	local camera = workspace.CurrentCamera
	if camera == nil then
		return 1
	end
	local viewport = camera.ViewportSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return 1
	end
	return math.clamp(math.min(viewport.X / BASE_VIEWPORT.X, viewport.Y / BASE_VIEWPORT.Y), MIN_SCALE, MAX_SCALE)
end

-- Calls `apply(scale)` now and whenever the screen size changes.
function CheckUI.onScaleChanged(apply: (number) -> ())
	apply(CheckUI.deviceScale())
	local function watch(camera: Camera)
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			apply(CheckUI.deviceScale())
		end)
	end
	if workspace.CurrentCamera then
		watch(workspace.CurrentCamera)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if workspace.CurrentCamera then
			watch(workspace.CurrentCamera)
			apply(CheckUI.deviceScale())
		end
	end)
end

function CheckUI.gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

-- Evenly spaced color sequence through `colors`.
function CheckUI.sequence(colors: { Color3 }): ColorSequence
	local keypoints = {}
	for index, color in colors do
		keypoints[index] = ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color)
	end
	return ColorSequence.new(keypoints)
end

function CheckUI.stroke(parent: Instance, color: Color3, thickness: number, border: boolean?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	if border then
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	stroke.Parent = parent
	return stroke
end

function CheckUI.corner(parent: Instance, radius: number): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

-- Plain frame: the building block of every layer.
function CheckUI.box(props: {
	name: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	transparency: number?,
	radius: number?,
	zIndex: number?,
	parent: Instance,
}): Frame
	local frame = Instance.new("Frame")
	frame.Name = props.name
	frame.Size = props.size
	frame.Position = props.position or UDim2.new()
	frame.AnchorPoint = props.anchor or Vector2.zero
	frame.BackgroundColor3 = props.color or WHITE
	frame.BackgroundTransparency = props.transparency or 0
	frame.BorderSizePixel = 0
	frame.ZIndex = props.zIndex or 1
	frame.Parent = props.parent
	if props.radius then
		CheckUI.corner(frame, props.radius)
	end
	return frame
end

-- Hard drop shadow: a translucent black copy of the parent's shape, pushed down.
function CheckUI.shadow(parent: Instance, radius: number, offset: number, transparency: number?): Frame
	return CheckUI.box({
		name = "Shadow",
		size = UDim2.fromScale(1, 1),
		position = UDim2.fromOffset(0, offset),
		color = BLACK,
		transparency = transparency or 0.5,
		radius = radius,
		parent = parent,
	})
end

-- A transparent frame whose border stroke draws an inner edge highlight.
local function edge(
	parent: Instance,
	inset: number,
	radius: number,
	color: Color3,
	transparency: number,
	zIndex: number
)
	local frame = CheckUI.box({
		name = "Edge",
		size = UDim2.new(1, -inset * 2, 1, -inset * 2),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		transparency = 1,
		radius = radius,
		zIndex = zIndex,
		parent = parent,
	})
	CheckUI.stroke(frame, color, 1.4, true).Transparency = transparency
	return frame
end

-- White gloss over the top part of a face, fading downwards.
local function gloss(parent: Instance, height: number, radius: number, strength: number, zIndex: number): Frame
	local frame = CheckUI.box({
		name = "Gloss",
		size = UDim2.new(1, -10, height, 0),
		position = UDim2.new(0.5, 0, 0, 3),
		anchor = Vector2.new(0.5, 0),
		radius = radius,
		zIndex = zIndex,
		parent = parent,
	})
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(1 - strength, 0.94)
	fade.Parent = frame
	return frame
end

-- Checkerboard overlay with a vertical transparency fade (`from` at the top, `to` at the bottom).
function CheckUI.damier(
	parent: GuiObject,
	color: Color3,
	tile: number,
	from: number,
	to: number,
	radius: number?
): ImageLabel
	local damier = Instance.new("ImageLabel")
	damier.Name = "Checkerboard"
	damier.Size = UDim2.fromScale(1, 1)
	damier.BackgroundTransparency = 1
	damier.Image = CheckUI.Assets.Checkerboard
	damier.ScaleType = Enum.ScaleType.Tile
	damier.TileSize = UDim2.fromOffset(tile, tile)
	damier.ImageColor3 = color
	damier.ZIndex = parent.ZIndex + 1
	damier.Parent = parent
	if radius then
		CheckUI.corner(damier, radius)
	end
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(from, to)
	fade.Parent = damier
	return damier
end

-- Diagonal stripes in `color`, fading in from the left (a CanvasGroup clips them).
function CheckUI.stripes(parent: Instance, size: Vector2, color: Color3, zIndex: number): CanvasGroup
	local group = Instance.new("CanvasGroup")
	group.Name = "Stripes"
	group.Size = UDim2.fromOffset(size.X, size.Y)
	group.BackgroundTransparency = 1
	group.ZIndex = zIndex
	group.Parent = parent
	local step, width = 24, 12
	for index = 0, math.ceil((size.X + size.Y) / step) do
		CheckUI.box({
			name = "Stripe",
			size = UDim2.fromOffset(width, size.Y * 2),
			position = UDim2.fromOffset(index * step, size.Y / 2),
			anchor = Vector2.new(0.5, 0.5),
			color = color,
			parent = group,
		}).Rotation =
			25
	end
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	fade.Parent = group
	return group
end

-- GothamBlack text with the black outline, sized in pixels.
function CheckUI.text(props: {
	text: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	textSize: number,
	color: Color3?,
	stroke: number?,
	align: Enum.TextXAlignment?,
	italic: boolean?,
	zIndex: number?,
	parent: Instance,
}): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
	if props.italic then
		label.FontFace = Font.new(label.FontFace.Family, Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	end
	label.Text = props.text
	label.TextSize = props.textSize
	label.TextColor3 = props.color or CheckUI.Colors.Text
	label.Size = props.size
	label.Position = props.position or UDim2.fromScale(0.5, 0.5)
	label.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)
	label.TextXAlignment = props.align or Enum.TextXAlignment.Center
	label.ZIndex = props.zIndex or 1
	label.Parent = props.parent
	CheckUI.stroke(label, BLACK, props.stroke or 2.5)
	return label
end

-- Window: hard shadow, thick purple rim with a bevel, and the dark purple
-- body. Centered and hidden, with its "WindowScale". Content goes in the
-- window itself (ZIndex 10 and up); the body starts RIM px inside.
function CheckUI.window(name: string, size: Vector2, parent: Instance, zIndex: number?): (Frame, UIScale)
	local colors = CheckUI.Colors
	local window = CheckUI.box({
		name = name,
		size = UDim2.fromOffset(size.X, size.Y),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		transparency = 1,
		zIndex = zIndex or 20,
		parent = parent,
	})
	window.Visible = false
	CheckUI.shadow(window, WINDOW_RADIUS, 12, 0.45)

	local rim = CheckUI.box({
		name = "Rim",
		size = UDim2.fromScale(1, 1),
		color = colors.RimBevel,
		radius = WINDOW_RADIUS,
		zIndex = 2,
		parent = window,
	})
	CheckUI.stroke(rim, BLACK, 4, true)
	local rimFace = CheckUI.box({
		name = "RimFace",
		size = UDim2.new(1, 0, 1, -RIM_BEVEL),
		radius = WINDOW_RADIUS,
		zIndex = 2,
		parent = rim,
	})
	CheckUI.gradient(rimFace, colors.RimTop, colors.RimBottom)
	edge(rimFace, 2, WINDOW_RADIUS - 2, colors.RimHighlight, 0.3, 3)

	local body = CheckUI.box({
		name = "Body",
		size = UDim2.new(1, -RIM * 2, 1, -RIM * 2 - RIM_BEVEL),
		position = UDim2.fromOffset(RIM, RIM),
		radius = WINDOW_RADIUS - 7,
		zIndex = 3,
		parent = window,
	})
	CheckUI.gradient(body, colors.BodyTop, colors.BodyBottom)
	CheckUI.stroke(body, BLACK, 3, true)
	local glow = CheckUI.box({
		name = "Glow",
		size = UDim2.new(1, 0, 0, 120),
		position = UDim2.fromOffset(0, HEADER_HEIGHT),
		color = colors.BodyGlow,
		zIndex = 3,
		parent = body,
	})
	local glowFade = Instance.new("UIGradient")
	glowFade.Rotation = 90
	glowFade.Transparency = NumberSequence.new(0.84, 1)
	glowFade.Parent = glow

	local scale = Instance.new("UIScale")
	scale.Name = "WindowScale"
	scale.Parent = window
	return window, scale
end

-- Round purple [X] with a bevel, gloss and shadow (46 x 46), centered on `position`.
function CheckUI.closeButton(parent: GuiObject, position: UDim2, zIndex: number?): ImageButton
	local z = zIndex or 30
	local button = Instance.new("ImageButton")
	button.Name = "CloseButton"
	button.Size = UDim2.fromOffset(46, 46)
	button.Position = position
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.ZIndex = z
	button.Parent = parent
	CheckUI.shadow(button, 23, 5)
	local base = CheckUI.box({
		name = "Bevel",
		size = UDim2.fromScale(1, 1),
		color = Color3.fromRGB(48, 12, 96),
		radius = 23,
		zIndex = 2,
		parent = button,
	})
	CheckUI.stroke(base, BLACK, 3, true)
	local face = CheckUI.box({
		name = "Face",
		size = UDim2.new(1, 0, 1, -5),
		radius = 23,
		zIndex = 3,
		parent = base,
	})
	CheckUI.gradient(face, Color3.fromRGB(205, 150, 255), Color3.fromRGB(122, 48, 232))
	edge(face, 2, 20, Color3.fromRGB(235, 215, 255), 0.15, 4)
	CheckUI.box({
		name = "Gloss",
		size = UDim2.fromOffset(28, 12),
		position = UDim2.new(0.5, 0, 0, 4),
		anchor = Vector2.new(0.5, 0),
		transparency = 0.72,
		radius = 6,
		zIndex = 4,
		parent = face,
	})
	CheckUI.text({
		text = "X",
		size = UDim2.fromScale(1, 1),
		textSize = 26,
		stroke = 3.2,
		zIndex = 5,
		parent = face,
	})
	local scale = Instance.new("UIScale")
	scale.Name = "ButtonScale"
	scale.Parent = button
	return button
end

-- The tab's shape (a rectangle whose right edge leans by TAB_SLANT) in one
-- solid color, `inset` px smaller on every side.
local function tabShape(parent: Instance, name: string, inset: number, color: Color3, zIndex: number): CanvasGroup
	local height = TAB_SIZE.Y - inset * 2
	local group = Instance.new("CanvasGroup")
	group.Name = name
	group.Size = UDim2.fromOffset(TAB_SIZE.X, height)
	group.Position = UDim2.fromOffset(0, inset)
	group.BackgroundTransparency = 1
	group.ZIndex = zIndex
	group.Parent = parent
	local angle = math.atan(TAB_SLANT / TAB_SIZE.Y)
	-- x of the slanted edge halfway down; the rectangle stops where the edge is leftmost.
	local edgeX = TAB_SIZE.X - TAB_SLANT / 2 - inset / math.cos(angle)
	CheckUI.box({
		name = "Main",
		size = UDim2.fromOffset(edgeX - height / 2 * math.tan(angle) - inset + 1, height),
		position = UDim2.fromOffset(inset, 0),
		color = color,
		radius = math.max(16 - inset, 4),
		parent = group,
	})
	-- A tall rotated block whose right side draws the slanted edge.
	local wedgeWidth = 60
	CheckUI.box({
		name = "Wedge",
		size = UDim2.fromOffset(wedgeWidth, TAB_SIZE.Y * 2),
		position = UDim2.fromOffset(
			edgeX - wedgeWidth / 2 * math.cos(angle),
			TAB_SIZE.Y / 2 - inset - wedgeWidth / 2 * math.sin(angle)
		),
		anchor = Vector2.new(0.5, 0.5),
		color = color,
		parent = group,
	}).Rotation =
		math.deg(angle)
	return group
end

-- Header inside the window body (dark, with `accent` stripes and the two-line
-- divider), the slanted title tab sticking out above the window and the [X]
-- on the top-right corner. Returns the header, the close button and the title.
function CheckUI.header(window: GuiObject, title: string, accent: Color3): (Frame, ImageButton, TextLabel)
	local colors = CheckUI.Colors
	local body = window:FindFirstChild("Body") :: Frame
	local header = CheckUI.box({
		name = "Header",
		size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
		radius = WINDOW_RADIUS - 7,
		zIndex = 4,
		parent = body,
	})
	CheckUI.gradient(header, colors.HeaderTop, colors.HeaderBottom)
	-- Squares the header's bottom corners, matching its gradient there.
	local fillStart = 1 - 20 / HEADER_HEIGHT
	local fill = CheckUI.box({
		name = "SquareBottom",
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.new(0, 0, 1, -20),
		zIndex = 4,
		parent = header,
	})
	CheckUI.gradient(fill, colors.HeaderTop:Lerp(colors.HeaderBottom, fillStart), colors.HeaderBottom)
	local stripes = CheckUI.stripes(header, Vector2.new(300, HEADER_HEIGHT - 6), accent, 5)
	stripes.AnchorPoint = Vector2.new(1, 0)
	stripes.Position = UDim2.new(1, -40, 0, 0)
	for index, color in { accent, BLACK } do
		CheckUI.box({
			name = "Divider",
			size = UDim2.new(1, 0, 0, 3),
			position = UDim2.new(0, 0, 1, -9 + index * 3),
			color = color,
			zIndex = 6,
			parent = header,
		})
	end

	-- Title tab: shadow, black outline, dark gradient face and an accent edge.
	local tab = CheckUI.box({
		name = "TitleTab",
		size = UDim2.fromOffset(TAB_SIZE.X, TAB_SIZE.Y),
		position = UDim2.fromOffset(RIM + 9, -TAB_RISE),
		transparency = 1,
		zIndex = 8,
		parent = window,
	})
	local tabShadow = tabShape(tab, "Shadow", 0, BLACK, 1)
	tabShadow.Position += UDim2.fromOffset(4, 8)
	tabShadow.GroupTransparency = 0.5
	tabShape(tab, "Outline", 0, BLACK, 2)
	local face = tabShape(tab, "Face", 3.5, WHITE, 3)
	CheckUI.gradient(face, colors.TabTop, colors.TabBottom)
	CheckUI.box({
		name = "AccentEdge",
		size = UDim2.fromOffset(TAB_SIZE.X - 24, 2),
		position = UDim2.fromOffset(12, 4),
		color = accent,
		transparency = 0.15,
		zIndex = 4,
		parent = tab,
	})
	local titleLabel = CheckUI.text({
		text = title,
		size = UDim2.fromOffset(TAB_SIZE.X - 60, TAB_SIZE.Y),
		position = UDim2.fromOffset(18, TAB_SIZE.Y / 2),
		anchor = Vector2.new(0, 0.5),
		textSize = 30,
		stroke = 3.8,
		align = Enum.TextXAlignment.Left,
		italic = true,
		zIndex = 5,
		parent = tab,
	})
	titleLabel.TextScaled = true
	local maxSize = Instance.new("UITextSizeConstraint")
	maxSize.MaxTextSize = 30
	maxSize.Parent = titleLabel

	local close = CheckUI.closeButton(window, UDim2.new(1, -13, 0, 7), 9)
	return header, close, titleLabel
end

-- Inset panel for window content: darker, inner shadow at the top and a light
-- edge at the bottom.
function CheckUI.well(props: { name: string, size: UDim2, position: UDim2?, zIndex: number?, parent: Instance }): Frame
	local z = props.zIndex or 10
	local well = CheckUI.box({
		name = props.name,
		size = props.size,
		position = props.position,
		color = CheckUI.Colors.Well,
		radius = 12,
		zIndex = z,
		parent = props.parent,
	})
	CheckUI.stroke(well, BLACK, 2.5, true)
	local inner = CheckUI.box({
		name = "InnerShadow",
		size = UDim2.new(1, 0, 0, 10),
		color = BLACK,
		radius = 12,
		zIndex = z,
		parent = well,
	})
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(0.4, 1)
	fade.Parent = inner
	CheckUI.box({
		name = "LightEdge",
		size = UDim2.new(1, -16, 0, 3),
		position = UDim2.new(0.5, 0, 1, -3),
		anchor = Vector2.new(0.5, 0),
		color = CheckUI.Colors.WellEdge,
		transparency = 0.45,
		zIndex = z,
		parent = well,
	})
	return well
end

-- Rarity card frame: shadow, a thick border in the rarity color and a dark
-- inner panel tinted towards it at the bottom. Secret is black with a thin
-- white edge (never a rainbow). Returns the card and its inner panel.
function CheckUI.rarityCard(props: {
	name: string,
	size: Vector2,
	position: UDim2?,
	color: Color3,
	secret: boolean,
	zIndex: number?,
	parent: Instance,
}): (Frame, Frame)
	local colors = CheckUI.Colors
	local card = CheckUI.box({
		name = props.name,
		size = UDim2.fromOffset(props.size.X, props.size.Y),
		position = props.position,
		transparency = 1,
		zIndex = props.zIndex or 20,
		parent = props.parent,
	})
	CheckUI.shadow(card, 12, 5)
	local border = CheckUI.box({
		name = "Border",
		size = UDim2.fromScale(1, 1),
		radius = 12,
		zIndex = 2,
		parent = card,
	})
	if props.secret then
		CheckUI.gradient(border, Color3.fromRGB(40, 40, 44), Color3.fromRGB(4, 4, 6))
		CheckUI.stroke(border, WHITE, 1.6, true)
		edge(border, 3, 10, WHITE, 0.45, 3)
	else
		CheckUI.gradient(border, props.color:Lerp(WHITE, 0.25), props.color:Lerp(BLACK, 0.35))
		CheckUI.stroke(border, BLACK, 2.5, true)
	end
	local inner = CheckUI.box({
		name = "Inner",
		size = UDim2.new(1, -10, 1, -10),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		radius = 8,
		zIndex = 3,
		parent = card,
	})
	local tint = Instance.new("UIGradient")
	tint.Rotation = 90
	tint.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colors.CardInner),
		ColorSequenceKeypoint.new(0.35, colors.CardInner),
		ColorSequenceKeypoint.new(1, if props.secret then BLACK else props.color:Lerp(BLACK, 0.55)),
	})
	tint.Parent = inner
	CheckUI.stroke(inner, BLACK, 2, true).Transparency = 0.1
	gloss(inner, 0.3, 8, 0.1, 3)
	return card, inner
end

-- Rounded button with a shadow, a bevel base, a gradient face, a faint
-- checkerboard, a white gloss, a light inner edge and a GothamBlack label.
-- `subText` adds a smaller second line (e.g. a price).
function CheckUI.button(props: {
	name: string,
	size: Vector2,
	position: UDim2,
	text: string,
	textSize: number?,
	subText: string?,
	palette: ButtonPalette,
	zIndex: number?,
	parent: Instance,
}): (ImageButton, TextLabel, TextLabel?)
	local zIndex = props.zIndex or 25
	local radius = 12
	local button = Instance.new("ImageButton")
	button.Name = props.name
	button.Size = UDim2.fromOffset(props.size.X, props.size.Y)
	button.Position = props.position
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.ZIndex = zIndex
	button.Parent = props.parent
	CheckUI.shadow(button, radius, 5, 0.55)

	local base = CheckUI.box({
		name = "Bevel",
		size = UDim2.fromScale(1, 1),
		color = props.palette.bevel,
		radius = radius,
		zIndex = 2,
		parent = button,
	})
	CheckUI.stroke(base, BLACK, 3, true)
	local face = CheckUI.box({
		name = "Face",
		size = UDim2.new(1, 0, 1, -6),
		radius = radius,
		zIndex = 3,
		parent = base,
	})
	local gradient = CheckUI.gradient(face, props.palette.top, props.palette.bottom)
	gradient.Name = "ButtonGradient"
	CheckUI.damier(face, BLACK, 16, 0.96, 0.84, radius)
	gloss(face, 0.36, radius - 3, 0.38, 5)
	local highlight = edge(face, 2, radius - 2, props.palette.highlight, 0.25, 6)
	highlight.Name = "Highlight"

	local hasSub = props.subText ~= nil
	local label = CheckUI.text({
		text = props.text,
		size = UDim2.new(1, -8, if hasSub then 0.56 else 1, if hasSub then 0 else -6),
		position = UDim2.new(0.5, 0, if hasSub then 0.32 else 0.5, -3),
		textSize = props.textSize or 30,
		stroke = 3,
		zIndex = 7,
		parent = button,
	})
	local sub: TextLabel? = nil
	if props.subText then
		sub = CheckUI.text({
			text = props.subText,
			size = UDim2.new(1, -8, 0.34, 0),
			position = UDim2.new(0.5, 0, 0.7, -3),
			textSize = math.floor((props.textSize or 30) * 0.62),
			stroke = 2.5,
			zIndex = 7,
			parent = button,
		})
	end
	local scale = Instance.new("UIScale")
	scale.Name = "ButtonScale"
	scale.Parent = button
	return button, label, sub
end

-- Recolors a button made by CheckUI.button (e.g. Purple -> Gray).
function CheckUI.setPalette(button: GuiObject, palette: ButtonPalette)
	local base = button:FindFirstChild("Bevel")
	if not (base and base:IsA("Frame")) then
		return
	end
	base.BackgroundColor3 = palette.bevel
	local face = base:FindFirstChild("Face")
	if not face then
		return
	end
	local gradient = face:FindFirstChild("ButtonGradient")
	if gradient and gradient:IsA("UIGradient") then
		gradient.Color = ColorSequence.new(palette.top, palette.bottom)
	end
	local highlight = face:FindFirstChild("Highlight")
	local stroke = highlight and highlight:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = palette.highlight
	end
end

-- Center-anchored hover and press bounce through the button's "ButtonScale",
-- and `onActivated` on click or tap.
function CheckUI.bind(button: GuiButton, onActivated: () -> ())
	local scale = button:FindFirstChild("ButtonScale") :: UIScale?
	local hover = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local release = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local function to(value: number, info: TweenInfo)
		if scale then
			TweenService:Create(scale, info, { Scale = value }):Play()
		end
	end
	button.MouseEnter:Connect(function()
		to(1.05, hover)
		SoundController.play("UiHover")
	end)
	button.MouseLeave:Connect(function()
		to(1, hover)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.94, hover)
	end)
	button.MouseButton1Up:Connect(function()
		to(1.05, release)
	end)
	button.Activated:Connect(function()
		SoundController.play("UiClick")
		onActivated()
	end)
end

-- Icon for HUD pieces: an image (rbxassetid) when given, otherwise a text
-- glyph (e.g. the yen sign) in `glyphColor`. Centered on `position`.
local function icon(
	parent: Instance,
	props: {
		icon: string?,
		glyph: string?,
		glyphColor: Color3?,
		size: number,
		position: UDim2,
		zIndex: number,
	}
): GuiObject
	if props.icon then
		local image = Instance.new("ImageLabel")
		image.Name = "Icon"
		image.Image = props.icon
		image.ScaleType = Enum.ScaleType.Fit
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromOffset(props.size, props.size)
		image.Position = props.position
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.ZIndex = props.zIndex
		image.Parent = parent
		return image
	end
	local label = CheckUI.text({
		text = props.glyph or "",
		size = UDim2.fromOffset(props.size, props.size),
		position = props.position,
		textSize = math.floor(props.size * 0.62),
		color = props.glyphColor,
		stroke = 3,
		zIndex = props.zIndex,
		parent = parent,
	})
	label.Name = "Icon"
	return label
end

-- Dark purple pill (HUD counters and boost timers): shadow, base, gradient
-- face, gloss and a lavender inner edge.
local function pill(root: GuiObject, radius: number)
	CheckUI.shadow(root, radius, 5, 0.55)
	local base = CheckUI.box({
		name = "Base",
		size = UDim2.fromScale(1, 1),
		color = Color3.fromRGB(30, 14, 56),
		radius = radius,
		zIndex = 2,
		parent = root,
	})
	CheckUI.stroke(base, BLACK, 3, true)
	local face = CheckUI.box({
		name = "Face",
		size = UDim2.new(1, 0, 1, -4),
		radius = radius,
		zIndex = 3,
		parent = base,
	})
	CheckUI.gradient(face, Color3.fromRGB(58, 34, 98), Color3.fromRGB(26, 15, 46))
	gloss(face, 0.35, radius - 3, 0.14, 4)
	edge(face, 1.5, radius - 1, CheckUI.Colors.Lavender, 0.45, 5)
end

-- Small HUD panel with the window's purple rim (Raid status, queue, area,
-- notices). An optional title adds a dark strip with `accent` stripes.
-- Returns the panel and its body (content goes in the body, ZIndex 10 and up).
function CheckUI.hudPanel(props: {
	name: string,
	size: Vector2,
	position: UDim2?,
	anchor: Vector2?,
	title: string?,
	accent: Color3?,
	zIndex: number?,
	parent: Instance,
}): (Frame, Frame)
	local colors = CheckUI.Colors
	local radius = 16
	local panel = CheckUI.box({
		name = props.name,
		size = UDim2.fromOffset(props.size.X, props.size.Y),
		position = props.position,
		anchor = props.anchor,
		transparency = 1,
		zIndex = props.zIndex or 5,
		parent = props.parent,
	})
	CheckUI.shadow(panel, radius, 7)
	local rim = CheckUI.box({
		name = "Rim",
		size = UDim2.fromScale(1, 1),
		color = colors.RimBevel,
		radius = radius,
		zIndex = 2,
		parent = panel,
	})
	CheckUI.stroke(rim, BLACK, 3.5, true)
	local rimFace = CheckUI.box({
		name = "RimFace",
		size = UDim2.new(1, 0, 1, -6),
		radius = radius,
		zIndex = 2,
		parent = rim,
	})
	CheckUI.gradient(rimFace, colors.RimTop, colors.RimBottom)
	edge(rimFace, 2, radius - 2, colors.RimHighlight, 0.4, 3)
	local body = CheckUI.box({
		name = "Body",
		size = UDim2.new(1, -12, 1, -18),
		position = UDim2.fromOffset(6, 6),
		radius = radius - 5,
		zIndex = 3,
		parent = panel,
	})
	CheckUI.gradient(body, colors.BodyTop, colors.BodyBottom)
	CheckUI.stroke(body, BLACK, 2.5, true)

	if props.title then
		local accent = props.accent or CheckUI.Accents.Purple
		local strip = CheckUI.box({
			name = "TitleStrip",
			size = UDim2.new(1, 0, 0, 38),
			radius = radius - 5,
			zIndex = 4,
			parent = body,
		})
		CheckUI.gradient(strip, colors.HeaderTop, colors.HeaderBottom)
		local square = CheckUI.box({
			name = "SquareBottom",
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.new(0, 0, 1, -14),
			zIndex = 4,
			parent = strip,
		})
		CheckUI.gradient(square, colors.HeaderTop:Lerp(colors.HeaderBottom, 24 / 38), colors.HeaderBottom)
		local stripes = CheckUI.stripes(strip, Vector2.new(180, 32), accent, 5)
		stripes.AnchorPoint = Vector2.new(1, 0)
		stripes.Position = UDim2.fromScale(1, 0)
		for index, color in { accent, BLACK } do
			CheckUI.box({
				name = "Divider",
				size = UDim2.new(1, 0, 0, 3),
				position = UDim2.new(0, 0, 1, -9 + index * 3),
				color = color,
				zIndex = 6,
				parent = strip,
			})
		end
		CheckUI.text({
			text = props.title,
			size = UDim2.new(1, -24, 0, 32),
			position = UDim2.fromOffset(12, 16),
			anchor = Vector2.new(0, 0.5),
			textSize = 18,
			stroke = 3,
			align = Enum.TextXAlignment.Left,
			italic = true,
			zIndex = 7,
			parent = strip,
		}).Name =
			"Title"
	end
	return panel, body
end

-- HUD currency counter (Yen, Gems): a pill with a big icon sticking out on
-- the left and the value. Returns the counter and its value label.
function CheckUI.counter(props: {
	name: string,
	icon: string?,
	glyph: string?,
	glyphColor: Color3?,
	size: Vector2?,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	parent: Instance,
}): (Frame, TextLabel)
	local size = props.size or Vector2.new(220, 50)
	local counter = CheckUI.box({
		name = props.name,
		size = UDim2.fromOffset(size.X, size.Y),
		position = props.position,
		anchor = props.anchor,
		transparency = 1,
		zIndex = props.zIndex or 5,
		parent = props.parent,
	})
	pill(counter, 12)
	icon(counter, {
		icon = props.icon,
		glyph = props.glyph,
		glyphColor = props.glyphColor,
		size = math.floor(size.Y * 1.3),
		position = UDim2.new(0, 10, 0.5, -2),
		zIndex = 8,
	})
	local value = CheckUI.text({
		text = "0",
		size = UDim2.new(1, -size.Y - 4, 1, -4),
		position = UDim2.new(0, size.Y - 4, 0.5, -2),
		anchor = Vector2.new(0, 0.5),
		textSize = math.floor(size.Y * 0.52),
		stroke = 3,
		align = Enum.TextXAlignment.Left,
		zIndex = 8,
		parent = counter,
	})
	value.Name = "Value"
	return counter, value
end

-- HUD timer of an active boost: icon, multiplier (e.g. "x2") and time left.
-- Returns the chip and its time label.
function CheckUI.boostChip(props: {
	name: string,
	icon: string?,
	glyph: string?,
	glyphColor: Color3?,
	multiplier: string,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	parent: Instance,
}): (Frame, TextLabel)
	local chip = CheckUI.box({
		name = props.name,
		size = UDim2.fromOffset(150, 46),
		position = props.position,
		anchor = props.anchor,
		transparency = 1,
		zIndex = props.zIndex or 5,
		parent = props.parent,
	})
	pill(chip, 12)
	icon(chip, {
		icon = props.icon,
		glyph = props.glyph,
		glyphColor = props.glyphColor,
		size = 44,
		position = UDim2.new(0, 10, 0.5, -2),
		zIndex = 8,
	})
	CheckUI.text({
		text = props.multiplier,
		size = UDim2.fromOffset(34, 40),
		position = UDim2.new(0, 49, 0.5, -2),
		textSize = 16,
		color = Color3.fromRGB(190, 255, 60),
		stroke = 2.5,
		zIndex = 8,
		parent = chip,
	}).Name =
		"Multiplier"
	local time = CheckUI.text({
		text = "0:00",
		size = UDim2.fromOffset(80, 40),
		position = UDim2.new(0, 106, 0.5, -2),
		textSize = 20,
		stroke = 2.8,
		zIndex = 8,
		parent = chip,
	})
	time.Name = "Time"
	return chip, time
end

-- Purple square HUD button (Inventory, Boosts, Settings) with an icon and a
-- label across its bottom edge. Centered on `position`.
function CheckUI.sideButton(props: {
	name: string,
	text: string,
	icon: string?,
	glyph: string?,
	glyphColor: Color3?,
	position: UDim2,
	zIndex: number?,
	parent: Instance,
}): ImageButton
	local radius = 18
	local button = Instance.new("ImageButton")
	button.Name = props.name
	button.Size = UDim2.fromOffset(78, 78)
	button.Position = props.position
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.ZIndex = props.zIndex or 5
	button.Parent = props.parent
	CheckUI.shadow(button, radius, 6)
	local base = CheckUI.box({
		name = "Bevel",
		size = UDim2.fromScale(1, 1),
		color = CheckUI.Colors.RimBevel,
		radius = radius,
		zIndex = 2,
		parent = button,
	})
	CheckUI.stroke(base, BLACK, 3, true)
	local face = CheckUI.box({
		name = "Face",
		size = UDim2.new(1, 0, 1, -6),
		radius = radius,
		zIndex = 3,
		parent = base,
	})
	CheckUI.gradient(face, Color3.fromRGB(170, 110, 250), Color3.fromRGB(92, 40, 175))
	CheckUI.damier(face, BLACK, 12, 0.95, 0.8, radius)
	gloss(face, 0.36, radius - 4, 0.35, 5)
	edge(face, 2, radius - 2, Color3.fromRGB(230, 205, 255), 0.2, 6)
	icon(button, {
		icon = props.icon,
		glyph = props.glyph,
		glyphColor = props.glyphColor,
		size = 50,
		position = UDim2.new(0.5, 0, 0, 32),
		zIndex = 7,
	})
	CheckUI.text({
		text = props.text,
		size = UDim2.fromOffset(110, 22),
		position = UDim2.new(0.5, 0, 1, -6),
		textSize = 13,
		stroke = 3,
		zIndex = 8,
		parent = button,
	}).Name =
		"Label"
	local scale = Instance.new("UIScale")
	scale.Name = "ButtonScale"
	scale.Parent = button
	return button
end

-- Recessed bar with a glossy purple fill and centered text. Returns the bar
-- and a setter: set(progress 0..1, text?).
function CheckUI.progressBar(props: {
	name: string,
	size: Vector2,
	position: UDim2?,
	anchor: Vector2?,
	zIndex: number?,
	parent: Instance,
}): (Frame, (number, string?) -> ())
	local radius = 9
	local bar = CheckUI.box({
		name = props.name,
		size = UDim2.fromOffset(props.size.X, props.size.Y),
		position = props.position,
		anchor = props.anchor,
		color = Color3.fromRGB(10, 6, 18),
		radius = radius,
		zIndex = props.zIndex or 10,
		parent = props.parent,
	})
	CheckUI.stroke(bar, BLACK, 2.5, true)
	local fill = CheckUI.box({
		name = "Fill",
		size = UDim2.fromScale(0, 1),
		radius = radius,
		zIndex = 2,
		parent = bar,
	})
	CheckUI.gradient(fill, Color3.fromRGB(200, 140, 255), Color3.fromRGB(120, 48, 226))
	CheckUI.box({
		name = "Bevel",
		size = UDim2.new(1, -radius, 0, 4),
		position = UDim2.new(0.5, 0, 1, -4),
		anchor = Vector2.new(0.5, 0),
		color = Color3.fromRGB(60, 15, 120),
		zIndex = 3,
		parent = fill,
	})
	gloss(fill, 0.3, radius - 4, 0.3, 3)
	local inner = CheckUI.box({
		name = "InnerShadow",
		size = UDim2.new(1, 0, 0, 7),
		color = BLACK,
		radius = radius,
		zIndex = 4,
		parent = bar,
	})
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(0.35, 1)
	fade.Parent = inner
	local label = CheckUI.text({
		text = "",
		size = UDim2.fromScale(1, 1),
		textSize = math.floor(props.size.Y * 0.55),
		stroke = 2.6,
		zIndex = 5,
		parent = bar,
	})
	label.Name = "Label"
	local function set(progress: number, text: string?)
		local p = math.clamp(progress, 0, 1)
		fill.Size = UDim2.fromScale(p, 1)
		fill.Visible = p > 0
		if text then
			label.Text = text
		end
	end
	return bar, set
end

export type CharacterCard = {
	button: ImageButton,
	view: CharacterViewport.CharacterView?,
	setEquipped: (boolean) -> (),
	setSelected: (boolean) -> (),
}

-- One stroke of the equipped check mark.
local function checkArm(parent: Instance, size: Vector2, position: Vector2, rotation: number)
	local arm = CheckUI.box({
		name = "Arm",
		size = UDim2.fromOffset(size.X, size.Y),
		position = UDim2.fromOffset(position.X, position.Y),
		anchor = Vector2.new(0.5, 0.5),
		radius = 2,
		zIndex = 10,
		parent = parent,
	})
	arm.Rotation = rotation
	CheckUI.stroke(arm, BLACK, 1.2, true)
end

-- Inventory card: rarity frame, an aura and the character in 3D, damage at
-- the top left, a rarity diamond at the top right, the name on a dark strip
-- at the bottom, a green check when equipped and a white outline when
-- selected. Secret is black with a white edge.
function CheckUI.characterCard(
	props: {
		name: string,
		characterId: string?,
		displayName: string,
		damage: string,
		color: Color3,
		secret: boolean,
		size: Vector2?,
		position: UDim2?, -- center of the card
		zIndex: number?,
		parent: Instance,
	}
): CharacterCard
	local size = props.size or Vector2.new(112, 136)
	local button = Instance.new("ImageButton")
	button.Name = props.name
	button.Size = UDim2.fromOffset(size.X, size.Y)
	button.Position = props.position or UDim2.fromOffset(size.X / 2, size.Y / 2)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.ZIndex = props.zIndex or 10
	button.Parent = props.parent

	local selection = CheckUI.box({
		name = "Selection",
		size = UDim2.new(1, 10, 1, 10),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		transparency = 1,
		radius = 15,
		parent = button,
	})
	CheckUI.stroke(selection, WHITE, 3, true)
	selection.Visible = false

	local _, inner = CheckUI.rarityCard({
		name = "Frame",
		size = size,
		color = props.color,
		secret = props.secret,
		zIndex = 2,
		parent = button,
	})
	CheckUI.box({
		name = "Aura",
		size = UDim2.fromOffset(size.X * 0.82, size.X * 0.82),
		position = UDim2.new(0.5, 0, 0, size.X * 0.45),
		anchor = Vector2.new(0.5, 0.5),
		color = if props.secret then WHITE else props.color,
		transparency = if props.secret then 0.93 else 0.78,
		radius = math.floor(size.X * 0.41),
		zIndex = 3,
		parent = inner,
	})
	local view: CharacterViewport.CharacterView? = nil
	if props.characterId then
		view = CharacterViewport.new(props.characterId, {
			size = UDim2.fromOffset(size.X - 14, size.Y * 0.62),
			position = UDim2.new(0.5, 0, 0, size.Y * 0.4),
			zIndex = 4,
			parent = inner,
		})
	end
	local strip = CheckUI.box({
		name = "NameStrip",
		size = UDim2.new(1, 0, 0, 30),
		position = UDim2.new(0, 0, 1, -30),
		color = BLACK,
		radius = 8,
		zIndex = 5,
		parent = inner,
	})
	local stripFade = Instance.new("UIGradient")
	stripFade.Rotation = 90
	stripFade.Transparency = NumberSequence.new(0.8, 0.15)
	stripFade.Parent = strip
	local name = CheckUI.text({
		text = props.displayName,
		size = UDim2.new(1, -12, 0, 22),
		position = UDim2.new(0.5, 0, 1, -19),
		textSize = 12,
		stroke = 2.5,
		zIndex = 8,
		parent = button,
	})
	name.Name = "Name"
	name.TextScaled = true
	local maxName = Instance.new("UITextSizeConstraint")
	maxName.MaxTextSize = 13
	maxName.Parent = name
	CheckUI.text({
		text = props.damage,
		size = UDim2.fromOffset(size.X * 0.6, 18),
		position = UDim2.fromOffset(11, 17),
		anchor = Vector2.new(0, 0.5),
		textSize = 13,
		color = CheckUI.Colors.Gold,
		stroke = 2.6,
		align = Enum.TextXAlignment.Left,
		zIndex = 8,
		parent = button,
	}).Name =
		"Damage"
	local diamond = CheckUI.box({
		name = "RarityDiamond",
		size = UDim2.fromOffset(11, 11),
		position = UDim2.new(1, -16, 0, 17),
		anchor = Vector2.new(0.5, 0.5),
		color = if props.secret then Color3.fromRGB(10, 10, 10) else props.color,
		zIndex = 8,
		parent = button,
	})
	diamond.Rotation = 45
	CheckUI.stroke(diamond, if props.secret then WHITE else BLACK, 2, true)

	-- Green check: a circle with two white strokes.
	local check = CheckUI.box({
		name = "Equipped",
		size = UDim2.fromOffset(22, 22),
		position = UDim2.new(1, -15, 1, -44),
		anchor = Vector2.new(0.5, 0.5),
		color = Color3.fromRGB(123, 224, 0),
		radius = 11,
		zIndex = 9,
		parent = button,
	})
	CheckUI.stroke(check, BLACK, 2.5, true)
	checkArm(check, Vector2.new(3.5, 8), Vector2.new(8, 12), -45)
	checkArm(check, Vector2.new(3.5, 13), Vector2.new(13.5, 10), 40)
	check.Visible = false

	local scale = Instance.new("UIScale")
	scale.Name = "ButtonScale"
	scale.Parent = button

	return {
		button = button,
		view = view,
		setEquipped = function(equipped: boolean)
			check.Visible = equipped
		end,
		setSelected = function(selected: boolean)
			selection.Visible = selected
		end,
	}
end

return CheckUI
