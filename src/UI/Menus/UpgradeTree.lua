local Players = game:GetService "Players"
local ReplicatedStorage = game:GetService "ReplicatedStorage"
local UserInputService = game:GetService "UserInputService"

local UpgradeConfig = require(ReplicatedStorage.Modules.Game.UpgradeConfig)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)
local DataService = require(ReplicatedStorage.Packages.dataservice).client
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local GuidanceController = require(ReplicatedStorage.Controllers.GuidanceController)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local Networker = require(ReplicatedStorage.Packages.networker)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local Action = Vide.action
local Cleanup = Vide.cleanup
local Create = Vide.create
local Derive = Vide.derive
local Source = Vide.source
local Spring = Vide.spring

local LocalPlayer = Players.LocalPlayer

local StateColors = {
	Available = Color3.fromRGB(45, 190, 229),
	Purchased = Color3.fromRGB(75, 235, 148),
}
local TreeCanvasSize = UpgradeConfig.CameraBounds * 2 + Vector2.one * UpgradeConfig.NodeSize * 2

local function ClampCamera(Position: Vector2): Vector2
	local Bounds = UpgradeConfig.CameraBounds
	return Vector2.new(math.clamp(Position.X, -Bounds.X, Bounds.X), math.clamp(Position.Y, -Bounds.Y, Bounds.Y))
end

local function GetMysteryTransparency(Distance: number?): number
	if Distance == nil then
		return 1
	end
	if Distance == 1 then
		return 0.12
	end
	if Distance == 2 then
		return 0.58
	end
	return 0
end

local function CreateNode(Properties)
	local Upgrade = Properties.Upgrade
	local Hovered = Source(false)
	local Pressed = Source(false)
	local State = Derive(function()
		return UpgradeLogic.GetState(Properties.Ownership(), Upgrade)
	end)
	local RevealDistance = Derive(function()
		return Properties.RevealDistances()[Upgrade.Id]
	end)
	local IsDetailed = Derive(function()
		return RevealDistance() == 0
	end)
	local ShowsDetails = Derive(function()
		return RevealDistance() ~= nil
	end)
	local Transparency = Spring(
		Derive(function()
			if IsDetailed() then
				return 0
			end
			return GetMysteryTransparency(RevealDistance())
		end),
		0.22,
		0.86
	)
	local Scale = Spring(
		Derive(function()
			if Properties.LastPurchasedId() == Upgrade.Id then
				return 1.14
			end
			if Pressed() then
				return 0.94
			end
			return if Hovered() and State() == "Available" then 1.045 else 1
		end),
		0.15,
		0.86
	)
	local Icon = Images[Upgrade.Icon] or Images.Upgrade

	local function CanAfford(): boolean
		return type(Properties.Cash()) == "number" and Properties.Cash() >= Upgrade.Cost
	end

	local function AttemptPurchase()
		Pressed(false)
		if not IsDetailed() or State() ~= "Available" or Properties.IsPurchasing() then
			return
		end
		if not CanAfford() then
			Sounds.Play("Error", LocalPlayer.PlayerGui)
			GuidanceController.ShowLocal("Need More Cash")
			return
		end
		Properties.Purchase(Upgrade)
	end

	return Create "CanvasGroup" {
		Name = Upgrade.Id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = Transparency,
		Position = UDim2.fromOffset(TreeCanvasSize.X / 2 + Upgrade.Position.X, TreeCanvasSize.Y / 2 + Upgrade.Position.Y),
		Size = UDim2.fromOffset(UpgradeConfig.NodeSize, UpgradeConfig.NodeSize),
		Visible = function()
			return Transparency() < 0.985
		end,
		ZIndex = 3,
		Create "UIAspectRatioConstraint" { AspectRatio = 1 },
		Create "UIScale" { Scale = Scale },
		Create "TextLabel" {
			Name = "Title",
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Position = UDim2.fromScale(0.5, 0.08),
			Size = UDim2.fromScale(0.82, 0.28),
			Text = function()
				return if IsDetailed() then Upgrade.Name else "???"
			end,
			TextColor3 = Color3.fromRGB(241, 246, 255),
			TextScaled = true,
			TextTransparency = function()
				return if ShowsDetails() then 0 else 1
			end,
			TextWrapped = true,
			ZIndex = 4,
			Create "UIStroke" {
				Color = Color3.fromRGB(9, 13, 22),
				Thickness = 2,
				Transparency = function()
					return if ShowsDetails() then 0.15 else 1
				end,
			},
			Create "UITextSizeConstraint" { MaxTextSize = 16, MinTextSize = 7 },
		},
		Create "ImageLabel" {
			Name = "Hexagon",
			BackgroundTransparency = 1,
			Image = Images.Hexagon,
			ImageColor3 = function()
				if not IsDetailed() then
					return Color3.fromRGB(5, 6, 8)
				end
				return StateColors[State()] or Color3.fromRGB(35, 41, 52)
			end,
			Rotation = 90,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Create "UIAspectRatioConstraint" { AspectRatio = 1 },
		},
		Create "ImageLabel" {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = function()
				return if IsDetailed() then Icon else Images.Lock
			end,
			ImageColor3 = Color3.new(1, 1, 1),
			ImageTransparency = function()
				return if RevealDistance() == nil then 1 else 0
			end,
			Position = UDim2.fromScale(0.5, 0.53),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.34, 0.34),
			ZIndex = 4,
		},
		Create "TextLabel" {
			Name = "Price",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Position = UDim2.fromScale(0.5, 0.9),
			Size = UDim2.fromScale(0.72, 0.18),
			Text = function()
				return if IsDetailed() then `${FormatNumber(Upgrade.Cost) or "0"}` else "$???"
			end,
			TextColor3 = function()
				if State() == "Available" and not CanAfford() then
					return Color3.fromRGB(255, 75, 75)
				end
				return if State() == "Purchased" then StateColors.Purchased else Color3.fromRGB(241, 246, 255)
			end,
			TextScaled = true,
			TextTransparency = function()
				return if ShowsDetails() then 0 else 1
			end,
			ZIndex = 4,
			Create "UIStroke" {
				Color = Color3.fromRGB(9, 13, 22),
				Thickness = 2,
				Transparency = function()
					return if ShowsDetails() then 0.15 else 1
				end,
			},
			Create "UITextSizeConstraint" { MaxTextSize = 15, MinTextSize = 7 },
		},
		Create "TextButton" {
			Active = function()
				return IsDetailed() and State() == "Available"
			end,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Selectable = function()
				return IsDetailed() and State() == "Available"
			end,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 6,
			MouseEnter = function()
				if IsDetailed() then
					Hovered(true)
					Sounds.Play("HoverStart", LocalPlayer.PlayerGui)
				end
			end,
			MouseLeave = function()
				Hovered(false)
				Pressed(false)
			end,
			InputBegan = function(Input)
				Properties.BeginDrag(Input)
				if
					State() == "Available"
					and (
						Input.UserInputType == Enum.UserInputType.MouseButton1
						or Input.UserInputType == Enum.UserInputType.Touch
					)
				then
					Pressed(true)
				end
			end,
			InputEnded = function(Input)
				if
					Input.UserInputType == Enum.UserInputType.MouseButton1
					or Input.UserInputType == Enum.UserInputType.Touch
				then
					Pressed(false)
				end
			end,
			Activated = function()
				if not Properties.WasDragged() then
					AttemptPurchase()
				end
			end,
		},
	}
end

return function()
	local Ownership = Source(UpgradeLogic.NormalizeOwnership(DataService:get "Upgrades"))
	local Cash = Source(DataService:get "Cash" or 0)
	local IsOpen = Source(false)
	local IsPurchasing = Source(false)
	local LastPurchasedId = Source ""
	local StartUpgrade = UpgradeConfig.Get("Start")
	local CameraTarget = Source(if StartUpgrade then StartUpgrade.Position else Vector2.zero)
	local ZoomTarget = Source(UpgradeConfig.DefaultZoom)
	local CameraPosition = Spring(CameraTarget, 0.16, 0.9)
	local Zoom = Spring(ZoomTarget, 0.16, 0.9)
	local ViewportSize = Source(Vector2.new(800, 500))
	local RevealDistances = Derive(function()
		return UpgradeLogic.GetRevealDistances(Ownership(), UpgradeConfig.MaximumMysteryDistance)
	end)
	local Network = Networker.client.new("UpgradeController", {})
	local Viewport: Frame?
	local ViewportConnection: RBXScriptConnection?
	local DragInput: InputObject?
	local LastDragPosition: Vector2?
	local DragDistance = 0
	local DraggedLastInput = false

	local function BeginDrag(Input: InputObject)
		if
			not IsOpen()
			or (
				Input.UserInputType ~= Enum.UserInputType.MouseButton1
				and Input.UserInputType ~= Enum.UserInputType.Touch
			)
		then
			return
		end
		DragInput = Input
		LastDragPosition = Vector2.new(Input.Position.X, Input.Position.Y)
		DragDistance = 0
		DraggedLastInput = false
	end

	local function WasDragged(): boolean
		return DraggedLastInput
	end

	local function SetZoom(NewZoom: number, ScreenPosition: Vector2?)
		local OldZoom = ZoomTarget()
		NewZoom = math.clamp(NewZoom, UpgradeConfig.MinimumZoom, UpgradeConfig.MaximumZoom)
		if math.abs(NewZoom - OldZoom) < 0.001 then
			return
		end
		local CurrentCamera = CameraTarget()
		if ScreenPosition and Viewport then
			local LocalPosition = ScreenPosition - Viewport.AbsolutePosition
			local Offset = LocalPosition - Viewport.AbsoluteSize / 2
			local TreePosition = CurrentCamera + Offset / OldZoom
			CurrentCamera = TreePosition - Offset / NewZoom
		end
		CameraTarget(ClampCamera(CurrentCamera))
		ZoomTarget(NewZoom)
	end

	local InputChangedConnection = UserInputService.InputChanged:Connect(function(Input)
		if not IsOpen() then
			return
		end
		if Input.UserInputType == Enum.UserInputType.MouseWheel and Viewport then
			local MousePosition = UserInputService:GetMouseLocation()
			local Minimum = Viewport.AbsolutePosition
			local Maximum = Minimum + Viewport.AbsoluteSize
			if
				MousePosition.X >= Minimum.X
				and MousePosition.Y >= Minimum.Y
				and MousePosition.X <= Maximum.X
				and MousePosition.Y <= Maximum.Y
			then
				SetZoom(ZoomTarget() * UpgradeConfig.ZoomStep ^ Input.Position.Z, MousePosition)
			end
			return
		end
		if DragInput == nil or LastDragPosition == nil then
			return
		end
		if DragInput.UserInputType == Enum.UserInputType.Touch and Input ~= DragInput then
			return
		end
		if
			Input.UserInputType ~= Enum.UserInputType.MouseMovement
			and Input.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		local Position = Vector2.new(Input.Position.X, Input.Position.Y)
		local Delta = Position - LastDragPosition
		LastDragPosition = Position
		DragDistance += Delta.Magnitude
		if DragDistance > 6 then
			DraggedLastInput = true
		end
		CameraTarget(ClampCamera(CameraTarget() - Delta / ZoomTarget()))
	end)
	local InputEndedConnection = UserInputService.InputEnded:Connect(function(Input)
		if
			DragInput
			and (
				Input == DragInput
				or DragInput.UserInputType == Enum.UserInputType.MouseButton1
					and Input.UserInputType == Enum.UserInputType.MouseButton1
			)
		then
			DragInput = nil
			LastDragPosition = nil
			task.defer(function()
				DraggedLastInput = false
			end)
		end
	end)
	local UpgradeConnection = DataService:getChangedSignal("Upgrades"):Connect(function(Value)
		Ownership(UpgradeLogic.NormalizeOwnership(Value))
	end)
	local CashConnection = DataService:getChangedSignal("Cash"):Connect(function(Value)
		Cash(if type(Value) == "number" then Value else 0)
	end)
	Cleanup(function()
		InputChangedConnection:Disconnect()
		InputEndedConnection:Disconnect()
		UpgradeConnection:Disconnect()
		CashConnection:Disconnect()
		if ViewportConnection then
			ViewportConnection:Disconnect()
		end
	end)

	local function Purchase(Upgrade)
		if IsPurchasing() then
			return
		end
		IsPurchasing(true)
		task.spawn(function()
			local Success, Reason, NewOwnership = Network:fetch("Purchase", Upgrade.Id)
			if Success and type(NewOwnership) == "table" then
				Ownership(NewOwnership)
				LastPurchasedId(Upgrade.Id)
				Sounds.Play("Buy", LocalPlayer.PlayerGui)
				task.delay(0.14, function()
					if LastPurchasedId() == Upgrade.Id then
						LastPurchasedId ""
					end
				end)
			else
				Sounds.Play("Error", LocalPlayer.PlayerGui)
				if type(Reason) == "string" then
					local Messages = {
						["Invalid request"] = "Try Again",
						["That upgrade cannot be purchased"] = "Upgrade Unavailable",
						["Already purchased"] = "Already Purchased",
						["Requirements not met"] = "Requirements Not Met",
						["Not enough cash"] = "Need More Cash",
					}
					local Message = Messages[Reason] or "Try Again"
					GuidanceController.ShowLocal(Message)
				end
			end
			IsPurchasing(false)
		end)
	end

	local CanvasChildren = {}
	for _, Upgrade in UpgradeConfig.Upgrades do
		table.insert(
			CanvasChildren,
			CreateNode {
				Upgrade = Upgrade,
				Ownership = Ownership,
				Cash = Cash,
				RevealDistances = RevealDistances,
				IsPurchasing = IsPurchasing,
				LastPurchasedId = LastPurchasedId,
				BeginDrag = BeginDrag,
				WasDragged = WasDragged,
				Purchase = Purchase,
			}
		)
	end
	local CanvasProperties = {
		Name = "TreeCanvas",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = function()
			local Position = ViewportSize() / 2 - CameraPosition() * Zoom()
			return UDim2.fromOffset(Position.X, Position.Y)
		end,
		Size = UDim2.fromOffset(TreeCanvasSize.X, TreeCanvasSize.Y),
		Create "UIScale" { Scale = Zoom },
	}
	for _, Child in CanvasChildren do
		table.insert(CanvasProperties, Child)
	end

	local ViewportProperties = {
		Name = "TreeViewport",
		Active = true,
		BackgroundColor3 = Color3.fromRGB(16, 22, 34),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.025, 0.12),
		Size = UDim2.fromScale(0.95, 0.84),
		ZIndex = 22,
		InputBegan = BeginDrag,
		Action(function(Instance)
			Viewport = Instance :: Frame
			ViewportSize(Viewport.AbsoluteSize)
			ViewportConnection = Viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				ViewportSize(Viewport.AbsoluteSize)
			end)
		end),
		Create "UICorner" { CornerRadius = UDim.new(0, 15) },
		Create "Frame"(CanvasProperties),
	}

	local PanelScale = Spring(
		Derive(function()
			return if IsOpen() then 1 else 0.92
		end),
		0.18,
		0.86
	)
	local PanelTransparency = Spring(
		Derive(function()
			return if IsOpen() then 0 else 1
		end),
		0.17,
		0.9
	)

	return Create "Frame" {
		Name = "UpgradeTreeRoot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Create "Frame" {
			Name = "OpenButton",
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = Color3.fromRGB(31, 42, 62),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.015, 0.52),
			Size = UDim2.fromOffset(68, 68),
			ZIndex = 25,
			Create "UICorner" { CornerRadius = UDim.new(0, 16) },
			Create "UIStroke" { Color = Color3.fromRGB(72, 209, 238), Thickness = 3 },
			Create "ImageLabel" {
				BackgroundTransparency = 1,
				Image = Images.Upgrade,
				Position = UDim2.fromScale(0.2, 0.1),
				Size = UDim2.fromScale(0.6, 0.6),
				ZIndex = 26,
			},
			Create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.fromScale(0.06, 0.7),
				Size = UDim2.fromScale(0.88, 0.2),
				Text = "UPGRADES",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 26,
			},
			Create "TextButton" {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				ZIndex = 27,
				Activated = function()
					local Opening = not IsOpen()
					if Opening then
						CameraTarget(if StartUpgrade then StartUpgrade.Position else Vector2.zero)
						ZoomTarget(UpgradeConfig.DefaultZoom)
						GuidanceController.OpenedUpgradeTree()
					end
					IsOpen(Opening)
					Sounds.Play("Click", LocalPlayer.PlayerGui)
				end,
			},
		},
		Create "CanvasGroup" {
			Name = "UpgradeTree",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(10, 15, 26),
			BorderSizePixel = 0,
			GroupTransparency = PanelTransparency,
			Interactable = IsOpen,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.7, 0.66),
			Visible = function()
				return PanelTransparency() < 0.995
			end,
			ZIndex = 21,
			Create "UIAspectRatioConstraint" { AspectRatio = 1.618 },
			Create "UISizeConstraint" { MaxSize = Vector2.new(1_100, 650) },
			Create "UIScale" { Scale = PanelScale },
			Create "UICorner" { CornerRadius = UDim.new(0, 20) },
			Create "UIStroke" { Color = Color3.fromRGB(56, 91, 124), Thickness = 3 },
			Create "TextLabel" {
				BackgroundTransparency = 1,
				FontFace = UIStyle.Font,
				Position = UDim2.fromScale(0.03, 0.025),
				Size = UDim2.fromScale(0.45, 0.07),
				Text = "UPGRADE TREE",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 24,
			},
			Create "TextButton" {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(174, 55, 67),
				Position = UDim2.fromScale(0.975, 0.025),
				Size = UDim2.fromOffset(40, 36),
				Text = "X",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				FontFace = UIStyle.Font,
				ZIndex = 26,
				Activated = function()
					IsOpen(false)
					Sounds.Play("Click", LocalPlayer.PlayerGui)
				end,
				Create "UICorner" { CornerRadius = UDim.new(0, 9) },
			},
			Create "Frame" {
				Name = "ZoomControls",
				AnchorPoint = Vector2.new(1, 1),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.965, 0.94),
				Size = UDim2.fromOffset(42, 92),
				ZIndex = 26,
				Create "UIListLayout" { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 8) },
				Create "TextButton" {
					BackgroundColor3 = Color3.fromRGB(35, 48, 68),
					FontFace = UIStyle.Font,
					Size = UDim2.fromOffset(42, 42),
					Text = "+",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 27,
					Activated = function()
						SetZoom(ZoomTarget() * UpgradeConfig.ZoomStep)
						Sounds.Play("Click", LocalPlayer.PlayerGui)
					end,
					Create "UICorner" { CornerRadius = UDim.new(0, 10) },
				},
				Create "TextButton" {
					BackgroundColor3 = Color3.fromRGB(35, 48, 68),
					FontFace = UIStyle.Font,
					Size = UDim2.fromOffset(42, 42),
					Text = "−",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 27,
					Activated = function()
						SetZoom(ZoomTarget() / UpgradeConfig.ZoomStep)
						Sounds.Play("Click", LocalPlayer.PlayerGui)
					end,
					Create "UICorner" { CornerRadius = UDim.new(0, 10) },
				},
			},
			Create "Frame"(ViewportProperties),
		},
	}
end
