local ReplicatedStorage = game:GetService("ReplicatedStorage")

local dataService = require(ReplicatedStorage.Packages.dataservice).client
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local vide = require(ReplicatedStorage.Packages.vide)

local cleanup = vide.cleanup
local create = vide.create
local source = vide.source

return function()
	local cash = source(dataService:get("Cash"))
	cleanup(dataService:getChangedSignal("Cash"):Connect(function(value)
		cash(value)
	end))

	return create "Frame" {
		Name = "BottomRight",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.98, 0.96),
		Size = UDim2.fromScale(0.25, 0.08),
		create "TextLabel" {
			BackgroundTransparency = 1,
			Font = Enum.Font.Bangers,
			Size = UDim2.fromScale(1, 1),
			Text = function()
				return `Cash: ${FormatNumber(cash()) or "0"}`
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
