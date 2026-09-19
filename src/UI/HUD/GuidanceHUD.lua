local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source

local LocalPlayer = Players.LocalPlayer
local DEFAULT_WIDTH = 220
local HEIGHT = 52
local EDGE_MARGIN = 18
local TARGET_GAP = 18
local MINIMUM_WIDTH = 96

local function GetWorldPosition(Target: Instance): Vector3?
	if Target:IsA("BasePart") then return Target.Position end
	if Target:IsA("Model") then return Target:GetPivot().Position end
end

return function()
	local Text = Source(RuntimeState.Get(LocalPlayer, "GuidanceText"))
	local Target = Source(RuntimeState.Get(LocalPlayer, "GuidanceTarget"))
	local Placement = Source(RuntimeState.Get(LocalPlayer, "GuidancePlacement"))
	local TargetPosition = Source(UDim2.new(0.5, 0, 0, SafeArea.GetTopOffset(44)))
	local GuidanceWidth = Source(DEFAULT_WIDTH)
	local ArrowRotation = Source(90)
	local ArrowDirection = Source(Vector2.yAxis)
	local ArrowPosition = Source(Vector2.new(0.5, 0.86))
	local HasTarget = Source(false)
	local FloatProgress = Source(0)
	local PointerProgress = Source(0)
	local FloatValue = Instance.new("NumberValue")
	local PointerValue = Instance.new("NumberValue")
	local FloatTween = TweenService:Create(
		FloatValue,
		TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Value = 1 }
	)
	local PointerTween = TweenService:Create(
		PointerValue,
		TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Value = 1 }
	)
	local IsAnimating = false

	local function SetAnimationEnabled(IsEnabled: boolean)
		if IsAnimating == IsEnabled then return end
		IsAnimating = IsEnabled
		if IsEnabled then
			FloatTween:Play()
			PointerTween:Play()
		else
			FloatTween:Cancel()
			PointerTween:Cancel()
			FloatValue.Value = 0
			PointerValue.Value = 0
		end
	end

	SetAnimationEnabled(type(Text()) == "string" and Text() ~= "")
	local Connections = {
		RuntimeState.GetChangedSignal(LocalPlayer, "GuidanceText"):Connect(function(Value)
			Text(Value)
			SetAnimationEnabled(type(Value) == "string" and Value ~= "")
		end),
		RuntimeState.GetChangedSignal(LocalPlayer, "GuidanceTarget"):Connect(Target),
		RuntimeState.GetChangedSignal(LocalPlayer, "GuidancePlacement"):Connect(Placement),
		FloatValue.Changed:Connect(FloatProgress),
		PointerValue.Changed:Connect(PointerProgress),
		RunService.RenderStepped:Connect(function()
			local CurrentTarget = Target()
			local ViewportSize = Workspace.CurrentCamera.ViewportSize
			local ScreenPosition
			local HeightOffset = 135
			if CurrentTarget and CurrentTarget:IsA("GuiObject") and CurrentTarget.Visible then
				ScreenPosition = CurrentTarget.AbsolutePosition + CurrentTarget.AbsoluteSize / 2
			elseif CurrentTarget then
				if CurrentTarget:IsA("Model") and CurrentTarget.Parent and CurrentTarget.Parent.Name == "CrateRewards" then
					HeightOffset = 170
				end
				local WorldPosition = GetWorldPosition(CurrentTarget)
				if WorldPosition then
					local Projected = Workspace.CurrentCamera:WorldToViewportPoint(WorldPosition)
					ScreenPosition = Vector2.new(Projected.X, Projected.Y)
				end
			end
			if ScreenPosition then
				local MinimumY = SafeArea.GetTopOffset(44)
				local IsRightPlacement = Placement() == "Right"
					and CurrentTarget
					and CurrentTarget:IsA("GuiObject")
				local IndicatorPosition
				if IsRightPlacement then
					-- Keep this step beside the button, with enough room to click it on narrow screens.
					local TargetRight = CurrentTarget.AbsolutePosition.X + CurrentTarget.AbsoluteSize.X
					local AvailableWidth = ViewportSize.X - EDGE_MARGIN - TARGET_GAP - TargetRight
					local Width = math.clamp(AvailableWidth, MINIMUM_WIDTH, DEFAULT_WIDTH)
					GuidanceWidth(Width)
					IndicatorPosition = Vector2.new(
						TargetRight + TARGET_GAP + Width / 2,
						math.clamp(
							ScreenPosition.Y,
							MinimumY + HEIGHT / 2,
							ViewportSize.Y - EDGE_MARGIN - HEIGHT / 2
						)
					)
					ArrowPosition(Vector2.new(0.08, 0.5))
				else
					GuidanceWidth(DEFAULT_WIDTH)
					IndicatorPosition = Vector2.new(
						math.clamp(ScreenPosition.X, DEFAULT_WIDTH / 2 + 10, ViewportSize.X - DEFAULT_WIDTH / 2 - 10),
						math.clamp(ScreenPosition.Y - HeightOffset, MinimumY, ViewportSize.Y - 90)
					)
					ArrowPosition(Vector2.new(0.5, 0.86))
				end
				local Direction = ScreenPosition - IndicatorPosition
				if Direction.Magnitude > 1 then
					ArrowDirection(Direction.Unit)
					ArrowRotation(math.deg(math.atan2(Direction.Y, Direction.X)))
				end
				TargetPosition(UDim2.fromOffset(IndicatorPosition.X, IndicatorPosition.Y))
				HasTarget(true)
			else
				GuidanceWidth(DEFAULT_WIDTH)
				ArrowPosition(Vector2.new(0.5, 0.86))
				TargetPosition(UDim2.new(0.5, 0, 0, SafeArea.GetTopOffset(44)))
				HasTarget(false)
			end
		end),
	}
	Cleanup(function()
		for _, Connection in Connections do Connection:Disconnect() end
		FloatTween:Cancel()
		PointerTween:Cancel()
		FloatValue:Destroy()
		PointerValue:Destroy()
	end)

	return Create "Frame" {
		Name = "GuidanceHUD",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(20, 29, 43),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = function()
			return TargetPosition() + UDim2.fromOffset(0, -3 + FloatProgress() * 6)
		end,
		Size = function() return UDim2.fromOffset(GuidanceWidth(), HEIGHT) end,
		Visible = function() return type(Text()) == "string" and Text() ~= "" end,
		ZIndex = 50,
		Create "UICorner" { CornerRadius = UDim.new(0, 13) },
		Create "UIStroke" {
			Color = Color3.fromRGB(72, 209, 238),
			Thickness = 3,
		},
		Create "TextLabel" {
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Size = UDim2.fromScale(1, 0.78),
			Text = function() return Text() or "" end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 51,
			Create "UITextSizeConstraint" { MaxTextSize = 24, MinTextSize = 12 },
		},
		Create "TextLabel" {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Position = function()
				local Motion = ArrowDirection() * PointerProgress() * 9
				local Position = ArrowPosition()
				return UDim2.fromScale(Position.X, Position.Y) + UDim2.fromOffset(Motion.X, Motion.Y)
			end,
			Rotation = ArrowRotation,
			Size = UDim2.fromOffset(32, 28),
			Text = ">",
			TextColor3 = Color3.fromRGB(72, 209, 238),
			TextScaled = true,
			Visible = HasTarget,
			ZIndex = 51,
		},
	}
end
