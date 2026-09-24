local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.vide)
local Confirmation = require(script.Parent.Classes.Confirmation)
local Notifications = require(script.Parent.HUD.Notifications)
local RageBar = require(script.Parent.HUD.RageBar)
local create = vide.create

return function()
	return create "ScreenGui" {
		Name = "App",
		-- Keep the root available for the loading flow and future game-specific composition.
		ClipToDeviceSafeArea = false,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.None,
		-- Simulator-era roll, inventory, currency, and extraction HUD components remain preserved in
		-- UI/HUD, but are intentionally not composed until a future lobby or post-run flow owns them.
		Notifications(),
		RageBar(),
		Confirmation.Component(),
	}
end
