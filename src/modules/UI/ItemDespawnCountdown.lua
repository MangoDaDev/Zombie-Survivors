local UIStyle = require(script.Parent.UIStyle)

local ItemDespawnCountdown = {}

function ItemDespawnCountdown.Create(Model: Model, Adornee: BasePart): (BillboardGui, TextLabel)
	local Billboard = Instance.new("BillboardGui")
	Billboard.Name = "DespawnCountdown"
	Billboard.Adornee = Adornee
	Billboard.AlwaysOnTop = true
	Billboard.MaxDistance = 100
	Billboard.Size = UDim2.fromOffset(190, 42)
	Billboard.StudsOffsetWorldSpace = Vector3.new(0, Model:GetExtentsSize().Y / 2 + 1.8, 0)
	Billboard.Enabled = false
	Billboard.Parent = Adornee

	local Label = Instance.new("TextLabel")
	Label.Name = "Label"
	Label.BackgroundColor3 = Color3.fromRGB(41, 19, 18)
	Label.BackgroundTransparency = 0.12
	Label.BorderSizePixel = 0
	Label.FontFace = UIStyle.Font
	Label.Size = UDim2.fromScale(1, 1)
	Label.TextColor3 = Color3.fromRGB(255, 224, 203)
	Label.TextScaled = true
	Label.TextStrokeColor3 = Color3.new(0, 0, 0)
	Label.TextStrokeTransparency = 0.35
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
	return Billboard, Label
end

function ItemDespawnCountdown.Update(Billboard: BillboardGui, Label: TextLabel, Remaining: number, VisibleDuration: number)
	if Remaining > 0 and Remaining <= VisibleDuration then
		Billboard.Enabled = true
		Label.Text = `Despawns in {math.max(1, math.ceil(Remaining))}s`
	else
		Billboard.Enabled = false
	end
end

return ItemDespawnCountdown
