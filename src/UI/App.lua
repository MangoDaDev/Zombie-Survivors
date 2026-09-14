local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.vide)
local BottomRight = require(script.Parent.HUD.BottomRight)
local CleaningHUD = require(script.Parent.HUD.CleaningHUD)
local FixingOverlay = require(script.Parent.HUD.FixingOverlay)
local create = vide.create

return function()
	return create "ScreenGui" {
		Name = "App",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		BottomRight(),
		CleaningHUD(),
		FixingOverlay(),
	}
end
