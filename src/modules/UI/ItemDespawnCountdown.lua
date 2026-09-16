local Images = require(script.Parent.Images)
local UIStyle = require(script.Parent.UIStyle)

local ItemDespawnCountdown = {}

function ItemDespawnCountdown.Create(Billboard: BillboardGui): Frame
	local Row = Instance.new("Frame")
	Row.Name = "DespawnTimer"
	Row.BackgroundTransparency = 1
	Row.Position = UDim2.fromScale(0, 0)
	Row.Size = UDim2.fromScale(1, 0.15)
	Row.Visible = false
	Row.Parent = Billboard

	local Layout = Instance.new("UIListLayout")
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Layout.Padding = UDim.new(0.02, 0)
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center
	Layout.Parent = Row

	local Icon = Instance.new("ImageLabel")
	Icon.Name = "Icon"
	Icon.BackgroundTransparency = 1
	Icon.Image = Images.Clock
	Icon.LayoutOrder = 1
	Icon.ScaleType = Enum.ScaleType.Fit
	Icon.Size = UDim2.fromScale(0.09, 0.8)
	Icon.Parent = Row

	local Label = Instance.new("TextLabel")
	Label.Name = "Value"
	Label.AutomaticSize = Enum.AutomaticSize.X
	Label.BackgroundTransparency = 1
	Label.FontFace = UIStyle.Font
	Label.LayoutOrder = 2
	Label.Size = UDim2.fromScale(0, 1)
	Label.Text = ""
	Label.TextColor3 = Color3.fromRGB(72, 232, 91)
	Label.TextScaled = true
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Row

	local Stroke = Instance.new("UIStroke")
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	Stroke.Color = Color3.new(0, 0, 0)
	Stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	Stroke.Thickness = 0.05
	Stroke.Parent = Label
	return Row
end

function ItemDespawnCountdown.Update(Row: Frame?, Remaining: number)
	if not Row or not Row.Parent then return end
	Row.Visible = Remaining > 0
	local Label = Row:FindFirstChild("Value")
	if Label and Label:IsA("TextLabel") then
		Label.Text = `{string.format("%.1f", math.max(0, Remaining))}s`
	end
end

return ItemDespawnCountdown
