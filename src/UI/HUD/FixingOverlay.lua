local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local FixingInterface = require(ReplicatedStorage.Modules.UI.FixingInterface)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source

local LocalPlayer = Players.LocalPlayer

return function()
	local IsFixing = Source(RuntimeState.Get(LocalPlayer, "IsFixing", false) == true)
	local StateConnection = RuntimeState.GetChangedSignal(LocalPlayer, "IsFixing"):Connect(function(Value)
		IsFixing(Value == true)
	end)
	Cleanup(function()
		StateConnection:Disconnect()
	end)

	return Create "Frame" {
		Name = "FixingOverlay",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.98, 0.065),
		Size = UDim2.fromScale(0.4, 0.075),
		Visible = IsFixing,
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
		Button({
			Text = "Exit Cleaning (Q)",
			BackgroundColor3 = UIStyle.Colors.Red,
			OnActivated = function()
				FixingInterface.ExitRequested:Fire()
			end,
		}),
	}
end
