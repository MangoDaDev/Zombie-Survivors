local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NotificationManager = require(ReplicatedStorage.Modules.UI.NotificationManager)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local Action = Vide.action
local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source

local ALERT_WIDTH = 420
local ALERT_HEIGHT = 28
local ALERT_TWEEN_INFO = TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

return function()
	local AlertContainer: Frame?
	local NotificationConnection: RBXScriptConnection?
	local ActiveAlerts = {}
	local NextLayoutOrder = 0
	local TopOffset = Source(SafeArea.GetTopOffset(76))
	local SafeAreaConnection = SafeArea.GetChangedSignal():Connect(function()
		TopOffset(SafeArea.GetTopOffset(76))
	end)

	local function Show(NotificationText: string, Duration: number, Color: Color3?)
		if not AlertContainer then return end
		NextLayoutOrder += 1

		local Alert = Instance.new("CanvasGroup")
		Alert.Name = "Alert"
		Alert.BackgroundTransparency = 1
		Alert.LayoutOrder = NextLayoutOrder
		Alert.Size = UDim2.fromOffset(ALERT_WIDTH, ALERT_HEIGHT)
		Alert.ZIndex = 80

		local Label = Instance.new("TextLabel")
		Label.Name = "AlertText"
		Label.AnchorPoint = Vector2.new(0.5, 0)
		Label.BackgroundTransparency = 1
		Label.ClipsDescendants = true
		Label.FontFace = UIStyle.Font
		Label.Position = UDim2.fromScale(0.5, 0)
		Label.Size = UDim2.fromScale(0, 1)
		Label.Text = NotificationText
		Label.TextColor3 = Color or UIStyle.Colors.Red
		Label.TextScaled = true
		Label.TextWrapped = true
		Label.ZIndex = 81
		Label.Parent = Alert

		local TextStroke = Instance.new("UIStroke")
		TextStroke.Name = "NotificationStroke"
		TextStroke.Color = UIStyle.Colors.Ink
		TextStroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
		TextStroke.Thickness = 0.06
		TextStroke.Transparency = 0.12
		TextStroke.Parent = Label

		local TextSizeConstraint = Instance.new("UITextSizeConstraint")
		TextSizeConstraint.MaxTextSize = 28
		TextSizeConstraint.MinTextSize = 12
		TextSizeConstraint.Parent = Label

		Alert.Parent = AlertContainer
		Sounds.Play("Alert", Players.LocalPlayer.PlayerGui)

		local TweenIn = TweenService:Create(Label, ALERT_TWEEN_INFO, { Size = UDim2.fromScale(1, 1) })
		local TweenOut = TweenService:Create(Alert, ALERT_TWEEN_INFO, {
			GroupTransparency = 1,
			Size = UDim2.fromOffset(ALERT_WIDTH, 0),
		})
		local AlertState = { TweenIn = TweenIn, TweenOut = TweenOut }
		ActiveAlerts[Alert] = AlertState
		TweenIn:Play()
		AlertState.Thread = task.spawn(function()
			task.wait(Duration)
			if not Alert.Parent then
				ActiveAlerts[Alert] = nil
				return
			end
			TweenOut:Play()
			TweenOut.Completed:Wait()
			ActiveAlerts[Alert] = nil
			Alert:Destroy()
		end)
	end

	Cleanup(function()
		SafeAreaConnection:Disconnect()
		if NotificationConnection then NotificationConnection:Disconnect() end
		for Alert, AlertState in ActiveAlerts do
			AlertState.TweenIn:Cancel()
			AlertState.TweenOut:Cancel()
			if AlertState.Thread then task.cancel(AlertState.Thread) end
			Alert:Destroy()
		end
		table.clear(ActiveAlerts)
	end)

	return Create "Frame" {
		Name = "Notifications",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = function() return UDim2.new(0.5, 0, 0, TopOffset()) end,
		Size = UDim2.fromOffset(ALERT_WIDTH, 260),
		ZIndex = 80,
		Action(function(Instance)
			AlertContainer = Instance :: Frame
			NotificationConnection = NotificationManager.GetNotificationAddedSignal():Connect(Show)
		end),
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		},
	}
end
