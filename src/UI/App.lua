local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.vide)
local BottomRight = require(script.Parent.HUD.BottomRight)
local CleaningHUD = require(script.Parent.HUD.CleaningHUD)
local CrateResetTimer = require(script.Parent.HUD.CrateResetTimer)
local FixingOverlay = require(script.Parent.HUD.FixingOverlay)
local GuidanceHUD = require(script.Parent.HUD.GuidanceHUD)
local UpgradeTree = require(script.Parent.Menus.UpgradeTree)
local create = vide.create

return function()
	return create "ScreenGui" {
		Name = "App",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		BottomRight(),
		CleaningHUD(),
		CrateResetTimer(),
		FixingOverlay(),
		GuidanceHUD(),
		UpgradeTree(),
	}
end
