local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.vide)
local Confirmation = require(script.Parent.Classes.Confirmation)
local CoinsDisplay = require(script.Parent.HUD.CoinsDisplay)
local Notifications = require(script.Parent.HUD.Notifications)
local RollInterface = require(script.Parent.HUD.RollInterface)
local create = vide.create

return function()
	return create "ScreenGui" {
		Name = "App",
		-- Keep the root available for the loading flow and future game-specific composition.
		ClipToDeviceSafeArea = false,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		CoinsDisplay(),
		Notifications(),
		RollInterface(),
		Confirmation.Component(),
	}
end
