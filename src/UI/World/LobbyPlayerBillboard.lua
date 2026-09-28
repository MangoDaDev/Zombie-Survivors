local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Images = require(ReplicatedStorage.Modules.UI.Images)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local source = Vide.source

local BADGE_COLOR = Color3.fromRGB(241, 180, 67)
local CLASS_COLOR = Color3.fromRGB(225, 232, 239)

return function(props)
	local roundsSurvived = source(props.RoundsSurvived)
	local className = source(props.ClassName)
	local changedConnection = props.Changed:Connect(function(newRoundsSurvived: number, newClassName: string)
		roundsSurvived(newRoundsSurvived)
		className(newClassName)
	end)

	cleanup(function()
		changedConnection:Disconnect()
	end)

	return create "BillboardGui" {
		Name = "LobbyPlayerBillboard",
		Adornee = props.Adornee,
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 80,
		-- BillboardGui scale components are world studs, so the overhead card keeps a physical 4:3 size in the lobby.
		Size = UDim2.fromScale(4, 3),
		StudsOffsetWorldSpace = Vector3.new(0, 3.25, 0),
		create "Frame" {
			Name = "Content",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			create "UIAspectRatioConstraint" {
				AspectRatio = 4 / 3,
				DominantAxis = Enum.DominantAxis.Width,
			},
			create "ImageLabel" {
				Name = "RoundsBadge",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Image = Images.Hexagon,
				ImageColor3 = BADGE_COLOR,
				Position = UDim2.fromScale(0.5, 0),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.58, 0.72),
				create "UIAspectRatioConstraint" {
					AspectRatio = 1,
					DominantAxis = Enum.DominantAxis.Height,
				},
				create "TextLabel" {
					Name = "RoundsValue",
					BackgroundTransparency = 1,
					FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
					Position = UDim2.fromScale(0.12, 0.14),
					Size = UDim2.fromScale(0.76, 0.43),
					Text = function()
						return tostring(roundsSurvived())
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					create "UIStroke" {
						Color = UIStyle.Colors.Ink,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.055,
					},
				},
				create "TextLabel" {
					Name = "RoundsCaption",
					BackgroundTransparency = 1,
					FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
					Position = UDim2.fromScale(0.12, 0.59),
					Size = UDim2.fromScale(0.76, 0.23),
					Text = "ROUNDS\nSURVIVED",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					create "UIStroke" {
						Color = UIStyle.Colors.Ink,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.045,
					},
				},
			},
			create "TextLabel" {
				Name = "ClassName",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(25, 30, 38),
				BackgroundTransparency = 0.12,
				BorderSizePixel = 0,
				FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromScale(0.92, 0.25),
				Text = function()
					return string.upper(className())
				end,
				TextColor3 = CLASS_COLOR,
				TextScaled = true,
				create "UICorner" { CornerRadius = UDim.new(0.22, 0) },
				create "UIStroke" {
					Color = UIStyle.Colors.Ink,
					Thickness = 2,
				},
				create "UIPadding" {
					PaddingBottom = UDim.new(0.12, 0),
					PaddingLeft = UDim.new(0.08, 0),
					PaddingRight = UDim.new(0.08, 0),
					PaddingTop = UDim.new(0.12, 0),
				},
			},
		},
	}
end
