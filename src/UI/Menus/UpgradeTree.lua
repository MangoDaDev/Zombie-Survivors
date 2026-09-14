local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local UpgradeConfig = require(ReplicatedStorage.Modules.Game.UpgradeConfig)
local UpgradeLogic = require(ReplicatedStorage.Modules.Game.UpgradeLogic)
local DataService = require(ReplicatedStorage.Packages.dataservice).client
local FormatNumber = require(ReplicatedStorage.Modules.Math.FormatNumber)
local Images = require(ReplicatedStorage.Modules.UI.Images)
local Networker = require(ReplicatedStorage.Packages.networker)
local Sounds = require(ReplicatedStorage.Modules.UI.Sounds)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Derive = Vide.derive
local Source = Vide.source
local Spring = Vide.spring

local LocalPlayer = Players.LocalPlayer

local StateColors = {
	Locked = Color3.fromRGB(61, 69, 83),
	Available = Color3.fromRGB(42, 190, 226),
	Purchased = Color3.fromRGB(80, 235, 151),
}

local function GetConnectionState(Ownership, FromUpgrade, ToUpgrade): string
	if UpgradeLogic.IsPurchased(Ownership, ToUpgrade.Id) then return "Purchased" end
	if UpgradeLogic.IsPurchased(Ownership, FromUpgrade.Id) then return "Available" end
	return "Locked"
end

local function CreateConnector(Ownership, FromUpgrade, ToUpgrade)
	local Difference = ToUpgrade.Position - FromUpgrade.Position
	local Midpoint = (ToUpgrade.Position + FromUpgrade.Position) / 2
	local TargetColor = Derive(function()
		return StateColors[GetConnectionState(Ownership(), FromUpgrade, ToUpgrade)]
	end)
	local Color = Spring(TargetColor, 0.22, 0.82)
	return Create "Frame" {
		Name = `{FromUpgrade.Id}To{ToUpgrade.Id}`,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color,
		BackgroundTransparency = function()
			return if GetConnectionState(Ownership(), FromUpgrade, ToUpgrade) == "Locked" then 0.62 else 0.08
		end,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(Midpoint.X, Midpoint.Y),
		Rotation = math.deg(math.atan2(Difference.Y, Difference.X)),
		Size = UDim2.fromOffset(Difference.Magnitude, 8),
		ZIndex = 1,
		Create "UICorner" { CornerRadius = UDim.new(1, 0) },
		Create "UIGradient" {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 190, 220)),
			Transparency = NumberSequence.new(0.15, 0.55),
		},
	}
end

local function CreateNode(Ownership, SelectedId, Upgrade)
	local Hovered = Source(false)
	local Pressed = Source(false)
	local State = Derive(function()
		return UpgradeLogic.GetState(Ownership(), Upgrade)
	end)
	local Scale = Spring(Derive(function()
		if Pressed() then return 0.92 end
		if SelectedId() == Upgrade.Id then return 1.09 end
		return if Hovered() then 1.05 else 1
	end), 0.16, 0.82)
	local Color = Spring(Derive(function()
		return StateColors[State()]
	end), 0.2, 0.85)
	local Icon = Images[Upgrade.Icon] or Images.Upgrade

	return Create "Frame" {
		Name = Upgrade.Id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(Upgrade.Position.X, Upgrade.Position.Y),
		Size = UDim2.fromOffset(UpgradeConfig.NodeSize, UpgradeConfig.NodeSize),
		ZIndex = 3,
		Create "UIAspectRatioConstraint" { AspectRatio = 1 },
		Create "UIScale" { Scale = Scale },
		Create "ImageLabel" {
			Name = "Hexagon",
			BackgroundTransparency = 1,
			Image = Images.Hexagon,
			ImageColor3 = Color,
			ImageTransparency = function()
				return if State() == "Locked" then 0.32 else 0
			end,
			Rotation = 0,
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
			Create "UIAspectRatioConstraint" { AspectRatio = 1 },
		},
		Create "ImageLabel" {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = Icon,
			ImageColor3 = function()
				return if State() == "Locked" then Color3.fromRGB(125, 133, 148) else Color3.new(1, 1, 1)
			end,
			ImageTransparency = function()
				return if State() == "Locked" then 0.45 else 0
			end,
			Position = UDim2.fromScale(0.5, if Upgrade.ShortValue then 0.43 else 0.5),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromScale(0.42, 0.42),
			ZIndex = 4,
		},
		Upgrade.ShortValue and Create "TextLabel" {
			Name = "Value",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			FontFace = UIStyle.Font,
			Position = UDim2.fromScale(0.5, 0.84),
			Size = UDim2.fromScale(0.68, 0.2),
			Text = Upgrade.ShortValue,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			ZIndex = 4,
			Create "UIStroke" { Color = Color3.fromRGB(17, 24, 39), Thickness = 2 },
		} or nil,
		Create "ImageLabel" {
			Name = "Lock",
			AnchorPoint = Vector2.new(1, 1),
			BackgroundColor3 = Color3.fromRGB(26, 31, 43),
			BackgroundTransparency = function() return if State() == "Locked" then 0 else 1 end,
			Image = Images.Lock,
			ImageTransparency = function() return if State() == "Locked" then 0 else 1 end,
			Position = UDim2.fromScale(0.9, 0.9),
			Size = UDim2.fromScale(0.27, 0.27),
			ZIndex = 5,
			Create "UICorner" { CornerRadius = UDim.new(1, 0) },
		},
		Create "TextButton" {
			Active = true,
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "",
			ZIndex = 6,
			MouseEnter = function()
				Hovered(true)
				SelectedId(Upgrade.Id)
				Sounds.Play("HoverStart", LocalPlayer.PlayerGui)
			end,
			MouseLeave = function() Hovered(false); Pressed(false) end,
			InputBegan = function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then Pressed(true) end
			end,
			InputEnded = function(Input)
				if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then Pressed(false) end
			end,
			Activated = function() SelectedId(Upgrade.Id); Pressed(false); Sounds.Play("Click", LocalPlayer.PlayerGui) end,
		},
	}
end

return function()
	local Ownership = Source(DataService:get("Upgrades") or { Start = true })
	local SelectedId = Source("ExtraDisplay")
	local IsOpen = Source(false)
	local IsPurchasing = Source(false)
	local Feedback = Source("")
	local Network = Networker.client.new("UpgradeController", {})
	local DataConnection = DataService:getChangedSignal("Upgrades"):Connect(function(Value)
		Ownership(if type(Value) == "table" then Value else { Start = true })
	end)
	Cleanup(function() DataConnection:Disconnect() end)

	local PanelScale = Spring(Derive(function() return if IsOpen() then 1 else 0.9 end), 0.2, 0.82)
	local PanelTransparency = Spring(Derive(function() return if IsOpen() then 0 else 1 end), 0.18, 0.9)
	local CanvasChildren = {}
	for _, FromUpgrade in UpgradeConfig.Upgrades do
		for _, ConnectedId in FromUpgrade.ConnectedUpgrades do
			local ToUpgrade = UpgradeConfig.Get(ConnectedId)
			if ToUpgrade then table.insert(CanvasChildren, CreateConnector(Ownership, FromUpgrade, ToUpgrade)) end
		end
	end
	for _, Upgrade in UpgradeConfig.Upgrades do table.insert(CanvasChildren, CreateNode(Ownership, SelectedId, Upgrade)) end

	local CanvasProperties = {
		Name = "TreeCanvas",
		Active = true,
		BackgroundColor3 = Color3.fromRGB(17, 23, 36),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(UpgradeConfig.CanvasSize.X, UpgradeConfig.CanvasSize.Y),
		ScrollBarImageColor3 = Color3.fromRGB(81, 183, 217),
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.XY,
		Size = UDim2.fromScale(1, 1),
	}
	for _, Child in CanvasChildren do table.insert(CanvasProperties, Child) end

	local function PurchaseSelected()
		if IsPurchasing() then return end
		local Upgrade = UpgradeConfig.Get(SelectedId())
		if not Upgrade or UpgradeLogic.GetState(Ownership(), Upgrade) ~= "Available" then return end
		IsPurchasing(true)
		Feedback("Purchasing...")
		task.spawn(function()
			local Success, Message, NewOwnership = Network:fetch("Purchase", Upgrade.Id)
			if Success and type(NewOwnership) == "table" then
				Ownership(NewOwnership)
				Feedback("Upgrade purchased!")
				Sounds.Play("Buy", LocalPlayer.PlayerGui)
			else
				Feedback(Message or "Purchase failed")
				Sounds.Play("Error", LocalPlayer.PlayerGui)
			end
			IsPurchasing(false)
		end)
	end

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
			Size = UDim2.fromOffset(76, 76),
			ZIndex = 25,
			Create "UICorner" { CornerRadius = UDim.new(0, 18) },
			Create "UIStroke" { Color = Color3.fromRGB(72, 209, 238), Thickness = 3 },
			Create "ImageLabel" { BackgroundTransparency = 1, Image = Images.Upgrade, Position = UDim2.fromScale(0.18, 0.12), Size = UDim2.fromScale(0.64, 0.64), ZIndex = 26 },
			Create "TextLabel" { BackgroundTransparency = 1, FontFace = UIStyle.Font, Position = UDim2.fromScale(0.05, 0.72), Size = UDim2.fromScale(0.9, 0.2), Text = "UPGRADES", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, ZIndex = 26 },
			Create "TextButton" { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 27, Activated = function() IsOpen(not IsOpen()); Sounds.Play("Click", LocalPlayer.PlayerGui) end },
		},
		Create "CanvasGroup" {
			Name = "UpgradeTree",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(10, 15, 26),
			BorderSizePixel = 0,
			GroupTransparency = PanelTransparency,
			Interactable = IsOpen,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.88, 0.82),
			Visible = function() return PanelTransparency() < 0.995 end,
			ZIndex = 21,
			Create "UIScale" { Scale = PanelScale },
			Create "UICorner" { CornerRadius = UDim.new(0, 22) },
			Create "UIStroke" { Color = Color3.fromRGB(56, 91, 124), Thickness = 3 },
			Create "TextLabel" { BackgroundTransparency = 1, FontFace = UIStyle.Font, Position = UDim2.fromScale(0.025, 0.018), Size = UDim2.fromScale(0.5, 0.07), Text = "UPGRADE TREE", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24 },
			Create "TextButton" { AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromRGB(191, 61, 73), Position = UDim2.fromScale(0.978, 0.025), Size = UDim2.fromOffset(46, 40), Text = "X", TextColor3 = Color3.new(1, 1, 1), TextScaled = true, FontFace = UIStyle.Font, ZIndex = 24, Activated = function() IsOpen(false); Sounds.Play("Click", LocalPlayer.PlayerGui) end, Create "UICorner" { CornerRadius = UDim.new(0, 10) } },
			Create "Frame" { AnchorPoint = Vector2.new(0, 1), BackgroundTransparency = 1, Position = UDim2.fromScale(0.025, 0.985), Size = UDim2.fromScale(0.7, 0.89), Create "UICorner" { CornerRadius = UDim.new(0, 16) }, Create "UIStroke" { Color = Color3.fromRGB(42, 63, 86), Thickness = 2 }, Create "UIPadding" { PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 4) }, Create "ScrollingFrame" (CanvasProperties) },
			Create "Frame" {
				Name = "SelectionPanel",
				AnchorPoint = Vector2.new(1, 1),
				BackgroundColor3 = Color3.fromRGB(24, 32, 48),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.978, 0.985),
				Size = UDim2.fromScale(0.255, 0.89),
				ZIndex = 23,
				Create "UICorner" { CornerRadius = UDim.new(0, 16) },
				Create "UIStroke" { Color = Color3.fromRGB(53, 83, 112), Thickness = 2 },
				Create "TextLabel" { BackgroundTransparency = 1, FontFace = UIStyle.Font, Position = UDim2.fromScale(0.07, 0.06), Size = UDim2.fromScale(0.86, 0.1), Text = function() local Upgrade = UpgradeConfig.Get(SelectedId()); return if Upgrade then Upgrade.Name else "Select an upgrade" end, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextWrapped = true, ZIndex = 24 },
				Create "TextLabel" { BackgroundTransparency = 1, FontFace = UIStyle.Font, Position = UDim2.fromScale(0.08, 0.19), Size = UDim2.fromScale(0.84, 0.18), Text = function() local Upgrade = UpgradeConfig.Get(SelectedId()); return if Upgrade then Upgrade.Description else "" end, TextColor3 = Color3.fromRGB(197, 207, 222), TextScaled = true, TextWrapped = true, ZIndex = 24, Create "UITextSizeConstraint" { MaxTextSize = 22, MinTextSize = 13 } },
				Create "TextLabel" { BackgroundTransparency = 1, FontFace = UIStyle.Font, Position = UDim2.fromScale(0.08, 0.4), Size = UDim2.fromScale(0.84, 0.07), Text = function() local Upgrade = UpgradeConfig.Get(SelectedId()); return if Upgrade then `TEST: {Upgrade.TestEffectLabel}` else "" end, TextColor3 = Color3.fromRGB(105, 190, 216), TextScaled = true, TextWrapped = true, ZIndex = 24, Create "UITextSizeConstraint" { MaxTextSize = 18, MinTextSize = 11 } },
				Create "TextLabel" { BackgroundTransparency = 1, FontFace = UIStyle.Font, Position = UDim2.fromScale(0.08, 0.5), Size = UDim2.fromScale(0.84, 0.08), Text = function() local Upgrade = UpgradeConfig.Get(SelectedId()); return if Upgrade then `$ {FormatNumber(Upgrade.Cost) or "0"}` else "" end, TextColor3 = Color3.fromRGB(91, 232, 112), TextScaled = true, ZIndex = 24 },
				Create "TextLabel" { BackgroundTransparency = 1, FontFace = UIStyle.Font, Position = UDim2.fromScale(0.08, 0.6), Size = UDim2.fromScale(0.84, 0.13), Text = function() local Upgrade = UpgradeConfig.Get(SelectedId()); if not Upgrade then return "" end; local State = UpgradeLogic.GetState(Ownership(), Upgrade); if State ~= "Locked" then return State end; local Missing = UpgradeLogic.GetMissingPrerequisiteNames(Ownership(), Upgrade); return `Requires: {table.concat(Missing, ", ")}` end, TextColor3 = function() local Upgrade = UpgradeConfig.Get(SelectedId()); return if Upgrade then StateColors[UpgradeLogic.GetState(Ownership(), Upgrade)] else Color3.new(1, 1, 1) end, TextScaled = true, TextWrapped = true, ZIndex = 24, Create "UITextSizeConstraint" { MaxTextSize = 21, MinTextSize = 12 } },
				Create "Frame" { AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Position = UDim2.fromScale(0.5, 0.76), Size = UDim2.fromScale(0.86, 0.09), ZIndex = 24, Create "UIListLayout" { HorizontalAlignment = Enum.HorizontalAlignment.Center }, Button({ Text = function() local Upgrade = UpgradeConfig.Get(SelectedId()); if not Upgrade then return "SELECT" end; local State = UpgradeLogic.GetState(Ownership(), Upgrade); return if State == "Available" then (if IsPurchasing() then "WAIT..." else "BUY") else string.upper(State) end, Enabled = function() local Upgrade = UpgradeConfig.Get(SelectedId()); return Upgrade ~= nil and UpgradeLogic.GetState(Ownership(), Upgrade) == "Available" and not IsPurchasing() end, BackgroundColor3 = Color3.fromRGB(35, 174, 110), OnActivated = PurchaseSelected }) },
				Create "TextLabel" { BackgroundTransparency = 1, FontFace = UIStyle.Font, Position = UDim2.fromScale(0.08, 0.88), Size = UDim2.fromScale(0.84, 0.06), Text = Feedback, TextColor3 = Color3.fromRGB(225, 229, 238), TextScaled = true, ZIndex = 24, Create "UITextSizeConstraint" { MaxTextSize = 17, MinTextSize = 10 } },
			},
		},
	}
end
