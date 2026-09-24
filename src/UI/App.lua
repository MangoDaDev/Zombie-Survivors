local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.vide)
local Confirmation = require(script.Parent.Classes.Confirmation)
local Notifications = require(script.Parent.HUD.Notifications)
local create = vide.create

return function()
	return create "ScreenGui" {
		Name = "App",
		-- Keep the root available for the loading flow and future game-specific composition.
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		Notifications(),
		Confirmation.Component(),
	}
end
