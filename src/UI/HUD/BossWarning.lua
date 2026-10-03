local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudTexture = require(script.Parent.Parent.Classes.StudTexture)
local RoundController = require(ReplicatedStorage.Controllers.RoundController)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local ResponsiveLayout = require(ReplicatedStorage.Modules.UI.ResponsiveLayout)
local ResponsiveViewport = require(script.Parent.Parent.ResponsiveViewport)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local source = Vide.source
local spring = Vide.spring

local function getStageTitle(stage: string): string
	if stage == "Entrance" then
		return "BOSS EMERGING"
	elseif stage == "Buildup" then
		return "BOSS ROUND"
	end
	return "WARNING"
end

return function()
	local responsiveViewport = ResponsiveViewport()
	local state = source(RoundController.GetState().bossAnnouncement)
	local scaleTarget = source(if state().active then 1 else 0.9)
	local animatedScale = spring(scaleTarget, 0.18, 0.78)
	local stateConnection = RoundController.GetStateChangedSignal():Connect(function(roundState)
		state(roundState.bossAnnouncement)
		scaleTarget(if roundState.bossAnnouncement.active then 1 else 0.9)
	end)
	cleanup(function()
		stateConnection:Disconnect()
	end)

	local layout = {}
	layout.Viewport = ResponsiveLayout.Viewport(responsiveViewport)
	layout.BossWarning = ResponsiveLayout.Base(UDim2.fromScale(0.9, 0.16), layout.Viewport, 580 / 112)
	layout.LeftAccent = ResponsiveLayout.Child(UDim2.new(0, 7, 1, -20), layout.BossWarning)
	layout.RightAccent = ResponsiveLayout.Child(UDim2.new(0, 7, 1, -20), layout.BossWarning)
	layout.Stage = ResponsiveLayout.Child(UDim2.new(1, -58, 0.2, 0), layout.BossWarning)
	layout.BossName = ResponsiveLayout.Child(UDim2.new(1, -58, 0.34, 0), layout.BossWarning)
	layout.Message = ResponsiveLayout.Child(UDim2.new(1, -58, 0.16, 0), layout.BossWarning)

	return create "Frame" {
		Name = "BossWarning",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = function()
			return Color3.fromRGB(18, 14, 18):Lerp(state().color, 0.12)
		end,
		BorderSizePixel = 0,
		Position = layout.BossWarning.Position(UDim2.new(0.5, 0, 0.18, 0), Vector2.new(0.5, 0)),
		Size = layout.BossWarning.Size,
		Visible = function()
			return state().active
		end,
		ZIndex = 140,
		create "UIAspectRatioConstraint" {
			AspectRatio = 580 / 112,
			AspectType = Enum.AspectType.FitWithinMaxSize,
		},
		create "UIScale" { Scale = animatedScale },
		create "UICorner" { CornerRadius = UDim.new(0, 5) },
		create "UIStroke" {
			Color = function()
				return state().color
			end,
			Thickness = 3,
		},
		StudTexture({ ZIndex = 141, ImageTransparency = 0.82, TileSize = UDim2.fromOffset(36, 36) }),
		create "Frame" {
			Name = "LeftAccent",
			BackgroundColor3 = function()
				return state().color
			end,
			BorderSizePixel = 0,
			Position = layout.BossWarning.Scale(UDim2.fromOffset(10, 10)),
			Size = layout.LeftAccent.Size,
			ZIndex = 142,
		},
		create "Frame" {
			Name = "RightAccent",
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = function()
				return state().color
			end,
			BorderSizePixel = 0,
			Position = layout.BossWarning.Scale(UDim2.new(1, -10, 0, 10)),
			Size = layout.RightAccent.Size,
			ZIndex = 142,
		},
		create "TextLabel" {
			Name = "Stage",
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
			Position = layout.BossWarning.Scale(UDim2.new(0, 29, 0, 9)),
			Size = layout.Stage.Size,
			Text = function()
				return getStageTitle(state().stage)
			end,
			TextColor3 = function()
				return state().color:Lerp(Color3.new(1, 1, 1), 0.42)
			end,
			TextScaled = true,
			ZIndex = 143,
		},
		create "TextLabel" {
			Name = "BossName",
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
			Position = layout.BossWarning.Scale(UDim2.new(0, 29, 0.31, 0)),
			Size = layout.BossName.Size,
			Text = function()
				return string.upper(state().bossName)
			end,
			TextColor3 = Color3.fromRGB(255, 242, 226),
			TextScaled = true,
			ZIndex = 143,
			create "UIStroke" {
				Color = Color3.fromRGB(6, 4, 5),
				StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
				Thickness = 0.045,
			},
		},
		create "TextLabel" {
			Name = "Message",
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
			Position = layout.BossWarning.Scale(UDim2.new(0, 29, 0.72, 0)),
			Size = layout.Message.Size,
			Text = function()
				return state().message
			end,
			TextColor3 = Color3.fromRGB(216, 207, 202),
			TextScaled = true,
			ZIndex = 143,
		},
	}
end
