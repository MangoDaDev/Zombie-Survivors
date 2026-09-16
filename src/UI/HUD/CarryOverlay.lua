local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local InventoryController = require(ReplicatedStorage.Controllers.InventoryController)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
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
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.98, 0.04),
		Size = UDim2.fromScale(0.4, 0.075),
		Visible = IsCarrying,
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
		Button({
			Text = "Drop",
			BackgroundColor3 = Color3.fromRGB(190, 72, 54),
			OnActivated = InventoryController.DropCarriedItem,
		}),
	}
end
