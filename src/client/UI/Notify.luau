--!strict
-- Short message banner at the top of the screen, shared by every controller.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local DISPLAY_TIME = 2.5

local Notify = {}

local banner: TextLabel? = nil
local stroke: UIStroke? = nil
local hideToken = 0

local function getBanner(): (TextLabel, UIStroke)
	if banner and stroke then
		return banner, stroke
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "Notify"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0.12, 0)
	label.Size = UDim2.fromOffset(420, 56)
	label.BackgroundColor3 = Theme.Background
	label.BackgroundTransparency = 0.15
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.5
	label.Visible = false
	label.Parent = gui
	Theme.corner(label)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = label

	local border = Instance.new("UIStroke")
	border.Thickness = 2
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = label

	banner, stroke = label, border
	return label, border
end

-- Shows `text` in `color`. `outline` overrides the text outline (e.g. white on dark text).
function Notify.show(text: string, color: Color3, outline: Color3?)
	local label, border = getBanner()
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = outline or Color3.new(0, 0, 0)
	border.Color = color
	label.Visible = true
	label.Size = UDim2.fromOffset(380, 50)
	TweenService:Create(label, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(420, 56) }):Play()

	hideToken += 1
	local token = hideToken
	task.delay(DISPLAY_TIME, function()
		if hideToken == token then
			label.Visible = false
		end
	end)
end

function Notify.error(text: string)
	Notify.show(text, Theme.Error)
end

return Notify
