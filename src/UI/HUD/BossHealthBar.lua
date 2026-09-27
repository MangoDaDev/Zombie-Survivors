local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZombieController = require(ReplicatedStorage.Controllers.ZombieController)
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local cleanup = Vide.cleanup
local create = Vide.create
local source = Vide.source
local spring = Vide.spring

local BOSS_RED = Color3.fromRGB(195, 48, 61)

return function()
	local initialState = ZombieController.GetBossState()
	local state = source(initialState)
	local progressTarget = source(
		if initialState.maximumHealth > 0 then initialState.health / initialState.maximumHealth else 0
	)
	local smoothProgress = spring(progressTarget, 0.16, 0.9)
	local topOffset = source(SafeArea.GetTopOffset(12))

	local stateConnection = ZombieController.GetBossStateChangedSignal():Connect(function(newState)
		state(newState)
		progressTarget(
			if newState.maximumHealth > 0 then math.clamp(newState.health / newState.maximumHealth, 0, 1) else 0
		)
	end)
	local safeAreaConnection = SafeArea.GetChangedSignal():Connect(function()
		topOffset(SafeArea.GetTopOffset(12))
	end)
	cleanup(function()
		stateConnection:Disconnect()
		safeAreaConnection:Disconnect()
	end)

	return create "Frame" {
		Name = "BossHealthBar",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(31, 16, 20),
		BorderSizePixel = 0,
		Position = function()
			-- The round panel owns the first top-center row; the boss bar stays directly below it.
			return UDim2.new(0.5, 0, 0, topOffset() + 78)
		end,
		Size = UDim2.new(0.48, 80, 0.07, 20),
		Visible = function()
			return state().active
		end,
		ZIndex = 95,
		create "UISizeConstraint" {
			MaxSize = Vector2.new(680, 76),
			MinSize = Vector2.new(300, 42),
		},
		create "UIAspectRatioConstraint" {
			AspectRatio = 620 / 72,
			DominantAxis = Enum.DominantAxis.Width,
		},
		create "UICorner" { CornerRadius = UDim.new(0, 4) },
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.fromRGB(154, 47, 58),
			Thickness = 3,
		},
		create "TextLabel" {
			Name = "Title",
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Heavy),
			Position = UDim2.new(0, 12, 0, 7),
			Size = UDim2.new(0.35, -12, 0.34, 0),
			Text = "BOSS ZOMBIE",
			TextColor3 = Color3.fromRGB(255, 226, 211),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 97,
		},
		create "TextLabel" {
			Name = "PhaseLabel",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
			Position = UDim2.new(0.5, 0, 0, 11),
			Size = UDim2.new(0.3, -8, 0.22, 0),
			Text = "ENRAGES AT 50%",
			TextColor3 = Color3.fromRGB(255, 211, 137),
			TextScaled = true,
			ZIndex = 97,
		},
		create "TextLabel" {
			Name = "Value",
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			FontFace = Font.new(UIStyle.Font.Family, Enum.FontWeight.Bold),
			Position = UDim2.new(1, -12, 0, 8),
			Size = UDim2.new(0.35, -12, 0.31, 0),
			Text = function()
				local current = state()
				return string.format(
					"%s / %s",
					FormatNumber(math.ceil(current.health)) or "0",
					FormatNumber(math.ceil(current.maximumHealth)) or "0"
				)
			end,
			TextColor3 = Color3.fromRGB(222, 178, 173),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 97,
		},
		create "Frame" {
			Name = "Track",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(58, 37, 41),
			BorderSizePixel = 0,
			ClipsDescendants = false,
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -24, 0.33, 0),
			ZIndex = 96,
			create "UICorner" { CornerRadius = UDim.new(0, 3) },
			create "Frame" {
				Name = "Fill",
				BackgroundColor3 = BOSS_RED,
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Size = function()
					return UDim2.fromScale(math.clamp(smoothProgress(), 0, 1), 1)
				end,
				ZIndex = 97,
				create "UICorner" { CornerRadius = UDim.new(0, 3) },
				create "UIGradient" {
					Color = ColorSequence.new(Color3.fromRGB(222, 61, 72), Color3.fromRGB(145, 30, 46)),
				},
			},
			create "Frame" {
				Name = "EnrageMarker",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 222, 158),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, 3, 1, 4),
				ZIndex = 98,
			},
		},
	}
end
