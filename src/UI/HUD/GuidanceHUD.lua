local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source

local LocalPlayer = Players.LocalPlayer

local function GetWorldPosition(Target: Instance): Vector3?
	if Target:IsA("BasePart") then return Target.Position end
	if Target:IsA("Model") then return Target:GetPivot().Position end
end

return function()
	local Text = Source(RuntimeState.Get(LocalPlayer, "GuidanceText"))
	local Target = Source(RuntimeState.Get(LocalPlayer, "GuidanceTarget"))
	local Position = Source(UDim2.fromScale(0.5, 0.16))
	local ArrowRotation = Source(90)
	local HasTarget = Source(false)
	local Connections = {
		RuntimeState.GetChangedSignal(LocalPlayer, "GuidanceText"):Connect(Text),
		RuntimeState.GetChangedSignal(LocalPlayer, "GuidanceTarget"):Connect(Target),
		RunService.RenderStepped:Connect(function()
			local CurrentTarget = Target()
			local ViewportSize = Workspace.CurrentCamera.ViewportSize
			local ScreenPosition
			if CurrentTarget and CurrentTarget:IsA("GuiObject") and CurrentTarget.Visible then
				ScreenPosition = CurrentTarget.AbsolutePosition + CurrentTarget.AbsoluteSize / 2
			elseif CurrentTarget then
				local WorldPosition = GetWorldPosition(CurrentTarget)
				if WorldPosition then
					local Projected = Workspace.CurrentCamera:WorldToViewportPoint(WorldPosition)
					ScreenPosition = Vector2.new(Projected.X, Projected.Y)
				end
			end
			if ScreenPosition then
				local IndicatorPosition = Vector2.new(
					math.clamp(ScreenPosition.X, 120, ViewportSize.X - 120),
					math.clamp(ScreenPosition.Y - 72, 70, ViewportSize.Y - 90)
				)
				local Direction = ScreenPosition - IndicatorPosition
				if Direction.Magnitude > 1 then ArrowRotation(math.deg(math.atan2(Direction.Y, Direction.X))) end
				Position(UDim2.fromOffset(IndicatorPosition.X, IndicatorPosition.Y))
				HasTarget(true)
			else
				Position(UDim2.fromScale(0.5, 0.16))
				HasTarget(false)
			end
		end),
	}
	Cleanup(function()
		for _, Connection in Connections do Connection:Disconnect() end
	end)

	return Create "Frame" {
		Name = "GuidanceHUD",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(20, 29, 43),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Position = Position,
		Size = UDim2.fromOffset(220, 52),
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
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Position = UDim2.fromScale(0.5, 0.72),
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
