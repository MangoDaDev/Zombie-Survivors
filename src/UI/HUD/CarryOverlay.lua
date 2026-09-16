local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local InventoryController = require(ReplicatedStorage.Controllers.InventoryController)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source

local LocalPlayer = Players.LocalPlayer

return function()
	local IsCarrying = Source(RuntimeState.Get(LocalPlayer, "IsCarryingItem", false) == true)
	local StateConnection = RuntimeState.GetChangedSignal(LocalPlayer, "IsCarryingItem"):Connect(function(Value)
		IsCarrying(Value == true)
	end)
	Cleanup(function()
		StateConnection:Disconnect()
	end)

	return Create "Frame" {
		Name = "CarryOverlay",
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.96),
		Size = UDim2.fromScale(0.4, 0.075),
		Visible = IsCarrying,
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
		Button({
			Text = "Drop",
			BackgroundColor3 = UIStyle.Colors.Red,
			OnActivated = InventoryController.DropCarriedItem,
		}),
	}
end
