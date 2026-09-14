local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Classes.Button)
local FixingInterface = require(ReplicatedStorage.Modules.UI.FixingInterface)
local Vide = require(ReplicatedStorage.Packages.vide)

local Cleanup = Vide.cleanup
local Create = Vide.create
local Source = Vide.source

local LocalPlayer = Players.LocalPlayer

return function()
	local IsFixing = Source(LocalPlayer:GetAttribute("IsFixing") == true)
	local AttributeConnection = LocalPlayer:GetAttributeChangedSignal("IsFixing"):Connect(function()
		IsFixing(LocalPlayer:GetAttribute("IsFixing") == true)
	end)
	Cleanup(function()
		AttributeConnection:Disconnect()
	end)

	return Create "Frame" {
		Name = "FixingOverlay",
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.98, 0.04),
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
			BackgroundColor3 = Color3.fromRGB(180, 58, 58),
			OnActivated = function()
				FixingInterface.ExitRequested:Fire()
			end,
		}),
	}
end
