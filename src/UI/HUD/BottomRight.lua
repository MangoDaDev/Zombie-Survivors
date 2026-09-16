local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local dataService = require(ReplicatedStorage.Packages.dataservice).client
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local vide = require(ReplicatedStorage.Packages.vide)

local cleanup = vide.cleanup
local create = vide.create
local source = vide.source
local spring = vide.spring

return function()
	local Cash = source(dataService:get("Cash"))
	local CashScaleTarget = source(1)
	local CashScale = spring(CashScaleTarget, 0.18, 0.75)
	local CashGain = source(0)
	local CashGainProgress = source(1)
	local PreviousCash = Cash()
	local ResetThread: thread?
	local CashGainValue = Instance.new("NumberValue")
	local CashGainTween: Tween?
	local CashGainConnection = CashGainValue.Changed:Connect(CashGainProgress)

	local function ShowCashGain(Amount: number)
		if CashGainProgress() >= 0.99 then CashGain(0) end
		CashGain(CashGain() + Amount)
		CashGainValue.Value = 0
		if CashGainTween then CashGainTween:Cancel() end
		CashGainTween = TweenService:Create(
			CashGainValue,
			TweenInfo.new(1.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = 1 }
		)
		CashGainTween:Play()
	end

	local CashChangedConnection = dataService:getChangedSignal("Cash"):Connect(function(Value)
		Cash(Value)
		if type(Value) == "number" and type(PreviousCash) == "number" and Value > PreviousCash then
			ShowCashGain(Value - PreviousCash)
			CashScaleTarget(1.18)
			if ResetThread then
				task.cancel(ResetThread)
			end
			ResetThread = task.delay(0.1, function()
				ResetThread = nil
				CashScaleTarget(1)
			end)
		end
		PreviousCash = Value
	end)
	cleanup(function()
		CashChangedConnection:Disconnect()
		CashGainConnection:Disconnect()
		if CashGainTween then CashGainTween:Cancel() end
		CashGainValue:Destroy()
		if ResetThread then
			task.cancel(ResetThread)
		end
	end)

	return create "Frame" {
		Name = "BottomRight",
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.98, 0.96),
		Size = UDim2.fromScale(0.25, 0.08),
		create "UIScale" {
			Scale = CashScale,
		},
		create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			Padding = UDim.new(0.03, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
		create "ImageLabel" {
			BackgroundTransparency = 1,
			Image = Images.Cash,
			LayoutOrder = 1,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.22, 0.9),
			create "UIAspectRatioConstraint" {
				AspectRatio = 1,
			},
		},
		create "TextLabel" {
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			LayoutOrder = 2,
			Size = UDim2.fromScale(0, 1),
			Text = function()
				return FormatNumber(Cash()) or "0"
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
			create "TextLabel" {
				Name = "CashGain",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = function()
					return UDim2.fromScale(0.5, -0.08 - CashGainProgress() * 0.55)
				end,
				Size = UDim2.fromScale(0.8, 0.58),
				Text = function()
					return `+${FormatNumber(CashGain()) or "0"}`
				end,
				TextColor3 = UIStyle.Colors.Green,
				TextScaled = true,
				TextTransparency = function()
					return math.clamp((CashGainProgress() - 0.5) / 0.5, 0, 1)
				end,
				Visible = function()
					return CashGain() > 0 and CashGainProgress() < 1
				end,
				ZIndex = 10,
				create "UIStroke" {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
					Color = UIStyle.Colors.Ink,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.06,
					Transparency = function()
						return math.clamp((CashGainProgress() - 0.5) / 0.5, 0, 1)
					end,
				},
				create "UITextSizeConstraint" {
					MaxTextSize = 30,
					MinTextSize = 10,
				},
			},
		},
	}
end
