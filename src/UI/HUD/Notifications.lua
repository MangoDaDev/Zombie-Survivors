local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NotificationManager = require(ReplicatedStorage.Modules.UI.NotificationManager)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source

return function()
	local Attention = Source(0)
	local IsVisible = Source(false)
	local Text = Source("")
	local AttentionValue = Instance.new("NumberValue")
	local AttentionTween = TweenService:Create(
		AttentionValue,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Value = 1 }
	)
	local HideThread: thread?

	local function Show(NotificationText: string, Duration: number)
		Text(NotificationText)
		IsVisible(true)
		AttentionTween:Play()

		if HideThread then
			task.cancel(HideThread)
		end

		HideThread = task.delay(Duration, function()
			HideThread = nil
			IsVisible(false)
			AttentionTween:Cancel()
			AttentionValue.Value = 0
		end)
	end

	local NotificationConnection = NotificationManager.GetNotificationAddedSignal():Connect(Show)
	local AttentionConnection = AttentionValue.Changed:Connect(Attention)

	Cleanup(function()
		NotificationConnection:Disconnect()
		AttentionConnection:Disconnect()
		AttentionTween:Cancel()
		AttentionValue:Destroy()

		if HideThread then
			task.cancel(HideThread)
		end
	end)

	return Create "Frame" {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(176, 46, 57),
		BorderSizePixel = 0,
		Position = function()
			return UDim2.fromScale(0.5, 0.035) + UDim2.fromOffset(0, math.sin(Attention() * math.pi) * 4)
		end,
		Rotation = function()
			return math.sin(Attention() * math.pi * 2) * 2.5
		end,
		Size = function()
			local Scale = 1 + math.sin(Attention() * math.pi) * 0.05
			return UDim2.fromOffset(290 * Scale, 54 * Scale)
		end,
		Visible = IsVisible,
		ZIndex = 80,
		Create "UICorner" { CornerRadius = UDim.new(0, 14) },
		Create "UIStroke" {
			Color = Color3.fromRGB(255, 183, 188),
			Thickness = 3,
		},
		Create "TextLabel" {
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Position = UDim2.fromScale(0.05, 0.12),
			Size = UDim2.fromScale(0.9, 0.76),
			Text = Text,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 81,
			Create "UITextSizeConstraint" { MaxTextSize = 24, MinTextSize = 12 },
		},
	}
end
