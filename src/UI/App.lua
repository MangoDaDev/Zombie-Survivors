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
local source = vide.source

return function()
	local isUpgradeTreeOpen = source(false)

	return create "ScreenGui" {
		Name = "App",
		-- Keep this enabled; topbar clearance is handled by the HUD's explicit safe offsets.
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		create "Frame" {
			Name = "GameplayUI",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			-- Hide the gameplay HUD while the full-screen upgrade tree is open.
			Visible = function() return not isUpgradeTreeOpen() end,
			BottomRight(),
			CarryOverlay(),
			CleaningHUD(),
			CrateResetTimer(),
			FixingOverlay(),
			Notifications(),
			Confirmation.Component(),
		},
		UpgradeTree(isUpgradeTreeOpen),
		-- Keep tutorial guidance above the tree so the Sponge purchase remains clear.
		GuidanceHUD(),
	}
end
