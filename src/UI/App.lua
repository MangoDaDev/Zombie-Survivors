local ReplicatedStorage = game:GetService("ReplicatedStorage")

local vide = require(ReplicatedStorage.Packages.vide)
local AbilityInterface = require(script.Parent.HUD.AbilityInterface)
local Confirmation = require(script.Parent.Classes.Confirmation)
local CoinsDisplay = require(script.Parent.HUD.CoinsDisplay)
local Notifications = require(script.Parent.HUD.Notifications)
local RageBar = require(script.Parent.HUD.RageBar)
local RollControls = require(script.Parent.HUD.RollControls)
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
		RageBar(),
		RollInterface(),
		RollControls(),
		AbilityInterface(),
		Confirmation.Component(),
	}
end
