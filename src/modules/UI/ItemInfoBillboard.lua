local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local ItemInteractionConfig = require(ReplicatedStorage.Modules.Game.ItemInteractionConfig)
local RarityInfo = require(ReplicatedStorage.Modules.Game.RarityInfo)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)

local BILLBOARD_SIZE = UDim2.fromScale(7.5, 4.6)
local BILLBOARD_HEIGHT_OFFSET = 2
local BILLBOARD_HEIGHT_SCALE = 0.18
local COMIC_FONT = UIStyle.Font
local ITEM_INFO_TAG = "ItemInfoBillboard"

local function addStroke(label: TextLabel)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.new(0, 0, 0)
	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = 0.05
	stroke.Parent = label
end

local function createStatRow(image: string, value: number, position: UDim2, ValuePrefix: string?, RowHeight: number?, IconWidth: number?): Frame
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = position
	row.Size = UDim2.fromScale(1, RowHeight or 0.28)

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
	icon.Size = UDim2.fromScale(IconWidth or 0.1, 0.8)
	icon.Parent = row

	local valueLabel = Instance.new("TextLabel")
	valueLabel.AutomaticSize = Enum.AutomaticSize.X
	valueLabel.BackgroundTransparency = 1
	valueLabel.FontFace = COMIC_FONT
	valueLabel.LayoutOrder = 2
	valueLabel.Size = UDim2.fromScale(0, 1)
	valueLabel.Text = `{ValuePrefix or ""}{FormatNumber(value) or "0"}`
	valueLabel.TextColor3 = Color3.fromRGB(72, 232, 91)
	valueLabel.TextScaled = true
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.Parent = row
	addStroke(valueLabel)

	return row
end

return function(itemInfo, adornee: BasePart, fixingState): BillboardGui
	local existingBillboard = adornee:FindFirstChild("ItemInfo")
	if existingBillboard then
		existingBillboard:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ItemInfo"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = ItemInteractionConfig.ItemBillboardMaxDistance
	billboard.Size = BILLBOARD_SIZE
	local ItemModel = adornee:FindFirstAncestorOfClass("Model")
	local ItemHeight = if ItemModel then ItemModel:GetExtentsSize().Y else adornee.Size.Y
	billboard.StudsOffsetWorldSpace = Vector3.new(0, ItemHeight / 2 + BILLBOARD_HEIGHT_OFFSET + ItemHeight * BILLBOARD_HEIGHT_SCALE, 0)
	billboard.Parent = adornee

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.FontFace = COMIC_FONT
	nameLabel.Position = UDim2.fromScale(0, 0.16)
	nameLabel.Size = UDim2.fromScale(1, 0.26)
	local IsCleaningComplete = CleaningConfig.IsCleaningComplete(fixingState)
	-- Keep the item name hidden until cleaning is complete; its rarity is intentionally always visible.
	nameLabel.Text = if IsCleaningComplete then itemInfo.Name else "???"
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = true
	nameLabel.Parent = billboard
	addStroke(nameLabel)
	local rarityGradient = Instance.new("UIGradient")
	rarityGradient.Name = "RarityGradient"
	rarityGradient.Color = RarityInfo.Get(itemInfo.Rarity).Gradient
	rarityGradient.Parent = nameLabel

	local RarityLabel = Instance.new("TextLabel")
	RarityLabel.Name = "Rarity"
	RarityLabel.BackgroundTransparency = 1
	RarityLabel.FontFace = COMIC_FONT
	RarityLabel.Position = UDim2.fromScale(0.2, 0.38)
	RarityLabel.Size = UDim2.fromScale(0.6, 0.12)
	RarityLabel.Text = itemInfo.Rarity
	RarityLabel.TextColor3 = Color3.new(1, 1, 1)
	RarityLabel.TextScaled = true
	RarityLabel.Parent = billboard
	addStroke(RarityLabel)
	local RarityTextGradient = rarityGradient:Clone()
	RarityTextGradient.Parent = RarityLabel

	local GuestPayRow = createStatRow(Images.Binoculars, itemInfo.GuestPay, UDim2.fromScale(0, 0.5), "$", 0.24, 0.14)
	GuestPayRow.Name = "GuestPay"
	GuestPayRow.Parent = billboard
	local DisplayValue = if IsCleaningComplete then itemInfo.SaleValue else itemInfo.Price
	local PriceRow = createStatRow(Images.Cash, DisplayValue, UDim2.fromScale(0, 0.73), nil, 0.18, 0.09)
	PriceRow.Name = "Price"
	PriceRow.Parent = billboard
	local RequiredSteps = CleaningConfig.GetStepsForItem(itemInfo)
	if fixingState and fixingState.Completed ~= true and #RequiredSteps > 0 and Images.FixIcons then
		local fixRow = Instance.new("Frame")
		fixRow.Name = "FixIcons"
		fixRow.BackgroundTransparency = 1
		fixRow.Position = UDim2.fromScale(0, 0.88)
		fixRow.Size = UDim2.fromScale(1, 0.12)
		fixRow.Parent = billboard
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Parent = fixRow
		for _, Step in RequiredSteps do
			local StepState = type(fixingState.Steps) == "table" and fixingState.Steps[Step.Id] or nil
			local IconImage = Images.FixIcons[Step.IconName]
			if IconImage and (type(StepState) ~= "table" or StepState.Completed ~= true) then
				local FixIcon = Instance.new("ImageLabel")
				FixIcon.Name = Step.IconName
				FixIcon.BackgroundTransparency = 1
				FixIcon.Image = IconImage
				FixIcon.ScaleType = Enum.ScaleType.Fit
				FixIcon.Size = UDim2.fromScale(0.14, 1)
				FixIcon.Parent = fixRow
			end
		end
	end

	CollectionService:AddTag(billboard, ITEM_INFO_TAG)

	return billboard
end
