local ReplicatedStorage = game:GetService("ReplicatedStorage")
local vide = require(ReplicatedStorage.Packages.vide)
local Confirmation = require(script.Parent.Classes.Confirmation)
local Notifications = require(script.Parent.HUD.Notifications)
local PartyTeleporterMenu = require(script.Parent.HUD.PartyTeleporterMenu)
local RageBar = require(script.Parent.HUD.RageBar)
local RunHUD = require(script.Parent.HUD.RunHUD)
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
		-- RunHUD is always mounted so Studio's promoted destination can activate reactively without remounting App.
		RunHUD(),
		-- The Creation Menu is presentation-only; party membership, settings, and departure stay authoritative.
		PartyTeleporterMenu(),
		Confirmation.Component(),
		-- RageBar owns reactive Game-map visibility so Studio destination promotion needs no App remount.
		RageBar(),
	}
end
