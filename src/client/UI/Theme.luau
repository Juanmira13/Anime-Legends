--!strict
-- Shared UI colors and small builders so every screen looks consistent.

local Theme = {}

Theme.RarityColors = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(110, 210, 110),
	Rare = Color3.fromRGB(80, 160, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 190, 40),
	Mythic = Color3.fromRGB(255, 70, 70),
	Secret = Color3.fromRGB(20, 20, 20),
} :: { [string]: Color3 }

Theme.Background = Color3.fromRGB(25, 25, 30)
Theme.Surface = Color3.fromRGB(40, 40, 48)
Theme.Accent = Color3.fromRGB(255, 200, 60)
Theme.Danger = Color3.fromRGB(220, 60, 60)
Theme.Text = Color3.new(1, 1, 1)
Theme.MutedText = Color3.fromRGB(180, 180, 190)
Theme.Error = Color3.fromRGB(255, 120, 120)

function Theme.rarityColor(rarityId: string): Color3
	return Theme.RarityColors[rarityId] or Theme.Text
end

function Theme.corner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
end

function Theme.label(props: { text: string?, size: UDim2?, position: UDim2?, color: Color3?, bold: boolean? }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = if props.bold == false then Enum.Font.Gotham else Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = props.color or Theme.Text
	label.Text = props.text or ""
	label.Size = props.size or UDim2.fromScale(1, 1)
	label.Position = props.position or UDim2.new()
	return label
end

function Theme.button(text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color
	button.AutoButtonColor = true
	button.Font = Enum.Font.GothamBold
	button.TextScaled = true
	button.TextColor3 = Theme.Text
	button.Text = text
	Theme.corner(button)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = button
	return button
end

return Theme
