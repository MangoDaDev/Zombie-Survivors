local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source
local Spring = Vide.spring

local LocalPlayer = Players.LocalPlayer

return function()
	local IsFixing = Source(RuntimeState.Get(LocalPlayer, "IsFixing", false) == true)
	local RadiusVisible = Source(RuntimeState.Get(LocalPlayer, "CleaningRadiusVisible", false) == true)
	local BrushRadius = Source(RuntimeState.Get(LocalPlayer, "CleaningBrushRadius", 0))
	local StepName = Source(RuntimeState.Get(LocalPlayer, "CleaningStepName", "Cleaning"))
	local StepComplete = Source(RuntimeState.Get(LocalPlayer, "CleaningStepComplete", false) == true)
	local ProgressTarget = Source(RuntimeState.Get(LocalPlayer, "CleaningProgress", 0))
	local Progress = Spring(ProgressTarget, 0.16, 0.85)
	local CursorPosition = Source(UserInputService:GetMouseLocation())
	local Connections = {
		RuntimeState.GetChangedSignal(LocalPlayer, "IsFixing"):Connect(function(Value)
			IsFixing(Value == true)
		end),
		RuntimeState.GetChangedSignal(LocalPlayer, "CleaningRadiusVisible"):Connect(function(Value)
			RadiusVisible(Value == true)
		end),
		RuntimeState.GetChangedSignal(LocalPlayer, "CleaningBrushRadius"):Connect(function(Value)
			BrushRadius(Value or 0)
		end),
		RuntimeState.GetChangedSignal(LocalPlayer, "CleaningStepName"):Connect(function(Value)
			StepName(Value or "Cleaning")
		end),
		RuntimeState.GetChangedSignal(LocalPlayer, "CleaningStepComplete"):Connect(function(Value)
			StepComplete(Value == true)
		end),
		RuntimeState.GetChangedSignal(LocalPlayer, "CleaningProgress"):Connect(function(Value)
			ProgressTarget(Value or 0)
		end),
		RuntimeState.GetChangedSignal(LocalPlayer, "CleaningCursorPosition"):Connect(function(Value)
			if typeof(Value) == "Vector2" then CursorPosition(Value) end
		end),
	}
	Cleanup(function()
		for _, Connection in Connections do Connection:Disconnect() end
	end)

	return Create "Frame" {
		Name = "CleaningHUD",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = IsFixing,
		Create "Frame" {
			Name = "BrushRadius",
			Visible = function() return RadiusVisible() and BrushRadius() > 0 end,
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(120, 220, 255),
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			Position = function()
				local Position = CursorPosition()
				return UDim2.fromOffset(Position.X, Position.Y)
			end,
			Size = function()
				local Diameter = BrushRadius() * 2
				return UDim2.fromOffset(Diameter, Diameter)
			end,
			Create "UICorner" { CornerRadius = UDim.new(1, 0) },
			Create "UIStroke" {
				Color = Color3.fromRGB(210, 245, 255),
				Thickness = 2,
				Transparency = 0.25,
			},
		},
		Create "Frame" {
			Name = "Progress",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(22, 30, 42),
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 1, -50),
			Size = UDim2.fromScale(0.38, 0.065),
			Create "UICorner" { CornerRadius = UDim.new(0, 12) },
			Create "UIStroke" {
				Color = Color3.fromRGB(115, 210, 255),
				Thickness = 2,
				Transparency = 0.35,
			},
			Create "Frame" {
				Name = "Track",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(48, 62, 78),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.84),
				Size = UDim2.fromScale(0.92, 0.22),
				ClipsDescendants = true,
				Create "UICorner" { CornerRadius = UDim.new(1, 0) },
				Create "Frame" {
					Name = "Fill",
					BackgroundColor3 = Color3.fromRGB(80, 205, 255),
					BorderSizePixel = 0,
					Size = function() return UDim2.fromScale(math.clamp(Progress(), 0, 1), 1) end,
					Create "UICorner" { CornerRadius = UDim.new(1, 0) },
					Create "UIGradient" {
						Color = ColorSequence.new(Color3.fromRGB(71, 183, 255), Color3.fromRGB(126, 255, 225)),
					},
				},
			},
			Create "TextLabel" {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.04, 0.05),
				Size = UDim2.fromScale(0.92, 0.55),
				FontFace = UIStyle.Font,
				Text = function()
					if StepComplete() then return `{StepName()} Complete!` end
					return `{StepName()} - {math.round(Progress() * 100)}%`
				end,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				Create "UITextSizeConstraint" { MaxTextSize = 22, MinTextSize = 13 },
			},
		},
	}
end
