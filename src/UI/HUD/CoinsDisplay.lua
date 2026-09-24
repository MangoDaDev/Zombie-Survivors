local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CoinsController = require(ReplicatedStorage.Controllers.CoinsController)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local source = Vide.source

local DARK_GOLD = Color3.fromRGB(94, 69, 23)
local FACE_GOLD = Color3.fromRGB(241, 180, 67)

return function()
	local balance = source(CoinsController.Get())
	local balanceConnection = CoinsController.GetChangedSignal():Connect(function(newBalance)
		if type(newBalance) == "number" then
			balance(newBalance)
		end
	end)

	cleanup(function()
		balanceConnection:Disconnect()
	end)

	return create "Frame" {
		Name = "CoinsDisplay",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = DARK_GOLD,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 18, 0.5, 0),
		Size = UDim2.new(0.1, 120, 0.052, 20),
		ZIndex = 10,
		create "UICorner" {
			CornerRadius = UIStyle.CornerRadius,
		},
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			-- Match the themed underlay so the outside half of the stroke does not read as a separate grey ring.
			Color = DARK_GOLD,
			Thickness = UIStyle.OutlineThickness,
		},
		create "ImageLabel" {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = UIStyle.GlowTexture,
			ImageColor3 = FACE_GOLD,
			ImageTransparency = 0.9,
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.new(1.12, 0, 1.35, 0),
		},
		create "Frame" {
			Name = "Content",
			BackgroundColor3 = FACE_GOLD,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0.88, 0),
			ZIndex = 11,
			create "UICorner" {
				CornerRadius = UIStyle.CornerRadius,
			},
			create "UIGradient" {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 207, 91)),
					ColorSequenceKeypoint.new(1, FACE_GOLD),
				}),
				Rotation = 90,
			},
			create "ImageLabel" {
				Name = "StudTexture",
				BackgroundTransparency = 1,
				Image = UIStyle.StudTexture,
				ImageTransparency = UIStyle.StudTransparency,
				ScaleType = Enum.ScaleType.Tile,
				Size = UDim2.fromScale(1, 1),
				TileSize = UDim2.fromOffset(54, 54),
				ZIndex = 12,
			},
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = UIStyle.Colors.Paper,
				Thickness = UIStyle.OutlineThickness,
				Transparency = UIStyle.InsideStrokeTransparency,
			},
			create "ImageLabel" {
				Name = "Icon",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				Image = Images.Coin,
				Position = UDim2.new(0.035, 0, 0.5, 0),
				Size = UDim2.new(0.21, 8, 0.72, 0),
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 13,
				create "UIAspectRatioConstraint" {
					AspectRatio = 1,
				},
			},
			create "TextLabel" {
				Name = "Amount",
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.new(0.29, 0, 0.5, 0),
				Size = UDim2.new(0.67, -8, 0.68, 0),
				Text = function()
					return FormatNumber(balance()) or "0"
				end,
				TextColor3 = UIStyle.Colors.Paper,
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 13,
				create "UIStroke" {
					Color = DARK_GOLD,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.055,
				},
			},
		},
	}
end
