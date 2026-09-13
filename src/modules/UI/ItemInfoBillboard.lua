local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Images = require(ReplicatedStorage.Modules.UI.Images)

local BILLBOARD_SIZE = UDim2.fromScale(7.5, 3)
local COMIC_FONT = Font.fromName("ComicNeueAngular")
local MAX_DISTANCE = 300

local function addStroke(label: TextLabel)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.new(0, 0, 0)
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = 0.05
	stroke.Parent = label
end

local function createStatRow(image: string, value: number, position: UDim2): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = position
	row.Size = UDim2.fromScale(1, 0.28)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = row

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Image = image
	icon.LayoutOrder = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromScale(0.1, 0.8)
	icon.Parent = row

	local valueLabel = Instance.new("TextLabel")
	valueLabel.AutomaticSize = Enum.AutomaticSize.X
	valueLabel.BackgroundTransparency = 1
	valueLabel.FontFace = COMIC_FONT
	valueLabel.LayoutOrder = 2
	valueLabel.Size = UDim2.fromScale(0, 1)
	valueLabel.Text = tostring(value)
	valueLabel.TextColor3 = Color3.fromRGB(72, 232, 91)
	valueLabel.TextScaled = true
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.Parent = row
	addStroke(valueLabel)

	return row
end

return function(itemInfo, adornee: BasePart): BillboardGui
	local existingBillboard = adornee:FindFirstChild("ItemInfo")
	if existingBillboard then
		existingBillboard:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ItemInfo"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = MAX_DISTANCE
	billboard.Size = BILLBOARD_SIZE
	billboard.StudsOffsetWorldSpace = Vector3.new(0, adornee.Size.Y / 2 + 1, 0)
	billboard.Parent = adornee

	local nameLabel = Instance.new("TextLabel")
	nameLabel.AutomaticSize = Enum.AutomaticSize.Y
	nameLabel.BackgroundTransparency = 1
	nameLabel.FontFace = COMIC_FONT
	nameLabel.Size = UDim2.fromScale(1, 0.38)
	nameLabel.Text = itemInfo.Name
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.Parent = billboard
	addStroke(nameLabel)

	createStatRow(Images.Cash, itemInfo.Price, UDim2.fromScale(0, 0.4)).Parent = billboard
	createStatRow(Images.Binoculars, itemInfo.GuestPay, UDim2.fromScale(0, 0.7)).Parent = billboard

	return billboard
end
