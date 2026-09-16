local UIStyle = require(script.Parent.UIStyle)

local ItemDespawnCountdown = {}

function ItemDespawnCountdown.Create(Billboard: BillboardGui): TextLabel
	local Label = Instance.new("TextLabel")
	Label.Name = "DespawnTimer"
	Label.BackgroundColor3 = Color3.fromRGB(41, 19, 18)
	Label.BackgroundTransparency = 0.12
	Label.BorderSizePixel = 0
	Label.FontFace = UIStyle.Font
	Label.Position = UDim2.fromScale(0.27, 0)
	Label.Size = UDim2.fromScale(0.46, 0.15)
	Label.Text = ""
	Label.TextColor3 = Color3.fromRGB(255, 224, 203)
	Label.TextScaled = true
	Label.TextStrokeColor3 = Color3.new(0, 0, 0)
	Label.TextStrokeTransparency = 0.35
	Label.Visible = false
	Label.Parent = Billboard

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 10)
	Corner.Parent = Label
	local Padding = Instance.new("UIPadding")
	Padding.PaddingBottom = UDim.new(0, 6)
	Padding.PaddingLeft = UDim.new(0, 9)
	Padding.PaddingRight = UDim.new(0, 9)
	Padding.PaddingTop = UDim.new(0, 6)
	Padding.Parent = Label
	return Label
end

function ItemDespawnCountdown.Update(Label: TextLabel?, Remaining: number)
	if not Label or not Label.Parent then return end
	Label.Visible = Remaining > 0
	Label.Text = `{string.format("%.1f", math.max(0, Remaining))}s`
end

return ItemDespawnCountdown
