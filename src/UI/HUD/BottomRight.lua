local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dataService = require(ReplicatedStorage.Packages.dataservice).client
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local vide = require(ReplicatedStorage.Packages.vide)

local cleanup = vide.cleanup
local create = vide.create
local source = vide.source
local spring = vide.spring

return function()
	local cash = source(dataService:get("Cash"))
	local cashScaleTarget = source(1)
	local cashScale = spring(cashScaleTarget, 0.18, 0.75)
	local previousCash = cash()
	local resetThread: thread?
	local cashChangedConnection = dataService:getChangedSignal("Cash"):Connect(function(value)
		cash(value)
		if type(value) == "number" and type(previousCash) == "number" and value > previousCash then
			cashScaleTarget(1.18)
			if resetThread then
				task.cancel(resetThread)
			end
			resetThread = task.delay(0.1, function()
				resetThread = nil
				cashScaleTarget(1)
			end)
		end
		previousCash = value
	end)
	cleanup(function()
		cashChangedConnection:Disconnect()
		if resetThread then
			task.cancel(resetThread)
		end
	end)

	return create "Frame" {
		Name = "BottomRight",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.98, 0.96),
		Size = UDim2.fromScale(0.25, 0.08),
		create "UIScale" {
			Scale = cashScale,
		},
		create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0.03, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
		create "ImageLabel" {
			BackgroundTransparency = 1,
			Image = Images.Cash,
			LayoutOrder = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.22, 0.9),
			create "UIAspectRatioConstraint" {
				AspectRatio = 1,
			},
		},
		create "TextLabel" {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			LayoutOrder = 2,
			Size = UDim2.fromScale(0, 1),
			Text = function()
				return FormatNumber(cash()) or "0"
			end,
			TextColor3 = Color3.fromRGB(72, 232, 91),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
				Color = Color3.new(0, 0, 0),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.06,
			},
			create "UITextSizeConstraint" {
				MaxTextSize = 48,
				MinTextSize = 12,
			},
		},
	}
end
