local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local FixingInterface = require(ReplicatedStorage.Modules.UI.FixingInterface)
local RuntimeState = require(ReplicatedStorage.Modules.Game.RuntimeState)
local SafeArea = require(ReplicatedStorage.Modules.UI.SafeArea)
local UIStyle = require(ReplicatedStorage.Modules.UI.UIStyle)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source

local LocalPlayer = Players.LocalPlayer

return function()
	local IsFixing = Source(RuntimeState.Get(LocalPlayer, "IsFixing", false) == true)
	local TopOffset = Source(SafeArea.GetTopOffset(16))
	local Connections = {
		RuntimeState.GetChangedSignal(LocalPlayer, "IsFixing"):Connect(function(Value)
			IsFixing(Value == true)
		end),
		SafeArea.GetChangedSignal():Connect(function()
			TopOffset(SafeArea.GetTopOffset(16))
		end),
	}
	Cleanup(function()
		for _, Connection in Connections do Connection:Disconnect() end
	end)

	return Create "Frame" {
		Name = "FixingOverlay",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = function() return UDim2.new(0.98, 0, 0, TopOffset()) end,
		Size = UDim2.fromScale(0.4, 0.075),
		Visible = IsFixing,
		Create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		},
		Button({
			Text = "Stop Cleaning (Q)",
			BackgroundColor3 = UIStyle.Colors.Red,
			OnActivated = function()
				FixingInterface.ExitRequested:Fire()
			end,
		}),
	}
end
