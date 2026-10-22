--!strict
-- Check-UI (skill check-ui-clean-roblox), the official UI style: tokens and
-- the constructors screens are built from. Solid #3B5866 windows with a dark
-- border, headers with a gradient per menu type and a two-line divider, the
-- beveled [X] close button, iconless buttons with gradient, checkerboard and
-- triple inner highlight, GothamBlack text with black outline, center-anchored
-- interactions with UIScale, and scaling from the 1050 x 620 base viewport.

local TweenService = game:GetService("TweenService")

local SoundController = require(script.Parent.Parent.Controllers.SoundController)

local CheckUI = {}

CheckUI.Assets = {
	Checkerboard = "rbxassetid://385956923",
	Sunburst = "rbxassetid://130563114903838",
	Star = "rbxassetid://93302981101722", -- CheckUIIcons Main/Star Golden_Star_1st
	Coin = "rbxassetid://96866635707429", -- CheckUIIcons Currency/Coin Golden_Coin_1st
}

CheckUI.Colors = {
	Canvas = Color3.fromRGB(59, 88, 102),
	CanvasBorder = Color3.fromRGB(24, 30, 34),
	Card = Color3.fromRGB(26, 44, 52),
	CardHighlight = Color3.fromRGB(75, 125, 145),
	ButtonBorder = Color3.fromRGB(12, 20, 26),
	TextStroke = Color3.fromRGB(17, 23, 26),
	Text = Color3.new(1, 1, 1),
}

export type HeaderTheme = {
	top: Color3,
	bottom: Color3,
	highlight: Color3,
	damier: Color3,
	divider: Color3,
}

CheckUI.Headers = {
	Shop = {
		top = Color3.fromRGB(255, 20, 150),
		bottom = Color3.fromRGB(225, 0, 25),
		highlight = Color3.fromRGB(255, 200, 225),
		damier = Color3.fromRGB(150, 0, 20),
		divider = Color3.fromRGB(125, 0, 18),
	},
	Codes = {
		top = Color3.fromRGB(0, 205, 255),
		bottom = Color3.fromRGB(0, 130, 245),
		highlight = Color3.fromRGB(180, 240, 255),
		damier = Color3.fromRGB(0, 75, 150),
		divider = Color3.fromRGB(0, 50, 110),
	},
	Rebirth = {
		top = Color3.fromRGB(160, 0, 255),
		bottom = Color3.fromRGB(96, 0, 200),
		highlight = Color3.fromRGB(224, 160, 255),
		damier = Color3.fromRGB(96, 0, 144),
		divider = Color3.fromRGB(80, 0, 120),
	},
} :: { [string]: HeaderTheme }

export type ButtonPalette = { top: Color3, bottom: Color3 }

-- The button state triad (Claim, Claimed, Locked) plus the golden Skip.
CheckUI.Buttons = {
	Claim = { top = Color3.fromRGB(180, 255, 25), bottom = Color3.fromRGB(105, 225, 0) },
	Claimed = { top = Color3.fromRGB(216, 222, 228), bottom = Color3.fromRGB(148, 160, 176) },
	Locked = { top = Color3.fromRGB(255, 32, 80), bottom = Color3.fromRGB(208, 0, 32) },
	Skip = { top = Color3.fromRGB(255, 208, 0), bottom = Color3.fromRGB(255, 140, 0) },
} :: { [string]: ButtonPalette }

-- The Check-UI spectrum (Day 7 rainbow).
CheckUI.Rainbow = {
	Color3.fromRGB(255, 30, 80),
	Color3.fromRGB(255, 140, 0),
	Color3.fromRGB(255, 230, 0),
	Color3.fromRGB(40, 230, 50),
	Color3.fromRGB(0, 210, 255),
	Color3.fromRGB(90, 60, 255),
	Color3.fromRGB(220, 0, 230),
}

local BASE_VIEWPORT = Vector2.new(1050, 620)
local MIN_SCALE, MAX_SCALE = 0.52, 1.18

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

-- Checkerboard overlay with a vertical transparency fade (`from` at the top, `to` at the bottom).
function CheckUI.damier(parent: GuiObject, color: Color3, tile: number, from: number, to: number): ImageLabel
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
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(from, to)
	fade.Parent = damier
	return damier
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
	zIndex: number?,
	parent: Instance,
}): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = props.text
	label.TextSize = props.textSize
	label.TextColor3 = props.color or CheckUI.Colors.Text
	label.Size = props.size
	label.Position = props.position or UDim2.fromScale(0.5, 0.5)
	label.AnchorPoint = props.anchor or Vector2.new(0.5, 0.5)
	label.TextXAlignment = props.align or Enum.TextXAlignment.Center
	label.ZIndex = props.zIndex or 1
	label.Parent = props.parent
	CheckUI.stroke(label, Color3.new(0, 0, 0), props.stroke or 2.5)
	return label
end

-- Solid window, centered, hidden, with its "WindowScale".
function CheckUI.window(name: string, size: Vector2, parent: Instance, zIndex: number?): (Frame, UIScale)
	local window = Instance.new("Frame")
	window.Name = name
	window.Size = UDim2.fromOffset(size.X, size.Y)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.BackgroundColor3 = CheckUI.Colors.Canvas
	window.BorderSizePixel = 0
	window.ZIndex = zIndex or 20
	window.Visible = false
	window.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = window
	CheckUI.stroke(window, CheckUI.Colors.CanvasBorder, 3.5, true)
	local scale = Instance.new("UIScale")
	scale.Name = "WindowScale"
	scale.Parent = window
	return window, scale
end

-- Beveled square [X] (38 x 38) on the right of a header.
function CheckUI.closeButton(header: GuiObject): ImageButton
	local zIndex = header.ZIndex + 4
	local button = Instance.new("ImageButton")
	button.Name = "CloseButton"
	button.Size = UDim2.fromOffset(38, 38)
	button.Position = UDim2.new(1, -34, 0.5, -2)
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = Color3.fromRGB(115, 0, 16)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.ZIndex = zIndex
	button.Parent = header
	CheckUI.stroke(button, Color3.new(0, 0, 0), 2.8, true)

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.Size = UDim2.new(1, 0, 1, -4)
	face.BackgroundColor3 = Color3.new(1, 1, 1)
	face.BorderSizePixel = 0
	face.ZIndex = zIndex + 1
	face.Parent = button
	CheckUI.gradient(face, Color3.fromRGB(255, 125, 175), Color3.fromRGB(255, 20, 40))

	local inner = Instance.new("Frame")
	inner.Size = UDim2.new(1, -2, 1, -2)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.BackgroundTransparency = 1
	inner.ZIndex = zIndex + 2
	inner.Parent = face
	CheckUI.stroke(inner, Color3.fromRGB(255, 210, 235), 1.2, true)

	local line = Instance.new("Frame")
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.new(0, 0, 1, -4)
	line.BackgroundColor3 = Color3.fromRGB(70, 0, 10)
	line.BorderSizePixel = 0
	line.ZIndex = zIndex + 2
	line.Parent = button

	CheckUI.text({
		text = "X",
		size = UDim2.fromScale(1, 1),
		textSize = 29,
		stroke = 3,
		zIndex = zIndex + 3,
		parent = face,
	})
	local scale = Instance.new("UIScale")
	scale.Name = "ButtonScale"
	scale.Parent = button
	return button
end

-- 60 px header with the theme's gradient, fading checkerboard, two-line
-- divider and title; returns it and its close button.
function CheckUI.header(window: GuiObject, title: string, theme: HeaderTheme): (Frame, ImageButton, TextLabel)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.BorderSizePixel = 0
	header.ClipsDescendants = true
	header.ZIndex = window.ZIndex + 1
	header.Parent = window
	CheckUI.gradient(header, theme.top, theme.bottom)

	local highlight = Instance.new("Frame")
	highlight.Size = UDim2.new(1, 0, 0, 2)
	highlight.BackgroundColor3 = theme.highlight
	highlight.BackgroundTransparency = 0.25
	highlight.BorderSizePixel = 0
	highlight.ZIndex = header.ZIndex + 1
	highlight.Parent = header

	local damier = CheckUI.damier(header, theme.damier, 26, 1, 0.05)
	damier.ImageTransparency = 0.35

	for index, color in { theme.divider, Color3.new(0, 0, 0) } do
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, 0, 0, 3)
		bar.Position = UDim2.new(0, 0, 1, -9 + index * 3)
		bar.BackgroundColor3 = color
		bar.BorderSizePixel = 0
		bar.ZIndex = header.ZIndex + 2
		bar.Parent = header
	end

	local titleLabel = CheckUI.text({
		text = title,
		size = UDim2.new(1, -80, 0, 44),
		position = UDim2.new(0, 18, 0.5, -2),
		anchor = Vector2.new(0, 0.5),
		textSize = 30,
		stroke = 3,
		align = Enum.TextXAlignment.Left,
		zIndex = header.ZIndex + 3,
		parent = header,
	})
	return header, CheckUI.closeButton(header), titleLabel
end

-- Iconless button (the Check-UI standard): sharp corners, 3 px dark border,
-- vertical gradient, black checkerboard, triple inner highlight and a
-- GothamBlack label. `subText` adds a smaller second line (e.g. a price).
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
	local button = Instance.new("ImageButton")
	button.Name = props.name
	button.Size = UDim2.fromOffset(props.size.X, props.size.Y)
	button.Position = props.position
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.ClipsDescendants = true
	button.ZIndex = zIndex
	button.Parent = props.parent
	CheckUI.stroke(button, CheckUI.Colors.ButtonBorder, 3, true)
	local gradient = CheckUI.gradient(button, props.palette.top, props.palette.bottom)
	gradient.Name = "ButtonGradient"

	local damier = CheckUI.damier(button, Color3.new(0, 0, 0), 19, 0.91, 0.62)
	damier.ZIndex = zIndex + 1
	for index, transparency in { 0.25, 0.45, 0.8 } do
		local inner = Instance.new("Frame")
		inner.Name = `InnerHighlight{index}`
		inner.Size = UDim2.new(1, -index * 2, 1, -index * 2)
		inner.Position = UDim2.fromScale(0.5, 0.5)
		inner.AnchorPoint = Vector2.new(0.5, 0.5)
		inner.BackgroundTransparency = 1
		inner.ZIndex = zIndex + 2
		inner.Parent = button
		local stroke = CheckUI.stroke(inner, Color3.new(1, 1, 1), 1, true)
		stroke.Transparency = transparency
	end

	local hasSub = props.subText ~= nil
	local label = CheckUI.text({
		text = props.text,
		size = UDim2.fromScale(1, if hasSub then 0.6 else 1),
		position = UDim2.new(0.5, 0, if hasSub then 0.36 else 0.5, -1),
		textSize = props.textSize or 36,
		stroke = 3,
		zIndex = zIndex + 3,
		parent = button,
	})
	local sub: TextLabel? = nil
	if props.subText then
		sub = CheckUI.text({
			text = props.subText,
			size = UDim2.fromScale(1, 0.38),
			position = UDim2.fromScale(0.5, 0.76),
			textSize = math.floor((props.textSize or 36) * 0.6),
			stroke = 2.5,
			zIndex = zIndex + 3,
			parent = button,
		})
	end
	local scale = Instance.new("UIScale")
	scale.Name = "ButtonScale"
	scale.Parent = button
	return button, label, sub
end

-- Recolors a button made by CheckUI.button (e.g. Claim -> Locked).
function CheckUI.setPalette(button: GuiObject, palette: ButtonPalette)
	local gradient = button:FindFirstChild("ButtonGradient")
	if gradient and gradient:IsA("UIGradient") then
		gradient.Color = ColorSequence.new(palette.top, palette.bottom)
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

return CheckUI
