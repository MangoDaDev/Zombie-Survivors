local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunRewardsController = require(ReplicatedStorage.Controllers.RunRewardsController)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Button = require(script.Parent.Parent.Classes.Button)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local source = Vide.source

local PANEL_BACK = Color3.fromRGB(35, 73, 43)
local PANEL_FACE = Color3.fromRGB(71, 190, 104)
local TEXT_OUTLINE = Color3.fromRGB(25, 59, 32)

local function textStroke()
	return create "UIStroke" {
		Color = TEXT_OUTLINE,
		StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		Thickness = 0.055,
	}
end

return function()
	local pendingCoins = source(RunRewardsController.GetPendingCoins())
	local topOffset = source(SafeArea.GetTopOffset(18))
	local pendingConnection = RunRewardsController.GetPendingCoinsChangedSignal():Connect(function(value)
		pendingCoins(value)
	end)
	local safeAreaConnection = SafeArea.GetChangedSignal():Connect(function()
		topOffset(SafeArea.GetTopOffset(18))
	end)

	cleanup(function()
		pendingConnection:Disconnect()
		safeAreaConnection:Disconnect()
	end)

	return create "Frame" {
		Name = "RunRewardsDisplay",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = PANEL_BACK,
		BorderSizePixel = 0,
		Position = function()
			return UDim2.new(1, -18, 0, topOffset())
		end,
		Size = UDim2.new(0.14, 140, 0.105, 82),
		ZIndex = 30,
		create "UICorner" { CornerRadius = UIStyle.CornerRadius },
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = PANEL_BACK,
			Thickness = UIStyle.OutlineThickness,
		},
		create "ImageLabel" {
			Name = "Glow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = UIStyle.GlowTexture,
			ImageColor3 = PANEL_FACE,
			ImageTransparency = 0.88,
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromScale(1.12, 1.38),
		},
		create "Frame" {
			Name = "Content",
			BackgroundColor3 = PANEL_FACE,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0.94, 0),
			ZIndex = 31,
			create "UICorner" { CornerRadius = UIStyle.CornerRadius },
			create "UIGradient" {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 218, 124)),
					ColorSequenceKeypoint.new(1, PANEL_FACE),
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
				ZIndex = 32,
			},
			create "UIStroke" {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = UIStyle.Colors.Paper,
				Thickness = UIStyle.OutlineThickness,
				Transparency = UIStyle.InsideStrokeTransparency,
			},
			create "TextLabel" {
				Name = "Heading",
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.fromScale(0.06, 0.05),
				Size = UDim2.fromScale(0.88, 0.17),
				Text = "RUN REWARDS",
				TextColor3 = UIStyle.Colors.Paper,
				TextScaled = true,
				ZIndex = 34,
				textStroke(),
			},
			create "TextLabel" {
				Name = "Amount",
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.fromScale(0.05, 0.23),
				Size = UDim2.fromScale(0.9, 0.22),
				Text = function()
					return string.format("+%s COINS THIS RUN", FormatNumber(pendingCoins()) or "0")
				end,
				TextColor3 = Color3.fromRGB(255, 231, 116),
				TextScaled = true,
				ZIndex = 34,
				textStroke(),
			},
			create "TextLabel" {
				Name = "Instruction",
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.fromScale(0.07, 0.45),
				Size = UDim2.fromScale(0.86, 0.13),
				Text = "RETURN TO BASE TO BANK THEM",
				TextColor3 = UIStyle.Colors.Paper,
				TextScaled = true,
				ZIndex = 34,
				textStroke(),
			},
			create "Frame" {
				Name = "ClaimButton",
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.07, 0.62),
				Size = UDim2.fromScale(0.86, 0.28),
				ZIndex = 34,
				Button({
					Text = "RETURN TO BASE & CLAIM",
					BackgroundColor3 = Color3.fromRGB(241, 180, 67),
					Size = UDim2.fromScale(1, 1),
					OnActivated = RunRewardsController.ReturnToBaseAndClaim,
				}),
			},
		},
	}
end
