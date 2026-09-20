local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.vide)
local Confirmation = require(script.Parent.Classes.Confirmation)
local BottomRight = require(script.Parent.HUD.BottomRight)
local CarryOverlay = require(script.Parent.HUD.CarryOverlay)
local CleaningHUD = require(script.Parent.HUD.CleaningHUD)
local CrateResetTimer = require(script.Parent.HUD.CrateResetTimer)
local FixingOverlay = require(script.Parent.HUD.FixingOverlay)
local GuidanceHUD = require(script.Parent.HUD.GuidanceHUD)
local Notifications = require(script.Parent.HUD.Notifications)
local UpgradeTree = require(script.Parent.Menus.UpgradeTree)
local create = vide.create

return function()
	return create "ScreenGui" {
		Name = "App",
		-- Keep this enabled; topbar clearance is handled by the HUD's explicit safe offsets.
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		BottomRight(),
		CarryOverlay(),
		CleaningHUD(),
		CrateResetTimer(),
		FixingOverlay(),
		GuidanceHUD(),
		Notifications(),
		UpgradeTree(),
		Confirmation.Component(),
	}
end
