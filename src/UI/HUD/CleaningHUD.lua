local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CleaningConfig = require(ReplicatedStorage.Modules.Game.CleaningConfig)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source
local Spring = Vide.spring

local LocalPlayer = Players.LocalPlayer

return function()
	local IsFixing = Source(LocalPlayer:GetAttribute("IsFixing") == true)
	local StepName = Source(LocalPlayer:GetAttribute("CleaningStepName") or "Cleaning")
	local StepComplete = Source(LocalPlayer:GetAttribute("CleaningStepComplete") == true)
	local ProgressTarget = Source(LocalPlayer:GetAttribute("CleaningProgress") or 0)
	local Progress = Spring(ProgressTarget, 0.16, 0.85)
	local CursorPosition = Source(UserInputService:GetMouseLocation())
	local Connections = {
		LocalPlayer:GetAttributeChangedSignal("IsFixing"):Connect(function()
			IsFixing(LocalPlayer:GetAttribute("IsFixing") == true)
		end),
		LocalPlayer:GetAttributeChangedSignal("CleaningStepName"):Connect(function()
			StepName(LocalPlayer:GetAttribute("CleaningStepName") or "Cleaning")
		end),
		LocalPlayer:GetAttributeChangedSignal("CleaningStepComplete"):Connect(function()
			StepComplete(LocalPlayer:GetAttribute("CleaningStepComplete") == true)
		end),
		LocalPlayer:GetAttributeChangedSignal("CleaningProgress"):Connect(function()
			ProgressTarget(LocalPlayer:GetAttribute("CleaningProgress") or 0)
		end),
		RunService.RenderStepped:Connect(function()
			CursorPosition(UserInputService:GetMouseLocation())
		end),
	}
	Cleanup(function()
		for _, Connection in Connections do Connection:Disconnect() end
	end)

	local Diameter = CleaningConfig.BrushRadiusPixels * 2
	return Create "Frame" {
		Name = "CleaningHUD",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = IsFixing,
		Create "Frame" {
			Name = "BrushRadius",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(120, 220, 255),
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			Position = function()
				local Position = CursorPosition()
				return UDim2.fromOffset(Position.X, Position.Y)
			end,
			Size = UDim2.fromOffset(Diameter, Diameter),
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
				Font = Enum.Font.GothamBold,
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
